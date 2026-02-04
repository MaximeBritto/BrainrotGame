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
local EconomySystem, economyLoadErr
do
    local ok, mod = pcall(function()
        return require(Systems["EconomySystem.module"])
    end)
    if ok then
        EconomySystem = mod
    else
        economyLoadErr = mod
    end
end

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
    EconomySystem = nil, -- Sera ajouté après
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
NetworkHandler:UpdateSystems({BaseSystem = BaseSystem})

-- 6. DoorSystem (Phase 2)
DoorSystem:Init({
    BaseSystem = BaseSystem,
    PlayerService = PlayerService,
    NetworkSetup = NetworkSetup,
})
print("[GameServer] DoorSystem: OK")

-- 6.1. Injecter DoorSystem dans NetworkHandler
NetworkHandler:UpdateSystems({DoorSystem = DoorSystem})

-- 7. EconomySystem (Phase 3) - optionnel si le chargement a échoué
if EconomySystem then
    EconomySystem:Init({
        DataService = DataService,
        PlayerService = PlayerService,
        NetworkSetup = NetworkSetup,
        BaseSystem = BaseSystem,
    })
    print("[GameServer] EconomySystem: OK")
    NetworkHandler:UpdateSystems({EconomySystem = EconomySystem})
else
    warn("[GameServer] EconomySystem non chargé (Phase 3 désactivée):", economyLoadErr or "inconnu")
end

-- 8. CollectPad : collecte au toucher (marcher dessus, pas besoin de E)
if EconomySystem and BaseSystem then
    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    local BASES = "Bases"
    local SLOTS = "Slots"
    local COLLECT_PAD = "CollectPad"
    local DEBOUNCE_SEC = 1.5
    local _debounce = {}

    local function getSlotIndex(pad)
        local slot = pad.Parent
        if not slot then return nil end
        local n = slot.Name:match("^Slot_(%d+)$")
        return n and tonumber(n) or nil
    end

    local function getBase(pad)
        local slot = pad.Parent
        if not slot then return nil end
        local folder = slot.Parent
        if not folder or folder.Name ~= SLOTS then return nil end
        return folder.Parent
    end

    local function getOwner(base)
        for userId, assignment in pairs(BaseSystem._assignedBases) do
            if assignment.Base == base then
                return Players:GetPlayerByUserId(userId)
            end
        end
        return nil
    end

    local function onTouched(pad, hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char or not char:FindFirstChild("Humanoid") then return end
        local player = Players:GetPlayerFromCharacter(char)
        if not player then return end
        local base = getBase(pad)
        if not base then return end
        if getOwner(base) ~= player then return end
        local slotIndex = getSlotIndex(pad)
        if not slotIndex then return end

        local key = player.UserId .. "_" .. slotIndex
        if _debounce[key] and (tick() - _debounce[key]) < DEBOUNCE_SEC then return end
        _debounce[key] = tick()

        local amount = EconomySystem:CollectSlotCash(player, slotIndex)
        if amount > 0 then
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes then
                local notif = remotes:FindFirstChild("Notification")
                if notif then
                    notif:FireClient(player, { Type = "Success", Message = "+$" .. amount .. " collected!", Duration = 2 })
                end
            end
        end
    end

    local basesFolder = Workspace:FindFirstChild(BASES)
    if basesFolder then
        for _, base in ipairs(basesFolder:GetChildren()) do
            if base:IsA("Model") then
                local slotsFolder = base:FindFirstChild(SLOTS)
                if slotsFolder then
                    for _, slot in ipairs(slotsFolder:GetChildren()) do
                        local pad = slot:FindFirstChild(COLLECT_PAD)
                        if pad and pad:IsA("BasePart") then
                            pad.Touched:Connect(function(hit) onTouched(pad, hit) end)
                        end
                    end
                end
            end
        end
        print("[GameServer] CollectPads: collecte au toucher activée (marcher dessus)")
    end
end

-- 9. Autres systèmes (sera ajouté en Phase 4+)
-- ArenaSystem:Init({...})
-- ...

-- ═══════════════════════════════════════════════════════
-- TERMINÉ
-- ═══════════════════════════════════════════════════════

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Serveur prêt!")
print("═══════════════════════════════════════════════")
