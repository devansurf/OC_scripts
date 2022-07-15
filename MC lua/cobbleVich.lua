local component = require("component")
local robot = require("robot")
local computer = component.computer

local length = 96
local rotation = "left"
local shutdownTicks = 1000
local coord = 0

local isBuilding = true
local state = "SEARCH_FLOOR"

local states = {
    SEARCH_FLOOR = "SEARCH_FLOOR",
    WAIT_FOR_BLOCK = "WAIT_FOR_BLOCK"
}
 -- CobbleVich time
function equipAvailableBlock()
    -- assign the target block
    robot.select(1)
    -- search through inventory for target block
    for i = 2, robot.inventorySize(), 1 do
        if robot.compareTo(i) then
            robot.select(i)
            return true
        end
    end
    return false
end

print("Building commencing...")
while isBuilding do
    shutdownTicks = shutdownTicks - 1
    if shutdownTicks <= 0 then
        isBuilding = false
    end
    -- search for surface to place block
    if state == states.SEARCH_FLOOR then
        -- check if any available blocks to place
        if robot.count() <= 1 then
            if not equipAvailableBlock() then
                state = states.WAIT_FOR_BLOCK
                print("INSERT MORE BLOCKS TO CONTINUE!")
            end
        end
        if robot.detectDown() then
            robot.up()
            robot.placeDown()
            if robot.detect() then
                print("Detected unlevel surface, smoothing out")
                computer.beep()
                robot.turnAround()
                if rotation == "left" then
                    rotation = "right"
                elseif rotation == "right" then
                    rotation = "left"
                end
            end
            if robot.forward() then
                if rotation == "left" then
                    coord = coord + 1
                elseif rotation == "right" then
                    coord = coord - 1
                end
            end
            
            if coord % length == 0 then
                print("Reached corner")
                computer.beep()
                if rotation == "left" then
                    robot.turnLeft()
                elseif rotation == "right" then
                    robot.turnRight()
                end
            end
        else
            robot.down()
        end
    elseif state == states.WAIT_FOR_BLOCK then
        if equipAvailableBlock() then
            state = states.SEARCH_FLOOR
            print("Building commencing...")
            computer.beep()
        end
    end
end
