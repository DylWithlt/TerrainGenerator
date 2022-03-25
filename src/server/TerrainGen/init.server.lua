
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RNG = Random.new()
local NOISE_SEED = RNG:NextNumber()

-- Terrain Specific Settings
local SIZE = 3
local smoothness = 0.005
local ZONE_SIZE = 200
local SEA_LEVEL = 0

-- Generation Speed Settings
local step_size = 50
local steps = math.ceil(ZONE_SIZE/step_size)

-- Hexagon Generator
local Hex = require(script.Hex)(SIZE)
local hexagon = ReplicatedStorage:WaitForChild("Hexagon")

local biomes = {
    OCEAN = Color3.fromRGB(49, 121, 198),
    DESERT = Color3.fromRGB(204, 215, 149),
    GRASS = Color3.fromRGB(21, 96, 12),
    SHRUB_LAND = Color3.fromRGB(177, 129, 25),
    TROPICAL_RAINFOREST = Color3.fromRGB(17, 50, 1),
    BOREAL_FOREST = Color3.fromRGB(91, 142, 82),
    TUNDRA = Color3.fromRGB(205, 194, 194),
    SNOW = Color3.fromRGB(255, 251, 251)
}

local HexagonFolder = Instance.new("Folder")
HexagonFolder.Name = "HexagonTerrain"
HexagonFolder.Parent = workspace


-- Util functions
local function pickRandom(tbl)
    return tbl[RNG:NextInteger(1,#tbl)]
end

local function noise(x, y, seed)
	return (math.noise(x, y, seed) + 1)/2
end

local function makeNoiseMap(hex, layers, seed)
    local worldSpace = Hex.hex_to_vec3(hex)
    local x, y = worldSpace.X * smoothness, worldSpace.Z * smoothness

    local e = 0
    local sum = 0
    for _, filter in ipairs(layers) do
        e += filter[1] * noise(x * filter[2], y * filter[2], seed)
        sum += filter[1]
    end
    e /= sum

    return e
end

-- Terrain Specific
local function placeHex(hex)
    local newHex = hexagon:Clone()
    local worldPos = Hex.hex_to_vec3(hex)

    newHex.Size = Vector3.new(Hex.h, 20, Hex.w)
    newHex.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, math.rad(30),0)
    newHex.Parent = HexagonFolder
    return newHex
end

local function getCloseColors(color)
    local colors = {color}

    local h, s, v = Color3.toHSV(color)
    
    for i = -2, 2 do
        if i == 0 then continue end

        local new_h = (h * 360 + 11 * i)/360

        table.insert(colors, Color3.fromHSV(new_h, s + .05, v))
    end

    return colors
end

local elevations, moistures, evaps = 5, 8, 8

local function getBiome(e, m, ev)
	--local adjusted = (math.noise(hex.q * smoothness, hex.r * smoothness) + -1)/2
    e = (e - 0.4)
    if e <= 0 then return biomes.OCEAN end
    if e < 0.05 then return biomes.DESERT end

    local e_s = 1/elevations
    local m_s = 1/moistures
    local ev_s = 1/evaps

    if e > e_s * (elevations-1) then
        return biomes.TUNDRA
    end

    if ev < ev_s then
        return biomes.TROPICAL_RAINFOREST
    end

    if m < m_s then
        return biomes.DESERT
    elseif m < m_s * 3 then
        return biomes.SHRUB_LAND
    elseif m < m_s * 4 then
        return biomes.BOREAL_FOREST
    elseif m < m_s * 5 then
        return biomes.BOREAL_FOREST
    end

    if e < 0.8 then return biomes.GRASS end

	return biomes.SNOW
end

local function getHeight(e)
    --return math.round((math.max(e, .4) * 200) / 4)* 4

    return math.pow(math.max(e, .4) * 100, 1.2)
end

local height_seed = RNG:NextNumber()
local moisture_seed = RNG:NextNumber()
local temp_seed = RNG:NextNumber()

local function getHeightMap(hex)
    return makeNoiseMap(hex, {
        {1, .5},
        {.5, 2},
        {.25, 4},
        {.1, 16}
    }, height_seed)
end

local function getMoistureMap(hex)
    return makeNoiseMap(hex, {
        {2, .5},
        {0.5, 16}
    }, moisture_seed)
end

local function getEvapMap(hex)
    return makeNoiseMap(hex, {
        {2, .5},
        {0.5, 16}
    }, temp_seed)
end

local function genTerrain(hex)

    local e = getHeightMap(hex)
    local m = getMoistureMap(hex)
    local ev = getEvapMap(hex)

    local biome = getBiome(e, m, ev)
    local height = getHeight(e)

    local hex_part = placeHex(hex)
	hex_part.CFrame = hex_part.CFrame *
        CFrame.new(0, height - 10, 0)
    hex_part.Size = hex_part.Size + Vector3.new(0, 20, 0)

    hex_part.Color = pickRandom(getCloseColors(biome))
end

local spawnPoint = Instance.new("SpawnLocation")
spawnPoint.Anchored = true
spawnPoint.CFrame = CFrame.new(0,getHeight(getHeightMap(Hex.new(0,0))),0)
spawnPoint.Parent = workspace

local function generateMap()

    genTerrain(Hex.new(0,0))
    for map_radius = 0, steps-1 do
        for i = 1, step_size do
            local ring = Hex.single_ring(Hex.new(0,0), map_radius * step_size + i)
            for count, hex in ipairs(ring) do
                genTerrain(hex)
                if count % 50 == 0 then
                    task.wait()
                end
            end
        end
    end
    print("Finished generating.")
end

generateMap()
