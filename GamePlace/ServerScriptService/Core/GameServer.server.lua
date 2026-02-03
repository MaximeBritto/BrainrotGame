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
-- PHASE 3 : Charger les systèmes (sera ajouté plus tard)
-- ═══════════════════════════════════════════════════════

-- local Systems = ServerScriptService:WaitForChild("Systems")
-- local BaseSystem = require(Systems:WaitForChild("BaseSystem"))
-- local EconomySystem = require(Systems:WaitForChild("EconomySystem"))
-- ...

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
})
print("[GameServer] PlayerService: OK")

-- 4. NetworkHandler
NetworkHandler:Init({
    NetworkSetup = NetworkSetup,
    DataService = DataService,
    PlayerService = PlayerService,
})
print("[GameServer] NetworkHandler: OK")

-- 5. Systèmes de jeu (sera ajouté en Phase 2+)
-- BaseSystem:Init({...})
-- EconomySystem:Init({...})
-- ...

-- ═══════════════════════════════════════════════════════
-- TERMINÉ
-- ═══════════════════════════════════════════════════════

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Serveur prêt!")
print("═══════════════════════════════════════════════")
