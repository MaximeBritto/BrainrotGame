--[[
    PlacementSystem.module.lua
    Gestion du placement des Brainrots dans les slots
    
    Responsabilités:
    - Trouver un slot libre
    - Placer un Brainrot dans un slot
    - Retirer un Brainrot d'un slot
    - Gérer les modèles visuels (Phase 6)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = nil
local DataService = nil
local PlayerService = nil
local BaseSystem = nil
local BrainrotModelSystem = nil

local PlacementSystem = {}
PlacementSystem._initialized = false

--[[
    Initialise le système de placement
    @param services: table - {DataService, PlayerService, BaseSystem, BrainrotModelSystem}
]]
function PlacementSystem:Init(services)
    if self._initialized then
        warn("[PlacementSystem] Déjà initialisé!")
        return
    end
    
    print("[PlacementSystem] Initialisation...")
    
    -- Récupérer les services injectés
    DataService = services.DataService
    PlayerService = services.PlayerService
    BaseSystem = services.BaseSystem
    BrainrotModelSystem = services.BrainrotModelSystem
    
    if not DataService or not PlayerService then
        error("[PlacementSystem] Services manquants!")
    end
    
    -- Charger GameConfig
    local Config = ReplicatedStorage:WaitForChild("Config")
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    
    self._initialized = true
    print("[PlacementSystem] Initialisé")
end

--[[
    Trouve le premier slot libre du joueur
    @param player: Player
    @return number | nil - Index du slot libre, ou nil si aucun
]]
function PlacementSystem:FindAvailableSlot(player)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then
        warn("[PlacementSystem] Données joueur introuvables")
        return nil
    end
    
    local ownedSlots = playerData.OwnedSlots or GameConfig.Base.StartingSlots
    local brainrots = playerData.Brainrots or {}
    
    print("[PlacementSystem] Recherche slot libre pour " .. player.Name)
    print("[PlacementSystem] Slots possédés:", ownedSlots)
    print("[PlacementSystem] Brainrots actuels:")
    for idx, data in pairs(brainrots) do
        print("  Slot " .. idx .. " occupé:", data.SetName or "unknown")
    end
    
    -- Parcourir tous les slots possédés
    for i = 1, ownedSlots do
        -- Vérifier si le slot est libre
        if not brainrots[i] then
            print("[PlacementSystem] Slot libre trouvé: " .. i)
            return i
        end
    end
    
    print("[PlacementSystem] Aucun slot libre pour " .. player.Name)
    return nil -- Aucun slot libre
end

--[[
    Place un Brainrot dans un slot
    @param player: Player
    @param slotIndex: number
    @param brainrotData: table - {SetName, SlotIndex, PlacedAt}
    @return boolean - true si succès
]]
function PlacementSystem:PlaceBrainrot(player, slotIndex, brainrotData)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then
        warn("[PlacementSystem] Données joueur introuvables")
        return false
    end
    
    local ownedSlots = playerData.OwnedSlots or GameConfig.Base.StartingSlots
    
    -- Vérifier que le joueur possède ce slot
    if slotIndex > ownedSlots then
        warn("[PlacementSystem] Slot " .. slotIndex .. " non possédé par " .. player.Name)
        return false
    end
    
    -- Vérifier que le slot est libre
    local placedBrainrots = playerData.PlacedBrainrots or {}
    if placedBrainrots[tostring(slotIndex)] then
        warn("[PlacementSystem] Slot " .. slotIndex .. " déjà occupé")
        return false
    end
    
    -- Placer le Brainrot dans PlacedBrainrots (pour la sauvegarde et restauration)
    placedBrainrots[tostring(slotIndex)] = brainrotData
    DataService:UpdateValue(player, "PlacedBrainrots", placedBrainrots)
    
    -- AUSSI placer dans Brainrots pour l'EconomySystem (compatibilité)
    local brainrots = playerData.Brainrots or {}
    brainrots[slotIndex] = brainrotData
    DataService:UpdateValue(player, "Brainrots", brainrots)
    
    -- Créer le modèle visuel (Phase 5.5)
    if BrainrotModelSystem then
        BrainrotModelSystem:CreateBrainrotModel(player, slotIndex, brainrotData)
    end
    
    return true
end

--[[
    Retire un Brainrot d'un slot
    @param player: Player
    @param slotIndex: number
    @return boolean - true si succès
]]
function PlacementSystem:RemoveBrainrot(player, slotIndex)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then
        warn("[PlacementSystem] Données joueur introuvables")
        return false
    end
    
    local placedBrainrots = playerData.PlacedBrainrots or {}
    
    -- Vérifier qu'il y a un Brainrot dans ce slot
    if not placedBrainrots[tostring(slotIndex)] then
        warn("[PlacementSystem] Aucun Brainrot dans slot " .. slotIndex)
        return false
    end
    
    -- Retirer le Brainrot
    placedBrainrots[tostring(slotIndex)] = nil
    DataService:UpdateValue(player, "PlacedBrainrots", placedBrainrots)
    
    -- Détruire le modèle visuel (Phase 5.5)
    if BrainrotModelSystem then
        BrainrotModelSystem:DestroyBrainrotModel(player, slotIndex)
    end
    
    print("[PlacementSystem] Brainrot retiré: " .. player.Name .. " slot " .. slotIndex)
    
    return true
end

--[[
    Récupère les données d'un Brainrot placé
    @param player: Player
    @param slotIndex: number
    @return table | nil - BrainrotData ou nil
]]
function PlacementSystem:GetBrainrotInSlot(player, slotIndex)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return nil end
    
    local placedBrainrots = playerData.PlacedBrainrots or {}
    return placedBrainrots[tostring(slotIndex)]
end

--[[
    Compte le nombre de Brainrots placés
    @param player: Player
    @return number
]]
function PlacementSystem:CountPlacedBrainrots(player)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return 0 end
    
    local placedBrainrots = playerData.PlacedBrainrots or {}
    local count = 0
    for _ in pairs(placedBrainrots) do
        count = count + 1
    end
    
    return count
end

return PlacementSystem
