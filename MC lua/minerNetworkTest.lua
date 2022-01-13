local modem = require("component").modem
local serialization = require("serialization")
local event = require("event")
local term = require("term")

print("Enter the robots port number to continue")
local port = tonumber(term.read())
if port then
    modem.open(port)
    print("Awaiting message from server...")
    local _, _, from, _, _, message = event.pull("modem_message")
    print("Message from server recieved!")
    local posTable = serialization.unserialize(message)
    for k, v in pairs(posTable) do 
        print(k..v)
    end
else
    print("invalid port number, exiting...")
end
