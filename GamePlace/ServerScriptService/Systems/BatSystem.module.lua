-- ServerScriptService/Systems/BatSystem.module.lua
local BatSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Modules
local DataService = require(script.Parent.Parent.Core["DataService.module"])
local GameConfig = require(ReplicatedStorage.Config["GameConfig.module"])

-- RemoteEvents (initialisé dans Init, après que NetworkSetup ait créé le dossier)
local remotes = nil

-- État temporaire : {userId = {IsStunned, StunEndTime, LastBatHitTime}}
local _playerStates = {}

-- Configuration
local STUN_DURATION = GameConfig.StunDuration or 5 -- secondes
local BAT_COOLDOWN = GameConfig.BatCooldown or 1 -- secondes
local BAT_MAX_DISTANCE = GameConfig.BatMaxDistance or 10 -- studs

---
-- Initialisation
---
function BatSystem:Init()
    print("[BatSystem] Initialisation...")

    remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not remotes then
        warn("[BatSystem] Remotes introuvable!")
    end

    -- Donner la batte au spawn
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            self:_GiveBat(player, character)
        end)
        if player.Character then
            self:_GiveBat(player, player.Character)
        end
    end)

    -- Donner la batte aux joueurs déjà connectés
    for _, player in ipairs(Players:GetPlayers()) do
        player.CharacterAdded:Connect(function(character)
            self:_GiveBat(player, character)
        end)
        if player.Character then
            self:_GiveBat(player, player.Character)
        end
    end

    print("[BatSystem] Initialisé!")
end

---
-- Soude la batte à la main droite du joueur (pas de Tool = pas de 180°)
---
function BatSystem:_GiveBat(player, character)
    task.wait(0.5) -- Attendre que le personnage soit complètement chargé

    local bat = ServerStorage:FindFirstChild("Bat")
    if not bat then
        warn("[BatSystem] Batte introuvable dans ServerStorage!")
        return
    end

    -- Trouver la main droite
    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if not rightHand then
        warn("[BatSystem] Main droite introuvable!")
        return
    end

    -- Supprimer l'ancienne batte si elle existe
    local oldBat = character:FindFirstChild("BatModel")
    if oldBat then
        oldBat:Destroy()
    end

    -- Cloner le Handle de la batte
    local handle = bat:FindFirstChild("Handle")
    if not handle then
        warn("[BatSystem] Handle introuvable dans la Bat!")
        return
    end

    local batModel = handle:Clone()
    batModel.Name = "BatModel"
    batModel.CanCollide = false

    -- Souder la batte à la main
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = rightHand
    weld.Part1 = batModel
    weld.Parent = batModel

    -- Positionner la batte dans la main
    batModel.CFrame = rightHand.CFrame * CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(180), 0, math.rad(90))
    batModel.Parent = character

    -- Marquer le joueur comme ayant une batte
    character:SetAttribute("HasBat", true)

    print(string.format("[BatSystem] Batte soudée à la main de %s", player.Name))
end

---
-- Gère un coup de batte
-- @param attacker Player - L'attaquant
-- @param victimId number - UserId de la victime
---
function BatSystem:HandleBatHit(attacker, victimId)
    local attackerId = attacker.UserId

    -- 1. Vérifier le cooldown de l'attaquant
    if not self:_CheckCooldown(attackerId) then
        return
    end

    -- 2. Vérifier que la victime existe
    local victim = Players:GetPlayerByUserId(victimId)
    if not victim then
        return
    end

    -- 3. Vérifier que la victime n'est pas déjà stun
    if self:IsStunned(victimId) then
        remotes.Notification:FireClient(attacker, {
            Type = "Info",
            Message = "Ce joueur est déjà assommé."
        })
        return
    end

    -- 4. Vérifier la distance
    if not self:_IsInRange(attacker, victim) then
        remotes.Notification:FireClient(attacker, {
            Type = "Error",
            Message = "Trop loin pour frapper!"
        })
        return
    end

    -- 5. Appliquer le stun
    self:_ApplyStun(victim)

    -- 6. Si la victime transportait un Brainrot volé, le retourner
    self:_ReturnStolenBrainrot(victim)

    -- 7. Mettre à jour le cooldown de l'attaquant
    _playerStates[attackerId] = _playerStates[attackerId] or {}
    _playerStates[attackerId].LastBatHitTime = tick()

    print(string.format("[BatSystem] %s a assommé %s", attacker.Name, victim.Name))
end

---
-- Vérifie le cooldown de l'attaquant
---
function BatSystem:_CheckCooldown(attackerId)
    local state = _playerStates[attackerId]
    if not state or not state.LastBatHitTime then
        return true
    end

    local elapsed = tick() - state.LastBatHitTime
    return elapsed >= BAT_COOLDOWN
end

---
-- Vérifie si l'attaquant est à portée de la victime
---
function BatSystem:_IsInRange(attacker, victim)
    local attackerChar = attacker.Character
    local victimChar = victim.Character

    if not attackerChar or not victimChar then return false end

    local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
    local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")

    if not attackerRoot or not victimRoot then return false end

    local distance = (attackerRoot.Position - victimRoot.Position).Magnitude
    return distance <= BAT_MAX_DISTANCE
end

---
-- Applique le stun à la victime
---
function BatSystem:_ApplyStun(victim)
    local victimId = victim.UserId

    -- Mettre à jour l'état
    _playerStates[victimId] = _playerStates[victimId] or {}
    _playerStates[victimId].IsStunned = true
    _playerStates[victimId].StunEndTime = tick() + STUN_DURATION

    -- Faire tomber le personnage au sol (ragdoll)
    local character = victim.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Désactiver le mouvement
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            -- Activer PlatformStand pour faire tomber au sol
            humanoid.PlatformStand = true
        end
    end

    -- Notification simple
    remotes.Notification:FireClient(victim, {
        Type = "Error",
        Message = "Vous êtes assommé!"
    })

    -- Retirer le stun après la durée
    task.delay(STUN_DURATION, function()
        self:_RemoveStun(victim)
    end)
end

---
-- Retire le stun de la victime
---
function BatSystem:_RemoveStun(victim)
    local victimId = victim.UserId

    -- Mettre à jour l'état
    _playerStates[victimId] = _playerStates[victimId] or {}
    _playerStates[victimId].IsStunned = false

    -- Relever le personnage et réactiver le mouvement
    local character = victim.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Désactiver PlatformStand pour relever le personnage
            humanoid.PlatformStand = false
            -- Réactiver le mouvement
            humanoid.WalkSpeed = 16 -- Vitesse par défaut
            humanoid.JumpPower = 50 -- Vitesse par défaut
        end
    end

    -- Notification simple
    remotes.Notification:FireClient(victim, {
        Type = "Success",
        Message = "Vous pouvez bouger à nouveau."
    })

    print(string.format("[BatSystem] %s n'est plus assommé", victim.Name))
end

---
-- Retourne le Brainrot volé (si la victime en transportait un)
---
function BatSystem:_ReturnStolenBrainrot(victim)
    local victimId = victim.UserId
    local victimData = DataService:GetPlayerData(victimId)
    if not victimData then return end

    -- Vérifier si l'inventaire contient des pièces "volées"
    -- (identifiables par le préfixe "stolen_")
    local stolenPieces = {}
    for pieceId, pieceData in pairs(victimData.Inventory) do
        if string.find(pieceId, "stolen_") then
            table.insert(stolenPieces, pieceId)
        end
    end

    if #stolenPieces == 0 then
        return -- Pas de Brainrot volé
    end

    -- Retirer les pièces de l'inventaire
    for _, pieceId in ipairs(stolenPieces) do
        victimData.Inventory[pieceId] = nil
    end

    DataService:SetPlayerData(victimId, victimData)

    -- Sync au client
    remotes.SyncInventory:FireClient(victim, victimData.Inventory)
    remotes.Notification:FireClient(victim, {
        Type = "Error",
        Message = "Votre Brainrot volé a été perdu!"
    })

    print(string.format("[BatSystem] Brainrot volé retiré de %s", victim.Name))
end

---
-- Vérifie si un joueur est stun
---
function BatSystem:IsStunned(userId)
    local state = _playerStates[userId]
    if not state or not state.IsStunned then
        return false
    end

    -- Vérifier si le stun est encore actif
    if tick() >= state.StunEndTime then
        state.IsStunned = false
        return false
    end

    return true
end

return BatSystem
