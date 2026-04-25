--[[
    TutorialController.client.lua
    Guided tutorial for first-time players.

    Flow:
        Step 1 → Server spawns Head/Body/Legs near base with "Pick me up!" labels.
                 Complete when player holds all 3 piece types (SyncInventory).
        Step 2 → Craft your Brainrot. SelectionBox on slot platform.
                 Complete when PlacedBrainrots updated (SyncPlayerData).
        Step 3 → Collect cash. SelectionBox on CollectPad.
                 Complete when Cash increases (SyncPlayerData).
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Remotes ──────────────────────────────────────────────────────
local Remotes                  = ReplicatedStorage:WaitForChild("Remotes", 15)
local GetFullPlayerData        = Remotes and Remotes:WaitForChild("GetFullPlayerData",    10)
local SyncInventoryRemote      = Remotes and Remotes:WaitForChild("SyncInventory",        10)
local SyncPlayerDataRemote     = Remotes and Remotes:WaitForChild("SyncPlayerData",       10)
local CompleteTutorialRemote   = Remotes and Remotes:WaitForChild("CompleteTutorial",     10)
local SpawnTutorialPiecesRemote = Remotes and Remotes:WaitForChild("SpawnTutorialPieces", 10)

print("[Tutorial] Remotes loaded:",
    GetFullPlayerData ~= nil,
    SyncInventoryRemote ~= nil,
    SyncPlayerDataRemote ~= nil,
    CompleteTutorialRemote ~= nil,
    SpawnTutorialPiecesRemote ~= nil)

if not GetFullPlayerData or not SyncInventoryRemote or not SyncPlayerDataRemote then
    warn("[Tutorial] Missing remotes — tutorial disabled")
    return
end

-- ── Visual constants ─────────────────────────────────────────────
local BG_COLOR     = Color3.fromRGB(15, 15, 25)
local ACCENT_COLOR = Color3.fromRGB(255, 210, 50)
local DONE_COLOR   = Color3.fromRGB(80, 210, 100)
local BOX_COLOR    = Color3.fromRGB(255, 210, 50)

-- ── State ─────────────────────────────────────────────────────────
local _active        = false
local _step          = 1
local _step1Sub      = "Head"   -- "Head" | "Body" | "Legs" : pièce attendue à l'étape 1
local _selectionBox  = nil
local _arrowGui      = nil
local _connections   = {}
local _cashAtStep3   = 0
local _floorArrows   = {}        -- flat Parts au sol indiquant la direction
local _currentPieces = {}        -- dernier snapshot SyncInventory (utilisé pour décider du sub-step)
local _focusGen      = 0         -- génération du focus caméra courant (pour annuler les précédents)

-- Ordre forcé de collecte des pièces tutoriel
local PIECE_ORDER = {"Head", "Body", "Legs"}

-- Texte affiché au-dessus de la cible (dans la flèche 3D) — toute la consigne tient ici.
local STEP_TEXT = {
    Head    = "PICK UP THE HEAD",
    Body    = "PICK UP THE BODY",
    Legs    = "PICK UP THE LEGS",
    Craft   = "CRAFT YOUR BRAINROT",
    Collect = "COLLECT YOUR CASH",
}

-- ── Helpers ───────────────────────────────────────────────────────
local function GetPlayerBase()
    local bases = workspace:FindFirstChild("Bases")
    if not bases then return nil end
    for _, base in ipairs(bases:GetChildren()) do
        if base:GetAttribute("OwnerUserId") == player.UserId then
            return base
        end
    end
    return nil
end

local function GetSlot1(base)
    if not base then return nil end
    local slots = base:FindFirstChild("Slots")
    if not slots then return nil end
    return slots:FindFirstChild("Slot_1")
end

local function HasAllPieceTypes(pieces)
    local h, b, l = false, false, false
    for _, p in ipairs(pieces) do
        if p.PieceType == "Head" then h = true end
        if p.PieceType == "Body" then b = true end
        if p.PieceType == "Legs" then l = true end
    end
    return h and b and l
end

-- ── Floor arrows ─────────────────────────────────────────────────
local ARROW_COUNT   = 30   -- pool max de flèches (toutes pré-créées, cachées si inutiles)
local ARROW_SPACING = 4    -- studs entre chaque flèche
local ARROW_COLOR   = Color3.fromRGB(255, 210, 50)

-- Trouve la pièce tutoriel la plus proche du joueur encore présente dans le workspace
-- Retourne (position Vector3, modèle) ou (nil, nil)
-- Si pieceType est fourni, ne considère que les pièces de ce type.
local function FindNearestTutorialPiece(pieceType)
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end

    local nearest, nearestDist, nearestModel = nil, math.huge, nil
    -- Les pièces actives sont dans workspace (serveur les a taggées IsTutorialPiece)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("IsTutorialPiece") then
            if pieceType and obj:GetAttribute("TutorialPieceType") ~= pieceType then
                continue
            end
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (part.Position - hrp.Position).Magnitude
                if d < nearestDist then
                    nearestDist  = d
                    nearest      = part.Position
                    nearestModel = obj
                end
            end
        end
    end
    return nearest, nearestModel
end

-- Détermine le prochain type de pièce manquant dans l'ordre PIECE_ORDER
local function GetNextNeededType(pieces)
    local has = {Head = false, Body = false, Legs = false}
    for _, p in ipairs(pieces or {}) do
        if has[p.PieceType] ~= nil then has[p.PieceType] = true end
    end
    for _, t in ipairs(PIECE_ORDER) do
        if not has[t] then return t end
    end
    return nil
end

-- Retourne la position cible des flèches selon l'étape courante
local function GetArrowTarget()
    if _step == 1 then
        local pos = FindNearestTutorialPiece(_step1Sub)
        return pos
    elseif _step == 2 then
        local base = GetPlayerBase()
        local slot = GetSlot1(base)
        if slot then
            local p = slot:FindFirstChild("Platform") or slot:FindFirstChildWhichIsA("BasePart")
            return p and p.Position
        end
    elseif _step == 3 then
        local base = GetPlayerBase()
        local slot = GetSlot1(base)
        if slot then
            local pad = slot:FindFirstChild("CollectPad")
            if pad and pad:IsA("BasePart") then return pad.Position end
        end
    end
    return nil
end

local _rayParams = RaycastParams.new()
_rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function GetFloorY(pos)
    local char = player.Character
    _rayParams.FilterDescendantsInstances = char and {char} or {}
    local result = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), _rayParams)
    return result and (result.Position.Y + 0.08) or (pos.Y - 3)
end

local function CreateFloorArrows()
    for _, p in ipairs(_floorArrows) do if p and p.Parent then p:Destroy() end end
    _floorArrows = {}

    for i = 1, ARROW_COUNT do
        local part = Instance.new("Part")
        part.Name        = "TutFloorArrow"
        part.Size        = Vector3.new(1.4, 0.08, 2.2)
        part.Anchored    = true
        part.CanCollide  = false
        part.CastShadow  = false
        part.Material    = Enum.Material.Neon
        part.Color       = ARROW_COLOR
        part.Transparency = 1
        part.Parent      = workspace

        local sg = Instance.new("SurfaceGui")
        sg.Face          = Enum.NormalId.Top
        sg.SizingMode    = Enum.SurfaceGuiSizingMode.FixedSize
        sg.CanvasSize    = Vector2.new(140, 220)
        sg.Parent        = part

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = "▲"
        lbl.TextColor3            = Color3.fromRGB(255, 255, 255)
        lbl.TextScaled            = true
        lbl.Font                  = Enum.Font.GothamBold
        lbl.Parent                = sg

        table.insert(_floorArrows, part)
    end
end

local function UpdateFloorArrows()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or #_floorArrows == 0 then return end

    local playerPos = hrp.Position
    local targetPos = GetArrowTarget()

    if not targetPos then
        for _, p in ipairs(_floorArrows) do p.Transparency = 1 end
        return
    end

    local diff = Vector3.new(targetPos.X - playerPos.X, 0, targetPos.Z - playerPos.Z)
    local dist = diff.Magnitude

    if dist < 4 then
        for _, p in ipairs(_floorArrows) do p.Transparency = 1 end
        return
    end

    local dir = diff / dist
    -- yaw+π : ▲ dans SurfaceGui sur face Top pointe vers -Z local → on veut -Z = dir
    local yaw     = math.atan2(dir.X, dir.Z) + math.pi
    local floorY  = GetFloorY(playerPos)

    -- Combien de flèches pour couvrir joueur → cible (2 studs de marge de chaque côté)
    local usable  = math.max(0, dist - 4)
    local needed  = math.min(ARROW_COUNT, math.floor(usable / ARROW_SPACING) + 1)

    for i, part in ipairs(_floorArrows) do
        if i > needed then
            part.Transparency = 1
            continue
        end

        -- Répartition uniforme de 2 studs devant le joueur jusqu'à 2 studs avant la cible
        local t       = (i - 1) / math.max(needed - 1, 1)   -- 0 → 1
        local d       = 2 + t * usable

        -- Fondu : proche du joueur = opaque, proche de la cible = transparent
        local fade    = 1 - t * 0.6   -- 1.0 → 0.4
        part.Transparency = 1 - fade

        local pos = playerPos + dir * d
        part.CFrame = CFrame.new(Vector3.new(pos.X, floorY, pos.Z))
                    * CFrame.Angles(0, yaw, 0)
    end
end

local function DestroyFloorArrows()
    for _, p in ipairs(_floorArrows) do if p and p.Parent then p:Destroy() end end
    _floorArrows = {}
end

-- ── 3D Arrow + SelectionBox ───────────────────────────────────────
local function DestroyArrow()
    if _arrowGui then _arrowGui:Destroy() ; _arrowGui = nil end
end

local function SpawnArrow(target, text)
    DestroyArrow()
    if not target then return end

    local bill = Instance.new("BillboardGui")
    bill.Name        = "TutorialArrow"
    bill.Size        = UDim2.new(0, 280, 0, 110)
    bill.StudsOffset = Vector3.new(0, 9, 0)
    bill.AlwaysOnTop = true
    bill.Adornee     = target
    bill.Parent      = workspace

    -- Texte de consigne (sans bulle)
    if text and text ~= "" then
        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, 0, 0.55, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = text
        lbl.TextColor3            = Color3.fromRGB(255, 255, 255)
        lbl.TextScaled            = true
        lbl.Font                  = Enum.Font.GothamBold
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
        lbl.Parent                = bill
    end

    -- Flèche pointant vers l'élément
    local arrow = Instance.new("TextLabel")
    arrow.Size                  = UDim2.new(1, 0, 0.45, 0)
    arrow.Position              = UDim2.new(0, 0, 0.55, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text                  = "▼"
    arrow.TextColor3            = BOX_COLOR
    arrow.TextScaled            = true
    arrow.Font                  = Enum.Font.GothamBold
    arrow.TextStrokeTransparency = 0
    arrow.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
    arrow.Parent                = bill

    task.spawn(function()
        local t = 0
        while bill.Parent do
            t = t + 0.05
            bill.StudsOffset = Vector3.new(0, 9 + math.sin(t) * 1.0, 0)
            task.wait(0.03)
        end
    end)

    _arrowGui = bill
end

local function ShowTarget(target, text)
    if _selectionBox then _selectionBox.Adornee = target end
    SpawnArrow(target, text)
end

local function HideTarget()
    if _selectionBox then _selectionBox.Adornee = nil end
    DestroyArrow()
end

-- ── Camera focus ──────────────────────────────────────────────────
-- Focus permanent : la caméra reste cadrée sur la cible tant que celle-ci existe.
-- Position : derrière le joueur sur l'axe joueur→cible (le perso reste visible au premier plan).
-- Le focus est interrompu si :
--   • un nouvel appel FocusCameraOn(...) le remplace (changement de sub-step / d'étape),
--   • la cible est détruite (pièce ramassée, slot vide etc.),
--   • ReleaseCamera() est appelée explicitement.
local _camPrevType    = nil
local _camPrevSubject = nil

local function FocusCameraOn(target)
    local cam = workspace.CurrentCamera
    if not cam then return end

    -- Résoudre la part à suivre (besoin de l'objet pour détecter sa destruction)
    local part = nil
    if typeof(target) == "Instance" then
        if target:IsA("BasePart") then
            part = target
        elseif target:IsA("Model") then
            part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
        end
    end
    if not part then return end

    _focusGen = _focusGen + 1
    local myGen = _focusGen

    -- Mémoriser le mode caméra original UNIQUEMENT lors du 1er focus (avant Scriptable).
    if cam.CameraType ~= Enum.CameraType.Scriptable then
        _camPrevType    = cam.CameraType
        _camPrevSubject = cam.CameraSubject
    end

    cam.CameraType = Enum.CameraType.Scriptable

    -- Boucle de suivi
    local lastTargetPos = part.Position
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if myGen ~= _focusGen then conn:Disconnect() ; return end
        if not part.Parent then conn:Disconnect() ; return end -- pièce détruite (ramassée)

        lastTargetPos = part.Position

        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local charPos = hrp.Position + Vector3.new(0, 2, 0)
        local diff    = lastTargetPos - charPos
        if diff.Magnitude < 0.5 then return end
        local unitDir = diff.Unit

        -- Caméra placée derrière le perso sur l'axe perso→cible, légèrement surélevée
        local camPos = charPos - unitDir * 12 + Vector3.new(0, 4, 0)
        cam.CFrame   = CFrame.lookAt(camPos, lastTargetPos)
    end)
end

-- Libère la caméra (rollback / fin du tuto)
local function ReleaseCamera()
    _focusGen = _focusGen + 1 -- annule tout focus en cours
    local cam = workspace.CurrentCamera
    if cam and cam.CameraType == Enum.CameraType.Scriptable then
        cam.CameraType    = _camPrevType or Enum.CameraType.Custom
        if _camPrevSubject then cam.CameraSubject = _camPrevSubject end
    end
    _camPrevType    = nil
    _camPrevSubject = nil
end

-- ── Sub-step (étape 1 : 1 pièce à viser à la fois) ───────────────
-- Vise le type de pièce attendu (déjà spawnée par STEPS[1].onEnter),
-- attend la pièce dans le workspace si besoin, puis pose SelectionBox +
-- flèche 3D (avec texte de consigne) + rotation caméra dessus.
local function EnterStep1Sub(subType)
    _step1Sub = subType
    HideTarget()

    task.spawn(function()
        local model
        for _ = 1, 30 do -- ~3s max d'attente
            if not _active or _step ~= 1 or _step1Sub ~= subType then return end
            local _pos, m = FindNearestTutorialPiece(subType)
            if m then model = m; break end
            task.wait(0.1)
        end
        if not model then return end

        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if part then
            ShowTarget(part, STEP_TEXT[subType])
            FocusCameraOn(part)
        end
    end)
end

-- ── Steps ─────────────────────────────────────────────────────────
local STEPS = {
    [1] = {
        onEnter = function()
            HideTarget()
            -- Spawn les 3 pièces (Head/Body/Legs) d'un coup.
            if SpawnTutorialPiecesRemote then
                task.delay(0.5, function()
                    if not _active or _step ~= 1 then return end
                    SpawnTutorialPiecesRemote:FireServer()
                end)
            end
            -- Vise la première pièce manquante (Head au démarrage).
            local nextType = GetNextNeededType(_currentPieces) or "Head"
            EnterStep1Sub(nextType)
        end,
    },
    [2] = {
        onEnter = function()
            local base = GetPlayerBase()
            local slot = GetSlot1(base)
            local target = nil
            if slot then
                target = slot:FindFirstChild("Platform") or slot:FindFirstChildWhichIsA("BasePart")
            elseif base then
                target = base:FindFirstChildWhichIsA("BasePart")
            end
            ShowTarget(target, STEP_TEXT.Craft)
            if target then FocusCameraOn(target) end
        end,
    },
    [3] = {
        onEnter = function()
            local base = GetPlayerBase()
            local slot = GetSlot1(base)
            local target = nil
            if slot then
                local pad = slot:FindFirstChild("CollectPad")
                target = (pad and pad:IsA("BasePart")) and pad or slot:FindFirstChildWhichIsA("BasePart")
            end
            ShowTarget(target, STEP_TEXT.Collect)
            if target then FocusCameraOn(target) end
        end,
    },
}

-- ── UI ────────────────────────────────────────────────────────────
-- Plus de panneau bottom-left : toute la consigne tient dans la flèche 3D
-- au-dessus de l'élément focusé. On garde juste une ScreenGui vide pour
-- l'écran de complétion (court flash centré).
local function BuildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name         = "TutorialGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 50
    gui.Parent       = playerGui
    return gui
end

-- ── Step rendering ────────────────────────────────────────────────
local function RenderStep()
    local s = STEPS[_step]
    if not s then return end
    s.onEnter()
end

-- ── Completion ────────────────────────────────────────────────────
local function CompleteTutorial(gui)
    _active = false

    for _, c in ipairs(_connections) do c:Disconnect() end
    _connections = {}

    HideTarget()
    DestroyFloorArrows()
    ReleaseCamera()
    if _selectionBox then _selectionBox:Destroy() ; _selectionBox = nil end

    if CompleteTutorialRemote then CompleteTutorialRemote:FireServer() end

    -- Flash centré "TUTORIAL COMPLETE!" qui s'estompe.
    local label = Instance.new("TextLabel")
    label.Size                  = UDim2.new(0, 480, 0, 70)
    label.AnchorPoint           = Vector2.new(0.5, 0.5)
    label.Position              = UDim2.new(0.5, 0, 0.35, 0)
    label.BackgroundColor3      = BG_COLOR
    label.BackgroundTransparency = 0.1
    label.Text                  = "TUTORIAL COMPLETE!"
    label.TextColor3            = DONE_COLOR
    label.TextScaled            = true
    label.Font                  = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.4
    label.Parent                = gui
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke")
    stroke.Color     = DONE_COLOR
    stroke.Thickness = 2
    stroke.Parent    = label

    task.delay(2.5, function()
        local tInfo = TweenInfo.new(1.0, Enum.EasingStyle.Quad)
        TweenService:Create(label, tInfo, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        TweenService:Create(stroke, tInfo, {Transparency = 1}):Play()
        task.delay(1.2, function()
            if gui and gui.Parent then gui:Destroy() end
        end)
    end)
end

-- ── Main ──────────────────────────────────────────────────────────
local function StartTutorial()
    print("[Tutorial] StartTutorial() called")
    local fullData = GetFullPlayerData:InvokeServer()
    if not fullData then warn("[Tutorial] No data received") ; return end

    print("[Tutorial] HasSeenTutorial =", tostring(fullData.HasSeenTutorial))
    if fullData.HasSeenTutorial == true then
        print("[Tutorial] Already completed, skipping")
        return
    end

    print("[Tutorial] Showing tutorial!")
    _active      = true
    -- Reprise si le joueur a quitté en cours : PlacedBrainrots est persisté,
    -- donc s'il a déjà crafté on saute direct à l'étape 3 (collect cash).
    local hasPlaced = fullData.PlacedBrainrots and next(fullData.PlacedBrainrots) ~= nil
    _step        = hasPlaced and 3 or 1
    _cashAtStep3 = fullData.Cash or 0

    local gui = BuildUI()

    _selectionBox = Instance.new("SelectionBox")
    _selectionBox.Color3              = BOX_COLOR
    _selectionBox.LineThickness       = 0.07
    _selectionBox.SurfaceColor3       = BOX_COLOR
    _selectionBox.SurfaceTransparency = 0.82
    _selectionBox.Parent              = workspace

    -- Show step 1 (fires SpawnTutorialPieces on server)
    RenderStep()

    -- Floor arrows
    CreateFloorArrows()
    task.spawn(function()
        while _active do
            UpdateFloorArrows()
            task.wait(0.1)
        end
        DestroyFloorArrows()
    end)

    -- Rollback sur mort (étapes 1 et 2 seulement — étape 3 le brainrot est déjà placé)
    -- À la mort, l'inventaire runtime est vidé serveur ; _currentPieces sera mis à jour
    -- par le prochain SyncInventory. On reset aussi le sub-step à "Head".
    local function RollbackToStep1()
        if not _active or _step >= 3 then return end
        ReleaseCamera()
        _step         = 1
        _step1Sub     = "Head"
        _currentPieces = {}
        RenderStep()
    end

    local respawnConn = player.CharacterAdded:Connect(function()
        task.wait(0.5) -- laisser le perso charger
        RollbackToStep1()
    end)
    table.insert(_connections, respawnConn)

    -- Step 1 : avancer sub-step par sub-step (Head → Body → Legs).
    -- Quand le joueur ramasse la pièce attendue, on passe à la suivante (ou à l'étape 2).
    local invConn = SyncInventoryRemote.OnClientEvent:Connect(function(pieces)
        _currentPieces = pieces or {}
        if not _active or _step ~= 1 then return end

        local nextType = GetNextNeededType(_currentPieces)
        if not nextType then
            -- Les 3 types sont collectés → étape 2
            _step = 2
            RenderStep()
            return
        end

        -- Si le type attendu a changé (= pièce courante ramassée), entrer le nouveau sub-step.
        -- Sinon (ex: pièce ramassée puis remplacée par même type, peu probable), on ne refait rien.
        if nextType ~= _step1Sub then
            EnterStep1Sub(nextType)
        end
    end)
    table.insert(_connections, invConn)

    -- Steps 2 & 3
    local dataConn = SyncPlayerDataRemote.OnClientEvent:Connect(function(data)
        if not _active then return end

        if _step == 2 then
            if data.PlacedBrainrots and next(data.PlacedBrainrots) then
                _cashAtStep3 = data.Cash or _cashAtStep3
                _step = 3
                RenderStep()
            end

        elseif _step == 3 then
            if data.Cash and data.Cash > _cashAtStep3 then
                CompleteTutorial(gui)
            end
        end
    end)
    table.insert(_connections, dataConn)
end

StartTutorial()
