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

