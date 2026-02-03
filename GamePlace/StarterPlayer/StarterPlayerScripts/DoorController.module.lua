--[[
    DoorController.module.lua
    Contrôleur client pour l'UI de la porte
    
    Responsabilités:
    - Afficher le statut de la porte (Open/Closed)
    - Afficher le timer de réouverture
    - Mettre à jour l'UI en temps réel
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])

local DoorController = {}
DoorController._initialized = false
DoorController._doorState = Constants.DoorState.Open
DoorController._reopenTime = 0

-- UI Elements
local doorTimerUI = nil
local statusLabel = nil
local timerLabel = nil

--[[
    Initialise le contrôleur
]]
function DoorController:Init()
    if self._initialized then
        warn("[DoorController] Déjà initialisé!")
        return
    end
    
    print("[DoorController] Initialisation...")
    
    -- Récupérer l'UI (optionnel)
    doorTimerUI = playerGui:FindFirstChild("DoorTimerUI")
    
    if doorTimerUI then
        local container = doorTimerUI:FindFirstChild("Container")
        if container then
            statusLabel = container:FindFirstChild("StatusLabel")
            timerLabel = container:FindFirstChild("TimerLabel")
            
            if statusLabel and timerLabel then
                print("[DoorController] UI trouvée et connectée")
            else
                warn("[DoorController] StatusLabel ou TimerLabel introuvable")
            end
        else
            warn("[DoorController] Container introuvable")
        end
    else
        warn("[DoorController] DoorTimerUI introuvable - UI désactivée")
    end
    
    -- Démarrer la loop de mise à jour
    self:_StartUpdateLoop()
    
    self._initialized = true
    print("[DoorController] Initialisé!")
end

--[[
    Met à jour l'état de la porte
    @param state: string - "Open" ou "Closed"
    @param reopenTime: number - Timestamp de réouverture (optionnel)
]]
function DoorController:UpdateDoorState(state, reopenTime)
    self._doorState = state
    self._reopenTime = reopenTime or 0
    
    print("[DoorController] État mis à jour: " .. state)
    
    -- Mettre à jour immédiatement
    self:_UpdateUI()
end

--[[
    Met à jour l'UI
]]
function DoorController:_UpdateUI()
    -- Vérifier que l'UI existe
    if not statusLabel or not timerLabel then
        return
    end
    
    if self._doorState == Constants.DoorState.Open then
        -- Porte ouverte
        statusLabel.Text = "🚪 DOOR STATUS"
        timerLabel.Text = "OPEN"
        timerLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Vert
        
    elseif self._doorState == Constants.DoorState.Closed then
        -- Porte fermée - calculer le temps restant
        local currentTime = os.time()
        local remainingTime = math.max(0, self._reopenTime - currentTime)
        
        if remainingTime > 0 then
            statusLabel.Text = "🚪 DOOR CLOSES IN:"
            timerLabel.Text = remainingTime .. "s"
            timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Rouge
        else
            -- Le timer est fini, la porte devrait être ouverte
            statusLabel.Text = "🚪 DOOR STATUS"
            timerLabel.Text = "OPEN"
            timerLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Vert
            self._doorState = Constants.DoorState.Open
        end
    end
end

--[[
    Loop de mise à jour (chaque seconde)
]]
function DoorController:_StartUpdateLoop()
    task.spawn(function()
        while true do
            task.wait(1) -- Mettre à jour chaque seconde
            
            if self._doorState == Constants.DoorState.Closed then
                self:_UpdateUI()
            end
        end
    end)
    
    print("[DoorController] Loop de mise à jour démarrée")
end

return DoorController
