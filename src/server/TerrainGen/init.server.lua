
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RNG = Random.new()

-- Terrain Specific Settings
local SIZE = 4

local CHUNK_SIZE = 21 -- MUST BE ODD
if CHUNK_SIZE % 2 == 0 then error("TerrainGen Chunk_SIZE can't be even.") return end
local RENDER_DISTANCE = 5

local smoothness = 0.005

-- Hexagon Generator
local HexFactory = require(script.Hex)

local Hex = HexFactory(SIZE)
local ChunkHex = HexFactory(SIZE * CHUNK_SIZE, true)

local CHUNK_R = math.floor(ChunkHex.h / Hex.w)
print(CHUNK_R)

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

local function visualizeChunk(chex)
    local newHex = hexagon:Clone()
    local worldPos = ChunkHex.hex_to_vec3(chex) + Vector3.new(0, 200, 0)

    newHex.Size = Vector3.new(ChunkHex.h, 200, ChunkHex.w)
    newHex.CFrame = CFrame.new(worldPos)
    newHex.Color = Color3.new(255, 0, 0)
    newHex.Transparency = 0.7
    newHex.CanCollide = false
    newHex.CastShadow = false
    newHex.Material = Enum.Material.ForceField
    newHex.Parent = workspace
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
    e = (e - 0.4)/(1-.4)
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

    return math.pow(math.max(e, .4) * 50, 1.7)
end

local height_seed = RNG:NextNumber()
local moisture_seed = RNG:NextNumber()
local temp_seed = RNG:NextNumber()

local function getHeightMap(hex)
    return makeNoiseMap(hex, {
        {2, .05},
        {1, .5},
        {.5, 2},
        {.25, 4},
        {.1, 16},
        {.05, 32}
    }, height_seed)
end

local function getMoistureMap(hex)
    return makeNoiseMap(hex, {
        {2, 1},
        {0.5, 8}
    }, moisture_seed)
end

local function getEvapMap(hex)
    return makeNoiseMap(hex, {
        {2, 1},
        {0.5, 8}
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

local center_height = getHeight(getHeightMap(Hex.new(0,0)))

local spawnPoint = Instance.new("SpawnLocation")
spawnPoint.Anchored = true
spawnPoint.CFrame = CFrame.new(0,center_height,0)
spawnPoint.Parent = workspace

local function getChunkCenterAsHex(cHex)
    return Hex.hex_round(Hex.vec3_to_hex(ChunkHex.hex_to_vec3(cHex)))
end

local chunkTracker = {}

local function generateChunk(chunkHex)
    local centerHex = getChunkCenterAsHex(ChunkHex.hex_round(chunkHex))

    if chunkTracker[tostring(chunkHex)] then return end
    chunkTracker[tostring(chunkHex)] = true
    print(chunkHex)
    visualizeChunk(chunkHex)

    local spiral = Hex.hex_spiral(centerHex, CHUNK_R)
    for _, hex in ipairs(spiral) do
        genTerrain(hex)
    end

    task.wait()
end

local lastChunk = {}

RunService.Heartbeat:Connect(function(dt)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end

        local hrp = char.PrimaryPart
        if not hrp then continue end

        local lc = lastChunk[player]

        local currChunk = ChunkHex.hex_round(ChunkHex.vec3_to_hex(hrp.CFrame.Position))

        if tostring(currChunk) == tostring(lc) then continue end
        
        lastChunk[player] = currChunk

        print("Spiraling")
        local neighbors = ChunkHex.hex_spiral(currChunk, RENDER_DISTANCE)
        for _, chunk in ipairs(neighbors) do
            generateChunk(chunk)
        end
    end
end)

generateChunk(ChunkHex.new(0,0))

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        hum.WalkSpeed = 100
    end)
end)

