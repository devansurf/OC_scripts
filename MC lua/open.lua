--Script for opening and closing miner ports
local redstone = component.proxy(component.list("redstone")())
local modem = component.proxy(component.list("modem")())
local sign = component.proxy(component.list("sign")())
-- get port number from sign in front of microcontroller
local port = tonumber(sign.getValue())
local toggle = false
modem.open(port)
while port do
    -- run when any message is recieved
    local signal = computer.pullSignal(0.5)
    if signal then
        if toggle then
            toggle = false
            redstone.setOutput(2, 0)
        else
            toggle = true
            redstone.setOutput(2, 15)
        end
    end
    -- ignore confirmation calls, 10 seconds should be enough
    os.sleep(10)
end
modem.close(port)

