--[[
    ArenaSystem.module.lua
    Gestion du spawn des pièces dans l'arène
    
    Responsabilités:
    - Spawn aléatoire de pièces selon les SpawnWeight
    - Gestion du lifetime des pièces (despawn auto)
    - Référence et suppression des pièces
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = nil
local BrainrotData = nil
local Constants = nil

local ArenaSystem = {}
ArenaSystem._initialized = false
ArenaSystem._pieces = {}  -- [pieceId] = {Model = piece, SpawnedAt = tick()}
ArenaSystem._spawnLoopRunning = false
ArenaSystem._cleanupLoopRunning = false
ArenaSystem._spawnZone = nil
ArenaSystem._piecesFolder = nil
ArenaSystem._headTemplates = nil
ArenaSystem._bodyTemplates = nil
ArenaSystem._legsTemplates = nil
ArenaSystem._nextPieceId = 1

--[[
    Initialise le système Arena
    @param services: table (optionnel)
]]
function ArenaSystem:Init(services)
    if self._initialized then
        warn("[ArenaSystem] Déjà initialisé!")
        return
    end
    
    print("[ArenaSystem] Initialisation...")
    
    -- Charger les modules de config
    local Config = ReplicatedStorage:WaitForChild("Config")
    local Data = ReplicatedStorage:WaitForChild("Data")
    local Shared = ReplicatedStorage:WaitForChild("Shared")
    
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
    Constants = require(Shared:WaitForChild("Constants.module"))
    
    -- Récupérer les références Workspace
    local arena = Workspace:FindFirstChild(Constants.WorkspaceNames.ArenaFolder)
    if not arena then
        warn("[ArenaSystem] Arena folder manquant dans Workspace!")
        return
    end
    
    self._spawnZone = arena:FindFirstChild(Constants.WorkspaceNames.SpawnZone)
    if not self._spawnZone then
        warn("[ArenaSystem] SpawnZone manquante dans Arena!")
        return
    end
    
    -- Créer ou récupérer le folder ActivePieces
    self._piecesFolder = Workspace:FindFirstChild(Constants.WorkspaceNames.PiecesFolder)
    if not self._piecesFolder then
        self._piecesFolder = Instance.new("Folder")
        self._piecesFolder.Name = Constants.WorkspaceNames.PiecesFolder
        self._piecesFolder.Parent = Workspace
        print("[ArenaSystem] Folder ActivePieces créé")
    end
    
    -- Récupérer les templates
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        warn("[ArenaSystem] Assets folder manquant!")
        return
    end
    
    local bodyPartTemplates = assets:FindFirstChild("BodyPartTemplates")
    if not bodyPartTemplates then
        warn("[ArenaSystem] BodyPartTemplates folder manquant!")
        return
    end
    
    self._headTemplates = bodyPartTemplates:FindFirstChild("HeadTemplate")
    self._bodyTemplates = bodyPartTemplates:FindFirstChild("BodyTemplate")
    self._legsTemplates = bodyPartTemplates:FindFirstChild("LegsTemplate")
    
    if not self._headTemplates or not self._bodyTemplates or not self._legsTemplates then
        warn("[ArenaSystem] Templates manquants (HeadTemplate, BodyTemplate, LegsTemplate)!")
        return
    end
    
    -- Lancer les boucles
    self:_StartSpawnLoop()
    self:_StartCleanupLoop()
    
    self._initialized = true
    print("[ArenaSystem] Initialisé - Spawn actif")
end

--[[
    Choisit un set et un type de pièce selon les SpawnWeight
    @return setName: string, pieceType: string, pieceInfo: table
]]
function ArenaSystem:_ChooseRandomPiece()
    -- 1. Calculer le poids total
    local totalWeight = 0
    local weightedSets = {}
    
    for setName, setData in pairs(BrainrotData.Sets) do
        for _, pieceType in ipairs(BrainrotData.PieceTypes) do
            local pieceInfo = setData[pieceType]
            if pieceInfo and pieceInfo.SpawnWeight then
                table.insert(weightedSets, {
                    SetName = setName,
                    PieceType = pieceType,
                    Weight = pieceInfo.SpawnWeight,
                    Info = pieceInfo,
                })
                totalWeight = totalWeight + pieceInfo.SpawnWeight
            end
        end
    end
    
    if totalWeight == 0 then
        warn("[ArenaSystem] Aucune pièce avec SpawnWeight > 0!")
        return nil, nil, nil
    end
    
    -- 2. Sélection pondérée
    local roll = math.random() * totalWeight
    local cumulative = 0
    
    for _, entry in ipairs(weightedSets) do
        cumulative = cumulative + entry.Weight
        if roll <= cumulative then
            return entry.SetName, entry.PieceType, entry.Info
        end
    end
    
    -- Fallback (ne devrait jamais arriver)
    local last = weightedSets[#weightedSets]
    return last.SetName, last.PieceType, last.Info
end

--[[
    Spawn une pièce aléatoire dans l'arène
    @return Model | nil
]]
function ArenaSystem:SpawnRandomPiece()
    if not self._initialized then return nil end
    
    -- Vérifier la limite
    local currentCount = 0
    for _ in pairs(self._pieces) do
        currentCount = currentCount + 1
    end
    
    if currentCount >= GameConfig.Arena.MaxPiecesInArena then
        return nil
    end
    
    -- Choisir une pièce
    local setName, pieceType, pieceInfo = self:_ChooseRandomPiece()
    if not setName then return nil end
    
    -- Récupérer le nom du template depuis pieceInfo
    local templateName = pieceInfo.TemplateName
    if not templateName or templateName == "" then
        warn("[ArenaSystem] TemplateName manquant ou vide pour: " .. setName .. " " .. pieceType)
        return nil
    end
    
    -- Choisir le bon template folder selon le type
    local templateFolder
    if pieceType == Constants.PieceType.Head then
        templateFolder = self._headTemplates
    elseif pieceType == Constants.PieceType.Body then
        templateFolder = self._bodyTemplates
    elseif pieceType == Constants.PieceType.Legs then
        templateFolder = self._legsTemplates
    else
        warn("[ArenaSystem] Type de pièce inconnu: " .. tostring(pieceType))
        return nil
    end
    
    -- Récupérer le template spécifique (ex: brrbrr, lalero, patapim)
    local template = templateFolder:FindFirstChild(templateName)
    if not template then
        warn("[ArenaSystem] Template introuvable: " .. templateName .. " dans " .. templateFolder.Name)
        return nil
    end
    
    -- Cloner le template
    local piece = template:Clone()
    
    -- Générer un ID unique
    local pieceId = "Piece_" .. self._nextPieceId
    self._nextPieceId = self._nextPieceId + 1
    
    -- Définir les attributs
    piece:SetAttribute("PieceId", pieceId)
    piece:SetAttribute("SetName", setName)
    piece:SetAttribute("PieceType", pieceType)
    piece:SetAttribute("Price", pieceInfo.Price)
    piece:SetAttribute("DisplayName", pieceInfo.DisplayName)
    piece:SetAttribute("SpawnedAt", tick())
    
    -- Nom du modèle
    piece.Name = pieceId
    
    -- Mettre à jour le BillboardGui dans PrimaryPart
    local primaryPart = piece.PrimaryPart
    if primaryPart then
        local billboard = primaryPart:FindFirstChildOfClass("BillboardGui")
        if billboard then
            -- Chercher NameLabel pour afficher le nom du template
            local nameLabel = billboard:FindFirstChild("NameLabel")
            if nameLabel and nameLabel:IsA("TextLabel") then
                nameLabel.Text = templateName -- Affiche "brrbrr", "lalero", etc.
            end
            
            -- Chercher PriceLabel pour afficher le prix
            local priceLabel = billboard:FindFirstChild("PriceLabel")
            if priceLabel and priceLabel:IsA("TextLabel") then
                priceLabel.Text = "$" .. pieceInfo.Price
            end
        end
    end
    
    -- Position aléatoire dans la SpawnZone
    local zonePos = self._spawnZone.Position
    local zoneSize = self._spawnZone.Size
    
    local randomX = zonePos.X + (math.random() - 0.5) * zoneSize.X
    local randomY = zonePos.Y + zoneSize.Y / 2 + 10 -- Au-dessus du sol
    local randomZ = zonePos.Z + (math.random() - 0.5) * zoneSize.Z
    
    piece:SetPrimaryPartCFrame(CFrame.new(randomX, randomY, randomZ))
    
    -- Supprimer l'ancien PickupZone s'il existe (pour éviter les problèmes de réplication)
    local oldPickupZone = primaryPart:FindFirstChild("PickupZone")
    if oldPickupZone then
        oldPickupZone:Destroy()
    end
    
    -- Créer un nouveau PickupZone
    local pickupZone = Instance.new("Part")
    pickupZone.Name = "PickupZone"
    pickupZone.Size = primaryPart.Size * 1.5 -- Un peu plus grand que la pièce
    pickupZone.CFrame = primaryPart.CFrame
    pickupZone.Transparency = 1
    pickupZone.CanCollide = false
    pickupZone.Anchored = false
    pickupZone.Massless = true
    
    -- Souder au PrimaryPart
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = primaryPart
    weld.Part1 = pickupZone
    weld.Parent = pickupZone
    
    pickupZone.Parent = primaryPart
    
    -- Créer le ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Pickup"
    prompt.ObjectText = templateName
    prompt.MaxActivationDistance = 15
    prompt.RequiresLineOfSight = false
    prompt.HoldDuration = 0
    prompt.Enabled = true
    prompt.Parent = pickupZone
    
    print("[ArenaSystem] PickupZone et ProximityPrompt créés pour:", pieceId)
    
    -- Parent et stockage
    piece.Parent = self._piecesFolder
    self._pieces[pieceId] = {
        Model = piece,
        SpawnedAt = tick(),
    }
    
    print("[ArenaSystem] Pièce spawnée: " .. pieceId .. " (" .. templateName .. " " .. pieceType .. " - Set: " .. setName .. ")")
    
    return piece
end

--[[
    Boucle de spawn des pièces
]]
function ArenaSystem:_StartSpawnLoop()
    if self._spawnLoopRunning then return end
    self._spawnLoopRunning = true
    
    task.spawn(function()
        print("[ArenaSystem] Boucle de spawn démarrée")
        
        while self._spawnLoopRunning do
            task.wait(GameConfig.Arena.SpawnInterval)
            
            -- Compter les pièces actuelles
            local count = 0
            for _ in pairs(self._pieces) do
                count = count + 1
            end
            
            -- Spawn si sous la limite
            if count < GameConfig.Arena.MaxPiecesInArena then
                local piece = self:SpawnRandomPiece()
                if piece then
                    print("[ArenaSystem] Pièce spawnée: " .. piece.Name)
                end
            end
        end
    end)
end

--[[
    Boucle de nettoyage des pièces expirées
]]
function ArenaSystem:_StartCleanupLoop()
    if self._cleanupLoopRunning then return end
    self._cleanupLoopRunning = true
    
    task.spawn(function()
        print("[ArenaSystem] Boucle de nettoyage démarrée")
        
        while self._cleanupLoopRunning do
            task.wait(10) -- Vérifier toutes les 10 secondes
            
            local now = tick()
            local toRemove = {}
            
            -- Trouver les pièces expirées
            for pieceId, data in pairs(self._pieces) do
                if (now - data.SpawnedAt) > GameConfig.Arena.PieceLifetime then
                    table.insert(toRemove, pieceId)
                end
            end
            
            -- Supprimer les pièces expirées
            for _, pieceId in ipairs(toRemove) do
                local data = self._pieces[pieceId]
                if data and data.Model then
                    data.Model:Destroy()
                    print("[ArenaSystem] Pièce expirée supprimée: " .. pieceId)
                end
                self._pieces[pieceId] = nil
            end
        end
    end)
end

--[[
    Récupère une pièce par son ID
    @param pieceId: string
    @return Model | nil
]]
function ArenaSystem:GetPieceById(pieceId)
    local data = self._pieces[pieceId]
    return data and data.Model or nil
end

--[[
    Supprime une pièce de l'arène
    @param piece: Model
]]
function ArenaSystem:RemovePiece(piece)
    if not piece then return end
    
    local pieceId = piece:GetAttribute("PieceId")
    if pieceId then
        self._pieces[pieceId] = nil
    end
    
    piece:Destroy()
    print("[ArenaSystem] Pièce supprimée: " .. (pieceId or "unknown"))
end

return ArenaSystem
