-- Miner Script for Robots
-- config
-- >> Scan Amount: The # of slots to consider as ore
local scanAmount = 1
-- >> Mining Level: The Y axis to mine at
local miningLevel = 79
-- >> parameter for how long the robot will mine
local miningTime = 30
-- Hello world
local component = require("component")
local sides = require("sides")
local nav = component.navigation
local computer = component.computer
local robot = require("robot")
local states = {
    DIG_DOWN = "DIG_DOWN",
    STRIP_MINE = "STRIP_MINE",
    MINE_ORE = "MINE_ORE",
    BACKTRACK = "BACKTRACK",
    GO_BACK_HOME = "GO_BACK_HOME"
}
-- nav info
function createNavInfo(facing, posX, posY, posZ, state)
    return {
        ["facing"] = facing,
        ["position"] = {
            ["X"] = posX,
            ["Y"] = posY,
            ["Z"] = posZ
        },
        ["state"] = state
    }
end
local nPx, nPy, nPz = nav.getPosition()
local backtrack = {createNavInfo(nav.getFacing(), nPx, nPy, nPz, states.BACKTRACK)}
local navInfo
local state = states.DIG_DOWN
local reasonOfFinish = ""
print("State changed to DIG_DOWN")
local isMining = true
-- keeps track of strip mine
local steps = 1
-- prev step helps with pattern in strip mine
local prevStep = 1
local stepsTaken = 0
robot["detectLeft"] = (function()
    robot.turnLeft()
    local b, s = robot.detect()
    robot.turnRight()
    return b, s
end)
robot["detectRight"] = (function()
    robot.turnRight()
    local b, s = robot.detect()
    robot.turnLeft()
    return b, s
end)
robot["detectBack"] = (function()
    robot.turnAround()
    local b, s = robot.detect()
    robot.turnAround()
    return b, s
end)
robot["compareLeft"] = (function()
    robot.turnLeft()
    local b = robot.compare()
    robot.turnRight()
    return b
end)
robot["compareRight"] = (function()
    robot.turnRight()
    local b = robot.compare()
    robot.turnLeft()
    return b
end)
robot["compareBack"] = (function()
    robot.turnAround()
    local b = robot.compare()
    robot.turnAround()
    return b
end)
robot["swingLeft"] = (function()
    robot.turnLeft()
    robot.swing()
    robot.turnRight()
end)
robot["swingRight"] = (function()
    robot.turnRight()
    robot.swing()
    robot.turnLeft()
end)

robot["swingBack"] = (function()
    robot.turnAround()
    robot.swing()
    robot.turnAround()
end)

robot["left"] = (function()
    robot.turnLeft()
    robot.forward()
end)
robot["right"] = (function()
    robot.turnRight()
    robot.forward()
end)
local mineDirections = {
    ["compare"] = "swing",
    ["compareLeft"] = "swingLeft",
    ["compareRight"] = "swingRight",
    ["compareUp"] = "swingUp",
    ["compareDown"] = "swingDown",
    ["compareBack"] = "swingBack"
}
local moveDirections = {
    ["compare"] = "forward",
    ["compareLeft"] = "left",
    ["compareRight"] = "right",
    ["compareUp"] = "up",
    ["compareDown"] = "down",
    ["compareBack"] = "back"
}
function mineOre(direction)
    robot[mineDirections[direction]]()
    robot[moveDirections[direction]]()
end
function backTrack()
    state = states.BACKTRACK
    print("State Changed to BACKTRACK")
    -- pop from stack
    navInfo = backtrack[#backtrack]
    table.remove(backtrack, #backtrack)
end
while isMining do
    computer.beep()
    miningTime = miningTime - 1
    if miningTime == 0 then
        reasonOfFinish = "REASON OF FINISH: MINING TIME EXCEEDED"
        while #backtrack > 0 do
            backTrack()
        end
    end
    local X, Y, Z = nav.getPosition()
    -- check if in range
    if math.abs(X) + 1 > nav.getRange() or math.abs(Z) + 1 > nav.getRange() then
        reasonOfFinish = "REASON OF FINISH: RANGE EXCEEDED"
        while #backtrack > 0 do
            backTrack()
        end
    end
    if state == states.DIG_DOWN then
        if Y < miningLevel + 1 then
            state = states.STRIP_MINE
            print("State Changed to STRIP_MINE")
        else
            if robot.detectDown() then
                robot.swingDown()
            end
            robot.down()
        end
    elseif state == states.STRIP_MINE then
        -- mine in a spiral
        if stepsTaken == steps then
            robot.turnLeft()
            stepsTaken = 0
            if prevStep == 1 then
                steps = steps + 2
                prevStep = 2
            else
                steps = steps + 1
                prevStep = 1
            end
        end
        if robot.detect() then
            robot.swing()
        end
        robot.forward()
        stepsTaken = stepsTaken + 1
        local detects = {
            ["compare"] = robot.detect(),
            ["compareLeft"] = robot.detectLeft(),
            ["compareRight"] = robot.detectRight(),
            ["compareUp"] = robot.detectUp(),
            ["compareDown"] = robot.detectDown()
        }
        -- check surrounding blocks
        for cmp, val in pairs(detects) do
            if val then
                for i = 1, scanAmount, 1 do
                    robot.select(i)
                    if robot[cmp]() then
                        state = states.MINE_ORE
                        print("State Changed to MINE_ORE")
                        nPx, nPy, nPz = nav.getPosition()
                        table.insert(backtrack, createNavInfo(nav.getFacing(), nPx, nPy, nPz, states.STRIP_MINE))
                        mineOre(cmp)
                    end
                end
            end
        end
    elseif state == states.MINE_ORE then
        -- check surrounding blocks
        local detects = {
            ["compare"] = robot.detect(),
            ["compareLeft"] = robot.detectLeft(),
            ["compareRight"] = robot.detectRight(),
            ["compareUp"] = robot.detectUp(),
            ["compareDown"] = robot.detectDown(),
            ["compareBack"] = robot.detectBack()
        }
        local foundOre = false
        for cmp, val in pairs(detects) do
            if val then
                for i = 1, scanAmount, 1 do
                    robot.select(i)
                    if robot[cmp]() then
                        nPx, nPy, nPz = nav.getPosition()
                        table.insert(backtrack, createNavInfo(nav.getFacing(), nPx, nPy, nPz, states.MINE_ORE))
                        mineOre(cmp)
                        foundOre = true
                    end
                end
            end
        end
        if not foundOre then
            backTrack()
        end
    elseif state == states.BACKTRACK then
        -- each step move closer to navInfo
        local dX, dY, dZ = navInfo.position.X - X, navInfo.position.Y - Y, navInfo.position.Z - Z
        if dX < 0 then
            while nav.getFacing() ~= sides.negx do
                robot.turnLeft()
            end
            if robot.detect() then
                robot.swing()
            end
            robot.forward()

        elseif dX > 0 then
            while nav.getFacing() ~= sides.posx do
                robot.turnLeft()
            end
            if robot.detect() then
                robot.swing()
            end
            robot.forward()
        end
        if dY < 0 then
            if robot.detectDown() then
                robot.swingDown()
            end
            robot.down()
        elseif dY > 0 then
            if robot.detectUp() then
                robot.swingUp()
            end
            robot.up()
        end
        if dZ < 0 then
            while nav.getFacing() ~= sides.negz do
                robot.turnLeft()
            end
            if robot.detect() then
                robot.swing()
            end
            robot.forward()
        elseif dZ > 0 then
            while nav.getFacing() ~= sides.posz do
                robot.turnLeft()
            end
            if robot.detect() then
                robot.swing()
            end
            robot.forward()
        end
        if dX == 0 and dY == 0 and dZ == 0 then
            while nav.getFacing() ~= navInfo.facing do
                robot.turnLeft()
            end
            state = navInfo.state
            if state == states.BACKTRACK and #backtrack <= 0 then
                isMining = false
                print(reasonOfFinish)
            end
            print("State Changed to " .. navInfo.state)
        end
    end
end
