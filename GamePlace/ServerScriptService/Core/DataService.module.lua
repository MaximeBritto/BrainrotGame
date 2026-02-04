--[[
    DataService.lua
    Gestion des données joueur avec DataStore
    
    Responsabilités:
    - Charger/Sauvegarder les données dans DataStore
    - Maintenir un cache en mémoire
    - Gérer les migrations de données
    - Auto-save périodique
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Config = ReplicatedStorage:WaitForChild("Config")
local Data = ReplicatedStorage:WaitForChild("Data")

local GameConfig = require(Config["GameConfig.module"])
local DefaultPlayerData = require(Data["DefaultPlayerData.module"])

-- DataStore (désactivé en Studio si pas de API access)
local dataStore = nil
local isStudio = RunService:IsStudio()

local DataService = {}
DataService._cache = {} -- {[userId] = playerData}
DataService._initialized = false

-- Événements internes (BindableEvents)
DataService.OnPlayerDataLoaded = Instance.new("BindableEvent")
DataService.OnPlayerDataSaved = Instance.new("BindableEvent")
DataService.OnDataError = Instance.new("BindableEvent")

--[[
    Initialise le DataStore
    @param services: table (optionnel) - { NetworkSetup = ... } pour Phase 6 (SyncCodex)
]]
function DataService:Init(services)
    if self._initialized then
        warn("[DataService] Déjà initialisé!")
        return
    end
    
    print("[DataService] Initialisation...")
    
    -- Phase 6: stocker NetworkSetup pour SyncCodex après UnlockCodexEntry
    if services and services.NetworkSetup then
        self._networkSetup = services.NetworkSetup
    end
    
    -- Tenter de créer le DataStore
    local success, result = pcall(function()
        return DataStoreService:GetDataStore(GameConfig.DataStore.Name)
    end)
    
    if success then
        dataStore = result
        print("[DataService] DataStore connecté: " .. GameConfig.DataStore.Name)
    else
        warn("[DataService] Impossible de créer DataStore: " .. tostring(result))
        warn("[DataService] Mode hors-ligne activé (données non persistantes)")
    end
    
    -- Démarrer l'auto-save
    self:_StartAutoSave()
    
    self._initialized = true
    print("[DataService] Initialisé!")
end

--[[
    Charge les données d'un joueur
    @param player: Player
    @return table | nil
]]
function DataService:LoadPlayerData(player)
    local userId = player.UserId
    local key = "Player_" .. userId
    
    print("[DataService] Chargement des données pour " .. player.Name .. " (ID: " .. userId .. ")")
    
    -- Tenter de charger depuis DataStore
    local data = nil
    
    if dataStore then
        for attempt = 1, GameConfig.DataStore.RetryAttempts do
            local success, result = pcall(function()
                return dataStore:GetAsync(key)
            end)
            
            if success then
                data = result
                break
            else
                warn("[DataService] Tentative " .. attempt .. "/" .. GameConfig.DataStore.RetryAttempts .. " échouée: " .. tostring(result))
                
                if attempt < GameConfig.DataStore.RetryAttempts then
                    task.wait(GameConfig.DataStore.RetryDelay)
                end
            end
        end
    end
    
    -- Si pas de données, utiliser les données par défaut
    if data == nil then
        print("[DataService] Nouveau joueur ou données vides, utilisation des défauts")
        data = self:_DeepCopy(DefaultPlayerData)
    else
        -- Appliquer les migrations si nécessaire
        data = self:_MigrateData(data)
    end
    
    -- Mettre en cache
    self._cache[userId] = data
    
    print("[DataService] Données chargées pour " .. player.Name)
    self.OnPlayerDataLoaded:Fire(player, data)
    
    return data
end

--[[
    Sauvegarde les données d'un joueur
    @param player: Player
    @return boolean
]]
function DataService:SavePlayerData(player)
    local userId = player.UserId
    local key = "Player_" .. userId
    local data = self._cache[userId]
    
    if not data then
        warn("[DataService] Pas de données en cache pour " .. player.Name)
        return false
    end
    
    print("[DataService] Sauvegarde des données pour " .. player.Name)
    
    if not dataStore then
        print("[DataService] Mode hors-ligne, sauvegarde ignorée")
        return true -- Pas d'erreur, juste pas de DataStore
    end
    
    -- Tenter de sauvegarder
    for attempt = 1, GameConfig.DataStore.RetryAttempts do
        local success, result = pcall(function()
            dataStore:SetAsync(key, data)
        end)
        
        if success then
            print("[DataService] Données sauvegardées pour " .. player.Name)
            self.OnPlayerDataSaved:Fire(player)
            return true
        else
            warn("[DataService] Tentative sauvegarde " .. attempt .. "/" .. GameConfig.DataStore.RetryAttempts .. " échouée: " .. tostring(result))
            
            if attempt < GameConfig.DataStore.RetryAttempts then
                task.wait(GameConfig.DataStore.RetryDelay)
            end
        end
    end
    
    warn("[DataService] ÉCHEC SAUVEGARDE pour " .. player.Name)
    self.OnDataError:Fire(player, "Échec de sauvegarde après " .. GameConfig.DataStore.RetryAttempts .. " tentatives")
    return false
end

--[[
    Récupère les données en cache d'un joueur
    @param player: Player
    @return table | nil
]]
function DataService:GetPlayerData(player)
    return self._cache[player.UserId]
end

--[[
    Met à jour une valeur dans les données du joueur
    @param player: Player
    @param key: string - Clé à modifier (supporte "Stats.TotalCrafts" format)
    @param value: any
    @return boolean
]]
function DataService:UpdateValue(player, key, value)
    local data = self._cache[player.UserId]
    
    if not data then
        warn("[DataService] Pas de données pour " .. player.Name)
        return false
    end
    
    -- Gérer les clés imbriquées (ex: "Stats.TotalCrafts")
    local keys = string.split(key, ".")
    local current = data
    
    for i = 1, #keys - 1 do
        current = current[keys[i]]
        if not current then
            warn("[DataService] Clé invalide: " .. key)
            return false
        end
    end
    
    current[keys[#keys]] = value
    return true
end

--[[
    Incrémente une valeur numérique
    @param player: Player
    @param key: string
    @param amount: number
    @return number - Nouvelle valeur
]]
function DataService:IncrementValue(player, key, amount)
    local data = self._cache[player.UserId]
    
    if not data then
        warn("[DataService] Pas de données pour " .. player.Name)
        return 0
    end
    
    -- Gérer les clés imbriquées
    local keys = string.split(key, ".")
    local current = data
    
    for i = 1, #keys - 1 do
        current = current[keys[i]]
        if not current then
            warn("[DataService] Clé invalide: " .. key)
            return 0
        end
    end
    
    local finalKey = keys[#keys]
    local currentValue = current[finalKey] or 0
    local newValue = currentValue + amount
    current[finalKey] = newValue
    
    return newValue
end

--[[
    Nettoie les données d'un joueur (quand il quitte)
    @param player: Player
]]
function DataService:CleanupPlayer(player)
    self._cache[player.UserId] = nil
    print("[DataService] Cache nettoyé pour " .. player.Name)
end

--[[
    Migration des données si la version change
    @param data: table
    @return table - Données migrées
]]
function DataService:_MigrateData(data)
    local currentVersion = data.Version or 1
    local latestVersion = DefaultPlayerData.Version
    
    if currentVersion >= latestVersion then
        return data -- Pas de migration nécessaire
    end
    
    print("[DataService] Migration des données de v" .. currentVersion .. " vers v" .. latestVersion)
    
    -- Ajouter les nouvelles clés manquantes
    for key, value in pairs(DefaultPlayerData) do
        if data[key] == nil then
            data[key] = self:_DeepCopy(value)
            print("[DataService] Ajout de la clé manquante: " .. key)
        end
    end
    
    -- Mettre à jour la version
    data.Version = latestVersion
    
    return data
end

--[[
    Copie profonde d'une table
    @param original: table
    @return table
]]
function DataService:_DeepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = self:_DeepCopy(value)
    end
    
    return copy
end

--[[
    Démarre la boucle d'auto-save
]]
function DataService:_StartAutoSave()
    task.spawn(function()
        while true do
            task.wait(GameConfig.DataStore.AutoSaveInterval)
            
            print("[DataService] Auto-save en cours...")
            
            for _, player in ipairs(Players:GetPlayers()) do
                if self._cache[player.UserId] then
                    self:SavePlayerData(player)
                end
            end
            
            print("[DataService] Auto-save terminé")
        end
    end)
    
    print("[DataService] Auto-save démarré (intervalle: " .. GameConfig.DataStore.AutoSaveInterval .. "s)")
end

--[[
    Débloque une partie du Codex (Head, Body ou Legs)
    @param player: Player
    @param setName: string
    @param partType: string - "Head", "Body" ou "Legs"
    @return boolean
]]
function DataService:UnlockCodexPart(player, setName, partType)
    local playerData = self:GetPlayerData(player)
    if not playerData then return false end
    if not playerData.CodexUnlocked then playerData.CodexUnlocked = {} end

    local setData = playerData.CodexUnlocked[setName]
    if type(setData) == "boolean" then
        setData = {Head = true, Body = true, Legs = true}
        playerData.CodexUnlocked[setName] = setData
    elseif not setData then
        setData = {Head = false, Body = false, Legs = false}
        playerData.CodexUnlocked[setName] = setData
    end

    if setData[partType] then
        return false
    end
    setData[partType] = true
    self:_SendCodexToClient(player)
    return true
end

--[[
    Débloque tout un set du Codex (Head + Body + Legs) - ex. après un craft
    @param player: Player
    @param setName: string
    @return boolean
]]
function DataService:UnlockCodexEntry(player, setName)
    local playerData = self:GetPlayerData(player)
    if not playerData then
        warn("[DataService] Impossible de débloquer Codex: données introuvables")
        return false
    end
    
    if not playerData.CodexUnlocked then
        playerData.CodexUnlocked = {}
    end
    
    local setData = playerData.CodexUnlocked[setName]
    if type(setData) == "table" and setData.Head and setData.Body and setData.Legs then
        return false
    end
    if type(setData) == "boolean" and setData then
        return false
    end
    
    playerData.CodexUnlocked[setName] = {Head = true, Body = true, Legs = true}
    print("[DataService] Codex débloqué: " .. player.Name .. " - " .. setName .. " (3/3)")
    self:_SendCodexToClient(player)
    return true
end

function DataService:_SendCodexToClient(player)
    local playerData = self:GetPlayerData(player)
    if not playerData then return end
    if self._codexService then
        self._codexService:SendCodexToPlayer(player)
    elseif self._networkSetup then
        local remotes = self._networkSetup:GetAllRemotes()
        if remotes and remotes.SyncCodex then
            remotes.SyncCodex:FireClient(player, playerData.CodexUnlocked)
        end
    end
end

--[[
    Phase 6: Injecte CodexService pour centraliser l'envoi SyncCodex
    @param codexService: CodexService module
]]
function DataService:SetCodexService(codexService)
    self._codexService = codexService
end

return DataService
