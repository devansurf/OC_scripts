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
    ["1"] = {X = -322, Y = 62, Z = -223},
}
local log = {
    -- key -> os.Time, value -> message
}
local kill = false
local RADIUS = 16 -- 4 chunks wide and length, radius height
local filename = "data.txt"
local function succ()
    computer.beep("..")
    os.sleep(1)
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
    print(n)
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
        while not kill do
            modem.open(port)
            log[os.time()] = "Opened port " .. port
            -- this component generates a signal named modem_message if a message from another network card is received.
            --It has the signature localAddress: string, remoteAddress: string, port: number, distance: number, ...
            local _, _, from, port, _, message = event.pull("modem_message")
            log[os.time()] = message
        end
    end, port)
end
-- find a location in the world where it hasnt been declared mined
function getFreshLocation()
    -- retrieve previous deploy locations data
    -- create a radius around the deploy locations to represent mined areas in 2 dimensions (planar)
    -- new location will be an increment on x or z axis by 2*radius
    local file = io.open(filename,"r")
    local lnNum = 1
    local angle, originX, originY, originZ
    for line in file:lines() do
        if lnNum == 1 then
            originX = tonumber(line)
        elseif lnNum == 2 then
            originY = tonumber(line)
        elseif lnNum == 3 then
            originZ = tonumber(line)
        elseif lnNum == 4 then
            angle = tonumber(line)
        end
        lnNum = lnNum + 1
    end
   
    file:close()
    --represents the amount of loops
    local loops = 1 + math.floor(angle / 360 ) 
    -- formula returns coordinates depending on the angle of rotation. Hence forming a blocky spiral since it only increments when loops is incremented
    local x, z = originX + getSignOf(math.cos(math.rad(angle)))*RADIUS*loops*2, originZ + getSignOf(math.sin(math.rad(angle)))*RADIUS*loops*2
    angle = angle + 45
    file = io.open(filename, "w")
    file:write(tostring(originX.."\n"))
    file:write(tostring(originY.."\n"))
    file:write(tostring(originZ.."\n"))
    file:write(tostring(angle.."\n"))
    file:close()
    return {X = x , Y = originY ,Z = z, R = RADIUS}
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

function deployRobot(port, location)
    local s_loc = serialization.serialize(location)
    print("Broadcasting to port ".. port)
    modem.broadcast(port, s_loc)
    succ()
end

function interface()
    -- create interface for user to interact with commands:
    print("(1) Insert new port with coordinates")
    print("(2) Open log")
    print("(3) Get robot location")
    print("(4) Recall robot")
    print("(5) Generate hologram")
    print("(6) Deploy robot")
    print("(0) Kill Server (not recommended)")
    input = tonumber(term.read())
    if input then
        if input == 2 then -- Open log
            displayLog()
        elseif input == 6 then -- deploy robot
            print("Type in the robot port to deploy.")
            local port = tonumber(term.read())
            if port and portExists(port) then
                local location = getFreshLocation()
                deployRobot(port, location)
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

interface()