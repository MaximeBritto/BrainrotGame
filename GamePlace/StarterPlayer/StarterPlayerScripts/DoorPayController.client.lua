--[[
    DoorPayController.client.lua (LocalScript)
    Affiche un ProximityPrompt "Open the door" (80 Robux) sur les portes fermées
    des autres joueurs.

    Flux:
    1. Scan toutes les bases toutes les 2 secondes
    2. Si porte fermée + pas notre base → créer ProximityPrompt
    3. Si porte ouverte → détruire le prompt
    4. Quand le joueur active le prompt → fire RequestDoorOpen au serveur
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Constants = require(Shared:WaitForChild("Constants.module"))
local GameConfig = require(Config:WaitForChild("GameConfig.module"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestDoorOpen = Remotes:WaitForChild("RequestDoorOpen")

-- Constantes
local PROMPT_NAME = "DoorOpenPrompt"
local SCAN_INTERVAL = 2
local ROBUX_PRICE = GameConfig.Door.DoorOpenRobux or 80

-- ═══════════════════════════════════════════════════════
-- SCAN DES PORTES
-- ═══════════════════════════════════════════════════════

--[[
    Vérifie si une porte est fermée (barres visibles)
    @param doorFolder: Instance - Le dossier Door d'une base
    @return boolean
]]
local function isDoorClosed(doorFolder)
    local bars = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorBars)
    if not bars then return false end

    for _, part in ipairs(bars:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 0.5 then
            return true
        end
    end

    return false
end

--[[
    Trouve un point d'ancrage pour le ProximityPrompt sur la porte
    @param doorFolder: Instance
    @return BasePart | nil
]]
local function getPromptAnchor(doorFolder)
    -- Préférer _LabelAnchor s'il existe
    local anchor = doorFolder:FindFirstChild("_LabelAnchor")
    if anchor and anchor:IsA("BasePart") then
        return anchor
    end

    -- Sinon utiliser le ActivationPad
    local pad = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorPad)
    if pad and pad:IsA("BasePart") then
        return pad
    end

    -- Dernier recours: première barre
    local bars = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorBars)
    if bars then
        for _, part in ipairs(bars:GetDescendants()) do
            if part:IsA("BasePart") then
                return part
            end
        end
    end

    return nil
end

--[[
    Scan toutes les bases et crée/détruit les prompts selon l'état des portes
]]
local function scanDoors()
    local workspace = game:GetService("Workspace")
    local basesFolder = workspace:FindFirstChild(Constants.WorkspaceNames.BasesFolder)
    if not basesFolder then return end

    for _, base in ipairs(basesFolder:GetChildren()) do
        if base:IsA("Model") and string.match(base.Name, "^Base_%d+$") then
            local ownerUserId = base:GetAttribute("OwnerUserId")

            -- Ignorer sa propre base et les bases sans propriétaire
            if ownerUserId and ownerUserId ~= player.UserId then
                local doorFolder = base:FindFirstChild(Constants.WorkspaceNames.DoorFolder)

                if doorFolder then
                    local anchor = getPromptAnchor(doorFolder)
                    if not anchor then continue end

                    local existingPrompt = anchor:FindFirstChild(PROMPT_NAME)
                    local closed = isDoorClosed(doorFolder)

                    if closed and not existingPrompt then
                        -- Créer le ProximityPrompt
                        local prompt = Instance.new("ProximityPrompt")
                        prompt.Name = PROMPT_NAME
                        prompt.ActionText = "Open the door"
                        prompt.ObjectText = "R$ " .. ROBUX_PRICE
                        prompt.HoldDuration = 0
                        prompt.MaxActivationDistance = 10
                        prompt.RequiresLineOfSight = false
                        prompt.KeyboardKeyCode = Enum.KeyCode.E
                        prompt:SetAttribute("TargetOwnerId", ownerUserId)
                        prompt.Parent = anchor
                    elseif not closed and existingPrompt then
                        -- La porte est ouverte, supprimer le prompt
                        existingPrompt:Destroy()
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- HANDLER DU PROMPT
-- ═══════════════════════════════════════════════════════

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
    if playerWhoTriggered ~= player then return end
    if prompt.Name ~= PROMPT_NAME then return end

    local targetOwnerId = prompt:GetAttribute("TargetOwnerId")
    if not targetOwnerId then return end

    requestDoorOpen:FireServer(targetOwnerId)
end)

-- ═══════════════════════════════════════════════════════
-- BOUCLE DE SCAN
-- ═══════════════════════════════════════════════════════

task.spawn(function()
    -- Attendre que le jeu soit chargé
    task.wait(3)

    while true do
        pcall(scanDoors)
        task.wait(SCAN_INTERVAL)
    end
end)
