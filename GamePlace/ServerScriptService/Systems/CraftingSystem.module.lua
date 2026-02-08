--[[
    CraftingSystem.module.lua
    Gestion du crafting de Brainrots
    
    Responsabilités:
    - Validation des pièces (3 pièces, 3 types différents)
    - Détection de set complet
    - Création et placement du Brainrot
    - Déblocage Codex
    - Bonus de set complet
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = nil
local BrainrotData = nil
local Constants = nil
local DataService = nil
local PlayerService = nil
local InventorySystem = nil
local PlacementSystem = nil

local CraftingSystem = {}
CraftingSystem._initialized = false

--[[
    Initialise le système de crafting
    @param services: table - {DataService, PlayerService, InventorySystem, PlacementSystem}
]]
function CraftingSystem:Init(services)
    if self._initialized then
        warn("[CraftingSystem] Déjà initialisé!")
        return
    end
    
    print("[CraftingSystem] Initialisation...")
    
    -- Récupérer les services injectés
    DataService = services.DataService
    PlayerService = services.PlayerService
    InventorySystem = services.InventorySystem
    PlacementSystem = services.PlacementSystem
    
    if not DataService or not PlayerService or not InventorySystem or not PlacementSystem then
        error("[CraftingSystem] Services manquants!")
    end
    
    -- Charger les modules de config
    local Config = ReplicatedStorage:WaitForChild("Config")
    local Data = ReplicatedStorage:WaitForChild("Data")
    local Shared = ReplicatedStorage:WaitForChild("Shared")
    
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
    Constants = require(Shared:WaitForChild("Constants.module"))
    
    self._initialized = true
    print("[CraftingSystem] Initialisé")
end

--[[
    Valide que les pièces peuvent être craftées
    @param pieces: table - Liste des pièces en main
    @return valid: boolean, errorMessage: string | nil
]]
function CraftingSystem:ValidateCraft(pieces)
    -- Vérifier qu'il y a exactement 3 pièces
    if #pieces ~= 3 then
        return false, "Need exactly 3 pieces"
    end
    
    -- Vérifier que les 3 types sont présents
    local hasHead = false
    local hasBody = false
    local hasLegs = false
    
    for _, piece in ipairs(pieces) do
        if piece.PieceType == Constants.PieceType.Head then hasHead = true end
        if piece.PieceType == Constants.PieceType.Body then hasBody = true end
        if piece.PieceType == Constants.PieceType.Legs then hasLegs = true end
    end
    
    if not (hasHead and hasBody and hasLegs) then
        return false, "Need Head, Body and Legs"
    end
    
    return true, nil
end

--[[
    Vérifie si les 3 pièces forment un set complet (même SetName)
    @param pieces: table
    @return boolean
]]
function CraftingSystem:IsCompleteSet(pieces)
    if #pieces ~= 3 then return false end
    
    local setName = pieces[1].SetName
    for i = 2, 3 do
        if pieces[i].SetName ~= setName then
            return false
        end
    end
    
    return true
end

--[[
    Détermine quel set sera crafté
    @param pieces: table
    @return string - SetName
]]
function CraftingSystem:GetCraftableSet(pieces)
    -- Si set complet, retourner le SetName
    if self:IsCompleteSet(pieces) then
        return pieces[1].SetName
    end
    
    -- Sinon, compter les occurrences de chaque set
    local counts = {}
    for _, piece in ipairs(pieces) do
        counts[piece.SetName] = (counts[piece.SetName] or 0) + 1
    end
    
    -- Retourner le set le plus fréquent
    local maxCount = 0
    local maxSet = "Mixed"
    for setName, count in pairs(counts) do
        if count > maxCount then
            maxCount = count
            maxSet = setName
        end
    end
    
    return maxSet
end

--[[
    Tente de crafter un Brainrot
    @param player: Player
    @return success: boolean, result: string (ActionResult), craftData: table | nil
]]
function CraftingSystem:TryCraft(player)
    if not self._initialized then
        return false, Constants.ActionResult.InvalidPiece, nil
    end
    
    -- 1. Récupérer les pièces en main
    local pieces = InventorySystem:GetPiecesInHand(player)
    
    -- 2. Valider les pièces
    local valid, errorMsg = self:ValidateCraft(pieces)
    if not valid then
        warn("[CraftingSystem] Validation échouée: " .. (errorMsg or "unknown"))
        return false, Constants.ActionResult.MissingPieces, nil
    end
    
    -- 3. Trouver un slot libre
    local slotIndex = PlacementSystem:FindAvailableSlot(player)
    if not slotIndex then
        warn("[CraftingSystem] Aucun slot disponible pour " .. player.Name)
        return false, Constants.ActionResult.NoSlotAvailable, nil
    end
    
    -- 4. Déterminer le set crafté
    local setName = self:GetCraftableSet(pieces)
    local isCompleteSet = self:IsCompleteSet(pieces)
    
    -- 5. Créer les données du Brainrot avec les noms des templates
    local headPiece, bodyPiece, legsPiece
    for _, piece in ipairs(pieces) do
        if piece.PieceType == Constants.PieceType.Head then headPiece = piece end
        if piece.PieceType == Constants.PieceType.Body then bodyPiece = piece end
        if piece.PieceType == Constants.PieceType.Legs then legsPiece = piece end
    end
    
    local brainrotData = {
        SetName = setName, -- Nom du set (pour affichage/bonus)
        SlotIndex = slotIndex,
        PlacedAt = os.time(),
        -- Noms des templates pour assemblage (ex: "brrbrr", "lalero", "patapim")
        HeadSet = headPiece.SetName,
        BodySet = bodyPiece.SetName,
        LegsSet = legsPiece.SetName,
    }
    
    -- 6. Placer le Brainrot
    local placed = PlacementSystem:PlaceBrainrot(player, slotIndex, brainrotData)
    if not placed then
        warn("[CraftingSystem] Échec placement Brainrot")
        return false, Constants.ActionResult.NoSlotAvailable, nil
    end
    
    -- 7. Débloquer dans le Codex
    DataService:UnlockCodexEntry(player, setName)
    
    -- 8. Bonus si set complet
    local bonus = 0
    if isCompleteSet then
        bonus = GameConfig.Economy.SetCompletionBonus
        DataService:IncrementValue(player, "Cash", bonus)
    end
    
    -- 9. Vider l'inventaire
    InventorySystem:ClearInventory(player)
    
    return true, Constants.ActionResult.Success, {
        SetName = setName,
        SlotIndex = slotIndex,
        IsCompleteSet = isCompleteSet,
        Bonus = bonus,
    }
end

return CraftingSystem
