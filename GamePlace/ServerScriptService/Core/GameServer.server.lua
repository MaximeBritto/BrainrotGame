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

-- Phase 4: Arena & Inventory
local ArenaSystem, arenaLoadErr
local InventorySystem, inventoryLoadErr
do
    local ok, mod = pcall(function()
        return require(Systems["ArenaSystem.module"])
    end)
    if ok then
        ArenaSystem = mod
    else
        arenaLoadErr = mod
    end
end
do
    local ok, mod = pcall(function()
        return require(Systems["InventorySystem.module"])
    end)
    if ok then
        InventorySystem = mod
    else
        inventoryLoadErr = mod
    end
end

-- Phase 5: Crafting & Placement
local CraftingSystem, craftingLoadErr
local PlacementSystem, placementLoadErr
local BrainrotModelSystem, brainrotModelLoadErr
do
    local ok, mod = pcall(function()
        return require(Systems["CraftingSystem.module"])
    end)
    if ok then
        CraftingSystem = mod
    else
        craftingLoadErr = mod
    end
end
do
    local ok, mod = pcall(function()
        return require(Systems["PlacementSystem.module"])
    end)
    if ok then
        PlacementSystem = mod
    else
        placementLoadErr = mod
    end
end

-- Phase 5.5: Brainrot Models
do
    local ok, mod = pcall(function()
        return require(Systems["BrainrotModelSystem.module"])
    end)
    if ok then
        BrainrotModelSystem = mod
    else
        brainrotModelLoadErr = mod
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

-- 9. ArenaSystem & InventorySystem (Phase 4)
if ArenaSystem and InventorySystem then
    ArenaSystem:Init()
    print("[GameServer] ArenaSystem: OK")
    
    InventorySystem:Init({
        PlayerService = PlayerService,
        ArenaSystem = ArenaSystem,
    })
    print("[GameServer] InventorySystem: OK")
    
    NetworkHandler:UpdateSystems({
        ArenaSystem = ArenaSystem,
        InventorySystem = InventorySystem,
    })
else
    if not ArenaSystem then
        warn("[GameServer] ArenaSystem non chargé:", arenaLoadErr or "inconnu")
    end
    if not InventorySystem then
        warn("[GameServer] InventorySystem non chargé:", inventoryLoadErr or "inconnu")
    end
end

-- 10. Spinner Kill (Phase 4) - Mort au contact de la barre
if ArenaSystem then
    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    
    local arena = Workspace:FindFirstChild("Arena")
    if arena then
        local spinner = arena:FindFirstChild("Spinner")
        if spinner then
            -- Trouver la barre mortelle (attribut Deadly = true)
            local bar = spinner:FindFirstChild("Bar")
            if bar and bar:IsA("BasePart") and bar:GetAttribute("Deadly") == true then
                local debounce = {}
                
                bar.Touched:Connect(function(hit)
                    local character = hit:FindFirstAncestorOfClass("Model")
                    if not character then return end
                    
                    local humanoid = character:FindFirstChild("Humanoid")
                    if not humanoid or humanoid.Health <= 0 then return end
                    
                    local player = Players:GetPlayerFromCharacter(character)
                    if not player then return end
                    
                    -- Debounce pour éviter de tuer plusieurs fois
                    if debounce[player.UserId] then return end
                    debounce[player.UserId] = true
                    
                    -- Tuer le joueur
                    humanoid.Health = 0
                    print("[GameServer] " .. player.Name .. " tué par le Spinner")
                    
                    -- Réinitialiser le debounce après 3 secondes
                    task.delay(3, function()
                        debounce[player.UserId] = nil
                    end)
                end)
                
                print("[GameServer] Spinner Kill: activé (Bar.Deadly = true)")
            else
                warn("[GameServer] Spinner Bar manquante ou attribut Deadly non défini")
            end
        else
            warn("[GameServer] Spinner manquant dans Arena")
        end
    else
        warn("[GameServer] Arena manquante dans Workspace")
    end
end

-- 11. CraftingSystem & PlacementSystem (Phase 5)
if CraftingSystem and PlacementSystem then
    -- Phase 5.5: BrainrotModelSystem
    if BrainrotModelSystem then
        BrainrotModelSystem:Init({
            BaseSystem = BaseSystem,
        })
        print("[GameServer] BrainrotModelSystem: OK")
        
        -- Injecter dans PlayerService pour la recréation au spawn
        PlayerService.BrainrotModelSystem = BrainrotModelSystem
    else
        warn("[GameServer] BrainrotModelSystem non chargé:", brainrotModelLoadErr or "inconnu")
    end
    
    PlacementSystem:Init({
        DataService = DataService,
        PlayerService = PlayerService,
        BaseSystem = BaseSystem,
        BrainrotModelSystem = BrainrotModelSystem,
    })
    print("[GameServer] PlacementSystem: OK")
    
    CraftingSystem:Init({
        DataService = DataService,
        PlayerService = PlayerService,
        InventorySystem = InventorySystem,
        PlacementSystem = PlacementSystem,
    })
    print("[GameServer] CraftingSystem: OK")
    
    NetworkHandler:UpdateSystems({
        CraftingSystem = CraftingSystem,
        PlacementSystem = PlacementSystem,
    })
else
    if not CraftingSystem then
        warn("[GameServer] CraftingSystem non chargé:", craftingLoadErr or "inconnu")
    end
    if not PlacementSystem then
        warn("[GameServer] PlacementSystem non chargé:", placementLoadErr or "inconnu")
    end
end

-- 12. Autres systèmes (Phase 6+)
-- ...

-- ═══════════════════════════════════════════════════════
-- TERMINÉ
-- ═══════════════════════════════════════════════════════

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Serveur prêt!")
print("═══════════════════════════════════════════════")
