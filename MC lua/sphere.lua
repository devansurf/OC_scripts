local component = require("component")
local sides = require("sides")
local robot = require("robot")
local term = require("term")

local computer = component.computer

-- Purpose: Create a sphere of R radius, with any block available. If ground blocks the sphere, create dome.
-- Requirements: Angel Upgrade, Hover Upgrade, Inventory Controller.
local BOTTOM_TO_TOP = 'bottomToTop'
local TOP_TO_BOTTOM = 'topToBottom'

local sorts = {
    [BOTTOM_TO_TOP] = function(c1, c2) 
        return c1['y'] < c2['y']
    end,
    [TOP_TO_BOTTOM] = function(c1, c2) 
        return c1['y'] > c2['y']
    end,
}


local function reversed(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversed[itemCount + 1 - k] = v
    end
    return reversedTable
end

local function round(val, dec)
    return math.floor(val*(10^dec)+0.5)/(10^dec)
end

local function createCoord(x,y,z)
    return {['x'] = x, ['y'] = y, ['z'] = z}
end

local function err(message)
    computer.beep("..-")
    print(message)
    os.sleep(2)
    term.clear()
    input()
end



function generateBlueprint(radius)
    -- create blueprint of relative coordinates of blocks that must be placed
    -- algorithm: create many layers of rings with of different radiuses, combine them into a sphere.
    -- possible to store calculated values in cache and mirror them, can decrease computation times.

    function createRing(radius, zLayer)
        local currentX = radius
        local currentY = 0
        local coords = {}
        table.insert(coords,createCoord(currentX,currentY,zLayer))
        local updated = false
        
        --increment by 1/radius
        for i = 0, 90, (1/radius) do
            local y = math.sin(math.rad(i))*radius
            --check if number is whole, up to 3 decimal places
            if round(y,0) == round(y,1) then
                y = round(y,0)
                if y ~= currentY then
                    currentY = y
                    updated = true
                end
            end
            local x = math.cos(math.rad(i))*radius
            if round(x,0) == round(x,1) then
                x = round(x,0)
                if x ~= currentX then
                    currentX = x
                    updated = true
                end
            end
            if updated then
                table.insert(coords, createCoord(currentX,currentY,zLayer))
                updated = false
            end
        end
        return coords
    end

    function completeSphere(coords)
        --mirror coords to create sphere
        --mirror on the x axis
        reversedCoords = reversed(coords)
        print("Phase 1 X")
        for _, coord in ipairs(reversedCoords) do
        --ignore duplicates
            if coord['x'] ~= 0 then
               
                newCoord = createCoord(coord['x']*-1, coord['y'], coord['z'])
                table.insert(coords, newCoord)
            end
        end
        --mirror on the y axis
        print("Phase 2 Y")
        reversedCoords = reversed(coords)
        for _, coord in ipairs(reversedCoords) do
            --ignore duplicates
            if coord['y'] ~= 0 then
                newCoord = createCoord(coord['x'], coord['y']*-1, coord['z'])
                table.insert(coords, newCoord)
            end
        end
        --mirror in the z axis
        print("Phase 3 Z")
        reversedCoords = reversed(coords)
        for _, coord in ipairs(reversedCoords) do
            --ignore duplicates
            if coord['z'] ~= 0 then
                newCoord = createCoord(coord['x'], coord['y'], coord['z']*-1)
                table.insert(coords, newCoord)
            end
        end
        return coords
    end

    function flipRingOnZ(ring)
        --swap Y values with Z values, visualize it as laying it flat on the plane
        
        local newRing = {}
        for _, coord in ipairs(ring) do
            --print(coord['x'] .. " " .. coord['y'] .. " " .. coord['z'])
            local newCoord = createCoord(coord['x'], coord['z'], coord['y'])
            table.insert(newRing, newCoord)
        end
        --printTable(newRing)
        return newRing
    end

    local coords = {} --3d coords
    local mainRing = {}
    --create main ring coordinates
    mainRing = createRing(radius,0)
    --flip ring on its side
 
    mainRing = flipRingOnZ(mainRing)
   --printTable(flipRingOnZ(mainRing))
   
    --take every coordinate of the mainRing and create a ring with it as a reference point
    for _, coord in ipairs(mainRing) do
    --its x value represents the radius, its z axis represents zLayer
        r = coord['x']
        zLayer = coord['z']
        --append subRing onto main coords, duplicates are made on contact points (needs to be fixed)
        
        for _, newCoord in ipairs(createRing(r, zLayer)) do
            table.insert(coords, newCoord)
        end
    end  
    --print(coords['x'])
    return completeSphere(coords)
end

function buildSphere(blueprint, mode)
    -- place blocks at blueprint coordinates

    -- count how many blocks will be needed and prompt the user

    -- build from blueprint, if restricted to move in a certain direction, have smart algorithm remove blueprint coords
    -- build from bottom to top (could be configurable in the future)
    table.sort(blueprint, sorts[mode])

    local pos = createCoord(0,0,0)
    local dir = sides.posx

    for _, coord in ipairs(blueprint) do
        pos, dir = traverseTo(pos, dir, coord, mode)
        build(mode)
      
    end
end

function traverseTo(pos, dir, coord, mode)
    -- using geolyzer, it may be possible to may a block map.

    -- travel to coordinates if possible, otherwise return false
    -- horizontally before vertically
    while coord['x'] ~= pos['x'] or coord['y'] ~= pos['y'] or coord['z'] ~= pos['z'] do
        -- move in x and z axis first.
        deltaX = pos['x'] - coord['x']
        deltaY = pos['y'] - coord['y']
        deltaZ = pos['z'] - coord['z']

        if deltaX > 0 then
            faceDirection(sides.posx)
        elseif deltaX < 0 then
            faceDirection(sides.negx)
        end
        deltaX = math.abs(deltaX)
        while deltaX ~= 0 do
            if robot.forward() then
                deltaX = deltaX - 1
            else
                -- smart geolyzer pathfinding would be nice
                
            end
        end

        if deltaZ > 0 then
            faceDirection(sides.posz)
        elseif deltaX < 0 then
            faceDirection(sides.negz)
        end
        deltaZ = math.abs(deltaZ)
        while deltaZ ~= 0 do
            if robot.forward() then
                deltaZ = deltaZ - 1
            else
                -- smart geolyzer pathfinding would be nice
                
            end
        end
        if deltaY > 0 then
            faceDirection(sides.posy)
        elseif deltaY < 0 then
            faceDirection(sides.negy)
        end
        deltaY = math.abs(deltaY)
        while deltaY ~= 0 do
            if robot.forward() then
                deltaY = deltaY - 1
            else
                -- smart geolyzer pathfinding would be nice
                
            end
        end

    end
    -- returns new position and direction

end

function faceDirection(currentDir)

end

function interrupt()

end

function input()
    print("Insert the radius to build the Sphere:")
    local input = tonumber(term.read())
    if type(input) == 'number' then
        local radius = math.floor(input)
        local blueprint = generateBlueprint(radius)
        buildSphere(blueprint, BOTTOM_TO_TOP)
    else
        err("Please type in a number")
    end
end
input()

