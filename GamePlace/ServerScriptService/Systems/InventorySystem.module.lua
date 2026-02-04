--[[
    InventorySystem.module.lua
    Gestion de l'inventaire de pièces en main côté serveur
    
    Responsabilités:
    - Délégation vers PlayerService pour les opérations d'inventaire
    - Validation du pickup de pièces (4 validations)
    - Coordination entre ArenaSystem et PlayerService
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = nil
local Constants = nil
local PlayerService = nil
local ArenaSystem = nil

local InventorySystem = {}
InventorySystem._initialized = false

--[[
    Initialise le système d'inventaire
    @param services: table - {PlayerService, ArenaSystem}
]]
function InventorySystem:Init(services)
    if self._initialized then
        warn("[InventorySystem] Déjà initialisé!")
        return
    end
    
    print("[InventorySystem] Initialisation...")
    
    -- Récupérer les services injectés
    PlayerService = services.PlayerService
    ArenaSystem = services.ArenaSystem
    
    if not PlayerService then
        error("[InventorySystem] PlayerService requis!")
    end
    
    if not ArenaSystem then
        error("[InventorySystem] ArenaSystem requis!")
    end
    
    -- Charger les modules de config
    local Config = ReplicatedStorage:WaitForChild("Config")
    local Shared = ReplicatedStorage:WaitForChild("Shared")
    
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    Constants = require(Shared:WaitForChild("Constants.module"))
    
    self._initialized = true
    print("[InventorySystem] Initialisé")
end

--[[
    Récupère les pièces en main d'un joueur
    @param player: Player
    @return table
]]
function InventorySystem:GetPiecesInHand(player)
    return PlayerService:GetPiecesInHand(player)
end

--[[
    Ajoute une pièce à l'inventaire d'un joueur
    @param player: Player
    @param pieceData: table - {SetName, PieceType, Price, DisplayName}
    @return boolean
]]
function InventorySystem:AddPiece(player, pieceData)
    return PlayerService:AddPieceToHand(player, pieceData)
end

--[[
    Vide l'inventaire d'un joueur
    @param player: Player
    @return table - Les pièces retirées
]]
function InventorySystem:ClearInventory(player)
    return PlayerService:ClearPiecesInHand(player)
end

--[[
    Tente de ramasser une pièce (4 validations)
    @param player: Player
    @param pieceId: string
    @return success: boolean, result: string (ActionResult), pieceData: table | nil
]]
function InventorySystem:TryPickupPiece(player, pieceId)
    if not self._initialized then
        return false, Constants.ActionResult.InvalidPiece, nil
    end
    
    -- VALIDATION 1: La pièce existe dans l'arène
    local piece = ArenaSystem:GetPieceById(pieceId)
    if not piece then
        return false, Constants.ActionResult.InvalidPiece, nil
    end
    
    -- VALIDATION 2: L'inventaire n'est pas plein
    local currentPieces = self:GetPiecesInHand(player)
    if #currentPieces >= GameConfig.Inventory.MaxPiecesInHand then
        return false, Constants.ActionResult.InventoryFull, nil
    end
    
    -- VALIDATION 3: La pièce a tous les attributs requis
    local setName = piece:GetAttribute("SetName")
    local pieceType = piece:GetAttribute("PieceType")
    local price = piece:GetAttribute("Price")
    local displayName = piece:GetAttribute("DisplayName")
    
    if not setName or not pieceType or not price or not displayName then
        warn("[InventorySystem] Pièce avec attributs manquants: " .. pieceId)
        return false, Constants.ActionResult.InvalidPiece, nil
    end
    
    -- VALIDATION 4: La pièce est bien dans ActivePieces (vérification parent)
    local piecesFolder = piece.Parent
    if not piecesFolder or piecesFolder.Name ~= Constants.WorkspaceNames.PiecesFolder then
        return false, Constants.ActionResult.InvalidPiece, nil
    end
    
    -- Toutes les validations passées - Construire les données de la pièce
    local pieceData = {
        SetName = setName,
        PieceType = pieceType,
        Price = price,
        DisplayName = displayName,
    }
    
    -- Ajouter à l'inventaire du joueur
    local added = self:AddPiece(player, pieceData)
    if not added then
        warn("[InventorySystem] Échec ajout pièce à l'inventaire: " .. player.Name)
        return false, Constants.ActionResult.InvalidPiece, nil
    end
    
    -- Retirer la pièce de l'arène
    ArenaSystem:RemovePiece(piece)
    
    print("[InventorySystem] " .. player.Name .. " a ramassé: " .. displayName .. " " .. pieceType)
    
    return true, Constants.ActionResult.Success, pieceData
end

return InventorySystem
