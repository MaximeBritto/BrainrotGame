--[[
    TEST_SERVER_HANDLER.server.lua
    Handler serveur pour les tests de données avec save
    
    INSTRUCTIONS:
    1. Copier ce script dans ServerScriptService
    2. Utiliser avec TEST_SERVER.client.lua
    3. SUPPRIMER après les tests
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- Handler de test/cheat : actif uniquement en Roblox Studio (dev local).
-- En production, le script s'arrête ici et n'enregistre aucun RemoteEvent.
if not RunService:IsStudio() then
    return
end

-- Attendre que tout soit chargé
task.wait(2)

-- Récupérer les services
local Core = ServerScriptService:WaitForChild("Core")
local DataService = require(Core["DataService.module"])

-- Créer le RemoteEvent de test
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local testRemote = Instance.new("RemoteEvent")
testRemote.Name = "TestServerData"
testRemote.Parent = remotes

-- Handler pour les tests
testRemote.OnServerEvent:Connect(function(player, action, value)
    
    local playerData = DataService:GetPlayerData(player)
    
    if not playerData then
        warn("[TEST HANDLER] Pas de données pour " .. player.Name)
        return
    end
    
    -- Traiter l'action
    if action == "AddCash" then
        -- Ajouter du cash
        local newCash = playerData.Cash + value
        DataService:UpdateValue(player, "Cash", newCash)
        
        -- Notifier le client
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Success",
                Message = "Added $" .. value .. "! New total: $" .. newCash,
                Duration = 3
            })
        end
        
        -- Sync avec le client
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, {Cash = newCash})
        end
        
    elseif action == "RemoveCash" then
        -- Retirer du cash
        local newCash = math.max(0, playerData.Cash - value)
        DataService:UpdateValue(player, "Cash", newCash)
        
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Warning",
                Message = "Removed $" .. value .. "! New total: $" .. newCash,
                Duration = 3
            })
        end
        
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, {Cash = newCash})
        end
        
    elseif action == "SetCash" then
        -- Définir le cash
        DataService:UpdateValue(player, "Cash", value)
        
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Info",
                Message = "Cash set to $" .. value,
                Duration = 3
            })
        end
        
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, {Cash = value})
        end
        
    elseif action == "AddSlot" then
        -- Ajouter des slots
        local newSlots = playerData.OwnedSlots + value
        DataService:UpdateValue(player, "OwnedSlots", newSlots)
        
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Success",
                Message = "Added " .. value .. " slot(s)! Total: " .. newSlots,
                Duration = 3
            })
        end
        
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, {OwnedSlots = newSlots})
        end
        
    elseif action == "ForceSave" then
        -- Forcer la sauvegarde
        local success = DataService:SavePlayerData(player)
        
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            if success then
                notifRemote:FireClient(player, {
                    Type = "Success",
                    Message = "💾 Data saved successfully!",
                    Duration = 3
                })
            else
                notifRemote:FireClient(player, {
                    Type = "Error",
                    Message = "❌ Save failed!",
                    Duration = 3
                })
            end
        end
        
    elseif action == "ShowData" then
        -- Afficher les données actuelles
        
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Info",
                Message = "📊 Data: $" .. playerData.Cash .. " | " .. playerData.OwnedSlots .. " slots",
                Duration = 4
            })
        end
        
    elseif action == "FullTest" then
        -- Test complet
        -- Ajouter $5000
        local newCash = playerData.Cash + 5000
        DataService:UpdateValue(player, "Cash", newCash)
        
        -- Ajouter 5 slots
        local newSlots = playerData.OwnedSlots + 5
        DataService:UpdateValue(player, "OwnedSlots", newSlots)
        
        -- Forcer save
        task.wait(0.5)
        local success = DataService:SavePlayerData(player)
        
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Success",
                Message = "🧪 Full test done! +$5000, +5 slots, saved!",
                Duration = 4
            })
        end
        
        -- Sync avec le client
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, {
                Cash = newCash,
                OwnedSlots = newSlots
            })
        end
        
    elseif action == "ClearBrainrots" then
        -- Clear tous les Brainrots
        -- 1. Détruire tous les modèles 3D
        local BrainrotModelSystem = require(game.ServerScriptService.Systems["BrainrotModelSystem.module"])
        if BrainrotModelSystem and BrainrotModelSystem._models and BrainrotModelSystem._models[player.UserId] then
            for slotIndex, model in pairs(BrainrotModelSystem._models[player.UserId]) do
                if model then
                    model:Destroy()
                end
            end
            BrainrotModelSystem._models[player.UserId] = {}
        end
        
        -- 2. Clear les données sauvegardées (Brainrots ET PlacedBrainrots)
        DataService:UpdateValue(player, "Brainrots", {})
        DataService:UpdateValue(player, "PlacedBrainrots", {})
        
        -- 3. Arrêter la génération d'argent dans EconomySystem
        local EconomySystem = require(game.ServerScriptService.Systems["EconomySystem.module"])
        if EconomySystem and EconomySystem._slotRevenue and EconomySystem._slotRevenue[player.UserId] then
            EconomySystem._slotRevenue[player.UserId] = {}
        end
        
        -- 4. Forcer save
        task.wait(0.5)
        local success = DataService:SavePlayerData(player)
        
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Success",
                Message = "🗑️ All Brainrots cleared!",
                Duration = 3
            })
        end
        
        -- Sync avec le client
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, DataService:GetPlayerData(player))
        end
        
    elseif action == "ClearSlotCash" then
        -- Clear l'argent des slots
        DataService:UpdateValue(player, "SlotCash", {})
        
        -- Forcer save
        task.wait(0.5)
        local success = DataService:SavePlayerData(player)
        
        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Success",
                Message = "💰 Slot cash cleared!",
                Duration = 3
            })
        end
        
        -- Sync avec le client
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, DataService:GetPlayerData(player))
        end
        
    elseif action == "AddSpeed" then
        -- Ajouter du speed bonus permanent
        local amount = value or 10
        local GameConfig = require(ReplicatedStorage.Config["GameConfig.module"])
        local baseSpeed = GameConfig.MoveSpeed.BaseSpeed or 16
        local maxSpeed = GameConfig.MoveSpeed.MaxSpeed or 50
        local currentBonus = playerData.PermanentSpeedBonus or 0
        local newBonus = currentBonus + amount

        if baseSpeed + newBonus > maxSpeed then
            newBonus = maxSpeed - baseSpeed
        end

        DataService:UpdateValue(player, "PermanentSpeedBonus", newBonus)

        -- Appliquer immédiatement
        local PlayerService = require(Core["PlayerService.module"])
        if PlayerService and PlayerService.ApplyWalkSpeed then
            PlayerService:ApplyWalkSpeed(player)
        end

        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Success",
                Message = "+" .. amount .. " Speed! Total bonus: " .. newBonus .. " (WalkSpeed: " .. (baseSpeed + newBonus) .. ")",
                Duration = 3
            })
        end

        -- Sync speed vers le client
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, { PermanentSpeedBonus = newBonus })
        end

    elseif action == "ResetSpeed" then
        -- Reset le speed bonus à 0
        DataService:UpdateValue(player, "PermanentSpeedBonus", 0)

        -- Appliquer immédiatement
        local PlayerService = require(Core["PlayerService.module"])
        if PlayerService and PlayerService.ApplyWalkSpeed then
            PlayerService:ApplyWalkSpeed(player)
        end

        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Warning",
                Message = "Speed reset to default (16)",
                Duration = 3
            })
        end

        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, { PermanentSpeedBonus = 0 })
        end

    elseif action == "AddJump" then
        -- Ajouter du jump bonus permanent
        local amount = value or 20
        local GameConfig = require(ReplicatedStorage.Config["GameConfig.module"])
        local basePower = GameConfig.Jump.BasePower or 50
        local maxPower = GameConfig.Jump.MaxPower or 350
        local currentBonus = playerData.PermanentJumpBonus or 0
        local newBonus = currentBonus + amount

        if basePower + newBonus > maxPower then
            newBonus = maxPower - basePower
        end

        DataService:UpdateValue(player, "PermanentJumpBonus", newBonus)

        -- Appliquer immédiatement
        local PlayerService = require(Core["PlayerService.module"])
        if PlayerService and PlayerService.ApplyJumpPower then
            PlayerService:ApplyJumpPower(player)
        end

        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Success",
                Message = "+" .. amount .. " Jump! Total bonus: " .. newBonus .. " (JumpPower: " .. (basePower + newBonus) .. ")",
                Duration = 3
            })
        end

        -- Sync jump vers le client
        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, { PermanentJumpBonus = newBonus })
        end

    elseif action == "ResetJump" then
        -- Reset le jump bonus à 0
        DataService:UpdateValue(player, "PermanentJumpBonus", 0)

        -- Appliquer immédiatement
        local PlayerService = require(Core["PlayerService.module"])
        if PlayerService and PlayerService.ApplyJumpPower then
            PlayerService:ApplyJumpPower(player)
        end

        local notifRemote = remotes:FindFirstChild("Notification")
        if notifRemote then
            notifRemote:FireClient(player, {
                Type = "Warning",
                Message = "Jump reset to default (50)",
                Duration = 3
            })
        end

        local syncRemote = remotes:FindFirstChild("SyncPlayerData")
        if syncRemote then
            syncRemote:FireClient(player, { PermanentJumpBonus = 0 })
        end

    elseif action == "ToggleJump" then
        -- Toggle jump on/off (runtime uniquement, pas sauvegardé)
        local PlayerService = require(Core["PlayerService.module"])
        if PlayerService and PlayerService.ToggleJump then
            local boosted = PlayerService:ToggleJump(player)

            local notifRemote = remotes:FindFirstChild("Notification")
            if notifRemote then
                notifRemote:FireClient(player, {
                    Type = "Info",
                    Message = boosted and "Jump ENABLED (bonus applied)" or "Jump DISABLED (default 50)",
                    Duration = 2
                })
            end
        end

    elseif action == "SpawnBrainrotPiece" then
        -- Spawn une pièce comme ArenaSystem le fait
        local setName = value.SetName
        local pieceType = value.PieceType
        
        -- Récupérer ArenaSystem
        local Systems = ServerScriptService:WaitForChild("Systems")
        local ArenaSystem = require(Systems["ArenaSystem.module"])
        
        -- Récupérer le BrainrotData
        local BrainrotData = require(ReplicatedStorage.Data["BrainrotData.module"])
        local setData = BrainrotData.Sets[setName]
        
        if not setData or not setData[pieceType] then
            warn("[TEST HANDLER] Set ou pièce invalide: " .. setName .. " " .. pieceType)
            return
        end
        
        local pieceData = setData[pieceType]
        local templateName = pieceData.TemplateName
        
        if templateName == "" then
            warn("[TEST HANDLER] Pas de template pour cette pièce")
            return
        end
        
        -- Trouver le template dans Assets/BodyPartTemplates
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        if not assets then
            warn("[TEST HANDLER] Dossier Assets introuvable")
            return
        end
        
        local bodyPartTemplates = assets:FindFirstChild("BodyPartTemplates")
        if not bodyPartTemplates then
            warn("[TEST HANDLER] Dossier BodyPartTemplates introuvable")
            return
        end
        
        local templateFolder = bodyPartTemplates:FindFirstChild(pieceType .. "Template")
        if not templateFolder then
            warn("[TEST HANDLER] Dossier template introuvable: " .. pieceType .. "Template")
            return
        end
        
        local template = templateFolder:FindFirstChild(templateName)
        if not template then
            warn("[TEST HANDLER] Template introuvable: " .. templateName)
            return
        end
        
        -- Appeler la fonction interne d'ArenaSystem pour spawner correctement
        local piece = ArenaSystem:_SpawnSpecificPiece(setName, pieceType, pieceData, templateName, template, player.Character.HumanoidRootPart.Position + Vector3.new(0, 5, 0))
        
        if piece then
            local notifRemote = remotes:FindFirstChild("Notification")
            if notifRemote then
                notifRemote:FireClient(player, {
                    Type = "Success",
                    Message = "✨ Spawned " .. pieceData.DisplayName .. "!",
                    Duration = 2
                })
            end
        end
    end
end)

