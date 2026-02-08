--[[
    PlayerService.lua
    Gestion de la connexion/déconnexion des joueurs
    
    Responsabilités:
    - Charger les données à la connexion
    - Sauvegarder les données à la déconnexion
    - Maintenir les données runtime (non sauvegardées)
    - Gérer le respawn
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])

-- Services (seront injectés)
local DataService = nil
local NetworkSetup = nil
local BaseSystem = nil -- Phase 2
local CodexService = nil -- Phase 6

local PlayerService = {}
PlayerService._runtimeData = {} -- {[userId] = RuntimeData}
PlayerService._initialized = false

-- Structure des données runtime (non sauvegardées)
local function CreateRuntimeData()
    return {
        -- Pièces en main (temporaire)
        PiecesInHand = {},
        
        -- Base assignée
        AssignedBase = nil,
        BaseIndex = nil,
        
        -- État de la porte
        DoorState = Constants.DoorState.Open,
        DoorCloseTime = 0,
        DoorReopenTime = 0,
        
        -- Session
        JoinTime = os.time(),
        LastSaveTime = os.time(),
    }
end

--[[
    Initialise le service
    @param services: table - {DataService = ..., NetworkSetup = ..., BaseSystem = ...}
]]
function PlayerService:Init(services)
    if self._initialized then
        warn("[PlayerService] Déjà initialisé!")
        return
    end
    
    -- print("[PlayerService] Initialisation...")
    
    -- Récupérer les services injectés
    DataService = services.DataService
    NetworkSetup = services.NetworkSetup
    BaseSystem = services.BaseSystem -- Phase 2 (peut être nil au début)
    CodexService = services.CodexService -- Phase 6 (optionnel)
    
    if not DataService then
        error("[PlayerService] DataService requis!")
    end
    
    -- Connecter les événements
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoin(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeave(player)
    end)
    
    -- Gérer les joueurs déjà connectés (si script chargé en retard)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:OnPlayerJoin(player)
        end)
    end
    
    self._initialized = true
    -- print("[PlayerService] Initialisé!")
end

--[[
    Appelé quand un joueur rejoint
    @param player: Player
]]
function PlayerService:OnPlayerJoin(player)
    -- print("[PlayerService] Joueur rejoint: " .. player.Name)
    
    -- 1. Charger les données sauvegardées
    local playerData = DataService:LoadPlayerData(player)
    
    if not playerData then
        warn("[PlayerService] Échec chargement données pour " .. player.Name)
        player:Kick("Impossible de charger vos données. Veuillez réessayer.")
        return
    end
    
    -- 2. Créer les données runtime
    self._runtimeData[player.UserId] = CreateRuntimeData()
    
    -- 3. Configurer le respawn du personnage
    player.CharacterAdded:Connect(function(character)
        self:OnCharacterAdded(player, character)
    end)
    
    -- 4. Si le personnage existe déjà, le gérer maintenant
    if player.Character then
        task.spawn(function()
            self:OnCharacterAdded(player, player.Character)
        end)
    end
    
    -- 5. Envoyer les données au client
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, playerData)
        -- print("[PlayerService] Données envoyées au client: " .. player.Name)
    end
    -- Phase 6: envoyer le Codex au client (via CodexService si disponible)
    if CodexService then
        CodexService:SendCodexToPlayer(player)
    elseif remotes and remotes.SyncCodex then
        remotes.SyncCodex:FireClient(player, playerData.CodexUnlocked or {})
    end
    
    -- print("[PlayerService] Joueur initialisé: " .. player.Name)
end

--[[
    Appelé quand un joueur quitte
    @param player: Player
]]
function PlayerService:OnPlayerLeave(player)
    -- print("[PlayerService] Joueur quitte: " .. player.Name)
    
    -- 1. Libérer la base (Phase 2)
    if self.BaseSystem then
        self.BaseSystem:ReleaseBase(player)
    end
    
    -- 2. Sauvegarder les données
    DataService:SavePlayerData(player)
    
    -- 3. Nettoyer le cache DataService
    DataService:CleanupPlayer(player)
    
    -- 4. Nettoyer les données runtime
    self._runtimeData[player.UserId] = nil
    
    -- print("[PlayerService] Joueur nettoyé: " .. player.Name)
end

--[[
    Appelé quand le personnage d'un joueur spawn
    @param player: Player
    @param character: Model
]]
function PlayerService:OnCharacterAdded(player, character)
    -- print("[PlayerService] Personnage spawné: " .. player.Name)
    
    -- Attendre que le Humanoid soit prêt
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Connecter l'événement de mort
    humanoid.Died:Connect(function()
        self:OnPlayerDied(player)
    end)
    
    -- Assigner une base si pas encore fait (Phase 2)
    -- Utiliser self.BaseSystem car il est injecté après Init()
    if self.BaseSystem then
        -- print("[PlayerService] BaseSystem trouvé, assignation de base...")
        local runtimeData = self._runtimeData[player.UserId]
        
        -- Si pas de base assignée, en assigner une
        if not runtimeData or not runtimeData.AssignedBase then
            -- print("[PlayerService] Assignation de base pour " .. player.Name)
            local base = self.BaseSystem:AssignBase(player)
            
            if not base then
                warn("[PlayerService] Impossible d'assigner une base à " .. player.Name)
                -- Ne pas kick, juste laisser au spawn par défaut
            end
        end
        
        -- Téléporter à la base
        task.wait(0.5) -- Attendre que le personnage soit complètement chargé
        self.BaseSystem:SpawnPlayerAtBase(player)
        -- Réappliquer la visibilité des étages et des slots débloqués (OwnedSlots est sauvegardé)
        self.BaseSystem:ApplyFloorVisibility(player)
        self.BaseSystem:ApplySlotVisibility(player)
        
        -- Recréer les Brainrots sauvegardés (Phase 5.5)
        if self.BrainrotModelSystem then
            task.wait(0.5) -- Délai plus long pour que la base soit complètement prête
            local playerData = DataService:GetPlayerData(player)
            
            print("[PlayerService] === RESTAURATION BRAINROTS ===")
            print("[PlayerService] PlacedBrainrots:", playerData.PlacedBrainrots)
            print("[PlayerService] Brainrots:", playerData.Brainrots)
            
            if playerData and playerData.PlacedBrainrots then
                local brainrotCount = 0
                for _ in pairs(playerData.PlacedBrainrots) do
                    brainrotCount = brainrotCount + 1
                end
                
                if brainrotCount > 0 then
                    print("[PlayerService] Recréation de " .. brainrotCount .. " Brainrot(s) pour " .. player.Name)
                    
                    for slotIndex, brainrotData in pairs(playerData.PlacedBrainrots) do
                        print("[PlayerService] Slot " .. slotIndex .. " data:", brainrotData)
                        if brainrotData.HeadSet and brainrotData.BodySet and brainrotData.LegsSet then
                            print("[PlayerService] Recréation Brainrot slot " .. slotIndex .. ": " .. brainrotData.HeadSet .. " + " .. brainrotData.BodySet .. " + " .. brainrotData.LegsSet)
                            
                            local success = self.BrainrotModelSystem:CreateBrainrotModel(player, tonumber(slotIndex), brainrotData)
                            if success then
                                print("[PlayerService] ✓ Brainrot slot " .. slotIndex .. " recréé avec succès")
                            else
                                warn("[PlayerService] ✗ Échec recréation Brainrot slot " .. slotIndex)
                            end
                        else
                            warn("[PlayerService] Brainrot incomplet slot " .. slotIndex)
                        end
                    end
                else
                    print("[PlayerService] Pas de Brainrots à recréer pour " .. player.Name)
                end
            else
                print("[PlayerService] Pas de PlacedBrainrots pour " .. player.Name)
            end
        else
            warn("[PlayerService] BrainrotModelSystem non disponible pour recréation")
        end
    else
        -- print("[PlayerService] BaseSystem non disponible, pas de téléportation")
    end
end

--[[
    Appelé quand un joueur meurt
    @param player: Player
]]
function PlayerService:OnPlayerDied(player)
    -- print("[PlayerService] Joueur mort: " .. player.Name)
    
    -- Vider les pièces en main (elles sont perdues)
    local runtimeData = self._runtimeData[player.UserId]
    if runtimeData then
        local lostPieces = #runtimeData.PiecesInHand
        runtimeData.PiecesInHand = {}
        
        if lostPieces > 0 then
            -- print("[PlayerService] " .. player.Name .. " a perdu " .. lostPieces .. " pièces")
            
            -- Envoyer notification au client
            local remotes = NetworkSetup:GetAllRemotes()
            if remotes.SyncInventory then
                remotes.SyncInventory:FireClient(player, {})
            end
            if remotes.Notification then
                remotes.Notification:FireClient(player, {
                    Type = "Warning",
                    Message = "You died! " .. lostPieces .. " piece(s) lost.",
                    Duration = 3,
                })
            end
        end
    end
    
    -- Incrémenter les stats de mort
    DataService:IncrementValue(player, "Stats.TotalDeaths", 1)
end

--[[
    Récupère les données runtime d'un joueur
    @param player: Player
    @return RuntimeData | nil
]]
function PlayerService:GetRuntimeData(player)
    return self._runtimeData[player.UserId]
end

--[[
    Ajoute une pièce à l'inventaire runtime du joueur
    @param player: Player
    @param pieceData: table - {SetName, PieceType, Price, DisplayName}
    @return boolean
]]
function PlayerService:AddPieceToHand(player, pieceData)
    local runtimeData = self._runtimeData[player.UserId]
    if not runtimeData then return false end
    
    table.insert(runtimeData.PiecesInHand, pieceData)
    return true
end

--[[
    Vide les pièces en main d'un joueur
    @param player: Player
    @return table - Les pièces retirées
]]
function PlayerService:ClearPiecesInHand(player)
    local runtimeData = self._runtimeData[player.UserId]
    if not runtimeData then return {} end
    
    local pieces = runtimeData.PiecesInHand
    runtimeData.PiecesInHand = {}
    return pieces
end

--[[
    Récupère les pièces en main d'un joueur
    @param player: Player
    @return table
]]
function PlayerService:GetPiecesInHand(player)
    local runtimeData = self._runtimeData[player.UserId]
    if not runtimeData then return {} end
    
    return runtimeData.PiecesInHand
end

return PlayerService
