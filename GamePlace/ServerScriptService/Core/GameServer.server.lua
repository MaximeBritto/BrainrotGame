--[[
    GameServer.lua
    Point d'entrée principal du serveur
    
    Ce script initialise tous les services et systèmes dans le bon ordre
    C'est LE SEUL Script (pas ModuleScript) côté serveur
]]

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Démarrage du serveur")
print("═══════════════════════════════════════════════")

-- Attendre que tout soit chargé (évite les "Infinite yield")
task.wait(0.5)

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ═══════════════════════════════════════════════════════
-- PHASE 1 : Charger les modules Core
-- ═══════════════════════════════════════════════════════

local Core = ServerScriptService:WaitForChild("Core")

-- NetworkSetup DOIT être initialisé en premier (crée les Remotes)
local NetworkSetup = require(Core["NetworkSetup.module"])

-- Services Core
local DataService = require(Core["DataService.module"])
local PlayerService = require(Core["PlayerService.module"])

-- ═══════════════════════════════════════════════════════
-- PHASE 2 : Charger les handlers
-- ═══════════════════════════════════════════════════════

local Handlers = ServerScriptService:WaitForChild("Handlers")
local NetworkHandler = require(Handlers["NetworkHandler.module"])

-- ═══════════════════════════════════════════════════════
-- PHASE 3 : Charger les systèmes
-- ═══════════════════════════════════════════════════════

local Systems = ServerScriptService:WaitForChild("Systems")
local BaseSystem = require(Systems["BaseSystem.module"])
local DoorSystem = require(Systems["DoorSystem.module"])

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

print("[GameServer] Initialisation des services...")

-- 1. NetworkSetup (crée les RemoteEvents/Functions)
local remotesFolder = NetworkSetup:Init()
print("[GameServer] NetworkSetup: OK")

-- 2. DataService (gestion DataStore)
DataService:Init()
print("[GameServer] DataService: OK")

-- 3. PlayerService (gestion connexion/déconnexion)
PlayerService:Init({
    DataService = DataService,
    NetworkSetup = NetworkSetup,
    BaseSystem = nil, -- Sera initialisé après
})
print("[GameServer] PlayerService: OK (sans BaseSystem)")

-- 4. NetworkHandler
NetworkHandler:Init({
    NetworkSetup = NetworkSetup,
    DataService = DataService,
    PlayerService = PlayerService,
    BaseSystem = nil, -- Sera ajouté après
    DoorSystem = nil, -- Sera ajouté après
})
print("[GameServer] NetworkHandler: OK (sans systèmes)")

-- 5. BaseSystem (Phase 2)
BaseSystem:Init({
    DataService = DataService,
    PlayerService = PlayerService,
    NetworkSetup = NetworkSetup,
})
print("[GameServer] BaseSystem: OK")

-- 5.1. Injecter BaseSystem dans PlayerService et NetworkHandler
PlayerService.BaseSystem = BaseSystem
NetworkHandler.BaseSystem = BaseSystem

-- 6. DoorSystem (Phase 2)
DoorSystem:Init({
    BaseSystem = BaseSystem,
    PlayerService = PlayerService,
    NetworkSetup = NetworkSetup,
})
print("[GameServer] DoorSystem: OK")

-- 6.1. Injecter DoorSystem dans NetworkHandler
NetworkHandler.DoorSystem = DoorSystem

-- 7. Autres systèmes (sera ajouté en Phase 3+)
-- EconomySystem:Init({...})
-- ...

-- ═══════════════════════════════════════════════════════
-- TERMINÉ
-- ═══════════════════════════════════════════════════════

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Serveur prêt!")
print("═══════════════════════════════════════════════")
