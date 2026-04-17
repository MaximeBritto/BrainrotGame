--[[
    KillWall.server.lua  (remplace SpinnerRotation)

    SETUP STUDIO :
      1. Dans Workspace > Arena, place une Part nommée "RainbowCenter"
         → positionne-la exactement au centre des demi-cercles (au sol)
         → sa position Y définit la hauteur de base des murs
      2. (Optionnel) Dans GameConfig, renseigne InnerRadius/OuterRadius par zone
         pour forcer la taille exacte du bras. Sinon ils sont auto-calculés.

    Un bras rotatif est créé par zone (SpawnZone1..N).
    Rotation CFrame pure sur Part ancrée → aucun bug physique.
    Tout joueur touché est tué immédiatement.
]]

local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

task.wait(2)

local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig.module"))

local Arena = Workspace:WaitForChild("Arena", 10)
if not Arena then warn("[KillWall] Arena introuvable!") return end

-- ═══════════════════════════════════════
-- CENTRE (obligatoire)
-- ═══════════════════════════════════════
-- DEBUG : liste tous les enfants directs de Arena
print("[KillWall] Enfants directs de Arena :")
for _, child in ipairs(Arena:GetChildren()) do
    print("  → " .. child.ClassName .. ' "' .. child.Name .. '"')
end

-- WaitForChild attend jusqu'à 10s que la Part soit chargée
local centerPart = Arena:WaitForChild("RainbowCenter", 10)
if not centerPart then
    -- Fallback : recherche récursive au cas où elle est dans un sous-dossier
    centerPart = Arena:FindFirstChild("RainbowCenter", true)
end
if not centerPart or not centerPart:IsA("BasePart") then
    warn("[KillWall] Part 'RainbowCenter' introuvable dans Arena! Vérifie que la Part existe et est bien dans Workspace > Arena.")
    return
end

local centerX = centerPart.Position.X
local centerZ = centerPart.Position.Z
local centerY = centerPart.Position.Y
centerPart.Transparency = 1  -- invisible en jeu
centerPart.CanCollide   = false

print(string.format("[KillWall] Centre : (%.1f, %.1f, %.1f)", centerX, centerY, centerZ))

-- ═══════════════════════════════════════
-- COULEURS PAR ZONE
-- ═══════════════════════════════════════
local ZONE_COLORS = {
    [1] = Color3.fromRGB(180, 180, 180),  -- Common    : gris
    [2] = Color3.fromRGB(80,  130, 255),  -- Rare      : bleu
    [3] = Color3.fromRGB(180,  50, 255),  -- Epic      : violet
    [4] = Color3.fromRGB(255, 190,   0),  -- Legendary : or
}

-- ═══════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════
local function collectParts(obj)
    if obj:IsA("BasePart") then return { obj } end
    local parts = {}
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("BasePart") then table.insert(parts, d) end
    end
    return parts
end

-- Rayon max XZ des coins de chaque part par rapport au centre
local function maxRadius(parts)
    local rMax = 0
    for _, p in ipairs(parts) do
        local hx, hz = p.Size.X / 2, p.Size.Z / 2
        for _, c in ipairs({
            { p.Position.X + hx, p.Position.Z + hz },
            { p.Position.X - hx, p.Position.Z + hz },
            { p.Position.X + hx, p.Position.Z - hz },
            { p.Position.X - hx, p.Position.Z - hz },
        }) do
            local d = math.sqrt((c[1] - centerX)^2 + (c[2] - centerZ)^2)
            if d > rMax then rMax = d end
        end
    end
    return rMax
end

-- ═══════════════════════════════════════
-- KILL ON TOUCH
-- ═══════════════════════════════════════
local hitCooldowns = {}
local function killPlayer(player, character)
    if hitCooldowns[player.UserId] then return end
    hitCooldowns[player.UserId] = true
    local h = character:FindFirstChildOfClass("Humanoid")
    if h and h.Health > 0 then h.Health = 0 end
    task.delay(4, function() hitCooldowns[player.UserId] = nil end)
end

-- ═══════════════════════════════════════
-- CONSTRUCTION DES ZONES
-- Zones triées du plus extérieur (index 1) au plus intérieur (index N).
-- rMax[i] = rayon extérieur détecté depuis les parts.
-- rMin[i] = rMax[i+1]  (l'anneau commence là où le suivant finit).
-- Override possible via InnerRadius / OuterRadius dans GameConfig.
-- ═══════════════════════════════════════
local zones = {}

for i = 1, 10 do
    local obj = Arena:FindFirstChild("SpawnZone" .. i)
    if obj then
        local parts = collectParts(obj)
        if #parts > 0 then
            local zoneName = "SpawnZone" .. i
            local cfg      = GameConfig.SpawnZones[zoneName] or GameConfig.SpawnZones.DefaultZone
            table.insert(zones, {
                index  = i,
                rMax   = maxRadius(parts),
                rMin   = 0,
                config = cfg,
            })
        end
    end
end

-- Trier par index croissant : Zone1 = extérieur, ZoneN = intérieur (ordre défini par le level design)
table.sort(zones, function(a, b) return a.index < b.index end)

-- Enchaîner les rMin : rMin[k] = rMax[k+1] (la zone suivante plus intérieure définit la limite)
for k = 1, #zones do
    zones[k].rMin = (zones[k + 1] and zones[k + 1].rMax) or 0
end

-- Appliquer les overrides du config
print("─────────────────────────────────────────────────")
print("[KillWall] Rayons finaux (modifiables via InnerRadius/OuterRadius dans GameConfig) :")
for _, z in ipairs(zones) do
    local kw = z.config.KillWall or {}
    if kw.InnerRadius then z.rMin = kw.InnerRadius end
    if kw.OuterRadius then z.rMax = kw.OuterRadius end
    print(string.format("  SpawnZone%d  inner=%.0f  outer=%.0f  épaisseur=%.0f",
        z.index, z.rMin, z.rMax, z.rMax - z.rMin))
end
print("─────────────────────────────────────────────────")

-- ═══════════════════════════════════════
-- CRÉER UN BRAS PAR ZONE
-- ═══════════════════════════════════════
for _, z in ipairs(zones) do
    local kw = z.config.KillWall or {}
    if not kw.Enabled then continue end

    local rMin          = z.rMin
    local rMax          = z.rMax
    local ringThickness = rMax - rMin

    if ringThickness < 1 then
        warn(string.format("[KillWall] Zone%d : épaisseur trop faible (%.1f), ignoré.", z.index, ringThickness))
        continue
    end

    local midRadius  = rMin + ringThickness / 2
    local wallHeight = kw.Height    or 30
    local wallWidth  = kw.WallWidth or 5
    local speedRad    = math.rad(kw.Speed or 30)
    local sweepRad    = math.rad(kw.SweepAngle or 180)
    local startRad    = math.rad(kw.StartAngle or 0)
    local color       = ZONE_COLORS[z.index] or Color3.fromRGB(255, 50, 50)

    local wall = Instance.new("Part")
    wall.Name         = "KillWall_Zone" .. z.index
    wall.Size         = Vector3.new(wallWidth, wallHeight, ringThickness)
    wall.Color        = color
    wall.Transparency = 0.3
    wall.Material     = Enum.Material.Neon
    wall.Anchored     = true
    wall.CanCollide   = false
    wall.CastShadow   = false
    wall.Parent       = Arena

    local wallY = centerY + wallHeight / 2

    local function getCF(angle)
        return CFrame.new(centerX, wallY, centerZ)
             * CFrame.Angles(0, angle, 0)
             * CFrame.new(0, 0, -midRadius)
    end

    wall.CFrame = getCF(startRad)

    -- Détection fiable via OverlapParams (remplace Touched, peu fiable sur parts ancrées en CFrame)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = { wall }
    overlapParams.MaxParts = 0

    local function checkHits()
        local hits = Workspace:GetPartBoundsInBox(wall.CFrame, wall.Size, overlapParams)
        local seen = {}
        for _, part in ipairs(hits) do
            local character = part.Parent
            if character and not seen[character] then
                seen[character] = true
                local player = Players:GetPlayerFromCharacter(character)
                if player then killPlayer(player, character) end
            end
        end
    end

    -- Sweep 0 → SweepAngle puis reset au StartAngle
    local angle = startRad
    RunService.Heartbeat:Connect(function(dt)
        angle += speedRad * dt
        if angle >= startRad + sweepRad then
            angle = startRad  -- reset au début
        end
        wall.CFrame = getCF(angle)
        checkHits()
    end)
end

print("[KillWall] " .. #zones .. " bras initialisé(s).")
