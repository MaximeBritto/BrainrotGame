--[[
    ActivationPadManager.server.lua
    Gère automatiquement TOUS les ActivationPads dans toutes les bases
    
    INSTRUCTIONS:
    1. Copier ce script dans ServerScriptService
    2. Le script trouve automatiquement tous les ActivationPads
    3. Connecte les événements Touched pour chaque pad
    4. Pas besoin de dupliquer quoi que ce soit!
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Attendre que tout soit chargé
task.wait(3)

print("═══════════════════════════════════════════════")
print("   ACTIVATION PAD MANAGER - Initialisation")
print("═══════════════════════════════════════════════")

-- Récupérer les modules
local Systems = ServerScriptService:WaitForChild("Systems")
local Core = ServerScriptService:WaitForChild("Core")

local DoorSystem = require(Systems["DoorSystem.module"])
local NetworkSetup = require(Core["NetworkSetup.module"])

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])

-- Cooldown par joueur (éviter le spam)
local cooldowns = {}
local COOLDOWN_TIME = 1 -- 1 seconde entre chaque activation

--[[
    Connecte un ActivationPad à DoorSystem
    @param pad: Part - L'ActivationPad
]]
local function ConnectActivationPad(pad)
    print("[ActivationPadManager] Connexion de: " .. pad:GetFullName())
    
    -- Détecter quand un joueur touche le pad
    pad.Touched:Connect(function(hit)
        -- Vérifier que c'est un personnage
        local character = hit.Parent
        local humanoid = character:FindFirstChild("Humanoid")
        
        if not humanoid then
            return
        end
        
        -- Trouver le joueur
        local player = Players:GetPlayerFromCharacter(character)
        
        if not player then
            return
        end
        
        -- Vérifier le cooldown
        local lastActivation = cooldowns[player.UserId] or 0
        local currentTime = tick()
        
        if currentTime - lastActivation < COOLDOWN_TIME then
            return -- Trop tôt
        end
        
        cooldowns[player.UserId] = currentTime
        
        print("[ActivationPadManager] " .. player.Name .. " a touché " .. pad.Name)
        
        -- Activer la porte via DoorSystem
        local result = DoorSystem:ActivateDoor(player)
        
        -- Envoyer une notification au joueur
        local remotes = NetworkSetup:GetAllRemotes()
        
        if result == Constants.ActionResult.Success then
            if remotes.Notification then
                remotes.Notification:FireClient(player, {
                    Type = "Success",
                    Message = "🚪 Door closed for 30 seconds!",
                    Duration = 3
                })
            end
            print("[ActivationPadManager] Porte activée pour " .. player.Name)
            
        elseif result == Constants.ActionResult.OnCooldown then
            local doorState = DoorSystem:GetDoorState(player)
            if remotes.Notification then
                remotes.Notification:FireClient(player, {
                    Type = "Warning",
                    Message = "⏱️ Door already closed! " .. doorState.RemainingTime .. "s remaining",
                    Duration = 2
                })
            end
            
        elseif result == Constants.ActionResult.NotOwner then
            if remotes.Notification then
                remotes.Notification:FireClient(player, {
                    Type = "Error",
                    Message = "❌ This is not your base!",
                    Duration = 2
                })
            end
        end
    end)
end

--[[
    Trouve et connecte tous les ActivationPads
]]
local function InitializeAllPads()
    local workspace = game:GetService("Workspace")
    local basesFolder = workspace:FindFirstChild(Constants.WorkspaceNames.BasesFolder)
    
    if not basesFolder then
        warn("[ActivationPadManager] Dossier Bases introuvable!")
        return
    end
    
    local padCount = 0
    
    -- Parcourir toutes les bases
    for _, base in ipairs(basesFolder:GetChildren()) do
        if base:IsA("Model") and string.match(base.Name, "^Base_%d+$") then
            -- Trouver le dossier Door
            local doorFolder = base:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
            
            if doorFolder then
                -- Trouver l'ActivationPad
                local activationPad = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorPad)
                
                if activationPad and activationPad:IsA("BasePart") then
                    ConnectActivationPad(activationPad)
                    padCount = padCount + 1
                else
                    warn("[ActivationPadManager] ActivationPad introuvable dans " .. base.Name)
                end
            else
                warn("[ActivationPadManager] Dossier Door introuvable dans " .. base.Name)
            end
        end
    end
    
    print("[ActivationPadManager] " .. padCount .. " ActivationPad(s) connecté(s)")
end

-- Initialiser tous les pads
InitializeAllPads()

print("═══════════════════════════════════════════════")
print("   ACTIVATION PAD MANAGER - Prêt!")
print("═══════════════════════════════════════════════")
