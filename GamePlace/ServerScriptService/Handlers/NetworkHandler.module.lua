--[[
    NetworkHandler.lua
    Gère tous les RemoteEvents reçus du client
    
    Responsabilités:
    - Recevoir les requêtes client
    - Valider les données
    - Appeler les bons systèmes
    - Renvoyer les résultats
    
    Phase 6 (A6.4) - Vérification Codex:
    - SyncCodex est envoyé par CodexService/DataService/PlayerService (pas par NetworkHandler)
    - SyncPlayerData inclut CodexUnlocked pour synchro globale (GetFullPlayerData, Craft, etc.)
    - Aucun handler n'écrase ou ne duplique SyncCodex
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])

-- Services (seront injectés)
local NetworkSetup = nil
local DataService = nil
local PlayerService = nil

-- Systèmes (Phase 2+)
local BaseSystem = nil
local DoorSystem = nil
local EconomySystem = nil

-- Systèmes (Phase 4)
local ArenaSystem = nil
local InventorySystem = nil

-- Systèmes (Phase 5)
local CraftingSystem = nil
local PlacementSystem = nil

-- Systèmes (Phase 8)
local StealSystem = nil
local BatSystem = nil

-- Systèmes (Phase 9)
local ShopSystem = nil

-- Systèmes (Lucky Block)
local LuckyBlockSystem = nil

-- Systèmes (Spin Wheel)
local SpinWheelSystem = nil

-- Systèmes (Fusion)
local FusionSystem = nil

local NetworkHandler = {}
NetworkHandler._initialized = false

--[[
    Initialise le handler et connecte tous les événements
    @param services: table
]]
function NetworkHandler:Init(services)
    if self._initialized then
        warn("[NetworkHandler] Déjà initialisé!")
        return
    end
    
    print("[NetworkHandler] Initialisation...")
    
    -- Récupérer les services
    NetworkSetup = services.NetworkSetup
    DataService = services.DataService
    PlayerService = services.PlayerService
    
    -- Récupérer les systèmes (Phase 2+)
    BaseSystem = services.BaseSystem
    DoorSystem = services.DoorSystem
    EconomySystem = services.EconomySystem
    
    -- Récupérer les systèmes (Phase 4)
    ArenaSystem = services.ArenaSystem
    InventorySystem = services.InventorySystem
    
    -- Récupérer les systèmes (Phase 5)
    CraftingSystem = services.CraftingSystem
    PlacementSystem = services.PlacementSystem

    -- Récupérer les systèmes (Phase 8)
    StealSystem = services.StealSystem
    BatSystem = services.BatSystem

    -- Récupérer les systèmes (Phase 9)
    ShopSystem = services.ShopSystem

    -- Récupérer les systèmes (Lucky Block)
    LuckyBlockSystem = services.LuckyBlockSystem

    -- Récupérer les systèmes (Spin Wheel)
    SpinWheelSystem = services.SpinWheelSystem

    -- Connecter les handlers
    self:_ConnectHandlers()
    
    self._initialized = true
    print("[NetworkHandler] Initialisé!")
end

--[[
    Connecte tous les handlers aux RemoteEvents
]]
function NetworkHandler:_ConnectHandlers()
    local remotes = NetworkSetup:GetAllRemotes()
    
    -- ═══════════════════════════════════════
    -- CLIENT → SERVEUR (RemoteEvents)
    -- ═══════════════════════════════════════
    
    -- PickupPiece (Phase 4)
    if remotes.PickupPiece then
        remotes.PickupPiece.OnServerEvent:Connect(function(player, pieceId)
            self:_HandlePickupPiece(player, pieceId)
        end)
    end
    
    -- Craft (Phase 5)
    if remotes.Craft then
        remotes.Craft.OnServerEvent:Connect(function(player, slotIndex)
            self:_HandleCraft(player, slotIndex)
        end)
    end
    
    -- BuySlot (Phase 3)
    if remotes.BuySlot then
        remotes.BuySlot.OnServerEvent:Connect(function(player)
            self:_HandleBuySlot(player)
        end)
    end
    
    -- CollectSlotCash (Phase 3)
    if remotes.CollectSlotCash then
        remotes.CollectSlotCash.OnServerEvent:Connect(function(player, slotIndex)
            self:_HandleCollectSlotCash(player, slotIndex)
        end)
    end
    
    -- ActivateDoor (Phase 2)
    if remotes.ActivateDoor then
        remotes.ActivateDoor.OnServerEvent:Connect(function(player)
            self:_HandleActivateDoor(player)
        end)
    end
    
    -- DropPieces (Phase 4)
    if remotes.DropPieces then
        remotes.DropPieces.OnServerEvent:Connect(function(player)
            self:_HandleDropPieces(player)
        end)
    end

    -- Vente de Brainrot (SellBrainrot)
    if remotes.SellBrainrot then
        remotes.SellBrainrot.OnServerEvent:Connect(function(player, slotIndex)
            if type(slotIndex) == "string" then
                slotIndex = tonumber(slotIndex)
            end
            if not slotIndex or type(slotIndex) ~= "number" then return end

            local success, err = pcall(function()
                self:_HandleSellBrainrot(player, slotIndex)
            end)

            if not success then
                warn("[NetworkHandler] Erreur SellBrainrot: " .. tostring(err))
            end
        end)
    end

    -- Vol de Brainrot (Phase 8 - Version simplifiée)
    if remotes.StealBrainrot then
        remotes.StealBrainrot.OnServerEvent:Connect(function(player, ownerId, slotId)
            print(string.format("[NetworkHandler] StealBrainrot reçu - player: %s, ownerId: %s (type: %s), slotId: %s (type: %s)",
                player.Name, tostring(ownerId), type(ownerId), tostring(slotId), type(slotId)))

            -- Convertir les paramètres en nombres si nécessaire
            if type(ownerId) == "string" then
                ownerId = tonumber(ownerId)
            end
            if type(slotId) == "string" then
                slotId = tonumber(slotId)
            end

            local success, err = pcall(function()
                if StealSystem then
                    StealSystem:ExecuteSteal(player, ownerId, slotId)
                else
                    warn("[NetworkHandler] StealSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur StealBrainrot: " .. tostring(err))
            end
        end)
    end

    -- Placer brainrot volé sur un slot (Phase 8 v2)
    if remotes.PlaceStolenBrainrot then
        remotes.PlaceStolenBrainrot.OnServerEvent:Connect(function(player, slotIndex)
            if type(slotIndex) == "string" then
                slotIndex = tonumber(slotIndex)
            end
            if not slotIndex or type(slotIndex) ~= "number" then return end

            local success, err = pcall(function()
                if StealSystem then
                    StealSystem:PlaceStolenBrainrot(player, slotIndex)
                else
                    warn("[NetworkHandler] StealSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur PlaceStolenBrainrot: " .. tostring(err))
            end
        end)
    end

    -- Combat batte (Phase 8)
    if remotes.BatHit then
        remotes.BatHit.OnServerEvent:Connect(function(player, victimId)
            pcall(function()
                if BatSystem then
                    BatSystem:HandleBatHit(player, victimId)
                end
            end)
        end)
    end

    -- Achat Shop Robux (Phase 9)
    if remotes.RequestShopPurchase then
        remotes.RequestShopPurchase.OnServerEvent:Connect(function(player, categoryId, productIndex)
            -- Convertir productIndex en nombre si nécessaire
            if type(productIndex) == "string" then
                productIndex = tonumber(productIndex)
            end

            local success, err = pcall(function()
                if ShopSystem then
                    ShopSystem:RequestPurchase(player, categoryId, productIndex)
                else
                    warn("[NetworkHandler] ShopSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur RequestShopPurchase: " .. tostring(err))
            end
        end)
    end

    -- Achat Lucky Block (Lucky Block)
    if remotes.BuyLuckyBlock then
        remotes.BuyLuckyBlock.OnServerEvent:Connect(function(player, amount)
            if type(amount) == "string" then
                amount = tonumber(amount)
            end
            if not amount or type(amount) ~= "number" then return end

            local success, err = pcall(function()
                if LuckyBlockSystem then
                    LuckyBlockSystem:RequestBuy(player, amount)
                else
                    warn("[NetworkHandler] LuckyBlockSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur BuyLuckyBlock: " .. tostring(err))
            end
        end)
    end

    -- Ouverture de porte payante (Robux)
    if remotes.RequestDoorOpen then
        remotes.RequestDoorOpen.OnServerEvent:Connect(function(player, targetOwnerId)
            if type(targetOwnerId) == "string" then
                targetOwnerId = tonumber(targetOwnerId)
            end
            if not targetOwnerId or type(targetOwnerId) ~= "number" then return end

            local success, err = pcall(function()
                if DoorSystem then
                    DoorSystem:RequestDoorOpen(player, targetOwnerId)
                else
                    warn("[NetworkHandler] DoorSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur RequestDoorOpen: " .. tostring(err))
            end
        end)
    end

    -- Ouvrir Lucky Block (Lucky Block)
    if remotes.OpenLuckyBlock then
        remotes.OpenLuckyBlock.OnServerEvent:Connect(function(player)
            local success, err = pcall(function()
                if LuckyBlockSystem then
                    LuckyBlockSystem:TryOpen(player)
                else
                    warn("[NetworkHandler] LuckyBlockSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur OpenLuckyBlock: " .. tostring(err))
            end
        end)
    end

    -- Lucky Block Take (prendre les pièces)
    if remotes.LuckyBlockTake then
        remotes.LuckyBlockTake.OnServerEvent:Connect(function(player)
            local success, err = pcall(function()
                if LuckyBlockSystem then
                    LuckyBlockSystem:TakeResult(player)
                else
                    warn("[NetworkHandler] LuckyBlockSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur LuckyBlockTake: " .. tostring(err))
            end
        end)
    end

    -- Lucky Block Throw (jeter les pièces)
    if remotes.LuckyBlockThrow then
        remotes.LuckyBlockThrow.OnServerEvent:Connect(function(player)
            local success, err = pcall(function()
                if LuckyBlockSystem then
                    LuckyBlockSystem:ThrowResult(player)
                else
                    warn("[NetworkHandler] LuckyBlockSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur LuckyBlockThrow: " .. tostring(err))
            end
        end)
    end

    -- Achat Spin Wheel (Spin Wheel)
    if remotes.BuySpinWheel then
        remotes.BuySpinWheel.OnServerEvent:Connect(function(player, amount)
            if type(amount) == "string" then
                amount = tonumber(amount)
            end
            if not amount or type(amount) ~= "number" then return end

            local success, err = pcall(function()
                if SpinWheelSystem then
                    SpinWheelSystem:RequestBuy(player, amount)
                else
                    warn("[NetworkHandler] SpinWheelSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur BuySpinWheel: " .. tostring(err))
            end
        end)
    end

    -- Tourner la roue (Spin Wheel)
    if remotes.SpinWheel then
        remotes.SpinWheel.OnServerEvent:Connect(function(player)
            local success, err = pcall(function()
                if SpinWheelSystem then
                    SpinWheelSystem:TrySpin(player)
                else
                    warn("[NetworkHandler] SpinWheelSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur SpinWheel: " .. tostring(err))
            end
        end)
    end

    -- Réclamer récompense fusion (Fusion System)
    if remotes.ClaimFusionReward then
        remotes.ClaimFusionReward.OnServerEvent:Connect(function(player, milestoneIndex)
            if type(milestoneIndex) == "string" then
                milestoneIndex = tonumber(milestoneIndex)
            end
            if not milestoneIndex or type(milestoneIndex) ~= "number" then return end

            local success, err = pcall(function()
                if FusionSystem then
                    local claimed = FusionSystem:ClaimReward(player, milestoneIndex)
                    if claimed then
                        local playerData = DataService:GetPlayerData(player)
                        if playerData then
                            self:SyncPlayerData(player, { Cash = playerData.Cash })
                        end
                        self:_SendNotification(player, "Success", "Fusion reward claimed!", 3)
                    end
                else
                    warn("[NetworkHandler] FusionSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur ClaimFusionReward: " .. tostring(err))
            end
        end)
    end

    -- SpawnTutorialPieces: spawner Head/Body/Legs dans SpawnZone1 (même logique que les canons)
    if remotes.SpawnTutorialPieces then
        remotes.SpawnTutorialPieces.OnServerEvent:Connect(function(player)
            if not ArenaSystem then return end

            local TUTORIAL_SET = "CactoHipopoTamo"
            local BrainrotDataMod = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))
            local setData = BrainrotDataMod.Sets[TUTORIAL_SET]
            if not setData then return end

            -- Position de référence : SpawnPoint de la base du joueur
            local baseSpawnPos = nil
            local runtimeData = PlayerService and PlayerService:GetRuntimeData(player)
            local assignedBase = runtimeData and runtimeData.AssignedBase
            if assignedBase then
                local spawnPoint = assignedBase:FindFirstChild("SpawnPoint", true)
                local refPos = spawnPoint and spawnPoint.Position or assignedBase:GetPivot().Position
                baseSpawnPos = ArenaSystem:GetClosestPositionInZone("SpawnZone1", refPos)
            end
            if not baseSpawnPos then
                baseSpawnPos = ArenaSystem:GetRandomPositionInZone("SpawnZone1")
            end
            if not baseSpawnPos then
                warn("[Tutorial] SpawnZone1 introuvable")
                return
            end

            local pieceDefs = {
                { PieceType = "Head", offset = Vector3.new(-3.5, 0, 0) },
                { PieceType = "Body", offset = Vector3.new( 0,   0, 0) },
                { PieceType = "Legs", offset = Vector3.new( 3.5, 0, 0) },
            }

            for _, def in ipairs(pieceDefs) do
                local typeData = setData[def.PieceType]
                if not typeData or typeData.TemplateName == "" then continue end

                local spawnPos = baseSpawnPos + def.offset

                local pieceData = {
                    SetName     = TUTORIAL_SET,
                    PieceType   = def.PieceType,
                    Price       = typeData.Price,
                    DisplayName = typeData.DisplayName,
                }
                local model = ArenaSystem:SpawnPieceFromData(pieceData, spawnPos)

                if model then
                    model:SetAttribute("IsTutorialPiece", true)
                    model:SetAttribute("TutorialPieceType", def.PieceType)
                end
            end
        end)
    end

    -- CompleteTutorial: marquer le tutoriel comme vu
    if remotes.CompleteTutorial then
        remotes.CompleteTutorial.OnServerEvent:Connect(function(player)
            local ok, err = pcall(function()
                DataService:UpdateValue(player, "HasSeenTutorial", true)
            end)
            if not ok then
                warn("[NetworkHandler] Erreur CompleteTutorial: " .. tostring(err))
            end
        end)
    end

    -- Toggle Speed
    if remotes.ToggleSpeed then
        remotes.ToggleSpeed.OnServerEvent:Connect(function(player)
            if PlayerService then
                local boosted = PlayerService:ToggleSpeed(player)
                -- Renvoyer le nouvel état au client
                remotes.ToggleSpeed:FireClient(player, boosted)
            end
        end)
    end

    -- ═══════════════════════════════════════
    -- REMOTE FUNCTIONS
    -- ═══════════════════════════════════════

    -- GetFullPlayerData
    if remotes.GetFullPlayerData then
        remotes.GetFullPlayerData.OnServerInvoke = function(player)
            return self:_HandleGetFullPlayerData(player)
        end
    end
    
    print("[NetworkHandler] Handlers connectés")
end

-- ═══════════════════════════════════════════════════════
-- HANDLERS (Placeholders - seront complétés dans les phases suivantes)
-- ═══════════════════════════════════════════════════════

function NetworkHandler:_HandlePickupPiece(player, pieceId)
    print("[NetworkHandler] PickupPiece reçu de " .. player.Name .. " pour " .. tostring(pieceId))
    
    if not InventorySystem then
        self:_SendNotification(player, "Error", "Inventory system not initialized")
        return
    end
    
    -- Tenter de ramasser la pièce (4 validations + info pièce remplacée)
    local success, result, pieceData, replacedPieceData = InventorySystem:TryPickupPiece(player, pieceId)
    
    if success then
        -- Si une pièce a été remplacée, la respawner près du joueur
        if replacedPieceData and ArenaSystem then
            local character = player.Character
            if character then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local dropPos = rootPart.Position + rootPart.CFrame.LookVector * -3
                    ArenaSystem:SpawnPieceFromData(replacedPieceData, dropPos)
                end
            end
        end

        -- Sync l'inventaire avec le client
        self:SyncInventory(player)

        -- Notification de succès
        local message = Constants.SuccessMessages.PiecePickedUp
        if pieceData then
            if replacedPieceData then
                message = pieceData.DisplayName .. " " .. pieceData.PieceType .. " picked up! (" .. replacedPieceData.DisplayName .. " dropped)"
            else
                message = pieceData.DisplayName .. " " .. pieceData.PieceType .. " picked up!"
            end
        end
        self:_SendNotification(player, "Success", message, 2)
    else
        -- Notification d'erreur
        local errorMessage = Constants.ErrorMessages[result] or "Cannot pickup this piece"
        self:_SendNotification(player, "Error", errorMessage, 2)
    end
end

function NetworkHandler:_HandleCraft(player, slotIndex)
    print("[NetworkHandler] Craft reçu de " .. player.Name)

    if not CraftingSystem then
        self:_SendNotification(player, "Error", "Crafting system not initialized")
        return
    end

    -- Valider le slotIndex si fourni
    if slotIndex ~= nil then
        slotIndex = tonumber(slotIndex)
        if not slotIndex then
            self:_SendNotification(player, "Error", "Invalid slot", 2)
            return
        end
    end

    -- Tenter de crafter
    local success, result, craftData = CraftingSystem:TryCraft(player, slotIndex)
    
    if success then
        -- Construire le message
        local message = craftData.SetName .. " crafted! -$" .. craftData.CraftCost
        if craftData.IsCompleteSet then
            message = message .. " Complete set! +$" .. craftData.Bonus
        end
        
        -- Notifier le succès
        self:_SendNotification(player, "Success", message, 4)
        
        -- Sync l'inventaire (vide)
        self:SyncInventory(player)
        
        -- Sync les données (cash, PlacedBrainrots, Codex)
        local playerData = DataService:GetPlayerData(player)
        if playerData then
            self:SyncPlayerData(player, {
                Cash = playerData.Cash,
                PlacedBrainrots = playerData.PlacedBrainrots,
                CodexUnlocked = playerData.CodexUnlocked,
            })
        end
    else
        -- Notifier l'échec
        local errorMessage = Constants.ErrorMessages[result] or "Cannot craft"
        self:_SendNotification(player, "Error", errorMessage, 3)
    end
end

--[[
    Handler: Achat de slot
    @param player: Player
]]
function NetworkHandler:_HandleBuySlot(player)
    print("[NetworkHandler] BuySlot reçu de " .. player.Name)
    
    if not EconomySystem then
        self:_SendNotification(player, "Error", "Economy system not initialized")
        return
    end
    
    local result, newSlotCount = EconomySystem:BuyNextSlot(player)
    
    if result == "Success" then
        local nextPrice = EconomySystem:GetNextSlotPrice(player)
        local message = "Slot " .. newSlotCount .. " purchased!"
        if nextPrice then
            message = message .. " Next: $" .. nextPrice
        else
            message = message .. " (Max reached)"
        end
        self:_SendNotification(player, "Success", message)
    elseif result == "NotEnoughMoney" then
        local nextPrice = EconomySystem:GetNextSlotPrice(player)
        self:_SendNotification(player, "Error", "Not enough money! ($" .. (nextPrice or 0) .. " required)")
    elseif result == "MaxSlotsReached" then
        self:_SendNotification(player, "Warning", "Maximum slots reached!")
    else
        self:_SendNotification(player, "Error", "Purchase error")
    end
end

--[[
    Handler: Collecte de l'argent d'un slot
    @param player: Player
    @param slotIndex: number | nil - Si nil, collecte tout
]]
function NetworkHandler:_HandleCollectSlotCash(player, slotIndex)
    print("[NetworkHandler] CollectSlotCash reçu de " .. player.Name .. " pour slot " .. tostring(slotIndex))

    if not EconomySystem then
        self:_SendNotification(player, "Error", "Economy system not initialized")
        return
    end

    -- Accepter slotIndex en number ou string (sérialisation Remote)
    if type(slotIndex) == "string" and slotIndex ~= "" then
        slotIndex = tonumber(slotIndex)
    end

    -- Valider que le slot appartient bien au joueur
    if slotIndex and type(slotIndex) == "number" then
        local playerData = DataService:GetPlayerData(player)
        if not playerData then return end
        local ownedSlots = playerData.OwnedSlots or 1
        if slotIndex < 1 or slotIndex > ownedSlots then
            self:_SendNotification(player, "Error", "Invalid slot!", 2)
            return
        end
    end

    local amount

    if slotIndex and type(slotIndex) == "number" then
        -- Collecter un slot spécifique
        amount = EconomySystem:CollectSlotCash(player, slotIndex)
    else
        -- Collecter tous les slots
        amount = EconomySystem:CollectAllSlotCash(player)
    end

    if amount > 0 then
        self:_SendNotification(player, "Success", "+$" .. amount .. " collected!")
    end
end

function NetworkHandler:_HandleActivateDoor(player)
    -- Phase 2: DoorSystem:ActivateDoor(player)
    print("[NetworkHandler] ActivateDoor reçu de " .. player.Name)
    
    if not DoorSystem then
        self:_SendNotification(player, "Info", "Door system not loaded")
        return
    end
    
    local result = DoorSystem:ActivateDoor(player)
    
    if result == Constants.ActionResult.Success then
        self:_SendNotification(player, "Success", "Door closed for 30 seconds!", 3)
    elseif result == Constants.ActionResult.OnCooldown then
        local doorState = DoorSystem:GetDoorState(player)
        self:_SendNotification(player, "Warning", "Door already closed! " .. doorState.RemainingTime .. "s remaining", 2)
    elseif result == Constants.ActionResult.NotOwner then
        self:_SendNotification(player, "Error", "This is not your base!", 2)
    end
end

function NetworkHandler:_HandleDropPieces(player)
    -- Phase 4: Vider les pièces en main volontairement
    print("[NetworkHandler] DropPieces reçu de " .. player.Name)

    local pieces = PlayerService:ClearPiecesInHand(player)
    print("[NetworkHandler] " .. player.Name .. " a lâché " .. #pieces .. " pièces")

    -- Respawn les pièces dans l'arène (si sous la limite)
    if ArenaSystem and #pieces > 0 then
        local character = player.Character
        local dropPos = nil
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                dropPos = rootPart.Position
            end
        end

        for i, pieceData in ipairs(pieces) do
            -- Décaler chaque pièce pour éviter le stack
            local offset = Vector3.new((i - 1) * 3 - (#pieces - 1) * 1.5, 0, -3)
            local spawnPos = dropPos and (dropPos + offset) or nil
            if spawnPos then
                ArenaSystem:SpawnPieceFromData(pieceData, spawnPos)
            end
        end
    end

    -- Sync avec le client
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.SyncInventory then
        remotes.SyncInventory:FireClient(player, {})
    end

    if #pieces > 0 then
        self:_SendNotification(player, "Info", #pieces .. " piece(s) dropped")
    end
end

function NetworkHandler:_HandleGetFullPlayerData(player)
    -- Renvoie toutes les données du joueur
    print("[NetworkHandler] GetFullPlayerData demandé par " .. player.Name)
    
    local playerData = DataService:GetPlayerData(player)
    local runtimeData = PlayerService:GetRuntimeData(player)
    
    -- Combiner les données sauvegardées et runtime
    local fullData = {
        -- Données sauvegardées
        Cash = playerData and playerData.Cash or 0,
        OwnedSlots = playerData and (playerData.OwnedSlots or 10),
        PlacedBrainrots = playerData and playerData.PlacedBrainrots or {},
        SlotCash = playerData and playerData.SlotCash or {},
        LuckyBlocks = playerData and playerData.LuckyBlocks or 0,
        OwnedOneTimePurchases = playerData and playerData.OwnedOneTimePurchases or {},
        SpinWheelSpins = playerData and playerData.SpinWheelSpins or 0,
        LastFreeSpinTime = playerData and playerData.LastFreeSpinTime or 0,
        CodexUnlocked = playerData and playerData.CodexUnlocked or {},
        CompletedSets = playerData and playerData.CompletedSets or {},
        Stats = playerData and playerData.Stats or {},
        DiscoveredFusions = playerData and playerData.DiscoveredFusions or {},
        ClaimedFusionRewards = playerData and playerData.ClaimedFusionRewards or {},
        DailyPurchases = playerData and playerData.DailyPurchases or {},
        -- DEV RESET: retire cette ligne une fois le tutoriel testé
        HasSeenTutorial = false, -- TEMP: force reset pour test

        -- Données runtime
        PiecesInHand = runtimeData and runtimeData.PiecesInHand or {},
        CarriedBrainrot = runtimeData and runtimeData.CarriedBrainrot or nil,
        DoorState = runtimeData and runtimeData.DoorState or Constants.DoorState.Open,

        -- Multiplicateur temporaire (Boost)
        MultiplierBoostActive = (runtimeData and runtimeData.TemporaryMultiplier ~= nil
            and runtimeData.TemporaryMultiplierExpiry ~= nil
            and runtimeData.TemporaryMultiplierExpiry > os.time()) or false,
        MultiplierBoostRemaining = (runtimeData and runtimeData.TemporaryMultiplierExpiry
            and runtimeData.TemporaryMultiplierExpiry > os.time())
            and (runtimeData.TemporaryMultiplierExpiry - os.time()) or 0,
        MultiplierBoostValue = (runtimeData and runtimeData.TemporaryMultiplier) or 1,
    }
    
    return fullData
end

-- ═══════════════════════════════════════════════════════
-- SELL BRAINROT
-- ═══════════════════════════════════════════════════════

function NetworkHandler:_HandleSellBrainrot(player, slotIndex)
    if not PlacementSystem or not EconomySystem then
        self:_SendNotification(player, "Error", "System not initialized")
        return
    end

    -- 1. Vérifier que le slot contient un Brainrot
    local brainrotData = PlacementSystem:GetBrainrotInSlot(player, slotIndex)
    if not brainrotData then
        self:_SendNotification(player, "Error", "No Brainrot in this slot!", 2)
        return
    end

    -- 2. Calculer le prix de vente (60% de la somme des prix des 3 parties)
    local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))
    local Config = ReplicatedStorage:WaitForChild("Config")
    local GameConfig = require(Config:WaitForChild("GameConfig.module"))
    local sellMultiplier = GameConfig.Sell and GameConfig.Sell.PriceMultiplier or 0.6
    local sellPrice = 0

    local headSetData = BrainrotData.Sets[brainrotData.HeadSet]
    local bodySetData = BrainrotData.Sets[brainrotData.BodySet]
    local legsSetData = BrainrotData.Sets[brainrotData.LegsSet]

    if headSetData and headSetData.Head then
        sellPrice = sellPrice + (headSetData.Head.Price or 0)
    end
    if bodySetData and bodySetData.Body then
        sellPrice = sellPrice + (bodySetData.Body.Price or 0)
    end
    if legsSetData and legsSetData.Legs then
        sellPrice = sellPrice + (legsSetData.Legs.Price or 0)
    end

    sellPrice = math.floor(sellPrice * sellMultiplier)

    if sellPrice <= 0 then
        self:_SendNotification(player, "Error", "Cannot sell this Brainrot!", 2)
        return
    end

    -- 3. Retirer le Brainrot du slot
    PlacementSystem:RemoveBrainrot(player, slotIndex)

    -- Aussi retirer de Brainrots (utilisé par EconomySystem pour les revenus)
    local playerData = DataService:GetPlayerData(player)
    if playerData and playerData.Brainrots then
        playerData.Brainrots[slotIndex] = nil
        DataService:UpdateValue(player, "Brainrots", playerData.Brainrots)
    end

    -- 4. Donner l'argent au joueur
    EconomySystem:AddCash(player, sellPrice)

    -- 5. Sync les données vers le client
    if playerData then
        self:SyncPlayerData(player, {
            Cash = playerData.Cash,
            PlacedBrainrots = playerData.PlacedBrainrots,
        })
    end

    -- 6. Notification
    self:_SendNotification(player, "Success", "Brainrot sold for $" .. sellPrice .. "!", 3)
end

-- ═══════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════

--[[
    Envoie une notification au client
    @param player: Player
    @param notifType: string - "Success" | "Error" | "Info" | "Warning"
    @param message: string
    @param duration: number (optionnel, défaut 3)
]]
function NetworkHandler:_SendNotification(player, notifType, message, duration)
    local remotes = NetworkSetup:GetAllRemotes()
    
    if remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = duration or 3,
        })
    end
end

--[[
    Sync les données joueur vers le client
    @param player: Player
    @param data: table (partiel ou complet)
]]
function NetworkHandler:SyncPlayerData(player, data)
    local remotes = NetworkSetup:GetAllRemotes()
    
    if remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, data)
    end
end

--[[
    Sync l'inventaire vers le client
    @param player: Player
]]
function NetworkHandler:SyncInventory(player)
    local remotes = NetworkSetup:GetAllRemotes()
    local piecesInHand = PlayerService:GetPiecesInHand(player)
    
    if remotes.SyncInventory then
        remotes.SyncInventory:FireClient(player, piecesInHand)
    end
end

--[[
    Met à jour les systèmes après leur initialisation
    @param systems: table - {BaseSystem, DoorSystem, EconomySystem, ArenaSystem, InventorySystem, CraftingSystem, PlacementSystem, ...}
]]
function NetworkHandler:UpdateSystems(systems)
    if systems.BaseSystem then
        BaseSystem = systems.BaseSystem
    end
    if systems.DoorSystem then
        DoorSystem = systems.DoorSystem
    end
    if systems.EconomySystem then
        EconomySystem = systems.EconomySystem
    end
    if systems.ArenaSystem then
        ArenaSystem = systems.ArenaSystem
    end
    if systems.InventorySystem then
        InventorySystem = systems.InventorySystem
    end
    if systems.CraftingSystem then
        CraftingSystem = systems.CraftingSystem
    end
    if systems.PlacementSystem then
        PlacementSystem = systems.PlacementSystem
    end
    if systems.StealSystem then
        StealSystem = systems.StealSystem
    end
    if systems.BatSystem then
        BatSystem = systems.BatSystem
    end
    if systems.ShopSystem then
        ShopSystem = systems.ShopSystem
    end
    if systems.LuckyBlockSystem then
        LuckyBlockSystem = systems.LuckyBlockSystem
    end
    if systems.SpinWheelSystem then
        SpinWheelSystem = systems.SpinWheelSystem
    end
    if systems.FusionSystem then
        FusionSystem = systems.FusionSystem
    end

    print("[NetworkHandler] Systèmes mis à jour")
end

return NetworkHandler
