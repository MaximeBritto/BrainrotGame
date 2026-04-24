--[[
    ArenaController.module.lua
    Contrôleur client pour l'arène et le pickup de pièces
    
    Responsabilités:
    - Écouter les ProximityPrompts des pièces
    - Envoyer les requêtes de pickup au serveur
    - Gérer l'inventaire local (cache)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ArenaController = {}
local _remotes = nil
local _inventory = {} -- Cache local des pièces en main
local _connectedPrompts = {} -- Pour éviter les connexions multiples
local _blinkState = {} -- [piece] = {parts = {[BasePart] = originalT}, phase = number}

local BLINK_THRESHOLD = 10 -- secondes avant despawn où le clignotement commence
local BLINK_MIN_FREQ = 2   -- Hz au début du seuil
local BLINK_MAX_FREQ = 12  -- Hz à la fin (juste avant despawn)

--[[
    Initialise le contrôleur
]]
function ArenaController:Init()
    -- print("[ArenaController] Initialisation...")
    
    -- Récupérer les remotes
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not remotesFolder then
        warn("[ArenaController] Remotes folder introuvable!")
        return
    end
    
    _remotes = {
        PickupPiece = remotesFolder:WaitForChild("PickupPiece", 5),
        DropPieces = remotesFolder:WaitForChild("DropPieces", 5),
        SyncInventory = remotesFolder:WaitForChild("SyncInventory", 5),
    }
    
    if not _remotes.PickupPiece or not _remotes.SyncInventory then
        warn("[ArenaController] Remotes manquants!")
        return
    end
    
    -- Écouter SyncInventory du serveur
    _remotes.SyncInventory.OnClientEvent:Connect(function(pieces)
        self:_OnInventorySync(pieces)
    end)
    
    -- Connecter les pièces existantes et futures
    self:_ConnectActivePieces()

    -- Démarrer la boucle de clignotement d'expiration
    self:_StartBlinkLoop()

    -- print("[ArenaController] Initialisé!")
end

--[[
    Récupère (et cache) l'état de clignotement d'une pièce :
    liste des parts avec leur transparence d'origine + phase accumulée
]]
function ArenaController:_GetBlinkState(piece)
    local state = _blinkState[piece]
    if state then return state end

    local parts = {}
    for _, d in ipairs(piece:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "PickupZone" then
            parts[d] = d.Transparency
        end
    end
    state = { parts = parts, phase = 0 }
    _blinkState[piece] = state
    return state
end

--[[
    Applique un état visible/invisible sur toutes les parts cachées d'une pièce
]]
function ArenaController:_ApplyPieceVisibility(state, visible)
    for part, originalT in pairs(state.parts) do
        if part.Parent then
            part.Transparency = visible and originalT or 1
        end
    end
end

--[[
    Désactive le ProximityPrompt d'une pièce (pour empêcher le pickup
    pendant la phase finale avant que le serveur ne la détruise)
]]
function ArenaController:_SetPiecePromptEnabled(piece, enabled)
    local primary = piece.PrimaryPart
    if not primary then return end
    local pickupZone = primary:FindFirstChild("PickupZone")
    if not pickupZone then return end
    local prompt = pickupZone:FindFirstChildOfClass("ProximityPrompt")
    if prompt then prompt.Enabled = enabled end
end

--[[
    Boucle de clignotement : rend les pièces clignotantes dans les 10 dernières secondes,
    de plus en plus rapidement à mesure que le temps s'approche de zéro.
    Utilise une phase accumulée pour un clignotement régulier malgré la variation de fréquence.
]]
function ArenaController:_StartBlinkLoop()
    local piecesFolder = Workspace:WaitForChild("ActivePieces", 10)
    if not piecesFolder then return end

    piecesFolder.ChildRemoved:Connect(function(piece)
        _blinkState[piece] = nil
    end)

    RunService.Heartbeat:Connect(function(dt)
        for _, piece in ipairs(piecesFolder:GetChildren()) do
            if piece:IsA("Model") then
                local spawnedAt = piece:GetAttribute("SpawnedAt")
                local lifetime = piece:GetAttribute("Lifetime")
                if spawnedAt and lifetime then
                    local remaining = lifetime - (workspace:GetServerTimeNow() - spawnedAt)
                    if remaining <= 0 then
                        -- Expirée : cacher et désactiver le pickup en attendant la destruction serveur
                        local state = self:_GetBlinkState(piece)
                        self:_ApplyPieceVisibility(state, false)
                        self:_SetPiecePromptEnabled(piece, false)
                    elseif remaining < BLINK_THRESHOLD then
                        -- progress : 0 (début du seuil) → 1 (despawn)
                        local progress = 1 - (remaining / BLINK_THRESHOLD)
                        local freq = BLINK_MIN_FREQ + progress * (BLINK_MAX_FREQ - BLINK_MIN_FREQ)
                        local state = self:_GetBlinkState(piece)
                        -- Phase accumulée : freq * 2 demi-périodes/s (on/off)
                        state.phase = state.phase + dt * freq * 2
                        local visible = math.floor(state.phase) % 2 == 0
                        self:_ApplyPieceVisibility(state, visible)
                    elseif _blinkState[piece] then
                        -- Hors zone de clignotement : restaurer visibilité + prompt
                        self:_ApplyPieceVisibility(_blinkState[piece], true)
                        self:_SetPiecePromptEnabled(piece, true)
                    end
                end
            end
        end
    end)
end

--[[
    Connecte les ProximityPrompts des pièces dans l'arène
]]
function ArenaController:_ConnectActivePieces()
    -- Attendre le folder ActivePieces
    local piecesFolder = Workspace:WaitForChild("ActivePieces", 10)
    if not piecesFolder then
        warn("[ArenaController] ActivePieces folder introuvable!")
        return
    end
    
    -- print("[ArenaController] ActivePieces trouvé, connexion des prompts...")
    
    -- Fonction pour connecter un prompt
    local function connectPiecePrompt(piece)
        if not piece:IsA("Model") then return end
        
        -- Éviter les connexions multiples
        if _connectedPrompts[piece] then return end
        
        -- Attendre que le PrimaryPart et le PickupZone soient répliqués
        if not piece.PrimaryPart then
            piece:GetPropertyChangedSignal("PrimaryPart"):Wait()
        end
        if not piece.PrimaryPart then return end

        local pickupZone = piece.PrimaryPart:FindFirstChild("PickupZone")
            or piece.PrimaryPart:WaitForChild("PickupZone", 5)

        if not pickupZone then return end
        
        -- Trouver le ProximityPrompt
        local prompt = pickupZone:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
            warn("[ArenaController] ProximityPrompt manquant dans:", piece.Name)
            return
        end
        
        -- Connecter le Triggered
        local connection = prompt.Triggered:Connect(function(player)
            -- Vérifier que c'est bien le joueur local
            if player ~= Players.LocalPlayer then return end
            
            -- Récupérer le PieceId
            local pieceId = piece:GetAttribute("PieceId")
            if not pieceId then
                warn("[ArenaController] PieceId manquant sur:", piece.Name)
                return
            end
            
            -- print("[ArenaController] Pickup demandé pour:", pieceId)
            
            -- Envoyer au serveur
            _remotes.PickupPiece:FireServer(pieceId)
        end)
        
        -- Stocker la connexion
        _connectedPrompts[piece] = connection
        
        -- -- print("[ArenaController] Prompt connecté pour:", piece.Name)
    end
    
    -- Connecter les pièces déjà présentes
    for _, piece in ipairs(piecesFolder:GetChildren()) do
        connectPiecePrompt(piece)
    end
    
    -- Écouter les nouvelles pièces
    piecesFolder.ChildAdded:Connect(function(piece)
        task.wait(0.1) -- Petit délai pour que la pièce soit complètement chargée
        connectPiecePrompt(piece)
    end)
    
    -- Nettoyer les connexions quand une pièce est supprimée
    piecesFolder.ChildRemoved:Connect(function(piece)
        if _connectedPrompts[piece] then
            _connectedPrompts[piece]:Disconnect()
            _connectedPrompts[piece] = nil
        end
    end)
end

--[[
    Appelé quand le serveur envoie SyncInventory
    @param pieces: table - Liste des pièces en main
]]
function ArenaController:_OnInventorySync(pieces)
    _inventory = pieces or {}
    -- print("[ArenaController] Inventaire synchronisé:", #_inventory, "pièce(s)")
    
    -- TODO: Mettre à jour l'UI (Phase 4 DEV B)
    -- Pour l'instant, juste afficher dans la console
    if #_inventory > 0 then
        -- print("[ArenaController] Pièces en main:")
        for i, piece in ipairs(_inventory) do
            -- print("  " .. i .. ". " .. piece.DisplayName .. " " .. piece.PieceType .. " ($" .. piece.Price .. ")")
        end
    end
end

--[[
    Récupère l'inventaire actuel (cache local)
    @return table
]]
function ArenaController:GetInventory()
    return _inventory
end

--[[
    Lâche toutes les pièces en main
]]
function ArenaController:DropPieces()
    if _remotes.DropPieces then
        _remotes.DropPieces:FireServer()
        -- print("[ArenaController] DropPieces envoyé au serveur")
    end
end

return ArenaController
