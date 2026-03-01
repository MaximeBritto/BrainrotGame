--[[
    FusionSystem.module.lua
    Tracking des fusions uniques et récompenses de paliers

    Responsabilités:
    - Enregistrer chaque combinaison HeadSet+BodySet+LegsSet unique
    - Compter les fusions découvertes
    - Gérer les récompenses de paliers (Cash, Multiplier permanent)
    - Synchroniser les données fusion vers le client
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = nil
local DataService = nil
local NetworkSetup = nil
local EconomySystem = nil

local FusionSystem = {}
FusionSystem._initialized = false

function FusionSystem:Init(services)
    if self._initialized then
        warn("[FusionSystem] Déjà initialisé!")
        return
    end

    DataService = services.DataService
    NetworkSetup = services.NetworkSetup
    EconomySystem = services.EconomySystem

    if not DataService or not NetworkSetup then
        error("[FusionSystem] Services manquants!")
    end

    local Config = ReplicatedStorage:WaitForChild("Config")
    GameConfig = require(Config:WaitForChild("GameConfig.module"))

    self._initialized = true
end

--[[
    Génère la clé unique pour une fusion
    @param headSet: string
    @param bodySet: string
    @param legsSet: string
    @return string
]]
function FusionSystem:_GetFusionKey(headSet, bodySet, legsSet)
    return headSet .. "_" .. bodySet .. "_" .. legsSet
end

--[[
    Enregistre une nouvelle fusion après un craft
    @param player: Player
    @param headSet: string
    @param bodySet: string
    @param legsSet: string
    @return boolean - true si c'est une NOUVELLE fusion
]]
function FusionSystem:RecordFusion(player, headSet, bodySet, legsSet)
    if not self._initialized then return false end

    local playerData = DataService:GetPlayerData(player)
    if not playerData then return false end

    if not playerData.DiscoveredFusions then
        playerData.DiscoveredFusions = {}
    end

    local key = self:_GetFusionKey(headSet, bodySet, legsSet)
    if playerData.DiscoveredFusions[key] then
        return false -- Déjà connue
    end

    playerData.DiscoveredFusions[key] = true
    self:SendFusionData(player)
    return true
end

--[[
    Compte le nombre de fusions uniques d'un joueur
    @param player: Player
    @return number
]]
function FusionSystem:GetFusionCount(player)
    local playerData = DataService:GetPlayerData(player)
    if not playerData or not playerData.DiscoveredFusions then return 0 end

    local count = 0
    for _ in pairs(playerData.DiscoveredFusions) do
        count = count + 1
    end
    return count
end

--[[
    Réclame une récompense de palier
    @param player: Player
    @param milestoneIndex: number
    @return boolean - true si réussi
]]
function FusionSystem:ClaimReward(player, milestoneIndex)
    if not self._initialized then return false end

    local playerData = DataService:GetPlayerData(player)
    if not playerData then return false end

    local milestones = GameConfig.Fusion and GameConfig.Fusion.Milestones
    if not milestones then return false end

    local milestone = milestones[milestoneIndex]
    if not milestone then return false end

    -- Vérifier pas déjà réclamé
    if not playerData.ClaimedFusionRewards then
        playerData.ClaimedFusionRewards = {}
    end
    if playerData.ClaimedFusionRewards[milestoneIndex] then
        return false
    end

    -- Vérifier le nombre de fusions atteint
    local fusionCount = self:GetFusionCount(player)
    if fusionCount < milestone.Required then
        return false
    end

    -- Donner la récompense
    if milestone.Type == "Cash" and EconomySystem then
        EconomySystem:AddCash(player, milestone.Value)
    elseif milestone.Type == "Multiplier" then
        local currentBonus = playerData.PermanentMultiplierBonus or 0
        DataService:UpdateValue(player, "PermanentMultiplierBonus", currentBonus + milestone.Value)
    end

    -- Marquer comme réclamé
    playerData.ClaimedFusionRewards[milestoneIndex] = true

    -- Sync vers le client
    self:SendFusionData(player)

    return true
end

--[[
    Envoie les données fusion au client
    @param player: Player
]]
function FusionSystem:SendFusionData(player)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return end

    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.SyncFusionData then
        remotes.SyncFusionData:FireClient(player, {
            DiscoveredFusions = playerData.DiscoveredFusions or {},
            ClaimedFusionRewards = playerData.ClaimedFusionRewards or {},
            FusionCount = self:GetFusionCount(player),
        })
    end
end

return FusionSystem
