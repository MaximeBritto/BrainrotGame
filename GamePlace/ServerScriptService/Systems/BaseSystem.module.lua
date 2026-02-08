--[[
    BaseSystem.lua
    Gestion des bases et assignation aux joueurs
    
    Responsabilités:
    - Assigner une base libre à chaque joueur
    - Téléporter le joueur à sa base
    - Gérer les slots et placement de Brainrots
    - Débloquer les étages progressivement
    - Libérer la base quand le joueur quitte
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local Constants = require(Shared["Constants.module"])
local GameConfig = require(Config["GameConfig.module"])

-- Services (seront injectés)
local DataService = nil
local PlayerService = nil
local NetworkSetup = nil

local BaseSystem = {}
BaseSystem._initialized = false
BaseSystem._assignedBases = {} -- {[userId] = {Base = model, BaseIndex = number}}
BaseSystem._availableBases = {} -- Liste des indices de bases libres

--[[
    Initialise le système
    @param services: table - {DataService, PlayerService, NetworkSetup}
]]
function BaseSystem:Init(services)
    if self._initialized then
        warn("[BaseSystem] Déjà initialisé!")
        return
    end
    
    -- print("[BaseSystem] Initialisation...")
    
    -- Récupérer les services
    DataService = services.DataService
    PlayerService = services.PlayerService
    NetworkSetup = services.NetworkSetup
    
    -- Initialiser les bases disponibles
    self:_InitializeBases()
    
    self._initialized = true
    -- print("[BaseSystem] Initialisé! Bases disponibles: " .. #self._availableBases)
end

--[[
    Initialise la liste des bases disponibles
]]
function BaseSystem:_InitializeBases()
    local workspace = game:GetService("Workspace")
    local basesFolder = workspace:FindFirstChild(Constants.WorkspaceNames.BasesFolder)
    
    if not basesFolder then
        warn("[BaseSystem] Dossier Bases introuvable dans Workspace!")
        return
    end
    
    -- Compter les bases disponibles
    for _, base in ipairs(basesFolder:GetChildren()) do
        if base:IsA("Model") and string.match(base.Name, "^Base_%d+$") then
            local baseIndex = tonumber(string.match(base.Name, "%d+"))
            if baseIndex then
                table.insert(self._availableBases, baseIndex)
            end
        end
    end
    
    table.sort(self._availableBases)
    -- print("[BaseSystem] " .. #self._availableBases .. " base(s) trouvée(s)")
end

--[[
    Assigne une base libre à un joueur
    @param player: Player
    @return Model | nil - La base assignée, ou nil si aucune disponible
]]
function BaseSystem:AssignBase(player)
    -- print("[BaseSystem] AssignBase appelé pour " .. player.Name)
    
    -- Vérifier si le joueur a déjà une base
    if self._assignedBases[player.UserId] then
        warn("[BaseSystem] " .. player.Name .. " a déjà une base!")
        return self._assignedBases[player.UserId].Base
    end
    
    -- Vérifier s'il reste des bases
    if #self._availableBases == 0 then
        warn("[BaseSystem] Aucune base disponible pour " .. player.Name)
        return nil
    end
    
    -- Prendre la première base disponible
    local baseIndex = table.remove(self._availableBases, 1)
    -- print("[BaseSystem] Base index sélectionné: " .. baseIndex)
    
    -- Trouver le Model de la base
    local workspace = game:GetService("Workspace")
    local basesFolder = workspace:FindFirstChild(Constants.WorkspaceNames.BasesFolder)
    local baseModel = basesFolder:FindFirstChild("Base_" .. baseIndex)
    
    if not baseModel then
        warn("[BaseSystem] Base_" .. baseIndex .. " introuvable!")
        return nil
    end
    
    -- print("[BaseSystem] Base Model trouvé: " .. baseModel.Name)
    
    -- Assigner la base
    self._assignedBases[player.UserId] = {
        Base = baseModel,
        BaseIndex = baseIndex,
    }
    
    -- Attribut pour que le client trouve sa base (EconomyController, etc.)
    baseModel:SetAttribute("OwnerUserId", player.UserId)
    
    -- Mettre à jour les données runtime du joueur
    local runtimeData = PlayerService:GetRuntimeData(player)
    if runtimeData then
        runtimeData.AssignedBase = baseModel
        runtimeData.BaseIndex = baseIndex
        -- print("[BaseSystem] Runtime data mis à jour")
    end
    
    -- print("[BaseSystem] Base_" .. baseIndex .. " assignée à " .. player.Name)
    
    return baseModel
end

--[[
    Libère la base d'un joueur
    @param player: Player
]]
function BaseSystem:ReleaseBase(player)
    local assignment = self._assignedBases[player.UserId]
    
    if not assignment then
        return
    end
    
    -- Nettoyer les Brainrots visuels de la base
    self:_CleanupBaseBrainrots(assignment.Base)
    
    -- Retirer l'attribut pour que le client ne prenne plus cette base
    assignment.Base:SetAttribute("OwnerUserId", nil)
    
    -- Remettre la base dans les disponibles
    table.insert(self._availableBases, assignment.BaseIndex)
    table.sort(self._availableBases)
    
    -- Retirer de la table des assignations
    self._assignedBases[player.UserId] = nil
    
    -- print("[BaseSystem] Base_" .. assignment.BaseIndex .. " libérée par " .. player.Name)
end

--[[
    Récupère la base d'un joueur
    @param player: Player
    @return Model | nil
]]
function BaseSystem:GetPlayerBase(player)
    local assignment = self._assignedBases[player.UserId]
    return assignment and assignment.Base or nil
end

--[[
    Téléporte le joueur à sa base
    @param player: Player
    @return boolean - true si succès
]]
function BaseSystem:SpawnPlayerAtBase(player)
    -- print("[BaseSystem] SpawnPlayerAtBase appelé pour " .. player.Name)
    
    local base = self:GetPlayerBase(player)
    
    if not base then
        warn("[BaseSystem] " .. player.Name .. " n'a pas de base assignée!")
        return false
    end
    
    -- print("[BaseSystem] Base trouvée: " .. base.Name)
    
    local spawnPoint = base:FindFirstChild(Constants.WorkspaceNames.SpawnPoint)
    
    if not spawnPoint then
        warn("[BaseSystem] SpawnPoint introuvable dans " .. base.Name)
        return false
    end
    
    -- print("[BaseSystem] SpawnPoint trouvé: " .. spawnPoint.Name)
    
    -- Attendre que le personnage soit prêt
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    
    if not humanoidRootPart then
        warn("[BaseSystem] HumanoidRootPart introuvable pour " .. player.Name)
        return false
    end
    
    -- print("[BaseSystem] HumanoidRootPart trouvé, téléportation...")
    
    -- Téléporter
    humanoidRootPart.CFrame = spawnPoint.CFrame + Vector3.new(0, 3, 0)
    
    -- print("[BaseSystem] " .. player.Name .. " téléporté à sa base")
    return true
end

--[[
    Récupère le premier slot libre dans la base d'un joueur
    @param player: Player
    @return number | nil - Index du slot libre (1-30), ou nil si tous occupés
]]
function BaseSystem:GetFirstFreeSlot(player)
    local playerData = DataService:GetPlayerData(player)
    
    if not playerData then
        return nil
    end
    
    -- Parcourir les slots de 1 à OwnedSlots
    for i = 1, playerData.OwnedSlots do
        if not playerData.PlacedBrainrots[i] then
            return i
        end
    end
    
    return nil
end

--[[
    Place un Brainrot sur un slot
    @param player: Player
    @param slotIndex: number - Index du slot (1-30)
    @param brainrotData: table - {Name, HeadSet, BodySet, LegsSet, CreatedAt}
    @return boolean - true si succès
]]
function BaseSystem:PlaceBrainrotOnSlot(player, slotIndex, brainrotData)
    local base = self:GetPlayerBase(player)
    
    if not base then
        warn("[BaseSystem] Pas de base pour " .. player.Name)
        return false
    end
    
    -- Trouver le slot
    local slotsFolder = base:FindFirstChild(Constants.WorkspaceNames.SlotsFolder)
    if not slotsFolder then
        warn("[BaseSystem] Dossier Slots introuvable!")
        return false
    end
    
    local slot = slotsFolder:FindFirstChild("Slot_" .. slotIndex)
    if not slot then
        warn("[BaseSystem] Slot_" .. slotIndex .. " introuvable!")
        return false
    end
    
    -- Retirer l'ancien Brainrot visuel sur ce slot (évite les doublons)
    for _, child in ipairs(slot:GetChildren()) do
        if child:IsA("Model") and child.Name:match("^Brainrot_") then
            child:Destroy()
        end
    end
    
    -- Créer le Model visuel du Brainrot
    local brainrotModel = self:_CreateBrainrotModel(brainrotData)
    
    -- Positionner sur le slot
    local platform = slot:FindFirstChild(Constants.WorkspaceNames.SlotPlatform)
    if platform then
        brainrotModel:SetPrimaryPartCFrame(platform.CFrame + Vector3.new(0, 2, 0))
    end
    
    brainrotModel.Parent = slot
    
    -- Sauvegarder dans les données
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return false end
    if not playerData.PlacedBrainrots then playerData.PlacedBrainrots = {} end
    playerData.PlacedBrainrots[slotIndex] = brainrotData
    DataService:UpdateValue(player, "PlacedBrainrots", playerData.PlacedBrainrots)
    
    -- print("[BaseSystem] Brainrot placé sur Slot_" .. slotIndex .. " pour " .. player.Name)
    
    -- Vérifier déblocage d'étage
    self:CheckFloorUnlock(player)
    
    return true
end

--[[
    Vérifie et débloque les étages si nécessaire
    @param player: Player
    @return number | nil - Numéro de l'étage débloqué, ou nil
]]
function BaseSystem:CheckFloorUnlock(player)
    local playerData = DataService:GetPlayerData(player)
    local base = self:GetPlayerBase(player)
    
    if not playerData or not base then
        return nil
    end
    
    local ownedSlots = playerData.OwnedSlots
    local floorsFolder = base:FindFirstChild(Constants.WorkspaceNames.FloorsFolder)
    
    if not floorsFolder then
        return nil
    end
    
    -- Vérifier chaque seuil de déblocage
    for floorNum, threshold in pairs(GameConfig.Base.FloorUnlockThresholds) do
        if ownedSlots == threshold then
            local floor = floorsFolder:FindFirstChild("Floor_" .. floorNum)
            if floor then
                self:_SetFloorVisible(floor, true)
                local remotes = NetworkSetup:GetAllRemotes()
                if remotes and remotes.Notification then
                    remotes.Notification:FireClient(player, {
                        Type = "Success",
                        Message = "Floor " .. floorNum .. " unlocked!",
                        Duration = 3,
                    })
                end
                -- print("[BaseSystem] Floor_" .. floorNum .. " débloqué pour " .. player.Name)
                return floorNum
            end
        end
    end
    
    return nil
end

--[[
    Réapplique la visibilité des étages selon OwnedSlots (sauvegardé).
    À appeler au chargement du joueur / spawn pour que les étages débloqués restent visibles après reconnexion.
    @param player: Player
]]
function BaseSystem:ApplyFloorVisibility(player)
    local base = self:GetPlayerBase(player)
    if not base then return end
    
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return end
    
    local ownedSlots = playerData.OwnedSlots or GameConfig.Base.StartingSlots
    local floorsFolder = base:FindFirstChild(Constants.WorkspaceNames.FloorsFolder)
    if not floorsFolder then return end
    
    for floorNum, threshold in pairs(GameConfig.Base.FloorUnlockThresholds) do
        if ownedSlots >= threshold then
            local floor = floorsFolder:FindFirstChild("Floor_" .. floorNum)
            if floor then
                self:_SetFloorVisible(floor, true)
            end
        end
    end
end

--[[
    Réapplique la visibilité des slots selon OwnedSlots (slots 1..ownedSlots visibles, reste cachés).
    À appeler au chargement du joueur et après chaque achat de slot.
    @param player: Player
]]
function BaseSystem:ApplySlotVisibility(player)
    local base = self:GetPlayerBase(player)
    if not base then return end
    
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return end
    
    local ownedSlots = playerData.OwnedSlots or GameConfig.Base.StartingSlots
    local slotsFolder = base:FindFirstChild(Constants.WorkspaceNames.SlotsFolder)
    if not slotsFolder then return end
    
    for _, slot in ipairs(slotsFolder:GetChildren()) do
        local num = slot.Name:match("^Slot_(%d+)$")
        if num then
            local slotIndex = tonumber(num)
            local visible = (slotIndex <= ownedSlots)
            self:_SetFloorVisible(slot, visible)
        end
    end
end

--[[
    Débloque et affiche un étage dans la base du joueur (appelé par EconomySystem à l'achat du slot).
    @param player: Player
    @param floorNum: number - Numéro de l'étage (1 = Floor_1, 2 = Floor_2)
    @return boolean - true si l'étage a été affiché
]]
function BaseSystem:UnlockFloor(player, floorNum)
    local base = self:GetPlayerBase(player)
    if not base then return false end
    
    local floorsFolder = base:FindFirstChild(Constants.WorkspaceNames.FloorsFolder)
    if not floorsFolder then
        warn("[BaseSystem] Floors folder not found in base " .. base.Name)
        return false
    end
    
    local floor = floorsFolder:FindFirstChild("Floor_" .. floorNum)
    if not floor then
        warn("[BaseSystem] Floor_" .. floorNum .. " not found in " .. floorsFolder:GetFullName())
        return false
    end
    
    self:_SetFloorVisible(floor, true)
    -- print("[BaseSystem] Floor_" .. floorNum .. " unlocked (visible) for " .. player.Name)
    return true
end

--[[
    Rend un étage visible ou invisible (Part unique ou Model avec plusieurs Parts).
    @param floor: Instance - Part, Model ou Folder contenant des BaseParts
    @param visible: boolean
]]
function BaseSystem:_SetFloorVisible(floor, visible)
    if floor:IsA("BasePart") then
        floor.Transparency = visible and 0 or 1
        floor.CanCollide = visible
        return
    end
    
    if floor:IsA("Model") or floor:IsA("Folder") then
        for _, desc in ipairs(floor:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.Transparency = visible and 0 or 1
                desc.CanCollide = visible
            end
        end
        return
    end
    
    -- Fallback: un seul enfant Part
    for _, child in ipairs(floor:GetChildren()) do
        self:_SetFloorVisible(child, visible)
    end
end

--[[
    Compte le nombre de Brainrots placés dans la base
    @param player: Player
    @return number
]]
function BaseSystem:GetPlacedBrainrotCount(player)
    local playerData = DataService:GetPlayerData(player)
    
    if not playerData or not playerData.PlacedBrainrots then
        return 0
    end
    
    local count = 0
    for _ in pairs(playerData.PlacedBrainrots) do
        count = count + 1
    end
    
    return count
end

--[[
    Crée le Model visuel d'un Brainrot
    @param brainrotData: table
    @return Model
]]
function BaseSystem:_CreateBrainrotModel(brainrotData)
    -- TODO Phase 5: Créer le vrai modèle avec les meshes
    -- Pour l'instant, créer un placeholder
    
    local model = Instance.new("Model")
    model.Name = "Brainrot_" .. brainrotData.Name
    
    local part = Instance.new("Part")
    part.Name = "PrimaryPart"
    part.Size = Vector3.new(2, 4, 2)
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.Random()
    part.Parent = model
    
    model.PrimaryPart = part
    
    return model
end

--[[
    Nettoie les Brainrots visuels d'une base
    @param base: Model
]]
function BaseSystem:_CleanupBaseBrainrots(base)
    local slotsFolder = base:FindFirstChild(Constants.WorkspaceNames.SlotsFolder)
    
    if not slotsFolder then
        return
    end
    
    for _, slot in ipairs(slotsFolder:GetChildren()) do
        for _, child in ipairs(slot:GetChildren()) do
            if child:IsA("Model") and string.match(child.Name, "^Brainrot_") then
                child:Destroy()
            end
        end
    end
end

return BaseSystem
