--[[
    ActivationPad.server.lua
    Script à mettre dans chaque ActivationPad
    
    INSTRUCTIONS:
    1. Copier ce script dans Base_1/Door/ActivationPad
    2. Le script détecte quand un joueur touche le pad
    3. Active la porte via DoorSystem
    4. Dupliquer pour toutes les autres bases
]]

local pad = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Attendre que tout soit chargé
task.wait(2)

-- Récupérer DoorSystem
local Systems = ServerScriptService:WaitForChild("Systems")
local DoorSystem = require(Systems["DoorSystem.module"])

-- Récupérer NetworkSetup pour les notifications
local Core = ServerScriptService:WaitForChild("Core")
local NetworkSetup = require(Core["NetworkSetup.module"])

print("[ActivationPad] Script chargé pour: " .. pad:GetFullName())

-- Cooldown par joueur (éviter le spam)
local cooldowns = {}
local COOLDOWN_TIME = 1 -- 1 seconde entre chaque activation

-- Détecter quand un joueur touche le pad
pad.Touched:Connect(function(hit)
    -- Vérifier que c'est un personnage
    local character = hit.Parent
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not humanoid then
        return
    end
    
    -- Trouver le joueur
    local player = game.Players:GetPlayerFromCharacter(character)
    
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
    
    print("[ActivationPad] " .. player.Name .. " a touché le pad")
    
    -- Activer la porte via DoorSystem
    local result = DoorSystem:ActivateDoor(player)
    
    -- Envoyer une notification au joueur
    local remotes = NetworkSetup:GetAllRemotes()
    
    if result == "Success" then
        if remotes.Notification then
            remotes.Notification:FireClient(player, {
                Type = "Success",
                Message = "🚪 Door closed for 30 seconds!",
                Duration = 3
            })
        end
        print("[ActivationPad] Porte activée pour " .. player.Name)
        
    elseif result == "OnCooldown" then
        local doorState = DoorSystem:GetDoorState(player)
        if remotes.Notification then
            remotes.Notification:FireClient(player, {
                Type = "Warning",
                Message = "⏱️ Door already closed! " .. doorState.RemainingTime .. "s remaining",
                Duration = 2
            })
        end
        
    elseif result == "NotOwner" then
        if remotes.Notification then
            remotes.Notification:FireClient(player, {
                Type = "Error",
                Message = "❌ This is not your base!",
                Duration = 2
            })
        end
    end
end)

print("[ActivationPad] Prêt à détecter les touches")
