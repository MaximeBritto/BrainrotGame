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
local TEXT_COLOR   = Color3.fromRGB(235, 235, 235)
local DONE_COLOR   = Color3.fromRGB(80, 210, 100)
local BOX_COLOR    = Color3.fromRGB(255, 210, 50)
local TOTAL_STEPS  = 3

-- ── State ─────────────────────────────────────────────────────────
local _active       = false
local _step         = 1
local _selectionBox = nil
local _arrowGui     = nil
local _connections  = {}
local _cashAtStep3  = 0
local _floorArrows  = {}   -- flat Parts au sol indiquant la direction

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
    return slots:FindFirstChild("1") or slots:GetChildren()[1]
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
local function FindNearestTutorialPiece()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local nearest, nearestDist = nil, math.huge
    -- Les pièces actives sont dans workspace (serveur les a taggées IsTutorialPiece)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("IsTutorialPiece") then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (part.Position - hrp.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest = part.Position
                end
            end
        end
    end
    return nearest
end

-- Retourne la position cible des flèches selon l'étape courante
local function GetArrowTarget()
    if _step == 1 then
        return FindNearestTutorialPiece()
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

local function SpawnArrow(target)
    DestroyArrow()
    if not target then return end

    local bill = Instance.new("BillboardGui")
    bill.Name        = "TutorialArrow"
    bill.Size        = UDim2.new(0, 64, 0, 64)
    bill.StudsOffset = Vector3.new(0, 8, 0)
    bill.AlwaysOnTop = false
    bill.Adornee     = target
    bill.Parent      = workspace

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = "▼"
    lbl.TextColor3            = BOX_COLOR
    lbl.TextScaled            = true
    lbl.Font                  = Enum.Font.GothamBold
    lbl.Parent                = bill

    task.spawn(function()
        local t = 0
        while bill.Parent do
            t = t + 0.05
            bill.StudsOffset = Vector3.new(0, 8 + math.sin(t) * 1.5, 0)
            task.wait(0.03)
        end
    end)

    _arrowGui = bill
end

local function ShowTarget(target)
    if _selectionBox then _selectionBox.Adornee = target end
    SpawnArrow(target)
end

local function HideTarget()
    if _selectionBox then _selectionBox.Adornee = nil end
    DestroyArrow()
end

-- ── Steps ─────────────────────────────────────────────────────────
local STEPS = {
    [1] = {
        title = "COLLECT THE PIECES!",
        text  = "Pick up the Head, Body and Legs that just appeared in the collect zone!",
        onEnter = function()
            HideTarget()
            -- Ask server to spawn real tutorial pieces near the base
            if SpawnTutorialPiecesRemote then
                task.delay(0.5, function()
                    SpawnTutorialPiecesRemote:FireServer()
                end)
            end
        end,
    },
    [2] = {
        title = "CRAFT YOUR BRAINROT!",
        text  = "Now go craft your Brainrot on your base slot!",
        onEnter = function()
            local base = GetPlayerBase()
            local slot = GetSlot1(base)
            local target = nil
            if slot then
                target = slot:FindFirstChild("Platform") or slot:FindFirstChildWhichIsA("BasePart")
            elseif base then
                target = base:FindFirstChildWhichIsA("BasePart")
            end
            ShowTarget(target)
        end,
    },
    [3] = {
        title = "COLLECT YOUR CASH!",
        text  = "Step on the green CollectPad below your Brainrot!",
        onEnter = function()
            local base = GetPlayerBase()
            local slot = GetSlot1(base)
            local target = nil
            if slot then
                local pad = slot:FindFirstChild("CollectPad")
                target = (pad and pad:IsA("BasePart")) and pad or slot:FindFirstChildWhichIsA("BasePart")
            end
            ShowTarget(target)
        end,
    },
}

-- ── UI ────────────────────────────────────────────────────────────
local function BuildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name         = "TutorialGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 50
    gui.Parent       = playerGui

    local panel = Instance.new("Frame")
    panel.Name                   = "Panel"
    panel.Size                   = UDim2.new(0, 370, 0, 118)
    panel.Position               = UDim2.new(0, 20, 1, 20) -- starts off-screen
    panel.BackgroundColor3       = BG_COLOR
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel        = 0
    panel.Parent                 = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

    -- Accent stripe
    local stripe = Instance.new("Frame")
    stripe.Size             = UDim2.new(0, 5, 1, 0)
    stripe.BackgroundColor3 = ACCENT_COLOR
    stripe.BorderSizePixel  = 0
    stripe.Parent           = panel
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 12)

    -- Badge
    local badge = Instance.new("TextLabel")
    badge.Name                   = "Badge"
    badge.Size                   = UDim2.new(0, 48, 0, 24)
    badge.Position               = UDim2.new(1, -56, 0, 10)
    badge.BackgroundColor3       = ACCENT_COLOR
    badge.BackgroundTransparency = 0
    badge.Text                   = "1 / " .. TOTAL_STEPS
    badge.TextColor3             = Color3.fromRGB(20, 20, 30)
    badge.TextScaled             = true
    badge.Font                   = Enum.Font.GothamBold
    badge.BorderSizePixel        = 0
    badge.Parent                 = panel
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)

    -- Title
    local title = Instance.new("TextLabel")
    title.Name                   = "Title"
    title.Size                   = UDim2.new(1, -72, 0, 24)
    title.Position               = UDim2.new(0, 16, 0, 10)
    title.BackgroundTransparency = 1
    title.Text                   = ""
    title.TextColor3             = ACCENT_COLOR
    title.TextScaled             = true
    title.Font                   = Enum.Font.GothamBold
    title.TextXAlignment         = Enum.TextXAlignment.Left
    title.Parent                 = panel

    -- Body
    local body = Instance.new("TextLabel")
    body.Name                   = "Body"
    body.Size                   = UDim2.new(1, -20, 0, 46)
    body.Position               = UDim2.new(0, 16, 0, 38)
    body.BackgroundTransparency = 1
    body.Text                   = ""
    body.TextColor3             = TEXT_COLOR
    body.TextScaled             = true
    body.Font                   = Enum.Font.Gotham
    body.TextXAlignment         = Enum.TextXAlignment.Left
    body.TextWrapped            = true
    body.Parent                 = panel

    -- Progress dots
    local dotsRow = Instance.new("Frame")
    dotsRow.Size                   = UDim2.new(1, -16, 0, 14)
    dotsRow.Position               = UDim2.new(0, 16, 1, -24)
    dotsRow.BackgroundTransparency = 1
    dotsRow.Parent                 = panel

    local layout = Instance.new("UIListLayout")
    layout.FillDirection     = Enum.FillDirection.Horizontal
    layout.Padding           = UDim.new(0, 7)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent            = dotsRow

    local dots = {}
    for i = 1, TOTAL_STEPS do
        local dot = Instance.new("Frame")
        dot.Size             = UDim2.new(0, 10, 0, 10)
        dot.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        dot.BorderSizePixel  = 0
        dot.Parent           = dotsRow
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        dots[i] = dot
    end

    return gui, panel, title, body, badge, dots
end

-- ── Step rendering ────────────────────────────────────────────────
local function RenderStep(title, body, badge, dots)
    local s = STEPS[_step]
    if not s then return end

    title.Text = s.title
    body.Text  = s.text
    badge.Text = _step .. " / " .. TOTAL_STEPS

    for i, dot in ipairs(dots) do
        if i < _step then
            dot.BackgroundColor3 = DONE_COLOR
        elseif i == _step then
            dot.BackgroundColor3 = ACCENT_COLOR
        else
            dot.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        end
    end

    s.onEnter()
end

-- ── Completion ────────────────────────────────────────────────────
local function CompleteTutorial(gui, panel, title, body, badge, dots)
    _active = false

    for _, c in ipairs(_connections) do c:Disconnect() end
    _connections = {}

    HideTarget()
    DestroyFloorArrows()
    if _selectionBox then _selectionBox:Destroy() ; _selectionBox = nil end

    title.Text             = "TUTORIAL COMPLETE!"
    body.Text              = "You're ready! Craft more Brainrots and grow your empire!"
    badge.Text             = "✓"
    badge.BackgroundColor3 = DONE_COLOR
    for _, dot in ipairs(dots) do dot.BackgroundColor3 = DONE_COLOR end

    if CompleteTutorialRemote then CompleteTutorialRemote:FireServer() end

    task.delay(4, function()
        local tInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad)
        TweenService:Create(panel, tInfo, {BackgroundTransparency = 1}):Play()
        for _, lbl in ipairs({title, body, badge}) do
            TweenService:Create(lbl, tInfo, {TextTransparency = 1}):Play()
        end
        TweenService:Create(badge, tInfo, {BackgroundTransparency = 1}):Play()
        task.delay(1.4, function()
            if gui and gui.Parent then gui:Destroy() end
        end)
    end)
end

-- ── Main ──────────────────────────────────────────────────────────
local function StartTutorial()
    print("[Tutorial] StartTutorial() called")
    task.wait(1.5)

    local fullData = GetFullPlayerData:InvokeServer()
    if not fullData then warn("[Tutorial] No data received") ; return end

    print("[Tutorial] HasSeenTutorial =", tostring(fullData.HasSeenTutorial))
    if fullData.HasSeenTutorial == true then
        print("[Tutorial] Already completed, skipping")
        return
    end

    print("[Tutorial] Showing tutorial!")
    _active      = true
    _step        = 1
    _cashAtStep3 = fullData.Cash or 0

    local gui, panel, title, body, badge, dots = BuildUI()

    _selectionBox = Instance.new("SelectionBox")
    _selectionBox.Color3              = BOX_COLOR
    _selectionBox.LineThickness       = 0.07
    _selectionBox.SurfaceColor3       = BOX_COLOR
    _selectionBox.SurfaceTransparency = 0.82
    _selectionBox.Parent              = workspace

    -- Show step 1 (fires SpawnTutorialPieces on server)
    RenderStep(title, body, badge, dots)

    -- Slide in
    TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 20, 1, -138)}):Play()

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
    local function RollbackToStep1()
        if not _active or _step >= 3 then return end
        _step = 1
        RenderStep(title, body, badge, dots)
        -- Respawn les pièces tuto (les anciennes ont disparu avec la mort)
        if SpawnTutorialPiecesRemote then
            task.delay(1, function()
                if _active and _step == 1 then
                    SpawnTutorialPiecesRemote:FireServer()
                end
            end)
        end
    end

    local respawnConn = player.CharacterAdded:Connect(function()
        task.wait(0.5) -- laisser le perso charger
        RollbackToStep1()
    end)
    table.insert(_connections, respawnConn)

    -- Step 1: wait for all 3 piece types
    local invConn = SyncInventoryRemote.OnClientEvent:Connect(function(pieces)
        if not _active or _step ~= 1 then return end
        if HasAllPieceTypes(pieces or {}) then
            _step = 2
            RenderStep(title, body, badge, dots)
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
                RenderStep(title, body, badge, dots)
            end

        elseif _step == 3 then
            if data.Cash and data.Cash > _cashAtStep3 then
                CompleteTutorial(gui, panel, title, body, badge, dots)
            end
        end
    end)
    table.insert(_connections, dataConn)
end

StartTutorial()
