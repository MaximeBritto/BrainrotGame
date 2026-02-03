--[[
    DoorSystem.lua
    Gestion des portes sécurisées des bases
    
    Responsabilités:
    - Activer/désactiver les portes
    - Gérer les collisions (propriétaire peut passer)
    - Timer de fermeture (30 secondes)
    - Synchroniser l'état avec le client
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local Constants = require(Shared["Constants.module"])
local GameConfig = require(Config["GameConfig.module"])

-- Services (seront injectés)
local BaseSystem = nil
local PlayerService = nil
local NetworkSetup = nil

local DoorSystem = {}
DoorSystem._initialized = false
DoorSystem._doorStates = {} -- {[userId] = {State, CloseTime, ReopenTime}}

--[[
    Initialise le système
    @param services: table - {BaseSystem, PlayerService, NetworkSetup}
]]
function DoorSystem:Init(services)
    if self._initialized then
        warn("[DoorSystem] Déjà initialisé!")
        return
    end
    
    print("[DoorSystem] Initialisation...")
    
    -- Récupérer les services
    BaseSystem = services.BaseSystem
    PlayerService = services.PlayerService
    NetworkSetup = services.NetworkSetup
    
    -- Configurer les CollisionGroups
    self:_SetupCollisionGroups()
    
    -- Initialiser toutes les portes (ouvertes par défaut)
    self:_InitializeAllDoors()
    
    -- Démarrer la loop de mise à jour des portes
    self:_StartDoorUpdateLoop()
    
    self._initialized = true
    print("[DoorSystem] Initialisé!")
end

--[[
    Configure les CollisionGroups pour les portes
]]
function DoorSystem:_SetupCollisionGroups()
    -- Créer les groupes s'ils n'existent pas
    local _success1 = pcall(function()
        PhysicsService:RegisterCollisionGroup(Constants.CollisionGroup.Players)
    end)
    
    local _success2 = pcall(function()
        PhysicsService:RegisterCollisionGroup(Constants.CollisionGroup.DoorBars)
    end)
    
    -- Par défaut, Players collisionne avec DoorBars
    pcall(function()
        PhysicsService:CollisionGroupSetCollidable(
            Constants.CollisionGroup.Players,
            Constants.CollisionGroup.DoorBars,
            true
        )
    end)
    
    print("[DoorSystem] CollisionGroups configurés")
end

--[[
    Initialise toutes les portes (ouvertes par défaut)
]]
function DoorSystem:_InitializeAllDoors()
    local workspace = game:GetService("Workspace")
    local basesFolder = workspace:FindFirstChild(Constants.WorkspaceNames.BasesFolder)
    
    if not basesFolder then
        warn("[DoorSystem] Dossier Bases introuvable!")
        return
    end
    
    local doorCount = 0
    
    -- Parcourir toutes les bases
    for _, base in ipairs(basesFolder:GetChildren()) do
        if base:IsA("Model") and string.match(base.Name, "^Base_%d+$") then
            local doorFolder = base:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
            
            if doorFolder then
                local bars = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorBars)
                
                if bars then
                    -- Ouvrir la porte par défaut (INVISIBLE et non-solide)
                    for _, part in ipairs(bars:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                            part.Transparency = 1 -- INVISIBLE quand ouvert
                        end
                    end
                    
                    doorCount = doorCount + 1
                end
            end
        end
    end
    
    print("[DoorSystem] " .. doorCount .. " porte(s) initialisée(s) (ouvertes)")
end

--[[
    Active la porte d'une base (la ferme)
    @param player: Player
    @return string - ActionResult
]]
function DoorSystem:ActivateDoor(player)
    local base = BaseSystem:GetPlayerBase(player)
    
    if not base then
        return Constants.ActionResult.NotOwner
    end
    
    -- Vérifier si la porte est déjà fermée
    local doorState = self._doorStates[player.UserId]
    if doorState and doorState.State == Constants.DoorState.Closed then
        local remainingTime = doorState.ReopenTime - os.time()
        if remainingTime > 0 then
            return Constants.ActionResult.OnCooldown
        end
    end
    
    -- Fermer la porte
    self:_CloseDoor(player, base)
    
    -- Programmer la réouverture
    local closeTime = os.time()
    local reopenTime = closeTime + GameConfig.Door.CloseDuration
    
    self._doorStates[player.UserId] = {
        State = Constants.DoorState.Closed,
        CloseTime = closeTime,
        ReopenTime = reopenTime,
    }
    
    -- Mettre à jour les données runtime
    local runtimeData = PlayerService:GetRuntimeData(player)
    if runtimeData then
        runtimeData.DoorState = Constants.DoorState.Closed
        runtimeData.DoorCloseTime = closeTime
        runtimeData.DoorReopenTime = reopenTime
    end
    
    -- Synchroniser avec le client
    self:_SyncDoorState(player)
    
    print("[DoorSystem] Porte fermée pour " .. player.Name .. " pendant " .. GameConfig.Door.CloseDuration .. "s")
    
    return Constants.ActionResult.Success
end

--[[
    Ferme physiquement la porte
    @param player: Player
    @param base: Model
]]
function DoorSystem:_CloseDoor(player, base)
    local doorFolder = base:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
    if not doorFolder then return end
    
    local bars = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorBars)
    if not bars then return end
    
    -- Rendre les barres solides et VISIBLES
    for _, part in ipairs(bars:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
            part.Transparency = 0 -- VISIBLE quand fermé
            
            -- Assigner au CollisionGroup DoorBars
            part.CollisionGroup = Constants.CollisionGroup.DoorBars
        end
    end
    
    -- Désactiver la collision pour le propriétaire
    self:_SetPlayerDoorCollision(player, false)
end

--[[
    Ouvre physiquement la porte
    @param player: Player
    @param base: Model
]]
function DoorSystem:_OpenDoor(player, base)
    local doorFolder = base:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
    if not doorFolder then return end
    
    local bars = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorBars)
    if not bars then return end
    
    -- Rendre les barres non-solides et INVISIBLES
    for _, part in ipairs(bars:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Transparency = 1 -- INVISIBLE quand ouvert
        end
    end
    
    -- Réactiver la collision pour le propriétaire
    self:_SetPlayerDoorCollision(player, true)
end

--[[
    Active/désactive la collision entre un joueur et les portes
    @param player: Player
    @param collide: boolean
]]
function DoorSystem:_SetPlayerDoorCollision(player, collide)
    local character = player.Character
    if not character then return end
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if collide then
                part.CollisionGroup = Constants.CollisionGroup.Players
            else
                -- Créer un groupe unique pour ce joueur (pas de collision avec DoorBars)
                local groupName = "Player_" .. player.UserId
                
                pcall(function()
                    PhysicsService:RegisterCollisionGroup(groupName)
                end)
                
                pcall(function()
                    PhysicsService:CollisionGroupSetCollidable(
                        groupName,
                        Constants.CollisionGroup.DoorBars,
                        false
                    )
                end)
                
                part.CollisionGroup = groupName
            end
        end
    end
end

--[[
    Récupère l'état actuel de la porte d'un joueur
    @param player: Player
    @return table - {State, RemainingTime}
]]
function DoorSystem:GetDoorState(player)
    local doorState = self._doorStates[player.UserId]
    
    if not doorState then
        return {
            State = Constants.DoorState.Open,
            RemainingTime = 0,
        }
    end
    
    local remainingTime = math.max(0, doorState.ReopenTime - os.time())
    
    return {
        State = doorState.State,
        RemainingTime = remainingTime,
    }
end

--[[
    Vérifie si un joueur peut traverser une porte
    @param player: Player
    @param base: Model
    @return boolean
]]
function DoorSystem:CanPlayerPass(player, base)
    -- Le propriétaire peut toujours passer
    local playerBase = BaseSystem:GetPlayerBase(player)
    if playerBase == base then
        return true
    end
    
    -- Trouver le propriétaire de cette base
    for userId, assignment in pairs(BaseSystem._assignedBases) do
        if assignment.Base == base then
            local doorState = self._doorStates[userId]
            
            -- Si la porte est ouverte, tout le monde peut passer
            if not doorState or doorState.State == Constants.DoorState.Open then
                return true
            end
            
            -- Si la porte est fermée, seul le propriétaire peut passer
            return false
        end
    end
    
    -- Base sans propriétaire, tout le monde peut passer
    return true
end

--[[
    Loop de mise à jour des portes (vérifie les réouvertures)
]]
function DoorSystem:_StartDoorUpdateLoop()
    task.spawn(function()
        while true do
            task.wait(1) -- Vérifier chaque seconde
            
            local currentTime = os.time()
            
            for userId, doorState in pairs(self._doorStates) do
                if doorState.State == Constants.DoorState.Closed then
                    if currentTime >= doorState.ReopenTime then
                        -- Réouvrir la porte
                        local player = Players:GetPlayerByUserId(userId)
                        
                        if player then
                            local base = BaseSystem:GetPlayerBase(player)
                            
                            if base then
                                self:_OpenDoor(player, base)
                            end
                            
                            -- Mettre à jour l'état
                            doorState.State = Constants.DoorState.Open
                            
                            -- Mettre à jour runtime
                            local runtimeData = PlayerService:GetRuntimeData(player)
                            if runtimeData then
                                runtimeData.DoorState = Constants.DoorState.Open
                            end
                            
                            -- Synchroniser avec le client
                            self:_SyncDoorState(player)
                            
                            print("[DoorSystem] Porte rouverte pour " .. player.Name)
                        end
                    end
                end
            end
        end
    end)
    
    print("[DoorSystem] Loop de mise à jour démarrée")
end

--[[
    Synchronise l'état de la porte avec le client
    @param player: Player
]]
function DoorSystem:_SyncDoorState(player)
    local remotes = NetworkSetup:GetAllRemotes()
    local state = self:GetDoorState(player)
    
    if remotes.SyncDoorState then
        remotes.SyncDoorState:FireClient(player, {
            State = state.State,
            RemainingTime = state.RemainingTime,
            ReopenTime = self._doorStates[player.UserId] and self._doorStates[player.UserId].ReopenTime or 0
        })
    end
end

--[[
    Nettoie l'état de la porte d'un joueur (quand il quitte)
    @param player: Player
]]
function DoorSystem:CleanupPlayer(player)
    self._doorStates[player.UserId] = nil
end

return DoorSystem
