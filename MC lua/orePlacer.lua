local component = require("component")
local robot = require("robot")
local event = require("event")
local thread = require("thread")
local computer = component.computer

local oreQueue = {}

function placeOres()  
    while true do
        os.sleep(0.1)
        for i, func in pairs(oreQueue) do
            func()
            table.remove(oreQueue, i)
        end 
    end
end

function addToQueue(slot)
    table.insert(oreQueue, function() 
        robot.select(slot)
        while robot.count(slot) > 0 do
            robot.place()
        end
    end)
end

function inventoryListener()
    -- listen for changes in inventory
    thread.create(function()
        while true do
            local _, slot = event.pull(60,"inventory_changed")
            if robot.count(slot) > 0 then
                addToQueue(slot)
            end 
        end
    end)
end

inventoryListener()

for i = 1, robot.inventorySize() do
    if robot.count(i) > 0 then
        addToQueue(i)
    end
end

placeOres() 
