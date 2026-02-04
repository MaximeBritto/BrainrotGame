--[[
    SpinnerRotation.server.lua
    Fait tourner la barre du Spinner en continu
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Attendre que tout soit chargé
task.wait(1)

-- Charger GameConfig pour la vitesse
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig.module"))

-- Récupérer le Spinner
local arena = Workspace:FindFirstChild("Arena")
if not arena then
    warn("[SpinnerRotation] Arena manquante!")
    return
end

local spinner = arena:FindFirstChild("Spinner")
if not spinner then
    warn("[SpinnerRotation] Spinner manquant!")
    return
end

local center = spinner:FindFirstChild("Center")
local bar = spinner:FindFirstChild("Bar")

if not center or not bar then
    warn("[SpinnerRotation] Center ou Bar manquant dans Spinner!")
    return
end

-- Vérifier que Center est ancré et Bar ne l'est pas
center.Anchored = true
bar.Anchored = false

-- Créer un WeldConstraint pour attacher la barre au centre
local weld = Instance.new("WeldConstraint")
weld.Part0 = center
weld.Part1 = bar
weld.Parent = bar

-- Position initiale de la barre (offset depuis le centre)
local offset = bar.Position - center.Position
local offsetCFrame = CFrame.new(offset)

-- Vitesse de rotation (tours par seconde)
local spinSpeed = GameConfig.Arena.SpinnerSpeed or 2
local angle = 0

print("[SpinnerRotation] Rotation du Spinner activée - Vitesse: " .. spinSpeed .. " tours/sec")

-- Boucle de rotation
RunService.Heartbeat:Connect(function(deltaTime)
    -- Incrémenter l'angle
    angle = angle + (deltaTime * 2 * math.pi * spinSpeed)
    
    -- Appliquer la rotation au centre (qui entraîne la barre via le weld)
    center.CFrame = center.CFrame * CFrame.Angles(0, deltaTime * 2 * math.pi * spinSpeed, 0)
end)
