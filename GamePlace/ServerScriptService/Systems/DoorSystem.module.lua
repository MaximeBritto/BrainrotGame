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
local MarketplaceService = game:GetService("MarketplaceService")
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
DoorSystem._pendingDoorOpen = {} -- {[buyerUserId] = targetOwnerUserId}
DoorSystem._registeredBarsGroups = {} -- {[baseIndex] = groupName}

-- Itère toutes les BaseParts d'un objet "Bars" qui peut être soit un Model/Folder
-- (cas attendu, on parcourt les descendants), soit lui-même un BasePart.
-- Sans cette double prise en charge, une base où "Bars" est défini comme une
-- seule BasePart au lieu d'un Model ne voit jamais ses propriétés modifiées
-- (CanCollide reste tel quel : la porte semble fermée mais on passe à travers).
local function ForEachBarPart(bars, callback)
    if not bars then return end
    if bars:IsA("BasePart") then
        callback(bars)
    end
    for _, part in ipairs(bars:GetDescendants()) do
        if part:IsA("BasePart") then
            callback(part)
        end
    end
end

--[[
    Initialise le système
    @param services: table - {BaseSystem, PlayerService, NetworkSetup}
]]
function DoorSystem:Init(services)
    if self._initialized then
        warn("[DoorSystem] Déjà initialisé!")
        return
    end
    
    -- print("[DoorSystem] Initialisation...")
    
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
    -- print("[DoorSystem] Initialisé!")
end

--[[
    Configure les CollisionGroups pour les portes
]]
function DoorSystem:_SetupCollisionGroups()
    -- Groupe joueurs (état "porte ouverte" pour tout le monde)
    pcall(function()
        PhysicsService:RegisterCollisionGroup(Constants.CollisionGroup.Players)
    end)
    -- print("[DoorSystem] CollisionGroups configurés")
end

--[[
    Récupère (ou crée) le groupe de collision pour les barres d'une base donnée.
    Chaque base a son propre groupe pour que le bypass du propriétaire ne
    s'applique QU'À SES barres, pas à celles des autres joueurs.
    @param base: Model
    @return string - nom du groupe
]]
function DoorSystem:_GetBarsGroupForBase(base)
    if not base then return nil end
    local baseIndex = tonumber(string.match(base.Name, "%d+"))
    if not baseIndex then return nil end

    if self._registeredBarsGroups[baseIndex] then
        return self._registeredBarsGroups[baseIndex]
    end

    local groupName = Constants.CollisionGroup.DoorBars .. "_" .. baseIndex
    pcall(function()
        PhysicsService:RegisterCollisionGroup(groupName)
    end)
    pcall(function()
        PhysicsService:CollisionGroupSetCollidable(
            Constants.CollisionGroup.Players,
            groupName,
            true
        )
    end)
    self._registeredBarsGroups[baseIndex] = groupName
    return groupName
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
                    -- Pré-enregistrer le groupe par-base (et l'assigner aux parts)
                    local groupName = self:_GetBarsGroupForBase(base)

                    -- Ouvrir la porte par défaut (INVISIBLE et non-solide)
                    ForEachBarPart(bars, function(part)
                        part.CanCollide = false
                        part.Transparency = 1 -- INVISIBLE quand ouvert
                        if groupName then
                            part.CollisionGroup = groupName
                        end
                    end)

                    doorCount = doorCount + 1
                end
            end
        end
    end
    
    -- print("[DoorSystem] " .. doorCount .. " porte(s) initialisée(s) (ouvertes)")
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
    
    -- print("[DoorSystem] Porte fermée pour " .. player.Name .. " pendant " .. GameConfig.Door.CloseDuration .. "s")
    
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
    
    -- Rendre les barres solides et VISIBLES, en groupe par-base
    -- (chaque base a son propre groupe pour que le bypass du propriétaire
    -- ne traverse QUE ses barres, pas celles des autres joueurs)
    local groupName = self:_GetBarsGroupForBase(base)
    ForEachBarPart(bars, function(part)
        part.CanCollide = true
        part.Transparency = 0 -- VISIBLE quand fermé
        if groupName then
            part.CollisionGroup = groupName
        end
    end)

    -- Désactiver la collision pour le propriétaire (sur SES barres uniquement)
    self:_SetPlayerDoorCollision(player, false, base)
end

--[[
    Remet les barreaux d'une base en état « ouvert » (sans collision, invisibles).
    Indispensable quand l'ancien proprio se déconnecte les barreaux fermés : la loop
    de timer ne peut plus appeler _OpenDoor sans Player.
    @param base: Model
]]
function DoorSystem:OpenBaseDoorPhysically(base)
    if not base then return end
    local doorFolder = base:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
    if not doorFolder then return end

    local bars = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorBars)
    if not bars then return end

    ForEachBarPart(bars, function(part)
        part.CanCollide = false
        part.Transparency = 1
    end)
end

--[[
    Ouvre physiquement la porte
    @param player: Player
    @param base: Model
]]
function DoorSystem:_OpenDoor(player, base)
    self:OpenBaseDoorPhysically(base)
    -- Réactiver la collision pour le propriétaire (retour groupe générique Players)
    self:_SetPlayerDoorCollision(player, true)
end

--[[
    Active/désactive la collision entre un joueur et SES PROPRES barres.
    @param player: Player
    @param collide: boolean - true = retour au groupe générique Players (collide avec
                              toutes les barres fermées), false = bypass des barres
                              de SA base uniquement.
    @param base: Model? - La base du joueur (utile quand collide=false). Si non
                          fournie, on tente de la récupérer via BaseSystem.
]]
function DoorSystem:_SetPlayerDoorCollision(player, collide, base)
    local character = player.Character
    if not character then return end

    if collide then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = Constants.CollisionGroup.Players
            end
        end
        return
    end

    -- Bypass : il faut un groupe unique au joueur ET la cible (groupe de SA base).
    -- Sans la cible, on tombe sur l'ancien comportement (bypass global) qui
    -- permettait à un joueur ayant fermé sa porte de traverser TOUTES les
    -- portes fermées du serveur. On préfère ne rien faire que ce bypass global.
    base = base or (BaseSystem and BaseSystem:GetPlayerBase(player))
    local barsGroup = base and self:_GetBarsGroupForBase(base) or nil
    if not barsGroup then
        -- Pas de base identifiée : on garde le joueur dans Players.
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CollisionGroup = Constants.CollisionGroup.Players
            end
        end
        return
    end

    local groupName = "Player_" .. player.UserId
    pcall(function()
        PhysicsService:RegisterCollisionGroup(groupName)
    end)
    pcall(function()
        PhysicsService:CollisionGroupSetCollidable(groupName, barsGroup, false)
    end)

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = groupName
        end
    end
end

--[[
    Réapplique la collision de porte pour le personnage actuel
    (à appeler au respawn pour que le propriétaire puisse toujours
    traverser ses propres barreaux si sa porte est fermée)
    @param player: Player
]]
function DoorSystem:ApplyCharacterDoorCollision(player)
    local doorState = self._doorStates[player.UserId]
    local isClosed = doorState and doorState.State == Constants.DoorState.Closed
    self:_SetPlayerDoorCollision(player, not isClosed)
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

-- ═══════════════════════════════════════════════════════
-- OUVERTURE DE PORTE PAYANTE (Robux)
-- ═══════════════════════════════════════════════════════

--[[
    Demande d'ouverture de porte payante (appelé par NetworkHandler)
    @param player: Player - L'acheteur
    @param targetOwnerId: number - UserId du propriétaire de la base
]]
function DoorSystem:RequestDoorOpen(player, targetOwnerId)
    if not targetOwnerId or type(targetOwnerId) ~= "number" then
        self:_SendNotification(player, "Error", "Invalid target!")
        return
    end

    -- Vérifier que ce n'est pas sa propre base
    if player.UserId == targetOwnerId then
        self:_SendNotification(player, "Error", "This is your own base!")
        return
    end

    -- Vérifier que la porte cible est bien fermée
    local doorState = self._doorStates[targetOwnerId]
    if not doorState or doorState.State ~= Constants.DoorState.Closed then
        self:_SendNotification(player, "Error", "This door is already open!")
        return
    end

    -- Vérifier que le ProductId est configuré
    local productId = GameConfig.Door.DoorOpenProductId
    if not productId or productId == 0 then
        warn("[DoorSystem] DoorOpenProductId non configuré!")
        self:_SendNotification(player, "Error", "Feature not available yet.")
        return
    end

    -- Stocker le contexte d'achat
    self._pendingDoorOpen[player.UserId] = targetOwnerId

    -- Déclencher la fenêtre d'achat Roblox native
    local success, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, productId)
    end)

    if not success then
        warn("[DoorSystem] Erreur PromptProductPurchase: " .. tostring(err))
        self._pendingDoorOpen[player.UserId] = nil
        self:_SendNotification(player, "Error", "Purchase error. Try again.")
    end
end

--[[
    Traite l'achat confirmé d'ouverture de porte (appelé par ShopSystem.ProcessReceipt)
    @param player: Player - L'acheteur
    @return boolean - true si traité avec succès
]]
function DoorSystem:ProcessDoorPurchase(player)
    local targetOwnerId = self._pendingDoorOpen[player.UserId]
    self._pendingDoorOpen[player.UserId] = nil

    if not targetOwnerId then
        warn("[DoorSystem] Aucun achat de porte en attente pour " .. player.Name)
        return false
    end

    -- Ouvrir la porte cible
    local opened = self:ForceOpenDoor(targetOwnerId)

    if opened then
        self:_SendNotification(player, "Success", "Door opened!")
        -- Notifier le propriétaire aussi
        local owner = Players:GetPlayerByUserId(targetOwnerId)
        if owner then
            self:_SendNotification(owner, "Warning", player.Name .. " paid to open your door!")
        end
    else
        self:_SendNotification(player, "Error", "Door is already open.")
    end

    return opened
end

--[[
    Force l'ouverture de la porte d'un joueur (bypass timer)
    @param ownerUserId: number - UserId du propriétaire
    @return boolean - true si la porte a été ouverte
]]
function DoorSystem:ForceOpenDoor(ownerUserId)
    local doorState = self._doorStates[ownerUserId]
    if not doorState or doorState.State ~= Constants.DoorState.Closed then
        return false
    end

    local owner = Players:GetPlayerByUserId(ownerUserId)
    if not owner then
        return false
    end

    local base = BaseSystem:GetPlayerBase(owner)
    if not base then
        return false
    end

    -- Ouvrir la porte
    self:_OpenDoor(owner, base)

    -- Mettre à jour l'état
    doorState.State = Constants.DoorState.Open

    -- Mettre à jour runtime
    local runtimeData = PlayerService:GetRuntimeData(owner)
    if runtimeData then
        runtimeData.DoorState = Constants.DoorState.Open
    end

    -- Synchroniser avec le client du propriétaire
    self:_SyncDoorState(owner)

    return true
end

--[[
    Envoie une notification au client
    @param player: Player
    @param notifType: string
    @param message: string
]]
function DoorSystem:_SendNotification(player, notifType, message)
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = 3,
        })
    end
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
                            
                            -- print("[DoorSystem] Porte rouverte pour " .. player.Name)
                        else
                            -- Joueur déjà parti : l'état aurait dû être nettoyé au leave;
                            -- on enlève l'entrée pour ne pas laisser un timer fantôme.
                            self._doorStates[userId] = nil
                        end
                    end
                end
            end
        end
    end)
    
    -- print("[DoorSystem] Loop de mise à jour démarrée")
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
