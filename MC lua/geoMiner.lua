local component = require("component")
local sides = require("sides")
local term = require("term")
local as = require("as")
local robot = require("robot")
local computer = component.computer
local component_robot_api = component.robot
local geolyzer = component.geolyzer
local nav = component.navigation

-- Sizes of blocks to check at a time
local REGION_SIZE = 4
-- increment of mappings, should be the same as region_size to cover all space
local REGION_INC = 4
-- max distance to check (max 28, with INC of 4)
local REGION_MAX = 12
-- layers above specified Ylevel to check, should be Modular to region_size
local REGION_Y_THICKNESS = 5
-- detect scans with this hardness
local SCAN_HARDNESS = 3


-- color, properties, name, harvestlevel, hardness, harvestTool
local Ylevel = 11

-- table: {key-> distance, val-> position =>{X,Y,Z}}
local oreInfo = {}
local sortedOreDistance = {}
local paths = {}


local states = {
    DEPLOYING = "DEPLOYING",
    MAP_ORES = "MAP_ORES",
    PATHING = "PATHING"
}
local state = states.DEPLOYING
local isMining = true

function inputs()
    print("Input the Y axis to mine at: ")
    Ylevel = term.read()
end
function setState(_state)
    state = _state
    print("State changed to " .. _state)
end
function generatePath(sortedOreDistance)
    -- generate table in terms of steps until reaching destination, origin changes to where the previous path ends
    local pathTable = {}
    local currentX, currentZ, currentY = 0, 0, 0
    for _, key in ipairs(sortedOreDistance) do
        local individualPath = {
            xPath = oreInfo[key].X - currentX, 
            zPath = oreInfo[key].Z - currentZ,
            yPath = oreInfo[key].Y - currentY
        }
        table.insert(pathTable, individualPath)

        currentX = oreInfo[key].X 
        currentZ = oreInfo[key].Z
        currentY = oreInfo[key].Y 
    end 
    --{ {xPath, zPath, yPath = number}, ... }
    return pathTable
end
function getDirection(path)
    local direction
    local xDir, zDir, yDir = -1, -1, -1
    if path.xPath > 0 then
        xDir = sides.posx
    else
        xDir = sides.negx
    end
    if path.zPath > 0 then
        zDir = sides.posz
    else
        zDir = sides.negz
    end
    if path.yPath > 0 then
        yDir = sides.posy
    else
        yDir = sides.negy
    end
    direction = {
        X = xDir,
        Z = zDir,
        Y = yDir
    }
    return direction
end
function moveToAndHarvest(path)
    local direction = getDirection(path)
    -- stay 1 block away for harvesting
    if  path.yPath ~= 0 then
        for y = 1, math.abs(path.yPath), 1 do
            if direction.Y == sides.posy then
                if robot.detectUp() then
                    robot.swingUp()
                end
                if not robot.up() then
                    computer.beep()
                    y = y-1
                end
            else
                if robot.detectDown() then
                    robot.swingDown()
                end
                if not robot.down() then
                    computer.beep()
                    y = y-1
                end
            end  
        end
    end
    if  path.zPath ~= 0 then
        for z = 1, math.abs(path.zPath), 1 do
            while nav.getFacing() ~= direction.Z  do
                robot.turnRight()
            end
            if robot.detect() then
                robot.swing()
            end
            if not robot.forward() then
                computer.beep()
                z = z-1
            end
        end
    end
    if path.xPath ~= 0 then
        for x = 1, math.abs(path.xPath), 1 do
            while nav.getFacing() ~= direction.X  do
                robot.turnRight()
            end
            if robot.detect() then
                robot.swing()
            end
             if not robot.forward() then
                computer.beep()
                x = x-1
             end
        end
    end
    --harvest the ore
    print("harvested at coordinates:")
    print(path.xPath, path.zPath, path.yPath)

end
inputs()
local Ydug = Ylevel
while isMining do
    local cX, cY, cZ = nav.getPosition()
    if math.abs(cX) + 1 > nav.getRange() or math.abs(cZ) + 1 > nav.getRange() then
        -- reasonOfFinish = "REASON OF FINISH: RANGE EXCEEDED"
    end
    if state == "DEPLOYING" then
        if cY < Ylevel + 1 then
            setState(states.MAP_ORES)
        else
            if robot.detectDown() then
                robot.swingDown()
            end
            robot.down()
            Ydug = Ydug+1
        end
    elseif state == "MAP_ORES" then
        local counter = 0
        for x = (-1 * REGION_MAX), REGION_MAX, REGION_INC do
            for z = (-1 * REGION_MAX), REGION_MAX, REGION_INC do
                for y = 0, REGION_Y_THICKNESS, REGION_INC do
                    local scanData = geolyzer.scan(x, z, y, REGION_SIZE, REGION_SIZE, REGION_SIZE)
                    scanData = as.processData(scanData, x, z, y, REGION_SIZE, REGION_SIZE, REGION_SIZE)
                    for _, data in ipairs(scanData) do
                        if data.hardness == SCAN_HARDNESS and data.distance ~= 0 then
                            counter = counter + 1
                            oreInfo[counter] = {X = data.posX, Z = data.posZ, Y = data.posY}
                        end
                    end
                end
            end
        end
        -- add starting position to path
        oreInfo[counter+1] = {X = 0, Z = 0, Y = Ydug}

        -- sort oreInfo by distance
        for key, location in pairs(oreInfo) do table.insert(sortedOreDistance, key) end
        table.sort(sortedOreDistance)
        paths = generatePath(sortedOreDistance)
        setState(states.PATHING)

    elseif state == "PATHING" then
        for _, path in ipairs(paths) do
            moveToAndHarvest(path)         
        end  
        isMining = false
    end
end