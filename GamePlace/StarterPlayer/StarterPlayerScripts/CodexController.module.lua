--[[
    CodexController.module.lua
    Modern Codex UI — matches Shop/LuckyBlock/SpinWheel design language
    Pill tabs, overlay, animations, card strokes & gradients
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig.module"))
local ResponsiveScale = require(ReplicatedStorage:WaitForChild("Shared")["ResponsiveScale.module"])

local CodexController = {}
CodexController._codexUnlocked = {}
CodexController._codexUI = nil
CodexController._initialized = false
CodexController._activeFilter = nil -- nil = all, or rarity string, or "_fusion"
CodexController._gridContainer = nil
CodexController._counterLabel = nil
CodexController._tabs = {}
CodexController._bottomText = nil
CodexController._progressFill = nil
CodexController._progressCount = nil
CodexController._isOpen = false
CodexController._mainFrame = nil
CodexController._overlay = nil
-- Fusion tab state
CodexController._fusionData = {}
CodexController._activeFusionTab = false
CodexController._rewardTrackContainer = nil
CodexController._fusionBottomBar = nil
CodexController._codexBottomBar = nil
-- Badge notification state
CodexController._seenCodexUnlocked = {} -- snapshot of codex when user last viewed
CodexController._newCodexCount = 0      -- count of new codex entries since last view
CodexController._unclaimedRewardsCount = 0 -- fusion rewards ready to claim
CodexController._codexButtonBadge = nil -- reference to badge on sidebar button
CodexController._fusionTabBadge = nil   -- reference to badge on fusion tab

-- ══════════════════════════════════════════
-- Visual constants (matching Shop style)
-- ══════════════════════════════════════════

-- Palette "brainrot Index" : vert vif + stroke noir épais, cards sombres à rayures
local COLORS = {
	Overlay = Color3.fromRGB(0, 0, 0),
	OverlayTransparency = 0.45,

	-- Panneau principal : grand cadre vert vif
	PanelBg = Color3.fromRGB(85, 200, 78),
	PanelStroke = Color3.fromRGB(0, 0, 0),
	HeaderBg = Color3.fromRGB(110, 220, 95),
	HeaderStripe = Color3.fromRGB(70, 180, 60),

	-- Tabs (réutilisés pour la pilule)
	TabActive = Color3.fromRGB(255, 255, 255),
	TabPill = Color3.fromRGB(40, 130, 35),

	-- Bouton X (style cartoon rouge)
	CloseBtn = Color3.fromRGB(220, 45, 45),
	CloseBtnHover = Color3.fromRGB(240, 70, 70),

	-- Cards type "tile sombre"
	CardBg = Color3.fromRGB(28, 32, 28),
	CardLocked = Color3.fromRGB(22, 26, 22),
	CardStroke = Color3.fromRGB(0, 0, 0),
	CardStrokeHover = Color3.fromRGB(255, 255, 255),
	CardStripe = Color3.fromRGB(60, 170, 55),
	CardInner = Color3.fromRGB(35, 45, 35),

	PreviewBg = Color3.fromRGB(20, 24, 20),

	-- Bottom bar
	ProgressBg = Color3.fromRGB(30, 90, 30),
	ProgressFill = Color3.fromRGB(140, 240, 100),
	BottomBg = Color3.fromRGB(45, 130, 45),
	BottomStroke = Color3.fromRGB(0, 0, 0),

	White = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(220, 240, 220),
	ScrollBar = Color3.fromRGB(40, 130, 35),

	-- Texte revenu / valeurs
	PriceText = Color3.fromRGB(140, 240, 100),
	PriceTextLocked = Color3.fromRGB(160, 200, 160),

	-- Fusion reward track
	RewardNodeLocked = Color3.fromRGB(45, 55, 45),
	RewardNodeReady = Color3.fromRGB(140, 240, 100),
	RewardNodeClaimed = Color3.fromRGB(0, 160, 80),
	RewardLine = Color3.fromRGB(30, 60, 30),
	RewardLineFilled = Color3.fromRGB(140, 240, 100),
	MultiplierGold = Color3.fromRGB(255, 200, 50),
	FusionTabColor = Color3.fromRGB(220, 130, 30),
}

local SIZES = {
	Panel = UDim2.new(0, 780, 0, 540),
	PanelClosed = UDim2.new(0, 0, 0, 0),
	CornerRadius = UDim.new(0, 14),
	SmallCorner = UDim.new(0, 10),
	TinyCorner = UDim.new(0, 6),
	PillCorner = UDim.new(0, 18),
}

-- ══════════════════════════════════════════
-- Helpers de style "cartoon"
-- ══════════════════════════════════════════

local function addTextOutline(label, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

-- Fond rayé en diagonale pour les cards (NumberSequence d'alternance)
local function addStripePattern(parent, stripeColor, transparency, rotation)
	-- Cadre interne pour ne pas casser le UICorner du parent
	local stripeFrame = Instance.new("Frame")
	stripeFrame.Name = "StripePattern"
	stripeFrame.Size = UDim2.new(1, 0, 1, 0)
	stripeFrame.BackgroundColor3 = stripeColor or Color3.fromRGB(60, 170, 55)
	stripeFrame.BackgroundTransparency = transparency or 0.55
	stripeFrame.BorderSizePixel = 0
	stripeFrame.ZIndex = 0
	stripeFrame.Parent = parent

	-- Hérite du UICorner du parent
	local parentCorner = parent:FindFirstChildOfClass("UICorner")
	if parentCorner then
		local c = Instance.new("UICorner")
		c.CornerRadius = parentCorner.CornerRadius
		c.Parent = stripeFrame
	end

	-- UIGradient avec rayures alternées via Transparency
	-- Roblox : max 20 keypoints pour NumberSequence; 4 points × 5 bandes = 20 max
	local stripes = Instance.new("UIGradient")
	stripes.Rotation = rotation or 35
	stripes.Color = ColorSequence.new(stripeColor or Color3.fromRGB(60, 170, 55))
	local kps = {}
	local n = 5
	for i = 0, n - 1 do
		local a = i / n
		local b = (i + 0.5) / n
		local c = (i + 1) / n
		table.insert(kps, NumberSequenceKeypoint.new(a, 1))
		table.insert(kps, NumberSequenceKeypoint.new(math.min(b, 1), 1))
		table.insert(kps, NumberSequenceKeypoint.new(math.min(b + 0.001, 1), 0))
		table.insert(kps, NumberSequenceKeypoint.new(math.min(c, 1), 0))
	end
	kps[1] = NumberSequenceKeypoint.new(0, kps[1].Value)
	kps[#kps] = NumberSequenceKeypoint.new(1, kps[#kps].Value)
	stripes.Transparency = NumberSequence.new(kps)
	stripes.Parent = stripeFrame
	return stripeFrame
end

-- Couleur d'UI à partir d'une teinte (référence rareté / Data)
local function lerpColor3(a, b, t)
	t = math.clamp(t, 0, 1)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local W = Color3.new(1, 1, 1)
local K = Color3.new(0, 0, 0)

-- Dérive panneau / barres / cartes à partir d'une couleur d'accent
local function buildRarityTheme(accent)
	local a = accent
	return {
		panelTop = lerpColor3(a, W, 0.4),
		panelBottom = lerpColor3(a, lerpColor3(a, K, 0.35), 0.5),
		header = lerpColor3(a, W, 0.45),
		tabPill = lerpColor3(a, K, 0.5),
		bookCover = lerpColor3(a, K, 0.55),
		cardStripe = lerpColor3(a, W, 0.2),
		progressBg = lerpColor3(a, K, 0.55),
		progressFill = lerpColor3(a, W, 0.3),
		bottomBar = lerpColor3(a, K, 0.42),
		scrollBar = lerpColor3(a, K, 0.4),
		priceText = lerpColor3(a, W, 0.35),
		priceTextLocked = lerpColor3(lerpColor3(a, W, 0.2), lerpColor3(a, W, 0.6), 0.4),
		subText = lerpColor3(lerpColor3(a, W, 0.3), lerpColor3(a, W, 0.75), 0.5),
		partComplete = lerpColor3(a, W, 0.3),
	}
end

-- Réf. COULEUR rareté (Common = blanc dans data → on teinte en vert menthe lisible)
function CodexController:_GetFilterAccent()
	if self._activeFilter == "_fusion" then
		return COLORS.FusionTabColor
	end
	if not self._activeFilter then
		return Color3.fromRGB(90, 205, 80)
	end
	local rInfo = BrainrotData.Rarities[self._activeFilter]
	if not rInfo or not rInfo.Color then
		return Color3.fromRGB(90, 205, 80)
	end
	if self._activeFilter == "Common" then
		return lerpColor3(rInfo.Color, Color3.fromRGB(100, 210, 90), 0.55)
	end
	return rInfo.Color
end

-- Applique thème (panneau, header, onglets, bas de page) selon l’onglet actif
function CodexController:_ApplyRarityTheme()
	local accent = self:_GetFilterAccent()
	local t = buildRarityTheme(accent)
	self._rarityTheme = t

	if self._panelGradient and self._panelGradient.Parent then
		self._panelGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, t.panelTop),
			ColorSequenceKeypoint.new(1, t.panelBottom),
		})
	end

	if self._headerFrame then
		self._headerFrame.BackgroundColor3 = t.header
	end
	if self._headerBottomCover then
		self._headerBottomCover.BackgroundColor3 = t.header
	end
	if self._bookIconHolder then
		self._bookIconHolder.BackgroundColor3 = t.bookCover
	end

	if self._tabPillContainer and self._tabPillContainer.Parent then
		self._tabPillContainer.BackgroundColor3 = t.tabPill
	end

	if self._progressBg and self._progressBg.Parent then
		self._progressBg.BackgroundColor3 = t.progressBg
	end
	if self._progressFill and self._progressFill.Parent then
		self._progressFill.BackgroundColor3 = t.progressFill
	end
	if self._codexBottomBar and self._codexBottomBar.Parent then
		self._codexBottomBar.BackgroundColor3 = t.bottomBar
	end
	if self._gridContainer and self._gridContainer.Parent then
		self._gridContainer.ScrollBarImageColor3 = t.scrollBar
	end
	if self._rewardTrackContainer and self._rewardTrackContainer.Parent then
		self._rewardTrackContainer.ScrollBarImageColor3 = t.scrollBar
	end
	if self._fusionBottomBar and self._fusionBottomBar.Parent then
		self._fusionBottomBar.BackgroundColor3 = t.bottomBar
	end
end

-- ══════════════════════════════════════════
-- Rarity display names
-- ══════════════════════════════════════════

local RARITY_DISPLAY = {
	Common = "Common",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
}

-- ══════════════════════════════════════════
-- Set display names (kept for reference)
-- ══════════════════════════════════════════

local SET_DISPLAY_NAMES = {
	brrbrrPatapim = "Brr Brr Patapim",
	TralaleroTralala = "Tralalero Tralala",
	CactoHipopoTamo = "Cacto Hipopo Tamo",
	PiccioneMacchina = "Piccione Macchina",
	GirafaCelestre = "Girafa Celestre",
	LiriliLarila = "Liril\xC3\xAC Laril\xC3\xA0",
	TripiTropiTropaTripa = "Tripi Tropi",
	Talpadifero = "Talpa di Fero",
	GraipusMedussi = "Graipus Medussi",
	BombardiroCrocodilo = "Bombardiro Crocodilo",
	SpioniroGolubiro = "Spioniro Golubiro",
	ZibraZubraZibralini = "Zibra Zubra Zibralini",
	TorrtuginniDragonfrutini = "Torrtuginni Dragonfrutini",
}

-- ══════════════════════════════════════════
-- Helpers
-- ══════════════════════════════════════════

local function getPartsUnlocked(unlocked, setName)
	local d = unlocked[setName]
	if d == true then return { Head = true, Body = true, Legs = true } end
	if type(d) == "table" then
		return { Head = d.Head == true, Body = d.Body == true, Legs = d.Legs == true }
	end
	return { Head = false, Body = false, Legs = false }
end

-- ══════════════════════════════════════════
-- Initialization
-- ══════════════════════════════════════════

function CodexController:_EnsureUI()
	local gui = player:WaitForChild("PlayerGui")
	local existing = self._codexUI
	if existing and existing.Parent == gui then
		return
	end

	-- Re-fetch (either first time, or PlayerGui was reset on respawn)
	self._codexUI = gui:WaitForChild("CodexUI")
	self._codexUI.ResetOnSpawn = false

	-- Reset UI references (children were destroyed with the old ScreenGui)
	self._isOpen = false
	self._tabs = {}
	self._gridContainer = nil
	self._counterLabel = nil
	self._mainFrame = nil
	self._overlay = nil
	self._bottomText = nil
	self._progressFill = nil
	self._progressBg = nil
	self._progressCount = nil
	self._rewardTrackContainer = nil
	self._fusionBottomBar = nil
	self._codexBottomBar = nil
	self._panelGradient = nil
	self._headerFrame = nil
	self._headerBottomCover = nil
	self._bookIconHolder = nil
	self._tabPillContainer = nil
	self._rarityTheme = nil

	-- Remove any pre-existing children
	for _, child in ipairs(self._codexUI:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	ResponsiveScale.Apply(self._codexUI)
	self:_BuildUI()
	self._codexUI.Enabled = false
end

function CodexController:Init()
	if self._initialized then return end

	self:_EnsureUI()

	-- Rebuild on respawn if ResetPlayerGuiOnSpawn destroyed the UI
	player.CharacterAdded:Connect(function()
		task.defer(function()
			self:_EnsureUI()
		end)
	end)

	-- Connect SyncCodex
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local syncCodex = Remotes:WaitForChild("SyncCodex")
	syncCodex.OnClientEvent:Connect(function(codexUnlocked)
		self:UpdateCodex(codexUnlocked or {})
	end)

	-- Connect SyncFusionData
	local syncFusion = Remotes:FindFirstChild("SyncFusionData")
	if syncFusion then
		syncFusion.OnClientEvent:Connect(function(data)
			self._fusionData = data or {}
			if self._activeFusionTab then
				self:RefreshFusionList()
			end
			pcall(function() self:RefreshBadges() end)
		end)
	end

	self._initialized = true
end

-- ══════════════════════════════════════════
-- UI Construction
-- ══════════════════════════════════════════

function CodexController:_BuildUI()
	local screenGui = self._codexUI

	-- ═══ OVERLAY ═══
	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = COLORS.Overlay
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Parent = screenGui
	self._overlay = overlay

	overlay.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- ═══ MAIN FRAME ═══
	local mainFrame = Instance.new("TextButton")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = SIZES.PanelClosed
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = COLORS.PanelBg
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Text = ""
	mainFrame.AutoButtonColor = false
	mainFrame.Parent = overlay
	self._mainFrame = mainFrame

	Instance.new("UICorner", mainFrame).CornerRadius = SIZES.CornerRadius

	-- Stroke noir épais "cartoon"
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.PanelStroke
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = mainFrame

	-- Léger gradient vertical pour relief
	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 230, 110)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 175, 60)),
	})
	panelGradient.Rotation = 90
	panelGradient.Parent = mainFrame
	self._panelGradient = panelGradient

	-- ═══ HEADER ═══
	self:_BuildHeader(mainFrame)

	-- ═══ TAB BAR ═══
	self:_BuildTabBar(mainFrame)

	-- ═══ GRID ═══
	self:_BuildGrid(mainFrame)

	-- ═══ BOTTOM BAR ═══
	self:_BuildBottomBar(mainFrame)

	-- ═══ FUSION BOTTOM BAR (battle pass) ═══
	self:_BuildFusionBottomBar(mainFrame)

	self:_ApplyRarityTheme()
end

-- ══════════════════════════════════════════
-- Header
-- ══════════════════════════════════════════

function CodexController:_BuildHeader(mainFrame)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 56)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundColor3 = COLORS.HeaderBg
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	Instance.new("UICorner", header).CornerRadius = SIZES.CornerRadius

	-- Couvre les coins inférieurs pour effet "bandeau"
	local bottomCover = Instance.new("Frame")
	bottomCover.Size = UDim2.new(1, 0, 0, 16)
	bottomCover.Position = UDim2.new(0, 0, 1, -16)
	bottomCover.BackgroundColor3 = COLORS.HeaderBg
	bottomCover.BorderSizePixel = 0
	bottomCover.Parent = header

	-- Ligne noire de séparation en bas du bandeau
	local sep = Instance.new("Frame")
	sep.Name = "HeaderSep"
	sep.Size = UDim2.new(1, 0, 0, 3)
	sep.Position = UDim2.new(0, 0, 1, -3)
	sep.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	sep.BorderSizePixel = 0
	sep.ZIndex = 3
	sep.Parent = header

	-- Icône "livre" stylisée (Frame composé : couverture verte sombre + page blanche)
	local bookHolder = Instance.new("Frame")
	bookHolder.Name = "BookIcon"
	bookHolder.Size = UDim2.new(0, 38, 0, 32)
	bookHolder.Position = UDim2.new(0, 18, 0.5, 0)
	bookHolder.AnchorPoint = Vector2.new(0, 0.5)
	bookHolder.BackgroundColor3 = Color3.fromRGB(40, 140, 50)
	bookHolder.BorderSizePixel = 0
	bookHolder.Parent = header
	Instance.new("UICorner", bookHolder).CornerRadius = UDim.new(0, 4)
	local bookStroke = Instance.new("UIStroke")
	bookStroke.Color = Color3.fromRGB(0, 0, 0)
	bookStroke.Thickness = 2
	bookStroke.Parent = bookHolder

	local bookPage = Instance.new("Frame")
	bookPage.Name = "Page"
	bookPage.Size = UDim2.new(0, 22, 0, 24)
	bookPage.Position = UDim2.new(0.5, 0, 0.5, 0)
	bookPage.AnchorPoint = Vector2.new(0.5, 0.5)
	bookPage.BackgroundColor3 = Color3.fromRGB(245, 245, 220)
	bookPage.BorderSizePixel = 0
	bookPage.Parent = bookHolder
	Instance.new("UICorner", bookPage).CornerRadius = UDim.new(0, 2)
	local pageStroke = Instance.new("UIStroke")
	pageStroke.Color = Color3.fromRGB(0, 0, 0)
	pageStroke.Thickness = 1.5
	pageStroke.Parent = bookPage

	for i = 1, 3 do
		local lineDeco = Instance.new("Frame")
		lineDeco.Size = UDim2.new(0.7, 0, 0, 2)
		lineDeco.Position = UDim2.new(0.5, 0, 0, 5 + (i - 1) * 6)
		lineDeco.AnchorPoint = Vector2.new(0.5, 0)
		lineDeco.BackgroundColor3 = Color3.fromRGB(120, 130, 100)
		lineDeco.BorderSizePixel = 0
		lineDeco.Parent = bookPage
	end

	-- Titre "Index" (réserve l'espace compteur + croix à droite)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -240, 1, 0)
	title.Position = UDim2.new(0, 64, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Index"
	title.TextColor3 = COLORS.White
	title.TextSize = 36
	title.Font = Enum.Font.LuckiestGuy
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = header
	addTextOutline(title, 3)

	-- Compteur : ancré à droite mais à GAUCHE de la croix (zéro chevauchement)
	-- Croix = 40px + marge droite 10px → le bord droit du compteur reste à -58 px du bord parent
	local closeReserve = 10 + 40 + 8
	local counter = Instance.new("TextLabel")
	counter.Name = "Counter"
	counter.Size = UDim2.new(0, 150, 1, 0)
	counter.Position = UDim2.new(1, -closeReserve, 0.5, 0)
	counter.AnchorPoint = Vector2.new(1, 0.5)
	counter.BackgroundTransparency = 1
	counter.Text = "0/0"
	counter.TextColor3 = COLORS.White
	counter.TextSize = 20
	counter.Font = Enum.Font.LuckiestGuy
	counter.TextXAlignment = Enum.TextXAlignment.Right
	counter.ZIndex = 2
	counter.Parent = header
	self._counterLabel = counter
	addTextOutline(counter, 2.5)

	-- Bouton X carré (cartoon) — au bord, au-dessus du compteur si collision extrême
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.ZIndex = 5
	closeBtn.BackgroundColor3 = COLORS.CloseBtn
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = COLORS.White
	closeBtn.TextSize = 26
	closeBtn.Font = Enum.Font.LuckiestGuy
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Color3.fromRGB(0, 0, 0)
	closeStroke.Thickness = 3
	closeStroke.LineJoinMode = Enum.LineJoinMode.Round
	closeStroke.Parent = closeBtn
	addTextOutline(closeBtn, 2.5)

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = COLORS.CloseBtnHover
		}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = COLORS.CloseBtn
		}):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	self._headerFrame = header
	self._headerBottomCover = bottomCover
	self._bookIconHolder = bookHolder
end

-- ══════════════════════════════════════════
-- Tab Bar (pill-shaped, like Shop)
-- ══════════════════════════════════════════

function CodexController:_BuildTabBar(mainFrame)
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, 0, 0, 50)
	tabBar.Position = UDim2.new(0, 0, 0, 56)
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0
	tabBar.Parent = mainFrame

	-- Pill container avec stroke noir cartoon
	local pillContainer = Instance.new("Frame")
	pillContainer.Name = "PillContainer"
	-- Largeur relative : s'adapte au panneau (mobile / UIScale)
	pillContainer.Size = UDim2.new(1, -20, 0, 38)
	pillContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	pillContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	pillContainer.BackgroundColor3 = COLORS.TabPill
	pillContainer.BorderSizePixel = 0
	pillContainer.Parent = tabBar

	Instance.new("UICorner", pillContainer).CornerRadius = SIZES.PillCorner

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = Color3.fromRGB(0, 0, 0)
	pillStroke.Thickness = 2.5
	pillStroke.LineJoinMode = Enum.LineJoinMode.Round
	pillStroke.Parent = pillContainer

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = pillContainer

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 3)
	padding.PaddingRight = UDim.new(0, 3)
	padding.Parent = pillContainer

	self._tabPillContainer = pillContainer

	-- Sort rarities by DisplayOrder
	local rarityOrder = {}
	for rarity, info in pairs(BrainrotData.Rarities) do
		table.insert(rarityOrder, { name = rarity, order = info.DisplayOrder, color = info.Color })
	end
	table.sort(rarityOrder, function(a, b) return a.order < b.order end)

	-- Build tabs: "All" + each rarity
	local allTabs = { { name = nil, display = "All" } }
	for _, r in ipairs(rarityOrder) do
		table.insert(allTabs, { name = r.name, display = RARITY_DISPLAY[r.name] or r.name, color = r.color })
	end

	local totalTabCount = #allTabs + 1 -- +1 for Fusion tab
	-- ~736 px utiles (pilule = largeur panneau - marges) → onglets respirent sur tél. avec UIScale
	local tabWidth = math.max(50, math.floor(736 / totalTabCount) - 1)
	self._tabs = {}

	for i, tabInfo in ipairs(allTabs) do
		local rarity = tabInfo.name
		local displayName = tabInfo.display

		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "Tab_" .. (rarity or "All")
		tabBtn.Size = UDim2.new(0, tabWidth, 0, 32)
		tabBtn.BackgroundTransparency = 1
		tabBtn.BorderSizePixel = 0
		tabBtn.Text = ""
		tabBtn.AutoButtonColor = false
		tabBtn.LayoutOrder = i
		tabBtn.Parent = pillContainer

		Instance.new("UICorner", tabBtn).CornerRadius = SIZES.PillCorner

		-- Fill (visible when active)
		local tabFill = Instance.new("Frame")
		tabFill.Name = "Fill"
		tabFill.Size = UDim2.new(1, 0, 1, 0)
		tabFill.BackgroundColor3 = COLORS.TabActive
		tabFill.BackgroundTransparency = (rarity == nil) and 0 or 1 -- "All" active by default
		tabFill.BorderSizePixel = 0
		tabFill.Parent = tabBtn

		Instance.new("UICorner", tabFill).CornerRadius = SIZES.PillCorner

		-- Label
		local tabLabel = Instance.new("TextLabel")
		tabLabel.Name = "Label"
		tabLabel.Size = UDim2.new(1, 0, 1, 0)
		tabLabel.BackgroundTransparency = 1
		tabLabel.Text = displayName
		tabLabel.TextColor3 = COLORS.White
		tabLabel.TextSize = 16
		tabLabel.Font = Enum.Font.LuckiestGuy
		tabLabel.ZIndex = 2
		tabLabel.Parent = tabBtn
		addTextOutline(tabLabel, 2)

		tabBtn.MouseButton1Click:Connect(function()
			self:SetFilter(rarity)
		end)

		self._tabs[rarity or "_all"] = { button = tabBtn, fill = tabFill }
	end

	-- Fusion tab (special)
	local fusionTabBtn = Instance.new("TextButton")
	fusionTabBtn.Name = "Tab_Fusion"
	fusionTabBtn.Size = UDim2.new(0, tabWidth, 0, 32)
	fusionTabBtn.BackgroundTransparency = 1
	fusionTabBtn.BorderSizePixel = 0
	fusionTabBtn.Text = ""
	fusionTabBtn.AutoButtonColor = false
	fusionTabBtn.LayoutOrder = 0
	fusionTabBtn.Parent = pillContainer

	Instance.new("UICorner", fusionTabBtn).CornerRadius = SIZES.PillCorner

	local fusionFill = Instance.new("Frame")
	fusionFill.Name = "Fill"
	fusionFill.Size = UDim2.new(1, 0, 1, 0)
	fusionFill.BackgroundColor3 = COLORS.FusionTabColor
	fusionFill.BackgroundTransparency = 1
	fusionFill.BorderSizePixel = 0
	fusionFill.Parent = fusionTabBtn

	Instance.new("UICorner", fusionFill).CornerRadius = SIZES.PillCorner

	local fusionLabel = Instance.new("TextLabel")
	fusionLabel.Name = "Label"
	fusionLabel.Size = UDim2.new(1, 0, 1, 0)
	fusionLabel.BackgroundTransparency = 1
	fusionLabel.Text = "Fusion"
	fusionLabel.TextColor3 = COLORS.White
	fusionLabel.TextSize = 16
	fusionLabel.Font = Enum.Font.LuckiestGuy
	fusionLabel.ZIndex = 2
	fusionLabel.Parent = fusionTabBtn
	addTextOutline(fusionLabel, 2)

	fusionTabBtn.MouseButton1Click:Connect(function()
		self:SetFilter("_fusion")
	end)

	self._tabs["_fusion"] = { button = fusionTabBtn, fill = fusionFill }

	-- Badge on Fusion tab
	local fusionBadge = Instance.new("TextLabel")
	fusionBadge.Name = "Badge"
	fusionBadge.Size = UDim2.new(0, 20, 0, 20)
	fusionBadge.Position = UDim2.new(1, -6, 0, -6)
	fusionBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	fusionBadge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	fusionBadge.BorderSizePixel = 0
	fusionBadge.Text = "0"
	fusionBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	fusionBadge.TextSize = 11
	fusionBadge.Font = Enum.Font.GothamBold
	fusionBadge.ZIndex = 5
	fusionBadge.Visible = false
	fusionBadge.Parent = fusionTabBtn
	Instance.new("UICorner", fusionBadge).CornerRadius = UDim.new(1, 0)
	self._fusionTabBadge = fusionBadge
end

-- ══════════════════════════════════════════
-- Grid
-- ══════════════════════════════════════════

function CodexController:_BuildGrid(mainFrame)
	local gridScroll = Instance.new("ScrollingFrame")
	gridScroll.Name = "GridScroll"
	gridScroll.Size = UDim2.new(1, -40, 1, -190)
	gridScroll.Position = UDim2.new(0, 20, 0, 115)
	gridScroll.BackgroundTransparency = 1
	gridScroll.BorderSizePixel = 0
	gridScroll.ScrollBarThickness = 6
	gridScroll.ScrollBarImageColor3 = COLORS.ScrollBar
	gridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridScroll.Parent = mainFrame

	-- 4 cartes / ligne : 4*w + 3*pad ≈ 740 (largeur utile ~740 dans un panneau 780)
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 170, 0, 210)
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.Parent = gridScroll

	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 5)
	gridPad.PaddingBottom = UDim.new(0, 5)
	gridPad.Parent = gridScroll

	self._gridContainer = gridScroll
end

-- ══════════════════════════════════════════
-- Bottom Bar
-- ══════════════════════════════════════════

function CodexController:_BuildBottomBar(mainFrame)
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, -40, 0, 50)
	bottomBar.Position = UDim2.new(0, 20, 1, -60)
	bottomBar.BackgroundColor3 = COLORS.BottomBg
	bottomBar.BorderSizePixel = 0
	bottomBar.Parent = mainFrame
	self._codexBottomBar = bottomBar

	Instance.new("UICorner", bottomBar).CornerRadius = SIZES.SmallCorner

	local bottomStroke = Instance.new("UIStroke")
	bottomStroke.Color = COLORS.BottomStroke
	bottomStroke.Thickness = 2.5
	bottomStroke.LineJoinMode = Enum.LineJoinMode.Round
	bottomStroke.Parent = bottomBar

	-- Texte info
	local bottomText = Instance.new("TextLabel")
	bottomText.Size = UDim2.new(0.55, -10, 0, 22)
	bottomText.Position = UDim2.new(0, 14, 0, 4)
	bottomText.BackgroundTransparency = 1
	bottomText.Text = "Collect Brainrots to unlock bonuses!"
	bottomText.TextColor3 = COLORS.White
	bottomText.TextSize = 14
	bottomText.Font = Enum.Font.LuckiestGuy
	bottomText.TextXAlignment = Enum.TextXAlignment.Left
	bottomText.TextTruncate = Enum.TextTruncate.AtEnd
	bottomText.Parent = bottomBar
	self._bottomText = bottomText
	addTextOutline(bottomText, 2)

	-- Progress bar
	local progBg = Instance.new("Frame")
	progBg.Size = UDim2.new(1, -28, 0, 16)
	progBg.Position = UDim2.new(0, 14, 0, 28)
	progBg.BackgroundColor3 = COLORS.ProgressBg
	progBg.BorderSizePixel = 0
	progBg.Parent = bottomBar

	Instance.new("UICorner", progBg).CornerRadius = UDim.new(0, 8)

	local progBgStroke = Instance.new("UIStroke")
	progBgStroke.Color = Color3.fromRGB(0, 0, 0)
	progBgStroke.Thickness = 2
	progBgStroke.Parent = progBg

	local progFill = Instance.new("Frame")
	progFill.Size = UDim2.new(0, 0, 1, 0)
	progFill.BackgroundColor3 = COLORS.ProgressFill
	progFill.BorderSizePixel = 0
	progFill.Parent = progBg

	Instance.new("UICorner", progFill).CornerRadius = UDim.new(0, 8)
	self._progressFill = progFill
	self._progressBg = progBg

	-- Compteur (à droite, par-dessus la barre)
	local progCount = Instance.new("TextLabel")
	progCount.Size = UDim2.new(1, -10, 1, 0)
	progCount.BackgroundTransparency = 1
	progCount.Text = "0/0"
	progCount.TextColor3 = COLORS.White
	progCount.TextSize = 13
	progCount.Font = Enum.Font.LuckiestGuy
	progCount.TextXAlignment = Enum.TextXAlignment.Right
	progCount.ZIndex = 3
	progCount.Parent = progBg
	self._progressCount = progCount
	addTextOutline(progCount, 1.8)
end

-- ══════════════════════════════════════════
-- Tab switching
-- ══════════════════════════════════════════

function CodexController:SetFilter(rarity)
	self._activeFilter = rarity
	self._activeFusionTab = (rarity == "_fusion")

	for key, tabData in pairs(self._tabs) do
		local isActive = (key == "_all" and rarity == nil) or (key == rarity)
		TweenService:Create(tabData.fill, TweenInfo.new(0.15), {
			BackgroundTransparency = isActive and 0 or 1
		}):Play()
	end

	-- Toggle bottom bars
	if self._codexBottomBar then
		self._codexBottomBar.Visible = not self._activeFusionTab
	end
	if self._fusionBottomBar then
		self._fusionBottomBar.Visible = self._activeFusionTab
	end

	-- Adjust grid size for fusion (taller bottom bar)
	if self._gridContainer then
		if self._activeFusionTab then
			self._gridContainer.Size = UDim2.new(1, -40, 1, -250)
		else
			self._gridContainer.Size = UDim2.new(1, -40, 1, -190)
		end
	end

	self:_ApplyRarityTheme()

	if self._activeFusionTab then
		self:RefreshFusionList()
	else
		self:RefreshList()
	end
end

-- ══════════════════════════════════════════
-- 3D Assembly for ViewportFrame
-- ══════════════════════════════════════════

function CodexController:_AssemblePreviewModel(setName)
	local setData = BrainrotData.Sets[setName]
	if not setData then return nil end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then return nil end
	local templatesFolder = assetsFolder:FindFirstChild("BodyPartTemplates")
	if not templatesFolder then return nil end

	local headFolder = templatesFolder:FindFirstChild("HeadTemplate")
	local bodyFolder = templatesFolder:FindFirstChild("BodyTemplate")
	local legsFolder = templatesFolder:FindFirstChild("LegsTemplate")

	local headTN = setData.Head and setData.Head.TemplateName or ""
	local bodyTN = setData.Body and setData.Body.TemplateName or ""
	local legsTN = setData.Legs and setData.Legs.TemplateName or ""

	local headSrc = (headTN ~= "" and headFolder) and headFolder:FindFirstChild(headTN) or nil
	local bodySrc = (bodyTN ~= "" and bodyFolder) and bodyFolder:FindFirstChild(bodyTN) or nil
	local legsSrc = (legsTN ~= "" and legsFolder) and legsFolder:FindFirstChild(legsTN) or nil

	if not headSrc and not bodySrc and not legsSrc then return nil end

	local headModel = headSrc and headSrc:Clone() or nil
	local bodyModel = bodySrc and bodySrc:Clone() or nil
	local legsModel = legsSrc and legsSrc:Clone() or nil

	local headPart = headModel and headModel.PrimaryPart
	local bodyPart = bodyModel and bodyModel.PrimaryPart
	local legsPart = legsModel and legsModel.PrimaryPart

	local function cleanModel(m)
		if not m then return end
		for _, desc in ipairs(m:GetDescendants()) do
			if desc:IsA("BillboardGui") then
				desc:Destroy()
			elseif desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
			end
		end
	end

	cleanModel(headModel)
	cleanModel(bodyModel)
	cleanModel(legsModel)

	local function repositionModel(subModel, primaryPart, targetCFrame)
		if not subModel or not primaryPart then return end
		local delta = targetCFrame * primaryPart.CFrame:Inverse()
		for _, desc in ipairs(subModel:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.CFrame = delta * desc.CFrame
			end
		end
	end

	-- Position Legs at origin
	if legsModel and legsPart then
		local legsTopAtt = legsPart:FindFirstChild("TopAttachment")
		local legsOrientation = legsTopAtt and legsTopAtt.CFrame.Rotation or CFrame.new()
		repositionModel(legsModel, legsPart, CFrame.new(0, legsPart.Size.Y / 2, 0) * legsOrientation)
	end

	-- Body -> Legs via Attachments
	if bodyModel and bodyPart then
		if legsPart then
			local bba = bodyPart:FindFirstChild("BottomAttachment")
			local lta = legsPart:FindFirstChild("TopAttachment")
			if bba and lta then
				local targetCF = legsPart.CFrame * lta.CFrame * bba.CFrame:Inverse()
				repositionModel(bodyModel, bodyPart, targetCF)
			else
				repositionModel(bodyModel, bodyPart, CFrame.new(0, legsPart.Size.Y + bodyPart.Size.Y / 2, 0))
			end
		else
			-- No legs: place body at origin with its own orientation
			local bba = bodyPart:FindFirstChild("BottomAttachment")
			local bodyOrientation = bba and bba.CFrame.Rotation or CFrame.new()
			repositionModel(bodyModel, bodyPart, CFrame.new(0, bodyPart.Size.Y / 2, 0) * bodyOrientation)
		end
	end

	-- Head -> Body via Attachments (or Head -> Legs if no Body)
	if headModel and headPart then
		if bodyPart then
			local hba = headPart:FindFirstChild("BottomAttachment")
			local bta = bodyPart:FindFirstChild("TopAttachment")
			if hba and bta then
				local targetCF = bodyPart.CFrame * bta.CFrame * hba.CFrame:Inverse()
				repositionModel(headModel, headPart, targetCF)
			else
				repositionModel(headModel, headPart, bodyPart.CFrame * CFrame.new(0, bodyPart.Size.Y / 2 + headPart.Size.Y / 2, 0))
			end
		elseif legsPart then
			-- No body: stack head on top of legs using TopAttachment position
			local lta = legsPart:FindFirstChild("TopAttachment")
			if lta then
				local topWorldPos = (legsPart.CFrame * lta.CFrame).Position
				repositionModel(headModel, headPart, CFrame.new(topWorldPos.X, topWorldPos.Y + headPart.Size.Y / 2, topWorldPos.Z) * legsPart.CFrame.Rotation)
			else
				repositionModel(headModel, headPart, CFrame.new(0, legsPart.Size.Y + headPart.Size.Y / 2, 0))
			end
		else
			repositionModel(headModel, headPart, CFrame.new(0, headPart.Size.Y / 2, 0))
		end
	end

	local model = Instance.new("Model")
	model.Name = "Preview_" .. setName

	if legsModel then legsModel.Parent = model end
	if bodyModel then bodyModel.Parent = model end
	if headModel then headModel.Parent = model end

	model.PrimaryPart = bodyPart or headPart or legsPart

	return model, headModel, bodyModel, legsModel
end

-- ══════════════════════════════════════════
-- Card creation (modern style)
-- ══════════════════════════════════════════

function CodexController:_CreateCard(setName, setData, isDiscovered, layoutOrder, unlockedParts, totalParts, partsUnlocked)
	local theme = self._rarityTheme
	if not theme then
		theme = buildRarityTheme(self:_GetFilterAccent())
	end

	unlockedParts = unlockedParts or 0
	totalParts = totalParts or 3
	local rarity = setData.Rarity or "Common"
	local rarityInfo = BrainrotData.Rarities[rarity] or {}
	local rarityColor = rarityInfo.Color or Color3.fromRGB(140, 240, 100)

	-- Nom dynamique selon les parts débloquées
	local nameParts = {}
	for _, partType in ipairs({"Head", "Body", "Legs"}) do
		local partInfo = setData[partType]
		if partInfo and partInfo.TemplateName and partInfo.TemplateName ~= "" then
			if partsUnlocked and partsUnlocked[partType] then
				table.insert(nameParts, partInfo.DisplayName)
			else
				table.insert(nameParts, "???")
			end
		end
	end
	local dynamicName = table.concat(nameParts, " ")

	-- Revenu total/sec du set complet
	local totalGain = 0
	for _, partType in ipairs({"Head", "Body", "Legs"}) do
		local p = setData[partType]
		if p and p.GainPerSec then
			totalGain = totalGain + (tonumber(p.GainPerSec) or 0)
		end
	end

	local cardBg = isDiscovered and COLORS.CardBg or COLORS.CardLocked

	local card = Instance.new("Frame")
	card.Name = "Card_" .. setName
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = cardBg
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	Instance.new("UICorner", card).CornerRadius = SIZES.SmallCorner

	-- Stroke noir cartoon épais
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = COLORS.CardStroke
	cardStroke.Thickness = 3
	cardStroke.LineJoinMode = Enum.LineJoinMode.Round
	cardStroke.Parent = card

	-- Rayures = couleur de l'onglet / rareté actifs
	addStripePattern(card, theme.cardStripe, 0.65, 35)

	-- Hover : stroke devient blanc puis revient
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TweenService:Create(cardStroke, TweenInfo.new(0.2), {
				Color = COLORS.CardStrokeHover,
				Thickness = 4
			}):Play()
		end
	end)
	card.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TweenService:Create(cardStroke, TweenInfo.new(0.2), {
				Color = COLORS.CardStroke,
				Thickness = 3
			}):Play()
		end
	end)

	-- ── Prix passif "$X/s" en haut à droite (tinte rareté) ──
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(1, -12, 0, 20)
	priceLabel.Position = UDim2.new(0, 6, 0, 4)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = string.format("$%d/s", totalGain)
	priceLabel.TextColor3 = isDiscovered and theme.priceText or theme.priceTextLocked
	priceLabel.TextSize = 18
	priceLabel.Font = Enum.Font.LuckiestGuy
	priceLabel.TextXAlignment = Enum.TextXAlignment.Right
	priceLabel.TextYAlignment = Enum.TextYAlignment.Center
	priceLabel.ZIndex = 4
	priceLabel.Parent = card
	addTextOutline(priceLabel, 2.2)

	-- Zone preview (hauteur réduite : grille 4 col × cartes 210px de haut)
	local previewFrame = Instance.new("Frame")
	previewFrame.Name = "PreviewFrame"
	previewFrame.Size = UDim2.new(1, -12, 0, 115)
	previewFrame.Position = UDim2.new(0, 6, 0, 28)
	previewFrame.BackgroundTransparency = 1
	previewFrame.BorderSizePixel = 0
	previewFrame.ClipsDescendants = true
	previewFrame.ZIndex = 2
	previewFrame.Parent = card

	-- ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.ZIndex = 2
	viewport.Parent = previewFrame

	local previewModel, headSubModel, bodySubModel, legsSubModel = self:_AssemblePreviewModel(setName)
	if previewModel then
		local function applyBlackout(subModel)
			if not subModel then return end
			for _, desc in ipairs(subModel:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Color = Color3.fromRGB(15, 20, 30)
					desc.Material = Enum.Material.SmoothPlastic
					if desc:IsA("MeshPart") then
						desc.TextureID = ""
					end
					for _, c in ipairs(desc:GetChildren()) do
						if c:IsA("Decal") or c:IsA("Texture") or c:IsA("SurfaceGui") then
							c:Destroy()
						elseif c:IsA("SpecialMesh") then
							c.TextureId = ""
						end
					end
				end
			end
		end

		local pl = partsUnlocked or {}
		if not pl.Head then applyBlackout(headSubModel) end
		if not pl.Body then applyBlackout(bodySubModel) end
		if not pl.Legs then applyBlackout(legsSubModel) end

		previewModel.Parent = viewport

		local camera = Instance.new("Camera")
		viewport.CurrentCamera = camera
		camera.Parent = viewport
		camera.FieldOfView = 50

		-- Compute tight bounding box from visible parts only
		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		local partCount = 0
		for _, desc in ipairs(previewModel:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Transparency < 1 then
				local pos = desc.CFrame.Position
				local half = desc.Size / 2
				minX = math.min(minX, pos.X - half.X)
				maxX = math.max(maxX, pos.X + half.X)
				minY = math.min(minY, pos.Y - half.Y)
				maxY = math.max(maxY, pos.Y + half.Y)
				minZ = math.min(minZ, pos.Z - half.Z)
				maxZ = math.max(maxZ, pos.Z + half.Z)
				partCount = partCount + 1
			end
		end
		if partCount > 0 then
			local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
			local sizeX, sizeY, sizeZ = maxX - minX, maxY - minY, maxZ - minZ
			local maxDim = math.max(sizeX, sizeY, sizeZ)
			local dist = maxDim * 1.2
			camera.CFrame = CFrame.new(
				center + Vector3.new(dist * 0.3, dist * 0.2, dist),
				center
			)
		end
	else
		local ph = Instance.new("TextLabel")
		ph.Size = UDim2.new(1, 0, 1, 0)
		ph.BackgroundTransparency = 1
		ph.Text = "?"
		ph.TextColor3 = Color3.fromRGB(15, 20, 15)
		ph.TextSize = 64
		ph.Font = Enum.Font.LuckiestGuy
		ph.ZIndex = 3
		ph.Parent = previewFrame
		addTextOutline(ph, 3, Color3.fromRGB(0, 0, 0))
	end

	-- Compteur de parts (en bas à droite, type "1/3")
	local partsLabel = Instance.new("TextLabel")
	partsLabel.Name = "PartsLabel"
	partsLabel.Size = UDim2.new(0, 56, 0, 18)
	partsLabel.Position = UDim2.new(1, -6, 0, 148)
	partsLabel.AnchorPoint = Vector2.new(1, 0)
	partsLabel.BackgroundTransparency = 1
	partsLabel.Text = unlockedParts .. "/" .. totalParts
	partsLabel.TextColor3 = (unlockedParts >= totalParts and totalParts > 0)
		and theme.partComplete or theme.subText
	partsLabel.TextSize = 15
	partsLabel.Font = Enum.Font.LuckiestGuy
	partsLabel.TextXAlignment = Enum.TextXAlignment.Right
	partsLabel.ZIndex = 4
	partsLabel.Parent = card
	addTextOutline(partsLabel, 2)

	-- Bordure de rareté en bas (petite barre colorée)
	local rarityBar = Instance.new("Frame")
	rarityBar.Name = "RarityBar"
	rarityBar.Size = UDim2.new(0, 28, 0, 3)
	rarityBar.Position = UDim2.new(0, 6, 0, 150)
	rarityBar.BackgroundColor3 = rarityColor
	rarityBar.BorderSizePixel = 0
	rarityBar.ZIndex = 4
	rarityBar.Parent = card
	Instance.new("UICorner", rarityBar).CornerRadius = UDim.new(0, 2)
	local rarityBarStroke = Instance.new("UIStroke")
	rarityBarStroke.Color = Color3.fromRGB(0, 0, 0)
	rarityBarStroke.Thickness = 1.2
	rarityBarStroke.Parent = rarityBar

	-- ── Nom du brainrot en bas (style cartoon blanc + contour noir) ──
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -12, 0, 22)
	nameLabel.Position = UDim2.new(0, 6, 1, -2)
	nameLabel.AnchorPoint = Vector2.new(0, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = dynamicName
	nameLabel.TextColor3 = COLORS.White
	nameLabel.TextSize = 15
	nameLabel.Font = Enum.Font.LuckiestGuy
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.TextScaled = false
	nameLabel.TextWrapped = false
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 4
	nameLabel.Parent = card
	addTextOutline(nameLabel, 2.5)

	-- Completed checkmark overlay
	if unlockedParts >= totalParts and totalParts > 0 then
		local checkBadge = Instance.new("Frame")
		checkBadge.Name = "CheckBadge"
		checkBadge.Size = UDim2.new(0, 24, 0, 24)
		checkBadge.Position = UDim2.new(1, -6, 0, -6)
		checkBadge.AnchorPoint = Vector2.new(1, 0)
		checkBadge.BackgroundColor3 = Color3.fromRGB(0, 190, 100)
		checkBadge.BorderSizePixel = 0
		checkBadge.ZIndex = 3
		checkBadge.Parent = card

		Instance.new("UICorner", checkBadge).CornerRadius = UDim.new(1, 0)

		local checkMark = Instance.new("TextLabel")
		checkMark.Size = UDim2.new(1, 0, 1, 0)
		checkMark.BackgroundTransparency = 1
		checkMark.Text = "\xE2\x9C\x93" -- ✓
		checkMark.TextColor3 = COLORS.White
		checkMark.TextSize = 16
		checkMark.Font = Enum.Font.GothamBlack
		checkMark.ZIndex = 4
		checkMark.Parent = checkBadge
	end

	-- "NEW" badge (red pastille) for newly unlocked parts
	local newPartsCount = self:_CountNewPartsForSet(setName)
	local newBadge = nil
	if newPartsCount > 0 then
		newBadge = Instance.new("TextLabel")
		newBadge.Name = "NewBadge"
		newBadge.Size = UDim2.new(0, 22, 0, 22)
		newBadge.Position = UDim2.new(0, -4, 0, -4)
		newBadge.AnchorPoint = Vector2.new(0, 0)
		newBadge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
		newBadge.BorderSizePixel = 0
		newBadge.Text = tostring(newPartsCount)
		newBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
		newBadge.TextSize = 12
		newBadge.Font = Enum.Font.GothamBold
		newBadge.ZIndex = 5
		newBadge.Parent = card
		Instance.new("UICorner", newBadge).CornerRadius = UDim.new(1, 0)
	end

	-- Click handler: mark set as seen and hide badge
	card.Active = true
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if newBadge and newBadge.Visible then
				newBadge.Visible = false
				pcall(function()
					self:_MarkSetAsSeen(setName)
					self:RefreshBadges()
				end)
			end
		end
	end)

	return card
end

-- ══════════════════════════════════════════
-- Refresh grid
-- ══════════════════════════════════════════

function CodexController:RefreshList()
	local grid = self._gridContainer
	if not grid then return end

	-- Clear old cards (both codex and fusion)
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") and (child.Name:match("^Card_") or child.Name:match("^Fusion_")) then
			child:Destroy()
		end
	end

	local Sets = BrainrotData.Sets or {}
	local unlocked = self._codexUnlocked or {}
	local Rarities = BrainrotData.Rarities or {}

	-- Sort by rarity then alphabetical name
	local setNames = {}
	for name in pairs(Sets) do table.insert(setNames, name) end
	table.sort(setNames, function(a, b)
		local ra = Sets[a] and Sets[a].Rarity or "Common"
		local rb = Sets[b] and Sets[b].Rarity or "Common"
		local oa = Rarities[ra] and Rarities[ra].DisplayOrder or 99
		local ob = Rarities[rb] and Rarities[rb].DisplayOrder or 99
		if oa ~= ob then return oa < ob end
		return a < b
	end)

	local totalSets = 0
	local discoveredSets = 0
	local filteredTotal = 0
	local filteredDiscovered = 0
	local layoutOrder = 0

	for _, setName in ipairs(setNames) do
		local setData = Sets[setName]
		if not setData then continue end

		local parts = getPartsUnlocked(unlocked, setName)
		local rarity = setData.Rarity or "Common"

		local totalParts = 0
		local unlockedParts = 0
		for _, partType in ipairs({"Head", "Body", "Legs"}) do
			local partData = setData[partType]
			if partData and partData.TemplateName and partData.TemplateName ~= "" then
				totalParts = totalParts + 1
				if parts[partType] then
					unlockedParts = unlockedParts + 1
				end
			end
		end

		local isDiscovered = totalParts > 0 and unlockedParts == totalParts

		totalSets = totalSets + 1
		if isDiscovered then discoveredSets = discoveredSets + 1 end

		-- Active filter
		if self._activeFilter and rarity ~= self._activeFilter then continue end

		filteredTotal = filteredTotal + 1
		if isDiscovered then filteredDiscovered = filteredDiscovered + 1 end

		layoutOrder = layoutOrder + 1
		local card = self:_CreateCard(setName, setData, isDiscovered, layoutOrder, unlockedParts, totalParts, parts)
		card.Parent = grid
	end

	-- Global counter
	if self._counterLabel then
		self._counterLabel.Text = discoveredSets .. "/" .. totalSets
	end

	-- Progress bar
	if self._progressFill and self._progressCount and self._bottomText then
		local pct = filteredTotal > 0 and (filteredDiscovered / filteredTotal) or 0

		-- Animate progress bar
		TweenService:Create(self._progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
		}):Play()

		self._progressCount.Text = filteredDiscovered .. "/" .. filteredTotal

		local filterName = self._activeFilter and (RARITY_DISPLAY[self._activeFilter] or self._activeFilter) or ""
		if filterName ~= "" then
			self._bottomText.Text = string.format(
				"Collect 75%% of %s Brainrots for +0.5x base multiplier",
				filterName
			)
		else
			self._bottomText.Text = "Collect Brainrots to unlock bonuses!"
		end
	end
end

-- ══════════════════════════════════════════
-- Badge notification system
-- ══════════════════════════════════════════

function CodexController:_CountNewPartsForSet(setName)
	local current = self._codexUnlocked or {}
	local seen = self._seenCodexUnlocked or {}
	local data = current[setName]
	if not data then return 0 end

	local seenData = seen[setName]
	local count = 0

	if not seenData then
		-- Entire set is new
		if data == true then
			count = 3
		elseif type(data) == "table" then
			for _, partType in ipairs({"Head", "Body", "Legs"}) do
				if data[partType] == true then
					count = count + 1
				end
			end
		end
	elseif data == true and seenData ~= true then
		-- Was partial, now fully unlocked
		local seenParts = (type(seenData) == "table") and seenData or {}
		for _, partType in ipairs({"Head", "Body", "Legs"}) do
			if not seenParts[partType] then
				count = count + 1
			end
		end
	elseif type(data) == "table" then
		if seenData == true then
			-- Was already fully seen
		else
			local seenParts = (type(seenData) == "table") and seenData or {}
			for _, partType in ipairs({"Head", "Body", "Legs"}) do
				if data[partType] == true and not seenParts[partType] then
					count = count + 1
				end
			end
		end
	end

	return count
end

function CodexController:_CountNewCodexEntries()
	local newCount = 0
	local current = self._codexUnlocked or {}
	for setName in pairs(current) do
		if self:_CountNewPartsForSet(setName) > 0 then
			newCount = newCount + 1
		end
	end
	return newCount
end

function CodexController:_MarkSetAsSeen(setName)
	local data = (self._codexUnlocked or {})[setName]
	if not data then return end
	if data == true then
		self._seenCodexUnlocked[setName] = true
	elseif type(data) == "table" then
		self._seenCodexUnlocked[setName] = { Head = data.Head, Body = data.Body, Legs = data.Legs }
	end
end

function CodexController:_CountUnclaimedRewards()
	local milestones = GameConfig.Fusion and GameConfig.Fusion.Milestones or {}
	local fusionData = self._fusionData or {}
	local fusionCount = fusionData.FusionCount or 0
	local claimed = fusionData.ClaimedFusionRewards or {}
	local count = 0

	for i, milestone in ipairs(milestones) do
		if fusionCount >= milestone.Required then
			if not (claimed[i] == true or claimed[tostring(i)] == true) then
				count = count + 1
			end
		end
	end

	return count
end

function CodexController:_UpdateBadge(badgeLabel, count)
	if not badgeLabel then return end
	if count > 0 then
		badgeLabel.Text = tostring(count)
		badgeLabel.Visible = true
	else
		badgeLabel.Visible = false
	end
end

function CodexController:RefreshBadges()
	self._newCodexCount = self:_CountNewCodexEntries()
	self._unclaimedRewardsCount = self:_CountUnclaimedRewards()

	-- Update fusion tab badge
	self:_UpdateBadge(self._fusionTabBadge, self._unclaimedRewardsCount)

	-- Update main codex button badge (new codex entries + unclaimed rewards)
	local totalBadge = self._newCodexCount + self._unclaimedRewardsCount
	self:_UpdateBadge(self._codexButtonBadge, totalBadge)
end

function CodexController:_MarkCodexAsSeen()
	-- Deep copy current codex state as "seen"
	local copy = {}
	for setName, data in pairs(self._codexUnlocked or {}) do
		if data == true then
			copy[setName] = true
		elseif type(data) == "table" then
			copy[setName] = { Head = data.Head, Body = data.Body, Legs = data.Legs }
		end
	end
	self._seenCodexUnlocked = copy
end

-- ══════════════════════════════════════════
-- Public API
-- ══════════════════════════════════════════

function CodexController:UpdateCodex(codexUnlocked)
	self._codexUnlocked = codexUnlocked or {}
	self:RefreshList()
	pcall(function() self:RefreshBadges() end)
end

function CodexController:Open()
	-- Ensure UI is valid (guard against respawn-induced destruction)
	self:_EnsureUI()

	-- Safety: if _isOpen but UI not visible, reset the flag
	if self._isOpen and self._codexUI and not self._codexUI.Enabled then
		self._isOpen = false
	end
	if self._isOpen then return end
	if not self._codexUI then return end

	self._isOpen = true
	self._codexUI.Enabled = true

	-- Refresh badges (protected)
	pcall(function()
		self:RefreshBadges()
	end)

	-- Refresh content
	if self._activeFusionTab then
		self:RefreshFusionList()
	else
		self:RefreshList()
	end

	-- Animate overlay fade in
	self._overlay.BackgroundTransparency = 1
	TweenService:Create(self._overlay, TweenInfo.new(0.25), {
		BackgroundTransparency = COLORS.OverlayTransparency
	}):Play()

	-- Animate panel open
	self._mainFrame.Size = SIZES.PanelClosed
	TweenService:Create(self._mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = SIZES.Panel
	}):Play()
end

function CodexController:Close()
	if not self._isOpen then return end
	if not self._codexUI then return end

	-- Animate overlay fade out
	TweenService:Create(self._overlay, TweenInfo.new(0.2), {
		BackgroundTransparency = 1
	}):Play()

	-- Animate panel close
	local tweenClose = TweenService:Create(self._mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = SIZES.PanelClosed
	})
	tweenClose:Play()

	tweenClose.Completed:Connect(function()
		self._codexUI.Enabled = false
		self._isOpen = false
	end)
end

function CodexController:IsOpen()
	return self._isOpen
end

-- ══════════════════════════════════════════
-- Fusion: 3D Assembly (mixed sets)
-- ══════════════════════════════════════════

function CodexController:_AssembleFusionPreviewModel(headSet, bodySet, legsSet)
	local headSetData = BrainrotData.Sets[headSet]
	local bodySetData = BrainrotData.Sets[bodySet]
	local legsSetData = BrainrotData.Sets[legsSet]

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then return nil end
	local templatesFolder = assetsFolder:FindFirstChild("BodyPartTemplates")
	if not templatesFolder then return nil end

	local headFolder = templatesFolder:FindFirstChild("HeadTemplate")
	local bodyFolder = templatesFolder:FindFirstChild("BodyTemplate")
	local legsFolder = templatesFolder:FindFirstChild("LegsTemplate")

	local headTN = headSetData and headSetData.Head and headSetData.Head.TemplateName or ""
	local bodyTN = bodySetData and bodySetData.Body and bodySetData.Body.TemplateName or ""
	local legsTN = legsSetData and legsSetData.Legs and legsSetData.Legs.TemplateName or ""

	local headSrc = (headTN ~= "" and headFolder) and headFolder:FindFirstChild(headTN) or nil
	local bodySrc = (bodyTN ~= "" and bodyFolder) and bodyFolder:FindFirstChild(bodyTN) or nil
	local legsSrc = (legsTN ~= "" and legsFolder) and legsFolder:FindFirstChild(legsTN) or nil

	if not headSrc and not bodySrc and not legsSrc then return nil end

	local headModel = headSrc and headSrc:Clone() or nil
	local bodyModel = bodySrc and bodySrc:Clone() or nil
	local legsModel = legsSrc and legsSrc:Clone() or nil

	local headPart = headModel and headModel.PrimaryPart
	local bodyPart = bodyModel and bodyModel.PrimaryPart
	local legsPart = legsModel and legsModel.PrimaryPart

	local function cleanModel(m)
		if not m then return end
		for _, desc in ipairs(m:GetDescendants()) do
			if desc:IsA("BillboardGui") then
				desc:Destroy()
			elseif desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
			end
		end
	end

	cleanModel(headModel)
	cleanModel(bodyModel)
	cleanModel(legsModel)

	local function repositionModel(subModel, primaryPart, targetCFrame)
		if not subModel or not primaryPart then return end
		local delta = targetCFrame * primaryPart.CFrame:Inverse()
		for _, desc in ipairs(subModel:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.CFrame = delta * desc.CFrame
			end
		end
	end

	-- Position Legs at origin
	if legsModel and legsPart then
		local legsTopAtt = legsPart:FindFirstChild("TopAttachment")
		local legsOrientation = legsTopAtt and legsTopAtt.CFrame.Rotation or CFrame.new()
		repositionModel(legsModel, legsPart, CFrame.new(0, legsPart.Size.Y / 2, 0) * legsOrientation)
	end

	-- Body -> Legs via Attachments
	if bodyModel and bodyPart then
		if legsPart then
			local bba = bodyPart:FindFirstChild("BottomAttachment")
			local lta = legsPart:FindFirstChild("TopAttachment")
			if bba and lta then
				local targetCF = legsPart.CFrame * lta.CFrame * bba.CFrame:Inverse()
				repositionModel(bodyModel, bodyPart, targetCF)
			else
				repositionModel(bodyModel, bodyPart, CFrame.new(0, legsPart.Size.Y + bodyPart.Size.Y / 2, 0))
			end
		else
			local bba = bodyPart:FindFirstChild("BottomAttachment")
			local bodyOrientation = bba and bba.CFrame.Rotation or CFrame.new()
			repositionModel(bodyModel, bodyPart, CFrame.new(0, bodyPart.Size.Y / 2, 0) * bodyOrientation)
		end
	end

	-- Head -> Body via Attachments (or Head -> Legs if no Body)
	if headModel and headPart then
		if bodyPart then
			local hba = headPart:FindFirstChild("BottomAttachment")
			local bta = bodyPart:FindFirstChild("TopAttachment")
			if hba and bta then
				local targetCF = bodyPart.CFrame * bta.CFrame * hba.CFrame:Inverse()
				repositionModel(headModel, headPart, targetCF)
			else
				repositionModel(headModel, headPart, bodyPart.CFrame * CFrame.new(0, bodyPart.Size.Y / 2 + headPart.Size.Y / 2, 0))
			end
		elseif legsPart then
			local lta = legsPart:FindFirstChild("TopAttachment")
			if lta then
				local topWorldPos = (legsPart.CFrame * lta.CFrame).Position
				repositionModel(headModel, headPart, CFrame.new(topWorldPos.X, topWorldPos.Y + headPart.Size.Y / 2, topWorldPos.Z) * legsPart.CFrame.Rotation)
			else
				repositionModel(headModel, headPart, CFrame.new(0, legsPart.Size.Y + headPart.Size.Y / 2, 0))
			end
		else
			repositionModel(headModel, headPart, CFrame.new(0, headPart.Size.Y / 2, 0))
		end
	end

	local model = Instance.new("Model")
	model.Name = "FusionPreview"

	if legsModel then legsModel.Parent = model end
	if bodyModel then bodyModel.Parent = model end
	if headModel then headModel.Parent = model end

	model.PrimaryPart = bodyPart or headPart or legsPart

	return model
end

-- ══════════════════════════════════════════
-- Fusion: Card creation
-- ══════════════════════════════════════════

function CodexController:_CreateFusionCard(headSet, bodySet, legsSet, layoutOrder)
	local theme = self._rarityTheme
	if not theme then
		theme = buildRarityTheme(self:_GetFilterAccent())
	end
	local isSameSet = (headSet == bodySet and bodySet == legsSet)

	-- Get display names
	local headSetData = BrainrotData.Sets[headSet]
	local bodySetData = BrainrotData.Sets[bodySet]
	local legsSetData = BrainrotData.Sets[legsSet]
	local headName = headSetData and headSetData.Head and headSetData.Head.DisplayName or "?"
	local bodyName = bodySetData and bodySetData.Body and bodySetData.Body.DisplayName or "?"
	local legsName = legsSetData and legsSetData.Legs and legsSetData.Legs.DisplayName or "?"

	local card = Instance.new("Frame")
	card.Name = "Fusion_" .. headSet .. "_" .. bodySet .. "_" .. legsSet
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = COLORS.CardBg
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	Instance.new("UICorner", card).CornerRadius = SIZES.SmallCorner

	-- Stroke noir cartoon
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = COLORS.CardStroke
	cardStroke.Thickness = 3
	cardStroke.LineJoinMode = Enum.LineJoinMode.Round
	cardStroke.Parent = card

	-- Rayures : accent fusion (onglet) ; cartes "mix" plus chaud
	local stripeColor = isSameSet and theme.cardStripe or lerpColor3(COLORS.FusionTabColor, W, 0.12)
	addStripePattern(card, stripeColor, 0.7, 35)

	-- Hover effect
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TweenService:Create(cardStroke, TweenInfo.new(0.2), {
				Color = COLORS.CardStrokeHover,
				Thickness = 4
			}):Play()
		end
	end)
	card.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TweenService:Create(cardStroke, TweenInfo.new(0.2), {
				Color = COLORS.CardStroke,
				Thickness = 3
			}):Play()
		end
	end)

	-- 3D preview area transparent (pour laisser apparaître les rayures)
	local previewFrame = Instance.new("Frame")
	previewFrame.Name = "PreviewFrame"
	previewFrame.Size = UDim2.new(1, -12, 0, 115)
	previewFrame.Position = UDim2.new(0, 6, 0, 30)
	previewFrame.BackgroundTransparency = 1
	previewFrame.BorderSizePixel = 0
	previewFrame.ClipsDescendants = true
	previewFrame.ZIndex = 2
	previewFrame.Parent = card

	-- ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.ZIndex = 2
	viewport.Parent = previewFrame

	local previewModel = self:_AssembleFusionPreviewModel(headSet, bodySet, legsSet)
	if previewModel then
		previewModel.Parent = viewport

		local camera = Instance.new("Camera")
		viewport.CurrentCamera = camera
		camera.Parent = viewport
		camera.FieldOfView = 50

		-- Compute bounding box
		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		local partCount = 0
		for _, desc in ipairs(previewModel:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Transparency < 1 then
				local pos = desc.CFrame.Position
				local half = desc.Size / 2
				minX = math.min(minX, pos.X - half.X)
				maxX = math.max(maxX, pos.X + half.X)
				minY = math.min(minY, pos.Y - half.Y)
				maxY = math.max(maxY, pos.Y + half.Y)
				minZ = math.min(minZ, pos.Z - half.Z)
				maxZ = math.max(maxZ, pos.Z + half.Z)
				partCount = partCount + 1
			end
		end
		if partCount > 0 then
			local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
			local sizeX, sizeY, sizeZ = maxX - minX, maxY - minY, maxZ - minZ
			local maxDim = math.max(sizeX, sizeY, sizeZ)
			local dist = maxDim * 1.2
			camera.CFrame = CFrame.new(
				center + Vector3.new(dist * 0.3, dist * 0.2, dist),
				center
			)
		end
	else
		local ph = Instance.new("TextLabel")
		ph.Size = UDim2.new(1, 0, 1, 0)
		ph.BackgroundTransparency = 1
		ph.Text = "?"
		ph.TextColor3 = Color3.fromRGB(15, 20, 15)
		ph.TextSize = 64
		ph.Font = Enum.Font.LuckiestGuy
		ph.ZIndex = 3
		ph.Parent = previewFrame
		addTextOutline(ph, 3)
	end

	-- Badge: PURE / MIX (en haut à droite)
	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Name = "BadgeLabel"
	badgeLabel.Size = UDim2.new(1, -12, 0, 20)
	badgeLabel.Position = UDim2.new(0, 6, 0, 4)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Text = isSameSet and "PURE" or "MIX"
	badgeLabel.TextColor3 = isSameSet and theme.priceText or COLORS.MultiplierGold
	badgeLabel.TextSize = 18
	badgeLabel.Font = Enum.Font.LuckiestGuy
	badgeLabel.TextXAlignment = Enum.TextXAlignment.Right
	badgeLabel.ZIndex = 4
	badgeLabel.Parent = card
	addTextOutline(badgeLabel, 2.2)

	-- Fusion name (en bas, centré, cartoon)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -12, 0, 22)
	nameLabel.Position = UDim2.new(0, 6, 1, -2)
	nameLabel.AnchorPoint = Vector2.new(0, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = headName .. " " .. bodyName .. " " .. legsName
	nameLabel.TextColor3 = COLORS.White
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.LuckiestGuy
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 4
	nameLabel.Parent = card
	addTextOutline(nameLabel, 2.5)

	return card
end

-- ══════════════════════════════════════════
-- Fusion: Bottom bar (battle pass reward track)
-- ══════════════════════════════════════════

function CodexController:_BuildFusionBottomBar(mainFrame)
	local milestones = GameConfig.Fusion and GameConfig.Fusion.Milestones or {}

	local fusionBar = Instance.new("Frame")
	fusionBar.Name = "FusionBottomBar"
	fusionBar.Size = UDim2.new(1, -40, 0, 110)
	fusionBar.Position = UDim2.new(0, 20, 1, -120)
	fusionBar.BackgroundColor3 = COLORS.BottomBg
	fusionBar.BorderSizePixel = 0
	fusionBar.Visible = false
	fusionBar.ClipsDescendants = true
	fusionBar.Parent = mainFrame

	Instance.new("UICorner", fusionBar).CornerRadius = SIZES.SmallCorner

	local fusionStroke = Instance.new("UIStroke")
	fusionStroke.Color = COLORS.BottomStroke
	fusionStroke.Thickness = 1.5
	fusionStroke.Transparency = 0.3
	fusionStroke.Parent = fusionBar

	-- Title row
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "FusionTitle"
	titleLabel.Size = UDim2.new(1, -16, 0, 18)
	titleLabel.Position = UDim2.new(0, 8, 0, 3)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "FUSION REWARDS"
	titleLabel.TextColor3 = COLORS.SubText
	titleLabel.TextSize = 11
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = fusionBar

	-- Scrolling track
	local trackScroll = Instance.new("ScrollingFrame")
	trackScroll.Name = "TrackScroll"
	trackScroll.Size = UDim2.new(1, -16, 0, 82)
	trackScroll.Position = UDim2.new(0, 8, 0, 22)
	trackScroll.BackgroundTransparency = 1
	trackScroll.BorderSizePixel = 0
	trackScroll.ScrollBarThickness = 3
	trackScroll.ScrollBarImageColor3 = COLORS.ScrollBar
	trackScroll.CanvasSize = UDim2.new(0, math.max(#milestones * 80 + 20, 100), 0, 0)
	trackScroll.ScrollingDirection = Enum.ScrollingDirection.X
	trackScroll.Parent = fusionBar

	self._fusionBottomBar = fusionBar
	self._rewardTrackContainer = trackScroll
end

-- ══════════════════════════════════════════
-- Fusion: Refresh grid
-- ══════════════════════════════════════════

function CodexController:RefreshFusionList()
	local grid = self._gridContainer
	if not grid then return end

	-- Clear old cards
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") and (child.Name:match("^Card_") or child.Name:match("^Fusion_")) then
			child:Destroy()
		end
	end

	local fusionData = self._fusionData or {}
	local discovered = fusionData.DiscoveredFusions or {}
	local fusionCount = 0
	local layoutOrder = 0

	-- Sort fusion keys for consistent display
	local fusionKeys = {}
	for key in pairs(discovered) do
		table.insert(fusionKeys, key)
	end
	table.sort(fusionKeys)

	for _, key in ipairs(fusionKeys) do
		fusionCount = fusionCount + 1
		layoutOrder = layoutOrder + 1

		-- Parse key: "HeadSet_BodySet_LegsSet"
		local parts = string.split(key, "_")
		if #parts >= 3 then
			local headSet = parts[1]
			local bodySet = parts[2]
			local legsSet = parts[3]

			local card = self:_CreateFusionCard(headSet, bodySet, legsSet, layoutOrder)
			card.Parent = grid
		end
	end

	-- Update counter
	if self._counterLabel then
		self._counterLabel.Text = fusionCount .. " fusions"
	end

	-- Refresh reward track
	self:_RefreshRewardTrack()
end

-- ══════════════════════════════════════════
-- Fusion: Reward track (battle pass)
-- ══════════════════════════════════════════

function CodexController:_RefreshRewardTrack()
	local container = self._rewardTrackContainer
	if not container then return end

	local t = self._rarityTheme
	if not t then
		t = buildRarityTheme(self:_GetFilterAccent())
	end
	local nodeClaimed = Color3.fromRGB(32, 150, 80)

	-- Clear old nodes
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end

	local milestones = GameConfig.Fusion and GameConfig.Fusion.Milestones or {}
	local fusionData = self._fusionData or {}
	local fusionCount = fusionData.FusionCount or 0
	local claimed = fusionData.ClaimedFusionRewards or {}

	local nodeSize = 36
	local spacing = 80
	local nodeY = 16 -- vertical offset for node (leaves room for required label above)

	for i, milestone in ipairs(milestones) do
		local x = (i - 1) * spacing + 10
		local isReached = fusionCount >= milestone.Required
		local isClaimed = claimed[i] == true or claimed[tostring(i)] == true

		-- Connecting line to next node
		if i < #milestones then
			local line = Instance.new("Frame")
			line.Name = "Line_" .. i
			line.Size = UDim2.new(0, spacing - nodeSize, 0, 4)
			line.Position = UDim2.new(0, x + nodeSize, 0, nodeY + nodeSize / 2 - 2)
			line.BackgroundColor3 = isReached and t.progressFill or t.progressBg
			line.BorderSizePixel = 0
			line.Parent = container
			Instance.new("UICorner", line).CornerRadius = UDim.new(0, 2)
		end

		-- Required count label above the node
		local reqAbove = Instance.new("TextLabel")
		reqAbove.Name = "Req_" .. i
		reqAbove.Size = UDim2.new(0, spacing - 4, 0, 14)
		reqAbove.Position = UDim2.new(0, x + nodeSize / 2, 0, nodeY - 14)
		reqAbove.AnchorPoint = Vector2.new(0.5, 0)
		reqAbove.BackgroundTransparency = 1
		reqAbove.Text = tostring(milestone.Required) .. " fusions"
		reqAbove.TextColor3 = isReached and COLORS.White or t.subText
		reqAbove.TextSize = 9
		reqAbove.Font = Enum.Font.GothamBold
		reqAbove.Parent = container

		-- Node circle
		local node = Instance.new("TextButton")
		node.Name = "Node_" .. i
		node.Size = UDim2.new(0, nodeSize, 0, nodeSize)
		node.Position = UDim2.new(0, x, 0, nodeY)
		node.BorderSizePixel = 0
		node.AutoButtonColor = false
		node.Text = ""
		node.Parent = container

		Instance.new("UICorner", node).CornerRadius = UDim.new(1, 0)

		if isClaimed then
			-- Claimed: green with checkmark
			node.BackgroundColor3 = nodeClaimed

			local check = Instance.new("TextLabel")
			check.Size = UDim2.new(1, 0, 1, 0)
			check.BackgroundTransparency = 1
			check.Text = "\xE2\x9C\x93"
			check.TextColor3 = COLORS.White
			check.TextSize = 18
			check.Font = Enum.Font.GothamBlack
			check.Parent = node

		elseif isReached then
			-- Ready to claim: accent
			node.BackgroundColor3 = t.progressFill

			local glowStroke = Instance.new("UIStroke")
			glowStroke.Color = t.progressFill
			glowStroke.Thickness = 3
			glowStroke.Transparency = 0.3
			glowStroke.Parent = node

			-- Pulse animation
			local pulseIn = TweenService:Create(glowStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Transparency = 0.8
			})
			pulseIn:Play()

			-- Reward icon
			local rewardIcon = Instance.new("TextLabel")
			rewardIcon.Size = UDim2.new(1, 0, 1, 0)
			rewardIcon.BackgroundTransparency = 1
			rewardIcon.Text = milestone.Type == "Multiplier" and "x" or "$"
			rewardIcon.TextColor3 = COLORS.White
			rewardIcon.TextSize = 18
			rewardIcon.Font = Enum.Font.GothamBlack
			rewardIcon.Parent = node

			-- Red badge pastille (unclaimed reward)
			local claimBadge = Instance.new("TextLabel")
			claimBadge.Name = "ClaimBadge"
			claimBadge.Size = UDim2.new(0, 18, 0, 18)
			claimBadge.Position = UDim2.new(1, -2, 0, -4)
			claimBadge.AnchorPoint = Vector2.new(0.5, 0.5)
			claimBadge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
			claimBadge.BorderSizePixel = 0
			claimBadge.Text = "!"
			claimBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
			claimBadge.TextSize = 12
			claimBadge.Font = Enum.Font.GothamBold
			claimBadge.ZIndex = 5
			claimBadge.Parent = node
			Instance.new("UICorner", claimBadge).CornerRadius = UDim.new(1, 0)

			-- Click to claim
			local milestoneIdx = i
			node.MouseButton1Click:Connect(function()
				local Remotes = ReplicatedStorage:WaitForChild("Remotes")
				local claimRemote = Remotes:FindFirstChild("ClaimFusionReward")
				if claimRemote then
					claimRemote:FireServer(milestoneIdx)
				end
			end)

		else
			-- Locked: teinte rareté
			node.BackgroundColor3 = t.progressBg

			local lockIcon = Instance.new("TextLabel")
			lockIcon.Size = UDim2.new(1, 0, 1, 0)
			lockIcon.BackgroundTransparency = 1
			lockIcon.Text = milestone.Type == "Multiplier" and "x" or "$"
			lockIcon.TextColor3 = t.subText
			lockIcon.TextSize = 16
			lockIcon.Font = Enum.Font.GothamBold
			lockIcon.Parent = node
		end

		-- Reward label below node (DisplayName)
		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Name = "Reward_" .. i
		rewardLabel.Size = UDim2.new(0, spacing - 4, 0, 16)
		rewardLabel.Position = UDim2.new(0, x + nodeSize / 2, 0, nodeY + nodeSize + 2)
		rewardLabel.AnchorPoint = Vector2.new(0.5, 0)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.Text = milestone.DisplayName
		rewardLabel.TextSize = 11
		rewardLabel.Font = Enum.Font.GothamBold
		rewardLabel.Parent = container

		if isClaimed then
			rewardLabel.TextColor3 = nodeClaimed
		elseif isReached then
			rewardLabel.TextColor3 = COLORS.White
		elseif milestone.Type == "Multiplier" then
			rewardLabel.TextColor3 = COLORS.MultiplierGold
		else
			rewardLabel.TextColor3 = t.subText
		end
	end

	-- Update canvas size
	container.CanvasSize = UDim2.new(0, #milestones * spacing + 20, 0, 0)

	-- Auto-scroll to first unclaimed reachable node
	for i, milestone in ipairs(milestones) do
		local isReached = fusionCount >= milestone.Required
		local isClaimed = claimed[i] == true or claimed[tostring(i)] == true
		if isReached and not isClaimed then
			local targetX = math.max(0, (i - 1) * spacing - 100)
			container.CanvasPosition = Vector2.new(targetX, 0)
			break
		end
	end
end

return CodexController
