local component = require("component")
local sides = require("sides")
local serialization = require("serialization")
local event = require("event")
local term = require("term")
local as = require("as")
local robot = require("robot")
local modem = component.modem
local computer = component.computer
local component_robot_api = component.robot
local geolyzer = component.geolyzer

-- Sizes of blocks to check at a time
local REGION_SIZE = 4
-- increment of mappings, should be the same as region_size to cover all space
local REGION_INC = 4
-- max distance to check (max 28, with INC of 4)
local REGION_RADIUS = 16
-- detect scans with this hardness
local SCAN_HARDNESS = 3


local position = {
    X = 0, 
    Y = 0, 
    Z = 0
}
local initPos = {
    X = 0, 
    Y = 0, 
    Z = 0
}
local targetPos = {
    X = 0, 
    Y = 0, 
    Z = 0
}
local dir = {
    [1] = sides.north,
    [2] = sides.east,
    [3] = sides.south,
    [4] = sides.west
}
local facing
local port
-- table: {key-> distance, val-> position =>{X,Y,Z}}
local oreInfo = {}
local sortedOreDistance = {}
local paths = {}
local states = {
    DEPLOYING = "DEPLOYING",
    MAP_ORES = "MAP_ORES",
    PATHING = "PATHING",
    RETURN = "RETURN",
}
local state = states.DEPLOYING
local isMining = true
function awaitServerCall()
    modem.open(port)
    print("Awaiting message from server...")
    local _, _, _, _, _, message = event.pull("modem_message")
    print("Message from server recieved!")
    local dataTbl = serialization.unserialize(message)
    modem.broadcast(port, tostring("Port: ".. port .. " deployed to the coordinates: " .. dataTbl.targetX .. "-X, ".. dataTbl.targetY .. "-Y, ".. dataTbl.targetZ .. "-Z, "))
    REGION_RADIUS = dataTbl.R
    targetPos.X = dataTbl.targetX
    targetPos.Y = dataTbl.targetY
    targetPos.Z = dataTbl.targetZ
    initPos.X = dataTbl.X
    initPos.Y = dataTbl.Y
    initPos.Z = dataTbl.Z
    position.X = dataTbl.X
    position.Y = dataTbl.Y
    position.Z = dataTbl.Z
    modem.close(port)
end
function inputs()
    print("what direction is the robot facing? [1] North, [2] East, [3] South, [4] West")
    facing = tonumber(term.read())
    print("Enter the robots port number to continue...")
    port = tonumber(term.read())
    if port then
        awaitServerCall()
    else
        print("invalid port number, exiting...")
    end
end
function setState(_state)
    state = _state
    print("State changed to " .. _state)
end

function generateIndividualPath(currentX, currentZ, currentY, targetX, targetZ, targetY)
    local individualPath = {
        xPath = targetX - currentX, 
        zPath = targetZ - currentZ,
        yPath = targetY - currentY
    }
    return individualPath
end
function generatePath(sortedOreDistance)
    -- generate table in terms of steps until reaching destination, origin changes to where the previous path ends
    local pathTable = {}
    local currentX, currentZ, currentY = 0, 0, 0
    for _, key in ipairs(sortedOreDistance) do
        local individualPath = generateIndividualPath(currentX, currentZ, currentY, oreInfo[key].X, oreInfo[key].Z, oreInfo[key].Y)
        table.insert(pathTable, individualPath)
        currentX = oreInfo[key].X 
        currentZ = oreInfo[key].Z
        currentY = oreInfo[key].Y 
    end 
    --{ {xPath, zPath, yPath = number}, ... }
    print("the size of the path table is: " .. #pathTable)
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
function moveTo(path, axis)
    local direction = getDirection(path)
    if axis == "Y" then
        if  path.yPath ~= 0  then
            for y = 1, math.abs(path.yPath), 1 do
                if direction.Y == sides.posy then
                    if robot.detectUp() then
                        robot.swingUp()
                    end
                    if not robot.up() then
                        computer.beep()
                        y = y-1
                    else
                        position.Y = position.Y + 1
                    end
                else
                    if robot.detectDown() then
                        robot.swingDown()
                    end
                    if not robot.down() then
                        computer.beep()
                        y = y-1
                    else
                        position.Y = position.Y - 1
                    end
                end  
            end
        end
    elseif axis == "Z" then
        if  path.zPath ~= 0 then
            for z = 1, math.abs(path.zPath), 1 do
                
                while dir[facing] ~= direction.Z  do
                    robot.turnRight()
                    facing = facing + 1
                    if facing > 4 then
                        facing = 1
                    end
                end
                if robot.detect() then
                    robot.swing()
                end
                if not robot.forward() then
                    computer.beep()
                    z = z-1
                else
                    if dir[facing] == sides.posz then
                        position.Z = position.Z + 1
                    else
                        position.Z = position.Z - 1
                    end        
                end
            end
        end
    elseif axis == "X" then
        if path.xPath ~= 0 then
            for x = 1, math.abs(path.xPath), 1 do
                while dir[facing] ~= direction.X  do
                    print(dir[facing])
                    robot.turnRight()
                    facing = facing + 1
                    if facing > 4 then
                        facing = 1
                    end
                end
                if robot.detect() then
                    robot.swing()
                end
                if not robot.forward() then
                    computer.beep()
                    x = x-1
                else
                    if dir[facing] == sides.posx then
                        position.X = position.X + 1
                    else
                        position.X = position.X - 1
                    end 
                end
            end
        end
    end
end
function moveToAndHarvest(path, order)
    -- stay 1 block away for harvesting
    if order == "DESCENDING" then
        moveTo(path,"Y")
        moveTo(path, "Z")
        moveTo(path, "X")

    elseif order == "ASCENDING" then
        moveTo(path, "Z")
        moveTo(path, "X")
        moveTo(path,"Y")
    end
    --harvest the ore
    print("moved to coordinates:")
    print(position.X, position.Y, position.Z)
end
inputs()
while isMining do
    if state == "DEPLOYING" then
        local indPath = generateIndividualPath(position.X, position.Z, position.Y, targetPos.X, targetPos.Z, targetPos.Y)
        moveToAndHarvest(indPath, "DESCENDING")
        setState(states.MAP_ORES)

    elseif state == "MAP_ORES" then
        local counter = 0
        for x = (-1 *  REGION_RADIUS),  REGION_RADIUS, REGION_INC do
            for z = (-1 *  REGION_RADIUS),  REGION_RADIUS, REGION_INC do
                for y = 0,  REGION_RADIUS, REGION_INC do
                    local scanData = geolyzer.scan(x, z, y, REGION_SIZE, REGION_SIZE, REGION_SIZE)
                    scanData = as.processData(scanData, x, z, y, REGION_SIZE, REGION_SIZE, REGION_SIZE)
                    for _, data in ipairs(scanData) do
                        if data.hardness == SCAN_HARDNESS and data.distance ~= 0 then
                            counter = counter + 1
                            print("compatible ore found!")
                            oreInfo[counter] = {X = data.posX, Z = data.posZ, Y = data.posY}
                        end
                    end
                end
            end
        end

        -- sort oreInfo by distance
        for key, location in pairs(oreInfo) do table.insert(sortedOreDistance, key) end
        table.sort(sortedOreDistance)
        print("The soroted ore table size is: " .. #sortedOreDistance)
        paths = generatePath(sortedOreDistance)
        setState(states.PATHING)

    elseif state == "PATHING" then
        for _, path in ipairs(paths) do
            moveToAndHarvest(path, "DESCENDING")         
        end  
        setState(states.RETURN)

    elseif state == "RETURN" then
        local indPath = generateIndividualPath(position.X, position.Z, position.Y, initPos.X, initPos.Z, initPos.Y)
        moveToAndHarvest(indPath, "ASCENDING")
        awaitServerCall()
        setState(states.DEPLOYING)
    end
end