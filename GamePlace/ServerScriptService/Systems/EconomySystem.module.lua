--[[
    EconomySystem.lua
    Gestion de l'économie du jeu
    
    Responsabilités:
    - Gérer l'argent des joueurs (Cash)
    - Gérer l'argent stocké dans les slots (SlotCash)
    - Générer les revenus passifs des Brainrots
    - Gérer l'achat de slots
    - Gérer le déblocage des étages
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules de configuration (chargés dans Init pour ne pas bloquer le require)
local GameConfig = nil
local SlotPrices = nil

-- Services (seront injectés)
local DataService = nil
local PlayerService = nil
local NetworkSetup = nil
local BaseSystem = nil

local EconomySystem = {}
EconomySystem._initialized = false
EconomySystem._revenueLoopRunning = false

--[[
    Initialise le système économique
    @param services: table - {DataService, PlayerService, NetworkSetup, BaseSystem}
]]
function EconomySystem:Init(services)
    if self._initialized then
        warn("[EconomySystem] Déjà initialisé!")
        return
    end
    
    print("[EconomySystem] Initialisation...")
    
    -- Charger Config/Data ici pour ne pas bloquer le require() du module
    local Config = ReplicatedStorage:WaitForChild("Config")
    local Data = ReplicatedStorage:WaitForChild("Data")
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    SlotPrices = require(Data:WaitForChild("SlotPrices.module"))
    
    -- Récupérer les services injectés
    DataService = services.DataService
    PlayerService = services.PlayerService
    NetworkSetup = services.NetworkSetup
    BaseSystem = services.BaseSystem
    
    if not DataService then
        error("[EconomySystem] DataService requis!")
    end
    
    if not PlayerService then
        error("[EconomySystem] PlayerService requis!")
    end
    
    -- Démarrer la loop de revenus
    self:_StartRevenueLoop()
    
    self._initialized = true
    print("[EconomySystem] Initialisé!")
end

-- ═══════════════════════════════════════════════════════
-- GESTION DE L'ARGENT (CASH)
-- ═══════════════════════════════════════════════════════

--[[
    Ajoute de l'argent au portefeuille d'un joueur
    @param player: Player
    @param amount: number - Montant à ajouter (positif)
    @return number - Nouveau solde
]]
function EconomySystem:AddCash(player, amount)
    if amount <= 0 then
        warn("[EconomySystem] Montant invalide: " .. tostring(amount))
        return self:GetCash(player)
    end
    
    local newAmount = DataService:IncrementValue(player, "Cash", amount)
    
    -- Incrémenter les stats
    DataService:IncrementValue(player, "Stats.TotalCashEarned", amount)
    
    print("[EconomySystem] " .. player.Name .. " +$" .. amount .. " (total: $" .. newAmount .. ")")
    
    -- Sync vers le client
    self:_SyncCash(player, newAmount)
    
    return newAmount
end

--[[
    Retire de l'argent du portefeuille d'un joueur
    @param player: Player
    @param amount: number - Montant à retirer (positif)
    @return boolean - true si succès (avait assez d'argent)
]]
function EconomySystem:RemoveCash(player, amount)
    if amount <= 0 then
        warn("[EconomySystem] Montant invalide: " .. tostring(amount))
        return false
    end
    
    local currentCash = self:GetCash(player)
    
    if currentCash < amount then
        print("[EconomySystem] " .. player.Name .. " n'a pas assez d'argent ($" .. currentCash .. " < $" .. amount .. ")")
        return false
    end
    
    local newAmount = DataService:IncrementValue(player, "Cash", -amount)
    
    print("[EconomySystem] " .. player.Name .. " -$" .. amount .. " (total: $" .. newAmount .. ")")
    
    -- Sync vers le client
    self:_SyncCash(player, newAmount)
    
    return true
end

--[[
    Vérifie si le joueur peut payer un montant
    @param player: Player
    @param amount: number
    @return boolean
]]
function EconomySystem:CanAfford(player, amount)
    local currentCash = self:GetCash(player)
    return currentCash >= amount
end

--[[
    Récupère l'argent actuel d'un joueur
    @param player: Player
    @return number
]]
function EconomySystem:GetCash(player)
    local data = DataService:GetPlayerData(player)
    return data and data.Cash or 0
end

-- ═══════════════════════════════════════════════════════
-- GESTION DE L'ARGENT STOCKÉ (SLOTCASH)
-- ═══════════════════════════════════════════════════════

--[[
    Ajoute de l'argent au stockage d'un slot spécifique
    @param player: Player
    @param slotIndex: number - Index du slot (1-30)
    @param amount: number - Montant à ajouter
    @return number - Nouveau montant dans ce slot
]]
function EconomySystem:AddSlotCash(player, slotIndex, amount)
    if amount <= 0 then return 0 end
    
    local data = DataService:GetPlayerData(player)
    if not data then return 0 end
    
    -- Initialiser si nécessaire
    if not data.SlotCash then
        data.SlotCash = {}
    end
    
    local currentAmount = data.SlotCash[slotIndex] or 0
    local newAmount = currentAmount + amount
    data.SlotCash[slotIndex] = newAmount
    
    return newAmount
end

--[[
    Collecte l'argent d'un slot spécifique et le transfère au portefeuille
    @param player: Player
    @param slotIndex: number - Index du slot (1-30)
    @return number - Montant collecté
]]
function EconomySystem:CollectSlotCash(player, slotIndex)
    local data = DataService:GetPlayerData(player)
    if not data then return 0 end
    
    if not data.SlotCash then return 0 end
    
    local amount = data.SlotCash[slotIndex] or 0
    
    if amount > 0 then
        -- Vider le slot
        data.SlotCash[slotIndex] = 0
        
        -- Ajouter au portefeuille
        self:AddCash(player, amount)
        
        print("[EconomySystem] " .. player.Name .. " a collecté $" .. amount .. " du slot " .. slotIndex)
        
        -- Sync le SlotCash vers le client
        self:_SyncSlotCash(player, data.SlotCash)
    end
    
    return amount
end

--[[
    Collecte tout l'argent stocké dans tous les slots
    @param player: Player
    @return number - Montant total collecté
]]
function EconomySystem:CollectAllSlotCash(player)
    local data = DataService:GetPlayerData(player)
    if not data or not data.SlotCash then return 0 end
    
    local totalCollected = 0
    
    for slotIndex, amount in pairs(data.SlotCash) do
        if amount > 0 then
            totalCollected = totalCollected + amount
            data.SlotCash[slotIndex] = 0
        end
    end
    
    if totalCollected > 0 then
        self:AddCash(player, totalCollected)
        print("[EconomySystem] " .. player.Name .. " a collecté un total de $" .. totalCollected)
        
        -- Sync le SlotCash vers le client
        self:_SyncSlotCash(player, data.SlotCash)
    end
    
    return totalCollected
end

--[[
    Récupère le total de l'argent stocké dans tous les slots
    @param player: Player
    @return number
]]
function EconomySystem:GetTotalSlotCash(player)
    local data = DataService:GetPlayerData(player)
    if not data or not data.SlotCash then return 0 end
    
    local total = 0
    for _, amount in pairs(data.SlotCash) do
        total = total + amount
    end
    
    return total
end

-- ═══════════════════════════════════════════════════════
-- REVENUS PASSIFS (REVENUE LOOP)
-- ═══════════════════════════════════════════════════════

--[[
    Démarre la boucle de génération de revenus
    (appelé automatiquement par Init)
]]
function EconomySystem:_StartRevenueLoop()
    if self._revenueLoopRunning then
        warn("[EconomySystem] Revenue loop déjà en cours!")
        return
    end
    
    self._revenueLoopRunning = true
    
    task.spawn(function()
        print("[EconomySystem] Revenue loop démarrée (tick: " .. GameConfig.Economy.RevenueTickRate .. "s)")
        
        while self._revenueLoopRunning do
            task.wait(GameConfig.Economy.RevenueTickRate)
            
            -- Traiter chaque joueur connecté
            for _, player in ipairs(Players:GetPlayers()) do
                self:_ProcessPlayerRevenue(player)
            end
        end
    end)
end

--[[
    Traite les revenus pour un joueur
    @param player: Player
]]
function EconomySystem:_ProcessPlayerRevenue(player)
    local data = DataService:GetPlayerData(player)
    if not data then return end
    
    -- Compter les Brainrots placés et calculer les revenus par slot
    if not data.Brainrots then 
        -- Debug: vérifier si les données existent
        -- print("[EconomySystem] Pas de Brainrots pour " .. player.Name)
        return 
    end
    
    -- Compter combien de Brainrots on a
    local brainrotCount = 0
    for _ in pairs(data.Brainrots) do
        brainrotCount = brainrotCount + 1
    end
    
    if brainrotCount == 0 then
        -- print("[EconomySystem] Aucun Brainrot placé pour " .. player.Name)
        return
    end
    
    -- Charger BrainrotData pour récupérer les prix des pièces
    local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))
    
    local totalRevenue = 0
    
    for slotIndex, brainrotData in pairs(data.Brainrots) do
        if brainrotData and brainrotData.HeadSet and brainrotData.BodySet and brainrotData.LegsSet then
            -- Calculer le revenu basé sur les prix des pièces
            local headSetData = BrainrotData.Sets[brainrotData.HeadSet]
            local bodySetData = BrainrotData.Sets[brainrotData.BodySet]
            local legsSetData = BrainrotData.Sets[brainrotData.LegsSet]
            
            local slotRevenue = 0
            if headSetData and headSetData.Head then
                slotRevenue = slotRevenue + (headSetData.Head.Price or 0)
            end
            if bodySetData and bodySetData.Body then
                slotRevenue = slotRevenue + (bodySetData.Body.Price or 0)
            end
            if legsSetData and legsSetData.Legs then
                slotRevenue = slotRevenue + (legsSetData.Legs.Price or 0)
            end
            
            -- Ajouter au slot correspondant
            if slotRevenue > 0 then
                self:AddSlotCash(player, slotIndex, slotRevenue)
                totalRevenue = totalRevenue + slotRevenue
                -- print("[EconomySystem] Slot " .. slotIndex .. " génère $" .. slotRevenue .. "/s")
            end
        end
    end
    
    -- Si des revenus ont été générés, sync vers le client
    if totalRevenue > 0 then
        self:_SyncSlotCash(player, data.SlotCash)
        -- print("[EconomySystem] " .. player.Name .. " revenus totaux: +$" .. totalRevenue)
    end
end

--[[
    Calcule le multiplicateur de rareté pour un Brainrot
    @param brainrotData: table
    @return number
]]
function EconomySystem:_GetRarityMultiplier(brainrotData)
    -- TODO: Récupérer la rareté depuis BrainrotData et appliquer le multiplicateur
    -- Pour l'instant, retourne 1 (pas de bonus)
    return 1
end

-- ═══════════════════════════════════════════════════════
-- ACHAT DE SLOTS
-- ═══════════════════════════════════════════════════════

--[[
    Récupère le prix du prochain slot à acheter
    @param player: Player
    @return number | nil - Prix, ou nil si max atteint
]]
function EconomySystem:GetNextSlotPrice(player)
    local data = DataService:GetPlayerData(player)
    if not data then return nil end
    
    local currentSlots = data.OwnedSlots or GameConfig.Base.StartingSlots
    local nextSlot = currentSlots + 1
    
    if nextSlot > GameConfig.Base.MaxSlots then
        return nil -- Max atteint
    end
    
    return SlotPrices[nextSlot] or 999999
end

--[[
    Tente d'acheter le prochain slot
    @param player: Player
    @return string - ActionResult (Success, NotEnoughMoney, MaxSlotsReached)
    @return number | nil - Nouveau nombre de slots si succès
]]
function EconomySystem:BuyNextSlot(player)
    local data = DataService:GetPlayerData(player)
    if not data then
        return "Error", nil
    end
    
    local currentSlots = data.OwnedSlots or GameConfig.Base.StartingSlots
    local nextSlot = currentSlots + 1
    
    -- Vérifier le maximum
    if nextSlot > GameConfig.Base.MaxSlots then
        print("[EconomySystem] " .. player.Name .. " a déjà le maximum de slots (" .. GameConfig.Base.MaxSlots .. ")")
        return "MaxSlotsReached", nil
    end
    
    -- Récupérer le prix
    local price = SlotPrices[nextSlot]
    if not price then
        warn("[EconomySystem] Prix non défini pour le slot " .. nextSlot)
        return "Error", nil
    end
    
    -- Vérifier l'argent
    if not self:CanAfford(player, price) then
        print("[EconomySystem] " .. player.Name .. " n'a pas assez d'argent pour le slot " .. nextSlot .. " ($" .. price .. ")")
        return "NotEnoughMoney", nil
    end
    
    -- Débiter le joueur
    self:RemoveCash(player, price)
    
    -- Incrémenter les slots possédés
    local newSlotCount = DataService:IncrementValue(player, "OwnedSlots", 1)
    
    print("[EconomySystem] " .. player.Name .. " a acheté le slot " .. nextSlot .. " pour $" .. price .. " (total: " .. newSlotCount .. " slots)")
    
    -- Vérifier le déblocage d'étage
    local unlockedFloor = self:CheckFloorUnlock(player, newSlotCount)
    
    -- Rendre le nouveau slot visible dans la base (slot 11, 12, etc.)
    if BaseSystem and BaseSystem.ApplySlotVisibility then
        BaseSystem:ApplySlotVisibility(player)
    end
    
    -- Sync vers le client
    self:_SyncOwnedSlots(player, newSlotCount, unlockedFloor)
    
    return "Success", newSlotCount
end

--[[
    Récupère le nombre de slots possédés
    @param player: Player
    @return number
]]
function EconomySystem:GetOwnedSlots(player)
    local data = DataService:GetPlayerData(player)
    return data and data.OwnedSlots or GameConfig.Base.StartingSlots
end

-- ═══════════════════════════════════════════════════════
-- DÉBLOCAGE DES ÉTAGES
-- ═══════════════════════════════════════════════════════

--[[
    Vérifie et débloque les étages si nécessaire
    @param player: Player
    @param currentSlots: number - Nombre actuel de slots
    @return number | nil - Numéro de l'étage débloqué, ou nil
]]
function EconomySystem:CheckFloorUnlock(player, currentSlots)
    local thresholds = GameConfig.Base.FloorUnlockThresholds
    local unlockedFloor = nil
    
    for floor, requiredSlots in pairs(thresholds) do
        if currentSlots == requiredSlots then
            -- Étage atteint exactement maintenant!
            unlockedFloor = floor
            
            print("[EconomySystem] " .. player.Name .. " a débloqué l'étage " .. floor .. " !")
            
            -- Appeler BaseSystem pour afficher l'étage
            if BaseSystem and BaseSystem.UnlockFloor then
                BaseSystem:UnlockFloor(player, floor)
            end
            
            -- Envoyer une notification
            self:_SendNotification(player, "Success", "Floor " .. floor .. " unlocked!")
            
            break
        end
    end
    
    return unlockedFloor
end

-- ═══════════════════════════════════════════════════════
-- SYNCHRONISATION CLIENT
-- ═══════════════════════════════════════════════════════

--[[
    Sync le Cash vers le client
    @param player: Player
    @param cash: number
]]
function EconomySystem:_SyncCash(player, cash)
    if not NetworkSetup then return end
    
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, {
            Cash = cash
        })
    end
end

--[[
    Sync le SlotCash vers le client
    @param player: Player
    @param slotCash: table
]]
function EconomySystem:_SyncSlotCash(player, slotCash)
    if not NetworkSetup then return end
    
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, {
            SlotCash = slotCash
        })
    end
end

--[[
    Sync les OwnedSlots vers le client
    @param player: Player
    @param ownedSlots: number
    @param unlockedFloor: number | nil
]]
function EconomySystem:_SyncOwnedSlots(player, ownedSlots, unlockedFloor)
    if not NetworkSetup then return end
    
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.SyncPlayerData then
        local syncData = {
            OwnedSlots = ownedSlots,
        }
        
        if unlockedFloor then
            syncData.UnlockedFloor = unlockedFloor
        end
        
        remotes.SyncPlayerData:FireClient(player, syncData)
    end
end

--[[
    Envoie une notification au client
    @param player: Player
    @param notifType: string
    @param message: string
]]
function EconomySystem:_SendNotification(player, notifType, message)
    if not NetworkSetup then return end
    
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = 3,
        })
    end
end

return EconomySystem
