local modem = require("component").modem
local term = require("term")
local thread = require("thread")
local event = require("event")
local computer = component.computer
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

function createLog(time, message)
    return tostring(time .. " : " .. message)
end
-- create a thread for listening to a port
function createNetworkThread(port)
    thread.create(function(port)
        modem.open(port)
        log[os.time()] = "Opened port " .. port
        -- this component generates a signal named modem_message if a message from another network card is received.
        --It has the signature localAddress: string, remoteAddress: string, port: number, distance: number, ...
        local _, _, from, port, _, message = event.pull("modem_message")
        print("Got a message from " .. from .. " on port " .. port .. ": " .. tostring(message))
    end, port)
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

function interface()
    -- create interface for user to interact with commands:
    print("(1) Insert new port with coordinates")
    print("(2) Open log")
    print("(3) Get robot location")
    print("(4) Recall robot")
    print("(5) Generate hologram")
    print("(0) Kill Server (not recommended)")
    input = tonumber(term.read())
    if input then
        if input == 2 then -- Open log
            displayLog()
        elseif input == 0 then
            break
        end
    else
        computer.beep("..-")
        print("Invalid Input, try choosing a valid option.")
        os.sleep(2)
        term.clear()
        interface()
    end 
end

for port, _ in pairs(ports) do
    createNetworkThread(tonumber(port))
end

interface()