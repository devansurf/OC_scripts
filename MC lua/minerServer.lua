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

local ports = {
     -- key -> port, value -> deploy position
    ["1"] = {X = -332, Y = 62, Z = -223}
}
local log = {
    -- key -> os.Time, value -> message
}
local data = {
    ["angle"] = 0,
    ["originX"]= 0,
    ["originY"]= 0,
    ["originZ"]= 0,
    ["terrainData"] = {},
}
local kill = false
local RADIUS = 16 -- 4 chunks wide and length, radius height
local filename = "data.txt"

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

local function getSignOf(n)
    if n > 0.1 then
        return 1
    elseif n < -0.1 then
        return -1
    else
        return 0
    end
end
local function portExists(port)
    for p, _ in pairs(ports) do
        if tonumber(p) == port then
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
            local _, _, from, port, _, message = event.pull("modem_message")
            log[os.time()] = message
        end
        modem.close(port)
    end, port)
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
    print("\nCAUTION, all terrain data will be lost, will you want to proceed? Type 1 for yes\n")
    local input = tonumber(term.read())
    if input == 1 then
        local oX, oY, oZ
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
        data["angle"] = 0
        data["originX"] = 0
        data["originY"] = 0
        data["originZ"] = 0
        data["terrainData"] = {}
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
    local loops = 1 + math.floor(angle / 360 ) 
    -- formula returns coordinates depending on the angle of rotation. Hence forming a blocky spiral since it only increments when loops is incremented
    local x, z = originX + getSignOf(math.cos(math.rad(angle)))*RADIUS*loops*2, originZ + getSignOf(math.sin(math.rad(angle)))*RADIUS*loops*2
    angle = angle + 45
    
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

function deployRobot(port, data)
    local s_data = serialization.serialize(data)
    print("Broadcasting to port ".. port)
    modem.broadcast(port, s_data)
    local _, _, _, _, _, message = event.pull("modem_message")
    print("\n"..message.."\n")
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
    print("(0) Kill Server (not recommended)")
    input = tonumber(term.read())
    if input then
        if input == 2 then -- Open log
            displayLog()
        elseif input == 3 then
            generateData()
        elseif input == 4 then
            printData()
        elseif input == 6 then -- deploy robot
            print("Type in the robot port to deploy.")
            local port = tonumber(term.read())
            if port and portExists(port) then
                local data = getData(tostring(port))
                deployRobot(port, data)
            else
                err("Invalid port, returning to main interface...")
            end
        else
            -- kill threads
            kill = true
            print("Turn off machine dummy")
        end
    else
        err("Invalid Input, try choosing a valid option.")
    end 
end

for port, _ in pairs(ports) do
    createNetworkThread(tonumber(port))
end

loadData()
interface()