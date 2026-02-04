--[[
    CodexService.module.lua
    Phase 6 - Centralise l'envoi du Codex au client
    
    Responsabilités:
    - SendCodexToPlayer(player) : envoie SyncCodex au client avec CodexUnlocked
    - Utilisé à la connexion (PlayerService) et après UnlockCodexEntry (DataService)
]]

local DataService = nil
local NetworkSetup = nil

local CodexService = {}
CodexService._initialized = false

--[[
    Initialise le service
    @param services: table - { DataService, NetworkSetup }
]]
function CodexService:Init(services)
    if self._initialized then
        warn("[CodexService] Déjà initialisé!")
        return
    end
    
    print("[CodexService] Initialisation...")
    
    DataService = services.DataService
    NetworkSetup = services.NetworkSetup
    
    if not DataService or not NetworkSetup then
        error("[CodexService] DataService et NetworkSetup requis!")
    end
    
    self._initialized = true
    print("[CodexService] Initialisé")
end

--[[
    Envoie le Codex au client
    @param player: Player
]]
function CodexService:SendCodexToPlayer(player)
    if not DataService or not NetworkSetup then
        warn("[CodexService] Non initialisé, impossible d'envoyer le Codex")
        return
    end
    
    local playerData = DataService:GetPlayerData(player)
    if not playerData then
        warn("[CodexService] Données introuvables pour " .. player.Name)
        return
    end
    
    local codexUnlocked = playerData.CodexUnlocked or {}
    local remotes = NetworkSetup:GetAllRemotes()
    
    if remotes and remotes.SyncCodex then
        remotes.SyncCodex:FireClient(player, codexUnlocked)
    end
end

return CodexService
