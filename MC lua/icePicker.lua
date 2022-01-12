local component = require("component")
local robot = require("robot")
local computer = component.computer

local states = {WAITING = "WAITING", MINING = "MINING"}
local state = states.WAITING

while true do
    if state == states.WAITING then
        computer.beep()
        os.sleep(2)
        if robot.durability() > 0.05 then      
            state = states.MINING
        end
    elseif state == states.MINING then
        if robot.detect() then
            robot.swing()           
        end
        robot.turnLeft()
        if robot.durability() < 0.05 then      
            state = states.WAITING
        end
    
    end
end