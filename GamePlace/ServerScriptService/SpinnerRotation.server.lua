--[[
    SpinnerRotation.server.lua
    Fait tourner tous les Spinners de l'arène en continu
    Supporte plusieurs spinners avec des vitesses différentes
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Attendre que tout soit chargé
task.wait(1)

-- Charger GameConfig pour la vitesse
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig.module"))

-- Récupérer l'arène
local arena = Workspace:FindFirstChild("Arena")
if not arena then
    warn("[SpinnerRotation] Arena manquante!")
    return
end

-- Liste des spinners actifs: { center, speed }
local activeSpinners = {}

-- Fonction pour initialiser un spinner
local function setupSpinner(spinnerModel, speed)
    local center = spinnerModel:FindFirstChild("Center")
    local bar = spinnerModel:FindFirstChild("Bar")

    if not center or not bar then
        warn("[SpinnerRotation] Center ou Bar manquant dans " .. spinnerModel.Name .. "!")
        return
    end

    -- Ancrer le centre
    center.Anchored = true

    -- Désactiver les collisions (la détection de mort fonctionne via Touched)
    bar.CanCollide = false
    center.CanCollide = false

    -- Créer le WeldConstraint AVANT de désancrer la barre
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = center
    weld.Part1 = bar
    weld.Parent = bar

    -- Désancrer la barre maintenant que le weld la retient
    bar.Anchored = false

    table.insert(activeSpinners, {
        center = center,
        speed = speed,
    })

    print("[SpinnerRotation] " .. spinnerModel.Name .. " activé - Vitesse: " .. speed .. " tours/sec")
end

-- Initialiser le spinner principal
local mainSpinner = arena:FindFirstChild("Spinner")
if mainSpinner then
    local mainSpeed = GameConfig.Arena.SpinnerSpeed or 0.1
    setupSpinner(mainSpinner, mainSpeed)
else
    warn("[SpinnerRotation] Spinner principal manquant!")
end

-- Initialiser les spinners supplémentaires depuis la config
local extraSpinners = GameConfig.Arena.ExtraSpinners or {}
for _, spinnerConfig in ipairs(extraSpinners) do
    local spinnerModel = arena:FindFirstChild(spinnerConfig.Name)
    if spinnerModel then
        setupSpinner(spinnerModel, spinnerConfig.Speed)
    else
        warn("[SpinnerRotation] " .. spinnerConfig.Name .. " manquant dans Arena!")
    end
end

-- Boucle de rotation pour tous les spinners
RunService.Heartbeat:Connect(function(deltaTime)
    for _, spinner in ipairs(activeSpinners) do
        local rotationAngle = deltaTime * 2 * math.pi * spinner.speed
        spinner.center.CFrame = spinner.center.CFrame * CFrame.Angles(0, rotationAngle, 0)
    end
end)
