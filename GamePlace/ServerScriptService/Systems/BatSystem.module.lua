-- ServerScriptService/Systems/BatSystem.module.lua
local BatSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Modules
local DataService = require(script.Parent.Parent.Core["DataService.module"])
local GameConfig = require(ReplicatedStorage.Config["GameConfig.module"])

-- Systèmes injectés
local PlayerService = nil
local DataService_ref = nil
local BrainrotModelSystem_ref = nil

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
function BatSystem:Init(services)
    print("[BatSystem] Initialisation...")

    if services then
        PlayerService = services.PlayerService
        DataService_ref = services.DataService
        BrainrotModelSystem_ref = services.BrainrotModelSystem
    end

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
-- Retire le Brainrot volé porté en main et le retourne au slot d'origine
---
function BatSystem:_ReturnStolenBrainrot(victim)
    if not PlayerService then return end

    local carriedData = PlayerService:GetCarriedBrainrot(victim)
    if not carriedData then return end

    -- Vider le CarriedBrainrot
    PlayerService:ClearCarriedBrainrot(victim)

    -- Détruire le modèle visuel
    local character = victim.Character
    if character then
        local carriedModel = character:FindFirstChild("CarriedBrainrot")
        if carriedModel then carriedModel:Destroy() end
        character:SetAttribute("CarryingBrainrot", nil)
    end

    -- Sync client (vider le carried côté client)
    local syncCarried = remotes:FindFirstChild("SyncCarriedBrainrot")
    if syncCarried then
        syncCarried:FireClient(victim, nil)
    end

    -- Retourner le brainrot au slot d'origine
    local originalOwnerId = carriedData.StolenFromUserId
    local originalSlotId = carriedData.StolenFromSlotId
    if originalOwnerId and originalSlotId and DataService_ref then
        local owner = Players:GetPlayerByUserId(originalOwnerId)
        if owner then
            local ownerData = DataService_ref:GetPlayerData(owner)
            if ownerData then
                local slotKey = tostring(originalSlotId)
                local brainrotData = {
                    HeadSet = carriedData.HeadSet,
                    BodySet = carriedData.BodySet,
                    LegsSet = carriedData.LegsSet,
                    SetName = carriedData.SetName,
                    PlacedAt = os.time(),
                }
                ownerData.PlacedBrainrots[slotKey] = brainrotData
                DataService_ref:UpdateValue(owner, "PlacedBrainrots", ownerData.PlacedBrainrots)

                -- Recréer le modèle 3D sur le slot
                if BrainrotModelSystem_ref then
                    BrainrotModelSystem_ref:CreateBrainrotModel(owner, originalSlotId, brainrotData)
                end

                -- Sync le propriétaire
                remotes.SyncPlayerData:FireClient(owner, {
                    PlacedBrainrots = ownerData.PlacedBrainrots,
                    Cash = ownerData.Cash,
                })
                remotes.Notification:FireClient(owner, {
                    Type = "Success",
                    Message = "Votre Brainrot volé a été récupéré!"
                })

                print(string.format("[BatSystem] Brainrot retourné au slot %d de %s", originalSlotId, owner.Name))
            end
        end
    end

    remotes.Notification:FireClient(victim, {
        Type = "Error",
        Message = "Vous avez perdu le Brainrot volé!"
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
