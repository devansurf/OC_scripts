local modem = require("component").modem
local computer = require("component").computer
local term = require("term")
local thread = require("thread")
local event = require("event")
local serialization = require("serialization")
-- Listen for messages and display them with timestamp
-- store information containing mined areas
-- display that information via hologram
-- send commands for robots to mine
local log = {
    -- key -> os.Time, value -> message
}
local data = {
    ["angle"] = 0,
    ["originX"]= 0,
    ["originY"]= 0,
    ["originZ"]= 0,
    ["radius"] = 16, -- 4 chunks wide and length, radius height
    ["ports"] = {},
    ["terrainData"] = {},
}
local kill = false
local filename = "data.txt"
local miningQueue = 0

local function succ()
    computer.beep("..")
    os.sleep(3)
    term.clear()
    interface()
end

local function err(message)
    computer.beep("..-")
    print(message)
    os.sleep(2)
    term.clear()
    interface()
end

function sign(number)
    return (number > 0 and 1) or (number == 0 and 0) or -1
end

local function simplify(n, s, loops)
    local gaps = loops -1
    if s == "COS" then
        for i = 1, loops do
            -- if the cos is less than the upper bound of the gaps
            if n+0.001 < sign(n)*(math.cos(math.rad(45))/i) and n > sign(n)*(math.cos(math.rad(45))/(i+1)) then
                -- belonging gap found!
                
                return sign(n)*(gaps/i)/(loops)
            end
        end
        return math.floor(n+0.5)
    elseif s == "SIN" then
        for i = 1, loops do
            -- if the sin is less than the upper bound of the gaps
            if n+0.001 < sign(n)*(math.sin(math.rad(45))/i) and n > sign(n)*(math.sin(math.rad(45))/(i+1)) then
                -- belonging gap found!
                return sign(n)*(gaps/i)/(loops)
            end
        end
        return math.floor(n+0.5)
    end
end
local function portExists(port)
    for p, _ in pairs(data["ports"]) do
        if tonumber(p) == tonumber(port) then
            return true
        end
    end
    return false
end
local function createLog(time, message)
    return tostring(time .. " : " .. message)
end
-- create a thread for listening to a port
function createNetworkThread(port)
    thread.create(function(port)
        modem.open(port)
        log[os.time()] = "Opened port " .. port
        while not kill do     
            -- this component generates a signal named modem_message if a message from another network card is received.
            --It has the signature localAddress: string, remoteAddress: string, port: number, distance: number, ...
            local _, _, from, p, _, message = event.pull("modem_message")
            log[os.time()] = message
            if miningQueue > 0 and message == "Awaiting" then
                miningQueue = miningQueue - 1
                os.sleep(3)
                deployRobot(port)     
            end
        end
        modem.close(port)
    end, port)
end

function addPort()
    print("\nAdd a new port for robots to deploy from...\n")
    local p, x, y, z
    while not p or portExists(p) do
        print("Add a non-existing port number:")
        p = tonumber(term.read())
    end
    while x == nil do
        print("Insert the X coordinate where the robot will deploy:")
        x = tonumber(term.read())
    end  
    while y == nil do
        print("Insert the Y coordinate where the robot will deploy:")
        y = tonumber(term.read())
    end
    while z == nil do
        print("Insert the Z coordinate where the robot will deploy:")
        z = tonumber(term.read())
    end
    data["ports"][tostring(p)] = {X = x, Y = y, Z = z}
    createNetworkThread(tonumber(port))
    print("Port successfully added!")
    succ()
end
function printData()
    term.clear()
    for k, v in pairs(data) do
        if type(v) == 'number' then
            print(k .. " : " .. v)
        end
    end
    term.read()
    term.clear()
    interface()
end
function generateData()
    print("\nYou chose the option to modify data, will you want to proceed? Type 1 for yes\n")
    local input = tonumber(term.read())
    if input == 1 then
        local oX, oY, oZ, r = _, _, _, 0
        while oX == nil do
            print("Insert new X origin point: ")
            oX = tonumber(term.read())
            data["originX"] = oX
        end  
        while oY == nil do
            print("Insert new Y origin point: ")
            oY = tonumber(term.read())
            data["originY"] = oY
        end
        while oZ == nil do
            print("Insert new Z origin point: ")
            oZ = tonumber(term.read())
            data["originZ"] = oZ
        end
        while r >= 28 or r <= 4 do
            print("Insert new Radius (min 4, max 28): ")
            r = tonumber(term.read())
            data["radius"] = r
        end
    end
    print("\n Saved new data \n")
    local file = io.open(filename, "w")
    file:write(serialization.serialize(data))
    file:close()
    succ()
end
function loadData()
    local file = io.open(filename,"r")
    local fileData = file:read()
    file:close()
    if fileData then
        data = serialization.unserialize(fileData)
    else
        file = io.open(filename, "w")
        file:write(serialization.serialize(data))
        file:close()
    end
end
-- find a location in the world where it hasnt been declared mined
function getData(port)
    -- retrieve previous deploy locations data
    -- create a radius around the deploy locations to represent mined areas in 2 dimensions (planar)
    -- new location will be an increment on x or z axis by 2*radius
    --represents the amount of loops
    local file = io.open(filename, "w")
    local angle = tonumber(data["angle"])
    local originX = tonumber(data["originX"])
    local originY = tonumber(data["originY"])
    local originZ = tonumber(data["originZ"])
    local RADIUS = tonumber(data["radius"])
    local ports = data["ports"]
    local loops = 1 + math.floor(angle / 360 ) 
    -- formula returns coordinates depending on the angle of rotation. Hence forming a blocky spiral since it only increments when loops is incremented
    local x, z = originX + simplify(math.cos(math.rad(angle)), "COS", loops)*RADIUS*loops*2, originZ + simplify(math.sin(math.rad(angle)), "SIN", loops)*RADIUS*loops*2
    angle = angle + (45/loops)
    
    -- update angle
    data["angle"] = angle
    file:write(serialization.serialize(data))
    file:close()

    return {targetX = x , targetY = originY ,targetZ = z, R = RADIUS, X = ports[port].X, Y = ports[port].Y, Z = ports[port].Z}
end
-- create interactable interface
function displayLog()
    term.clear()
    for time, message in pairs(log) do
        print(tostring(time).. " : " .. message)
    end
    term.read()
    term.clear()
    interface()
end

function deployRobot(port)
    local d = getData(tostring(port))
    local s_data = serialization.serialize(d)
    print("Broadcasting to port ".. port)
    modem.broadcast(port, s_data)
    local message = "Robot of port " .. port .. " deployed to the coordinates: " .. d.targetX .. " X, ".. d.targetY .. " Y, ".. d.targetZ .. " Z"
    print(message)
    log[os.time()] = message
    succ()
end
-- automatically deploy robots
function addMiningQueue()
    term.clear()
    print("The current mining queue is set at: " .. miningQueue)
    local add
    while not add do
        print("Add onto the mining queue: ")
        add = tonumber(term.read())
    end
    miningQueue = miningQueue + add
    print("The mining queue has changed to: ".. miningQueue)
    succ()
end
function interface()
    -- create interface for user to interact with commands:
    print("(1) Insert new port with coordinates")
    print("(2) Open log")
    print("(3) Inject new data")
    print("(4) Inspect data")
    print("(5) Generate hologram")
    print("(6) Deploy robot")
    print("(7) Add mining queue")
    print("(0) Kill Server (not recommended)")
    input = tonumber(term.read())
    if input then
        if input == 1 then
            addPort()
        elseif input == 2 then -- Open log
            displayLog()
        elseif input == 3 then
            generateData()
        elseif input == 4 then
            printData()
        elseif input == 6 then -- deploy robot
            print("Type in the robot port to deploy.")
            local port = tonumber(term.read())
            if port and portExists(port) then
                deployRobot(port)
            else
                err("Invalid port, returning to main interface...")
            end
        elseif input == 7 then
            addMiningQueue()
        else
            -- kill threads
            kill = true
            print("Turn off machine dummy")
        end
    else
        err("Invalid Input, try choosing a valid option.")
    end 
end

loadData()
for port, _ in pairs(data["ports"]) do
    createNetworkThread(tonumber(port))
end
interface()