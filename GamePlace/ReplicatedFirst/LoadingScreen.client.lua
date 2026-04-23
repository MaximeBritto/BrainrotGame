--[[
    LoadingScreen.client.lua
    Écran de chargement affiché au démarrage du jeu.

    Placement : ReplicatedFirst (Roblox charge ReplicatedFirst AVANT le reste,
    donc c'est l'endroit standard pour un loading screen custom).

    Comportement :
    - Supprime l'écran de chargement Roblox par défaut
    - Affiche le logo "Brainrot Fusion" + une barre de progression sur le cadre doré
    - Précharge tous les assets du jeu (sons, meshes, images...) via ContentProvider
    - Mets à jour la barre de progression en temps réel
    - Disparaît en fondu une fois que tout est prêt

    ⚠️ CONFIG : tu dois uploader tes 2 PNG dans Roblox Studio puis remplir
    LOGO_IMAGE_ID et BAR_FRAME_IMAGE_ID ci-dessous.
    (Asset Manager → Images → clic droit "Add Image" → Copy ID)
]]

-- ═══════════════════════════════════════════════════════════════
-- 🔧 CONFIG : ASSET IDs
-- ═══════════════════════════════════════════════════════════════
local LOGO_IMAGE_ID          = "rbxassetid://137990593829302" -- ← Logo "BRAINROT FUSION"
local BAR_BACKGROUND_ID      = "rbxassetid://114349368090243" -- ← Plaque de fond de la barre
local BAR_FRAME_IMAGE_ID     = "rbxassetid://101184665163721" -- ← Cadre doré ornemental (avant)
-- rbxassetid://92879026943692  -- (fill alternatif, inutilisé)
-- ═══════════════════════════════════════════════════════════════

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")

-- Désactiver l'écran par défaut le plus tôt possible
pcall(function()
    ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ───────────────────────────────────────────────────────────────
-- CONSTRUCTION DE L'UI
-- ───────────────────────────────────────────────────────────────
local screen = Instance.new("ScreenGui")
screen.Name             = "LoadingScreen"
screen.IgnoreGuiInset   = true
screen.ResetOnSpawn     = false
screen.DisplayOrder     = 1000
screen.ZIndexBehavior   = Enum.ZIndexBehavior.Global -- ZIndex trié globalement, pas par parent
screen.Enabled          = true
screen.Parent           = playerGui

-- Fond sombre plein écran
local background = Instance.new("Frame")
background.Name             = "Background"
background.Size             = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
background.BorderSizePixel  = 0
background.ZIndex           = 1
background.Parent           = screen

-- Dégradé subtil pour l'ambiance
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(18, 22, 36)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(6,  8,  14)),
})
bgGradient.Rotation = 90
bgGradient.Parent   = background

-- Logo "Brainrot Fusion" en plein écran
local logo = Instance.new("ImageLabel")
logo.Name                   = "Logo"
logo.Size                   = UDim2.fromScale(1, 1)
logo.Position               = UDim2.fromScale(0, 0)
logo.BackgroundTransparency = 1
logo.Image                  = LOGO_IMAGE_ID
logo.ScaleType              = Enum.ScaleType.Crop
logo.ZIndex                 = 2
logo.Parent                 = screen

-- Dégradé sombre sur la partie basse pour que la barre reste lisible
local bottomFade = Instance.new("Frame")
bottomFade.Name                   = "BottomFade"
bottomFade.AnchorPoint            = Vector2.new(0.5, 1)
bottomFade.Position               = UDim2.fromScale(0.5, 1)
bottomFade.Size                   = UDim2.fromScale(1, 0.35)
bottomFade.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
bottomFade.BorderSizePixel        = 0
bottomFade.BackgroundTransparency = 0.4
bottomFade.ZIndex                 = 2
bottomFade.Parent                 = screen

local fadeGradient = Instance.new("UIGradient")
fadeGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 1.0), -- haut transparent
    NumberSequenceKeypoint.new(1.0, 0.2), -- bas presque opaque
})
fadeGradient.Rotation = 90
fadeGradient.Parent   = bottomFade

-- Container de la barre — ratio d'aspect verrouillé pour rester proportionnel
-- (l'image du cadre a la barre visible dans un ratio ~7:1, on le reproduit)
local BAR_ASPECT = 7.0
local barContainer = Instance.new("Frame")
barContainer.Name                   = "BarContainer"
barContainer.AnchorPoint            = Vector2.new(0.5, 0.5)
barContainer.Position               = UDim2.fromScale(0.5, 0.84)
barContainer.Size                   = UDim2.fromScale(0.9, 0.13) -- seed de hauteur, affiné par l'AspectRatio
barContainer.BackgroundTransparency = 1
barContainer.ZIndex                 = 3
barContainer.Parent                 = screen

local barAspect = Instance.new("UIAspectRatioConstraint")
barAspect.AspectRatio  = BAR_ASPECT
barAspect.DominantAxis = Enum.DominantAxis.Width
barAspect.Parent       = barContainer

-- COUCHE 1 (fond) : plaque de background — Stretch pour remplir tout le container
local barBackground = Instance.new("ImageLabel")
barBackground.Name                   = "BarBackground"
barBackground.Size                   = UDim2.fromScale(1, 1)
barBackground.BackgroundTransparency = 1
barBackground.Image                  = BAR_BACKGROUND_ID
barBackground.ScaleType              = Enum.ScaleType.Stretch
barBackground.ZIndex                 = 3
barBackground.Parent                 = barContainer

-- Zone intérieure : référence de taille pour le fill (invisible, sert de conteneur au fill)
-- Ajuste ces % si le fill déborde ou laisse un espace sur les bords.
local barInterior = Instance.new("Frame")
barInterior.Name                   = "Interior"
barInterior.AnchorPoint            = Vector2.new(0.5, 0.5)
barInterior.Position               = UDim2.fromScale(0.51, 0.5) -- calé sur la zone sombre du cadre
barInterior.Size                   = UDim2.fromScale(0.83, 0.45)
barInterior.BackgroundTransparency = 1
barInterior.ClipsDescendants       = true
barInterior.ZIndex                 = 4
barInterior.Parent                 = barContainer

-- COUCHE 2 (milieu) : fill gradient doré qui progresse 0% → 100%
local fill = Instance.new("Frame")
fill.Name             = "Fill"
fill.AnchorPoint      = Vector2.new(0, 0.5)
fill.Position         = UDim2.fromScale(0, 0.5)
fill.Size             = UDim2.fromScale(0, 1) -- grandira de 0 à 1 avec la progression
fill.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
fill.BorderSizePixel  = 0
fill.ZIndex           = 6 -- au-dessus du cadre (qui a un intérieur opaque)
fill.Parent           = barInterior

local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 215, 100)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 40)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 215, 100)),
})
fillGradient.Rotation = 0
fillGradient.Parent   = fill

-- COUCHE 3 (avant) : cadre doré ornemental PAR-DESSUS tout
-- L'image source a beaucoup de padding noir autour du cadre visible ;
-- on le crop via ImageRectOffset/Size puis on stretch sur le container.
local barFrame = Instance.new("ImageLabel")
barFrame.Name                   = "BarFrame"
barFrame.Size                   = UDim2.fromScale(1, 1)
barFrame.BackgroundTransparency = 1
barFrame.Image                  = BAR_FRAME_IMAGE_ID
barFrame.ScaleType              = Enum.ScaleType.Stretch
barFrame.ImageRectOffset        = Vector2.new(128, 275)
barFrame.ImageRectSize          = Vector2.new(770, 110)
barFrame.ZIndex                 = 5
barFrame.Parent                 = barContainer


-- Label de pourcentage (par-dessus la barre)
local percentLabel = Instance.new("TextLabel")
percentLabel.Name                   = "PercentLabel"
percentLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
percentLabel.Position               = UDim2.fromScale(0.5, 0.5)
percentLabel.Size                   = UDim2.fromScale(1, 0.7)
percentLabel.BackgroundTransparency = 1
percentLabel.Text                   = "0%"
percentLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
percentLabel.Font                   = Enum.Font.GothamBold
percentLabel.TextScaled             = true
percentLabel.TextStrokeTransparency = 0.2
percentLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
percentLabel.ZIndex                 = 7
percentLabel.Parent                 = barContainer

-- Label "Loading..." juste au-dessus de la barre
local statusLabel = Instance.new("TextLabel")
statusLabel.Name                   = "StatusLabel"
statusLabel.AnchorPoint            = Vector2.new(0.5, 1)
statusLabel.Position               = UDim2.fromScale(0.5, 0.68)
statusLabel.Size                   = UDim2.fromScale(0.6, 0.035)
statusLabel.BackgroundTransparency = 1
statusLabel.Text                   = "Loading assets..."
statusLabel.TextColor3             = Color3.fromRGB(220, 220, 220)
statusLabel.Font                   = Enum.Font.Gotham
statusLabel.TextScaled             = true
statusLabel.TextStrokeTransparency = 0.5
statusLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
statusLabel.ZIndex                 = 2
statusLabel.Parent                 = screen

-- ───────────────────────────────────────────────────────────────
-- PROGRESSION
-- ───────────────────────────────────────────────────────────────
local displayedProgress = 0
local targetProgress    = 0
local isDone            = false

-- Lerp visuel : la barre rattrape doucement targetProgress (plus fluide que des sauts)
RunService.RenderStepped:Connect(function(dt)
    if isDone then return end
    local speed = 4 -- plus haut = plus rapide
    displayedProgress = displayedProgress + (targetProgress - displayedProgress) * math.min(1, dt * speed)
    local clamped = math.clamp(displayedProgress, 0, 1)
    fill.Size         = UDim2.fromScale(clamped, 1)
    percentLabel.Text = math.floor(clamped * 100 + 0.5) .. "%"
end)

-- ───────────────────────────────────────────────────────────────
-- PRELOAD DES ASSETS
-- ───────────────────────────────────────────────────────────────
local function collectAssets()
    local list = {}
    local seen = {}
    local function tryAdd(inst)
        if not inst then return end
        local ok, content = pcall(function()
            if inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("Decal") or inst:IsA("Texture") then
                return inst.Image or inst.Texture
            elseif inst:IsA("Sound") then
                return inst.SoundId
            elseif inst:IsA("MeshPart") then
                return inst.MeshId
            elseif inst:IsA("SpecialMesh") then
                return inst.MeshId
            elseif inst:IsA("Animation") then
                return inst.AnimationId
            end
            return nil
        end)
        if ok and content and content ~= "" and not seen[content] then
            seen[content] = true
            table.insert(list, inst)
        end
    end

    for _, svc in ipairs({
        game:GetService("ReplicatedStorage"),
        game:GetService("Workspace"),
        game:GetService("StarterGui"),
        game:GetService("StarterPack"),
        game:GetService("Lighting"),
    }) do
        for _, inst in ipairs(svc:GetDescendants()) do
            tryAdd(inst)
        end
    end
    return list
end

script:SetAttribute("_startTime", tick())

-- Durée minimum d'affichage de l'écran de chargement (en secondes).
-- En Studio, les assets sont déjà locaux donc le preload est instantané ;
-- ce minimum garantit qu'on voit bien la barre se remplir.
local MIN_SHOW_TIME = 1.0

-- Lance le chargement par étapes dans un thread à part
task.spawn(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")

    -- ──────────────────────────────────────────────────────────
    -- ÉTAPE 1 : Attente des services critiques (0% → 15%)
    -- ──────────────────────────────────────────────────────────
    statusLabel.Text = "Initialisation des services..."
    targetProgress = 0.05

    ReplicatedStorage:WaitForChild("Remotes", 10)
    ReplicatedStorage:WaitForChild("Config", 10)
    ReplicatedStorage:WaitForChild("Data", 10)
    ReplicatedStorage:WaitForChild("Shared", 10)
    ReplicatedStorage:WaitForChild("Assets", 10)
    targetProgress = 0.15

    -- ──────────────────────────────────────────────────────────
    -- ÉTAPE 2 : Preload des assets par batchs (15% → 75%)
    -- ──────────────────────────────────────────────────────────
    statusLabel.Text = "Loading assets..."
    local assets = collectAssets()
    local total = #assets

    if total > 0 then
        -- ~25 batchs max, pour garder une animation fluide sans ralentir
        local batchSize = math.clamp(math.ceil(total / 25), 1, 16)
        local batch = {}
        local loaded = 0

        for i, asset in ipairs(assets) do
            table.insert(batch, asset)
            if #batch >= batchSize or i == total then
                pcall(function()
                    ContentProvider:PreloadAsync(batch)
                end)
                loaded = loaded + #batch
                targetProgress = 0.15 + (loaded / total) * 0.6
                batch = {}
                task.wait() -- un frame suffit pour que l'anim respire
            end
        end
    else
        targetProgress = 0.75
    end

    -- ──────────────────────────────────────────────────────────
    -- ÉTAPE 3 : Attendre que l'arène soit chargée (75% → 90%)
    -- ──────────────────────────────────────────────────────────
    statusLabel.Text = "Chargement de l'arène..."
    Workspace:WaitForChild("Arena", 15)
    Workspace:WaitForChild("Bases", 10)
    targetProgress = 0.90

    -- ──────────────────────────────────────────────────────────
    -- ÉTAPE 4 : Préparation du joueur (90% → 100%)
    -- ──────────────────────────────────────────────────────────
    statusLabel.Text = "Préparation du joueur..."
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    targetProgress = 1

    -- Délai minimum d'affichage (évite un flash trop court en Studio)
    local elapsed = tick() - script:GetAttribute("_startTime")
    if elapsed < MIN_SHOW_TIME then
        task.wait(MIN_SHOW_TIME - elapsed)
    end

    -- Fin : snap direct à 100% (plus de catch-up lent)
    displayedProgress = 1
    isDone            = true
    fill.Size          = UDim2.fromScale(1, 1)
    percentLabel.Text  = "100%"
    statusLabel.Text   = "Prêt !"

    -- Fade out
    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(background,   tweenInfo, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(logo,         tweenInfo, { ImageTransparency = 1 }):Play()
    TweenService:Create(bottomFade,   tweenInfo, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(barBackground,tweenInfo, { ImageTransparency = 1 }):Play()
    TweenService:Create(barFrame,     tweenInfo, { ImageTransparency = 1 }):Play()
    TweenService:Create(fill,         tweenInfo, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(percentLabel, tweenInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
    TweenService:Create(statusLabel,  tweenInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

    task.wait(0.35)
    screen:Destroy()
end)
