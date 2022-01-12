local event = require("event")
local robot = require('robot')
local computer = require("computer")
local sides = require("sides")
local redstone = require("component").redstone
local invController = require("component").inventory_controller

function equip() -- equip rod
	for slot = 1, invController.getInventorySize(sides.up), 1 do
		if invController.suckFromSlot(sides.up, slot) then
			if invController.equip() then return true end
		end
	end 
	return false
end

function fish()
    robot.use(0, true, 1)
    os.sleep(3)
    print('Waiting for fish...')
    _ = event.pull(60,'redstone_changed') 
    robot.use(0, true, 1)
    print('Caught one!')
    os.sleep(2)
    if redstone.getInput(0) > 0 then robot.use(0, true, 1) end
    os.sleep(1)
end

while true do
    if (robot.durability() ~= nil) and (robot.count(slots) == 0) then 
      fish()
    else
      if not equip() then break end
    end
end