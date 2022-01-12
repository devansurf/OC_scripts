analyzeScan = {}
round = setmetatable({
    up = function(n, p)
        local m = 10 ^ (p or 0)
        return math.ceil(n * m) / m
    end,

    down = function(n, p)
        local m = 10 ^ (p or 0)
        return math.floor(n * m) / m
    end
}, {
    __call = function(self, n, p)
        local m = 10 ^ (p or 0)
        if n >= 0 then
            return math.floor(n * m + 0.5) / m
        else
            return math.ceil(n * m - 0.5) / m
        end
    end
})

function processData(data, x, z, y, w, d, h)

    local minX = math.min(x, x + w - 1)
    local minY = math.min(y, y + h - 1)
    local minZ = math.min(z, z + d - 1)

    local maxX = math.max(x, x + w - 1)
    local maxY = math.max(y, y + h - 1)
    local maxZ = math.max(z, z + d - 1)

    local rW = maxX - minX + 1 -- relative Width
    local rH = maxY - minY + 1 -- relative Height
    local rD = maxZ - minZ + 1 -- relative Depth

    local volume = rW * rH * rD
    local function relativeCoordinates(index)
        local rX = ((index - 1) % rW) + minX
        local rZ = ((math.ceil(index / rW) - 1) % rD) + minZ
        local rY = ((math.ceil(index / rW / rH) - 1) % rH) + minY
        local rD = math.sqrt(rX ^ 2 + rZ ^ 2 + rY ^ 2)
        return rX, rZ, rY, rD
    end

    local error = 0.0005
    local factor = 2112

    local newData = {}
    for index = 1, volume do
        local hardness, byte = 3, 0

        local x, z, y, distance = relativeCoordinates(index)
        local noise = data[index]

        if (noise < 104 and noise > 96) then
            hardness = 100 -- block is a liquid (water or lava)
        elseif (noise < 54 and noise > 46) then
            hardness = 50 -- block is obsidian
        elseif (noise < 26 and noise > 19) then
            hardness = 22.5 -- block is an Ender Chest
        else
            local lo = round.down(-(127 * distance / factor) + noise, 1)
            local hi = round.up(-(-128 * distance / factor) + noise, 1)
            for H = math.max(lo * 10, -1), math.min(hi * 10, 50) do
                local H = H / 10
                local B = (noise - H) * factor / distance
                if math.abs(B - round(B, 0)) < error then
                    hardness, byte = H, round(B)
                    break
                end
            end
        end
        byte = byte or round((noise - hardness) * factor / distance)

        newData[index] = {
            posX = x, 
            posZ = z, 
            posY = y, 
            ["distance"] = distance, 
            ["noise"] = noise, 
            ["hardness"] = hardness, 
            ["byte"] = byte
        }
    end
    return newData
end
analyzeScan["processData"] = processData

return analyzeScan
