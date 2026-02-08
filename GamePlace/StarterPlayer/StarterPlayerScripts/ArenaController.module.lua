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

local ArenaController = {}
local _remotes = nil
local _inventory = {} -- Cache local des pièces en main
local _connectedPrompts = {} -- Pour éviter les connexions multiples

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
    
    -- print("[ArenaController] Initialisé!")
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
        
        -- Trouver le PickupZone (dans le PrimaryPart)
        local pickupZone = nil
        if piece.PrimaryPart then
            pickupZone = piece.PrimaryPart:FindFirstChild("PickupZone")
        end
        
        if not pickupZone then
            warn("[ArenaController] PickupZone manquant dans:", piece.Name)
            return
        end
        
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
