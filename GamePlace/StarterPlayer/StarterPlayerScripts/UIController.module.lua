--[[
    UIController.lua (ModuleScript)
    Gère toutes les mises à jour de l'UI - HUD entièrement programmatique

    Responsabilités:
    - Créer le HUD complet (Cash, Inventaire, Notifications)
    - Mettre à jour l'affichage
    - Afficher les notifications
    - Gérer les animations UI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Assets pickup cash (icône = même $ que la pilule HUD, son demandé)
local CASH_BILL_IMAGE = "rbxassetid://75938011448548"
local CASH_PICKUP_SOUND = "rbxassetid://92876713905078"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])
local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))
local ResponsiveScale = require(Shared["ResponsiveScale.module"])

-- ═══════════════════════════════════════════════════════
-- CONSTANTES VISUELLES
-- ═══════════════════════════════════════════════════════

local COLORS = {
	HudBg = Color3.fromRGB(30, 30, 40),
	HudBgLight = Color3.fromRGB(45, 45, 55),
	CashBg = Color3.fromRGB(25, 100, 25),
	CashBgHover = Color3.fromRGB(30, 120, 30),
	CashIcon = Color3.fromRGB(255, 220, 50),
	SlotEmpty = Color3.fromRGB(55, 55, 65),
	SlotEmptyText = Color3.fromRGB(120, 120, 130),
	White = Color3.fromRGB(255, 255, 255),
	CraftGreen = Color3.fromRGB(0, 200, 0),
	CraftYellow = Color3.fromRGB(150, 150, 0),
	DropRed = Color3.fromRGB(180, 40, 40),
}

local FONTS = {
	Bold = Enum.Font.GothamBold,
	Black = Enum.Font.GothamBlack,
	Regular = Enum.Font.Gotham,
}

local function addTextOutline(label, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

-- Icônes de type par slot (slot 1=Head, 2=Body, 3=Legs)
-- Couleurs nude/neutres, distinctes des raretés (blanc, bleu, violet, or)
local SLOT_TYPE_INFO = {
	[1] = { Symbol = "▲", Color = Color3.fromRGB(195, 150, 130), Label = "HEAD" },  -- terracotta rosé
	[2] = { Symbol = "■", Color = Color3.fromRGB(165, 155, 135), Label = "BODY" },  -- pierre/taupe
	[3] = { Symbol = "●", Color = Color3.fromRGB(140, 155, 160), Label = "LEGS" },  -- ardoise gris-bleu (très désaturé)
}

-- ═══════════════════════════════════════════════════════
-- ÉTAT LOCAL
-- ═══════════════════════════════════════════════════════

local currentPlayerData = {
	Cash = 0,
	OwnedSlots = 10,
	PiecesInHand = {},
}

local UIController = {}

-- Références UI
UIController._screenGui = nil
UIController._cashLabel = nil
UIController._inventoryTitle = nil
UIController._inventorySlots = {}
UIController._craftLabel = nil
UIController._dropButton = nil
UIController._notifContainer = nil
UIController._notifTemplate = nil
UIController._initialized = false

-- Couleurs des notifications
local NOTIFICATION_COLORS = {
	Success = Color3.fromRGB(0, 150, 0),
	Error = Color3.fromRGB(200, 50, 50),
	Warning = Color3.fromRGB(200, 150, 0),
	Info = Color3.fromRGB(50, 100, 200),
}

local notificationCounter = 0

-- ═══════════════════════════════════════════════════════
-- INITIALISATION - Crée tout le HUD
-- ═══════════════════════════════════════════════════════

function UIController:Init()
	if self._initialized then return end

	-- ScreenGui principal
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	-- Responsive scaling
	ResponsiveScale.Apply(screenGui)

	-- Créer les éléments du HUD
	self:_CreateCashDisplay(screenGui)
	self:_CreateInventoryDisplay(screenGui)

	-- Notifications: utiliser le NotificationUI pré-existant
	local notificationUI = playerGui:WaitForChild("NotificationUI")
	ResponsiveScale.Apply(notificationUI)
	self._notifContainer = notificationUI:WaitForChild("Container")
	self._notifTemplate = self._notifContainer:WaitForChild("Template")

	-- Centrer les notifications au milieu, au-dessus de l'inventaire
	self._notifContainer.AnchorPoint = Vector2.new(0.5, 1)
	self._notifContainer.Position = UDim2.new(0.5, 0, 0.75, 0)

	self._initialized = true
end

-- ═══════════════════════════════════════════════════════
-- CASH DISPLAY (bas-gauche)
-- ═══════════════════════════════════════════════════════

function UIController:_CreateCashDisplay(parent)
	-- Ombre cartoon sous la pilule cash
	local shadow = Instance.new("Frame")
	shadow.Name = "CashDisplayShadow"
	shadow.Size = UDim2.new(0, 226, 0, 56)
	shadow.Position = UDim2.new(0, 14, 1, -16)
	shadow.AnchorPoint = Vector2.new(0, 1)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.45
	shadow.BorderSizePixel = 0
	shadow.Parent = parent

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 16)
	shadowCorner.Parent = shadow

	-- Container principal - pilule verte
	local cashFrame = Instance.new("Frame")
	cashFrame.Name = "CashDisplay"
	cashFrame.Size = UDim2.new(0, 226, 0, 56)
	cashFrame.Position = UDim2.new(0, 15, 1, -20)
	cashFrame.AnchorPoint = Vector2.new(0, 1)
	cashFrame.BackgroundColor3 = Color3.fromRGB(29, 118, 36)
	cashFrame.BackgroundTransparency = 0.05
	cashFrame.BorderSizePixel = 0
	cashFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = cashFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 3
	stroke.Transparency = 0.05
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = cashFrame

	-- Icône dollar (sac d'argent style "brainrot")
	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Name = "CashIcon"
	iconLabel.Size = UDim2.new(0, 64, 0, 64)
	iconLabel.Position = UDim2.new(0, 4, 0.5, 0)
	iconLabel.AnchorPoint = Vector2.new(0, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Image = "rbxassetid://75938011448548"
	iconLabel.ScaleType = Enum.ScaleType.Fit
	iconLabel.ZIndex = 3
	iconLabel.Parent = cashFrame

	-- Montant
	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Size = UDim2.new(1, -78, 1, 0)
	cashLabel.Position = UDim2.new(0, 74, 0, 0)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Text = "$100"
	cashLabel.TextColor3 = Color3.fromRGB(195, 255, 105)
	cashLabel.TextSize = 28
	cashLabel.Font = FONTS.Black
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.TextTruncate = Enum.TextTruncate.AtEnd
	cashLabel.ZIndex = 3
	cashLabel.Parent = cashFrame
	addTextOutline(cashLabel, 3, 0)

	self._cashLabel = cashLabel
	self._cashFrame = cashFrame
	self._cashIcon = iconLabel

end

-- ═══════════════════════════════════════════════════════
-- INVENTORY DISPLAY (bas-droite)
-- ═══════════════════════════════════════════════════════

function UIController:_CreateInventoryDisplay(parent)
	-- Container
	local invContainer = Instance.new("Frame")
	invContainer.Name = "InventoryDisplay"
	invContainer.Size = UDim2.new(0, 396, 0, 215)
	invContainer.Position = UDim2.new(1, -15, 1, -15)
	invContainer.AnchorPoint = Vector2.new(1, 1)
	invContainer.BackgroundTransparency = 1
	invContainer.BorderSizePixel = 0
	invContainer.Parent = parent

	-- Titre "PIECES IN HAND (0/3)"
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "PIECES IN HAND (0/3)"
	title.TextColor3 = Color3.fromRGB(200, 200, 210)
	title.TextSize = 14
	title.Font = FONTS.Black
	title.TextXAlignment = Enum.TextXAlignment.Right
	title.Parent = invContainer

	self._inventoryTitle = title

	-- Label prix total (en dessous du titre)
	local priceTotalLabel = Instance.new("TextLabel")
	priceTotalLabel.Name = "PriceTotalLabel"
	priceTotalLabel.Size = UDim2.new(1, 0, 0, 28)
	priceTotalLabel.Position = UDim2.new(0, 0, 0, 20)
	priceTotalLabel.BackgroundTransparency = 1
	priceTotalLabel.Text = ""
	priceTotalLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
	priceTotalLabel.TextSize = 22
	priceTotalLabel.Font = FONTS.Black
	priceTotalLabel.TextXAlignment = Enum.TextXAlignment.Right
	priceTotalLabel.TextStrokeTransparency = 0.5
	priceTotalLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	priceTotalLabel.Visible = false
	priceTotalLabel.Parent = invContainer

	self._priceTotalLabel = priceTotalLabel

	-- Container pour les 3 slots
	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "SlotsContainer"
	slotsContainer.Size = UDim2.new(1, 0, 0, 155)
	slotsContainer.Position = UDim2.new(0, 0, 0, 55)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Parent = invContainer

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = slotsContainer

	-- Créer 3 slots
	self._inventorySlots = {}
	for i = 1, 3 do
		local slot = self:_CreateInventorySlot(slotsContainer, i)
		self._inventorySlots[i] = slot
	end

	-- Démarrer la boucle de rotation des viewports 3D
	self:_StartViewportRotation()

	-- Message Craft (au-dessus de l'inventaire, centré) - remplace l'ancien bouton
	local craftLabel = Instance.new("TextLabel")
	craftLabel.Name = "CraftLabel"
	craftLabel.Size = UDim2.new(1, 0, 0, 40)
	craftLabel.Position = UDim2.new(0, 0, 0, -48)
	craftLabel.AnchorPoint = Vector2.new(0, 0)
	craftLabel.BackgroundColor3 = COLORS.CraftGreen
	craftLabel.BackgroundTransparency = 0.15
	craftLabel.BorderSizePixel = 0
	craftLabel.Text = "Go place your Brainrot at your base!"
	craftLabel.TextColor3 = COLORS.White
	craftLabel.TextSize = 16
	craftLabel.Font = FONTS.Black
	craftLabel.Visible = false
	craftLabel.Parent = invContainer

	local craftCorner = Instance.new("UICorner")
	craftCorner.CornerRadius = UDim.new(0, 10)
	craftCorner.Parent = craftLabel

	local craftStroke = Instance.new("UIStroke")
	craftStroke.Color = Color3.fromRGB(0, 255, 0)
	craftStroke.Thickness = 2
	craftStroke.Transparency = 0.5
	craftStroke.Parent = craftLabel

	self._craftLabel = craftLabel

	-- Bouton Drop (à gauche du Craft, visible dès 1 pièce)
	local dropButton = Instance.new("TextButton")
	dropButton.Name = "DropButton"
	dropButton.Size = UDim2.new(1, 0, 0, 40)
	dropButton.Position = UDim2.new(0, 0, 0, -96)
	dropButton.AnchorPoint = Vector2.new(0, 0)
	dropButton.BackgroundColor3 = COLORS.DropRed
	dropButton.BorderSizePixel = 0
	dropButton.Text = "DROP"
	dropButton.TextColor3 = COLORS.White
	dropButton.TextSize = 18
	dropButton.Font = FONTS.Black
	dropButton.Visible = false
	dropButton.AutoButtonColor = false
	dropButton.Parent = invContainer

	local dropCorner = Instance.new("UICorner")
	dropCorner.CornerRadius = UDim.new(0, 10)
	dropCorner.Parent = dropButton

	local dropStroke = Instance.new("UIStroke")
	dropStroke.Color = Color3.fromRGB(220, 60, 60)
	dropStroke.Thickness = 2
	dropStroke.Transparency = 0.5
	dropStroke.Parent = dropButton

	-- Hover effect
	dropButton.MouseEnter:Connect(function()
		TweenService:Create(dropButton, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(210, 50, 50)
		}):Play()
	end)
	dropButton.MouseLeave:Connect(function()
		TweenService:Create(dropButton, TweenInfo.new(0.15), {
			BackgroundColor3 = COLORS.DropRed
		}):Play()
	end)

	self._dropButton = dropButton
end

function UIController:_CreateInventorySlot(parent, index)
	local typeInfo = SLOT_TYPE_INFO[index] or { Symbol = "?", Color = Color3.fromRGB(150, 150, 150), Label = "EMPTY" }
	local MISSING_COLOR = Color3.fromRGB(220, 70, 70)

	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. index
	slot.Size = UDim2.new(0, 120, 0, 150)
	slot.LayoutOrder = index
	slot.BackgroundColor3 = COLORS.SlotEmpty
	slot.BackgroundTransparency = 0.2
	slot.BorderSizePixel = 0
	slot.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = MISSING_COLOR
	stroke.Thickness = 2.5
	stroke.Transparency = 0.4
	stroke.Parent = slot

	-- ── Top bar : type label + status badge ──────────────────
	local typeLabel = Instance.new("TextLabel")
	typeLabel.Name = "TypeLabel"
	typeLabel.Size = UDim2.new(1, -28, 0, 20)
	typeLabel.Position = UDim2.new(0, 7, 0, 5)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Text = typeInfo.Symbol .. " " .. typeInfo.Label
	typeLabel.TextColor3 = typeInfo.Color
	typeLabel.TextSize = 14
	typeLabel.Font = FONTS.Black
	typeLabel.TextXAlignment = Enum.TextXAlignment.Left
	typeLabel.Parent = slot
	addTextOutline(typeLabel, 2, 0)

	local statusBadge = Instance.new("TextLabel")
	statusBadge.Name = "StatusBadge"
	statusBadge.Size = UDim2.new(0, 22, 0, 22)
	statusBadge.Position = UDim2.new(1, -27, 0, 4)
	statusBadge.BackgroundTransparency = 1
	statusBadge.Text = "✗"
	statusBadge.TextColor3 = MISSING_COLOR
	statusBadge.TextSize = 22
	statusBadge.Font = FONTS.Black
	statusBadge.Parent = slot
	addTextOutline(statusBadge, 2, 0)

	-- ── Centre : ViewportFrame (filled) ou gros ✗ + MISSING (empty) ──
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.new(1, -12, 0, 90)
	viewport.Position = UDim2.new(0, 6, 0, 30)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Visible = false
	viewport.Parent = slot

	local missingIcon = Instance.new("TextLabel")
	missingIcon.Name = "MissingIcon"
	missingIcon.Size = UDim2.new(0, 80, 0, 80)
	missingIcon.Position = UDim2.new(0.5, 0, 0, 35)
	missingIcon.AnchorPoint = Vector2.new(0.5, 0)
	missingIcon.BackgroundTransparency = 1
	missingIcon.Text = "?"
	missingIcon.TextColor3 = MISSING_COLOR
	missingIcon.TextSize = 76
	missingIcon.Font = FONTS.Black
	missingIcon.Parent = slot
	addTextOutline(missingIcon, 3, 0)

	-- ── Bottom : nom de la pièce ou "MISSING" ────────────────
	local pieceLabel = Instance.new("TextLabel")
	pieceLabel.Name = "PieceLabel"
	pieceLabel.Size = UDim2.new(1, -8, 0, 26)
	pieceLabel.Position = UDim2.new(0, 4, 1, -29)
	pieceLabel.BackgroundTransparency = 1
	pieceLabel.Text = "MISSING"
	pieceLabel.TextColor3 = MISSING_COLOR
	pieceLabel.TextSize = 14
	pieceLabel.Font = FONTS.Black
	pieceLabel.TextXAlignment = Enum.TextXAlignment.Center
	pieceLabel.TextScaled = false
	pieceLabel.TextTruncate = Enum.TextTruncate.AtEnd
	pieceLabel.Parent = slot
	addTextOutline(pieceLabel, 2, 0)

	slot.Parent = parent

	return {
		Frame = slot,
		Stroke = stroke,
		TypeLabel = typeLabel,
		StatusBadge = statusBadge,
		Viewport = viewport,
		MissingIcon = missingIcon,
		PieceLabel = pieceLabel,
		TypeInfo = typeInfo,
		_currentPieceKey = nil, -- "<setName>:<pieceType>" pour éviter de re-assembler si identique
	}
end

-- Remplit un ViewportFrame avec le template 3D d'une pièce et configure la caméra
function UIController:_PopulateSlotViewport(viewport, setName, pieceType)
	-- Vider le viewport
	for _, child in ipairs(viewport:GetChildren()) do
		child:Destroy()
	end

	local setData = BrainrotData.Sets[setName]
	if not setData then return end
	local pieceData = setData[pieceType]
	if not pieceData or not pieceData.TemplateName or pieceData.TemplateName == "" then return end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then return end
	local templatesFolder = assetsFolder:FindFirstChild("BodyPartTemplates")
	if not templatesFolder then return end
	local typeFolder = templatesFolder:FindFirstChild(pieceType .. "Template")
	if not typeFolder then return end
	local source = typeFolder:FindFirstChild(pieceData.TemplateName)
	if not source then return end

	local clone = source:Clone()
	-- Nettoyer : supprimer BillboardGui, désactiver collisions, ancrer
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BillboardGui") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end

	clone.Parent = viewport

	-- Caméra cadrée sur la bounding box du modèle (la rotation continue se charge ensuite de la bouger)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 50
	viewport.CurrentCamera = camera
	camera.Parent = viewport

	-- Bounding box TIGHT : seulement les parts visibles (Transparency < 1)
	-- Évite que des parts cachées gonflent la BBox et fassent paraître le modèle minuscule.
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local partCount = 0
	for _, desc in ipairs(clone:GetDescendants()) do
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
	if partCount == 0 then return end

	local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	local sizeX, sizeY, sizeZ = maxX - minX, maxY - minY, maxZ - minZ
	local maxDim = math.max(sizeX, sizeY, sizeZ)
	local distance = maxDim * 1.2 -- aligné sur le Codex pour bien remplir le cadre

	-- Stocker les paramètres pour la boucle de rotation (_StartViewportRotation)
	viewport:SetAttribute("RotCenterX", center.X)
	viewport:SetAttribute("RotCenterY", center.Y)
	viewport:SetAttribute("RotCenterZ", center.Z)
	viewport:SetAttribute("RotDistance", distance)

	-- Position initiale (sera écrasée par la boucle au prochain frame)
	local camPos = center + Vector3.new(distance * 0.7, distance * 0.4, distance * 0.9)
	camera.CFrame = CFrame.new(camPos, center)
end

-- Boucle unique de rotation des viewports 3D (caméra orbite autour du modèle)
function UIController:_StartViewportRotation()
	if self._viewportRotationStarted then return end
	self._viewportRotationStarted = true

	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		local slots = self._inventorySlots
		if not slots then return end

		for index, slot in ipairs(slots) do
			local viewport = slot.Viewport
			if viewport and viewport.Visible then
				local cam = viewport.CurrentCamera
				local cx = viewport:GetAttribute("RotCenterX")
				local cy = viewport:GetAttribute("RotCenterY")
				local cz = viewport:GetAttribute("RotCenterZ")
				local distance = viewport:GetAttribute("RotDistance")
				if cam and cx and distance then
					local center = Vector3.new(cx, cy, cz)
					-- 1 rad/sec ≈ 6.3s/tour ; léger décalage par slot pour varier
					local angle = elapsed * 1.0 + (index - 1) * 0.7
					local horizDist = distance * 0.95
					local x = math.cos(angle) * horizDist
					local z = math.sin(angle) * horizDist
					local y = distance * 0.4
					cam.CFrame = CFrame.new(center + Vector3.new(x, y, z), center)
				end
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════

-- _CreateNotificationArea supprimé: on utilise le NotificationUI pré-existant

-- ═══════════════════════════════════════════════════════
-- MISE À JOUR DU CASH
-- ═══════════════════════════════════════════════════════

function UIController:UpdateCash(cash)
	currentPlayerData.Cash = cash
	if self._cashLabel then
		self._cashLabel.Text = "$" .. self:FormatNumber(cash)
	end

	-- Animation de pulse
	if self._cashFrame then
		self:PulseElement(self._cashFrame)
	end
end


-- ═══════════════════════════════════════════════════════
-- MISE À JOUR DE L'INVENTAIRE
-- ═══════════════════════════════════════════════════════

function UIController:UpdateInventory(pieces)
	currentPlayerData.PiecesInHand = pieces

	-- Mettre à jour le titre
	if self._inventoryTitle then
		self._inventoryTitle.Text = "PIECES IN HAND (" .. #pieces .. "/3)"
	end

	-- Trier les pièces par type : Head → slot 1, Body → slot 2, Legs → slot 3
	local sortedPieces = {nil, nil, nil}
	for _, piece in ipairs(pieces) do
		if piece.PieceType == Constants.PieceType.Head then
			sortedPieces[1] = piece
		elseif piece.PieceType == Constants.PieceType.Body then
			sortedPieces[2] = piece
		elseif piece.PieceType == Constants.PieceType.Legs then
			sortedPieces[3] = piece
		end
	end

	-- Mettre à jour chaque slot
	local MISSING_COLOR = Color3.fromRGB(220, 70, 70)
	local SUCCESS_COLOR = Color3.fromRGB(80, 220, 110)

	for i, slotData in ipairs(self._inventorySlots) do
		local piece = sortedPieces[i]
		local typeInfo = slotData.TypeInfo

		if piece then
			-- Slot REMPLI : viewport 3D + nom + bordure rareté + ✓ vert
			local rarityColor = self:GetRarityColor(piece.SetName)
			local pieceKey = piece.SetName .. ":" .. piece.PieceType

			-- Recharger le viewport seulement si la pièce a changé (perf)
			if slotData._currentPieceKey ~= pieceKey then
				self:_PopulateSlotViewport(slotData.Viewport, piece.SetName, piece.PieceType)
				slotData._currentPieceKey = pieceKey
			end

			slotData.Viewport.Visible = true
			slotData.MissingIcon.Visible = false

			slotData.PieceLabel.Visible = true
			slotData.PieceLabel.Text = piece.DisplayName
			slotData.PieceLabel.TextColor3 = rarityColor

			slotData.StatusBadge.Text = "✓"
			slotData.StatusBadge.TextColor3 = SUCCESS_COLOR

			slotData.TypeLabel.TextColor3 = typeInfo.Color

			slotData.Frame.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
			slotData.Frame.BackgroundTransparency = 0.1
			slotData.Stroke.Color = rarityColor
			slotData.Stroke.Transparency = 0
			slotData.Stroke.Thickness = 2.5
		else
			-- Slot VIDE : "?" + "MISSING" + bordure rouge dim + ✗ rouge
			slotData.Viewport.Visible = false
			slotData.MissingIcon.Visible = true

			slotData.PieceLabel.Visible = true
			slotData.PieceLabel.Text = "MISSING"
			slotData.PieceLabel.TextColor3 = MISSING_COLOR

			slotData.StatusBadge.Text = "✗"
			slotData.StatusBadge.TextColor3 = MISSING_COLOR

			slotData.TypeLabel.TextColor3 = typeInfo.Color

			slotData.Frame.BackgroundColor3 = COLORS.SlotEmpty
			slotData.Frame.BackgroundTransparency = 0.2
			slotData.Stroke.Color = MISSING_COLOR
			slotData.Stroke.Transparency = 0.4
			slotData.Stroke.Thickness = 2

			slotData._currentPieceKey = nil
		end
	end

	-- Afficher/masquer le prix total cumulé
	if self._priceTotalLabel then
		if #pieces >= 1 then
			local total = 0
			for _, piece in ipairs(pieces) do
				total = total + (piece.Price or 0)
			end
			self._priceTotalLabel.Text = "Craft cost: $" .. self:FormatNumber(total)
			self._priceTotalLabel.Visible = true
		else
			self._priceTotalLabel.Visible = false
		end
	end

	-- Afficher/masquer le bouton Drop (dès 1 pièce)
	if self._dropButton then
		self._dropButton.Visible = (#pieces >= 1)
	end

	-- Afficher/masquer le message Craft
	if self._craftLabel then
		self._craftLabel.Visible = (#pieces >= 3)

		if #pieces >= 3 then
			local hasHead = false
			local hasBody = false
			local hasLegs = false

			for _, piece in ipairs(pieces) do
				if piece.PieceType == Constants.PieceType.Head then hasHead = true end
				if piece.PieceType == Constants.PieceType.Body then hasBody = true end
				if piece.PieceType == Constants.PieceType.Legs then hasLegs = true end
			end

			if hasHead and hasBody and hasLegs then
				self._craftLabel.BackgroundColor3 = COLORS.CraftGreen
				self._craftLabel.Text = "Go place your Brainrot at your base!"
				self._craftReady = true
			else
				self._craftLabel.BackgroundColor3 = COLORS.CraftYellow
				self._craftLabel.Text = "Need 3 different types!"
				self._craftReady = false
			end
		else
			self._craftReady = false
		end
	end
end

-- ═══════════════════════════════════════════════════════
-- MISE À JOUR GLOBALE
-- ═══════════════════════════════════════════════════════

function UIController:UpdateAll(data)
	if data.Cash ~= nil then
		self:UpdateCash(data.Cash)
	end


	if data.PiecesInHand ~= nil then
		self:UpdateInventory(data.PiecesInHand)
	end

	if data.OwnedSlots ~= nil then
		currentPlayerData.OwnedSlots = data.OwnedSlots
	end
end

-- ═══════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════

function UIController:ShowNotification(notifType, message, duration)
	duration = duration or 3

	if not self._notifContainer or not self._notifTemplate then return end

	-- Cloner le template
	local notif = self._notifTemplate:Clone()
	notif.Name = "Notification_" .. notificationCounter
	notif.Visible = true
	notif.LayoutOrder = notificationCounter
	notificationCounter = notificationCounter + 1

	-- Configurer le contenu
	local messageLabel = notif:FindFirstChild("Message")
	if not messageLabel then return end
	messageLabel.Text = message

	-- Configurer la couleur
	local color = NOTIFICATION_COLORS[notifType] or NOTIFICATION_COLORS.Info
	notif.BackgroundColor3 = color

	-- Positionner hors écran (apparition par le bas)
	notif.Position = UDim2.new(0, 0, 0, 20)
	notif.Parent = self._notifContainer

	-- Animation d'entrée (fade in + slide up)
	local tweenIn = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	})
	tweenIn:Play()

	-- Attendre la durée
	task.delay(duration, function()
		-- Animation de sortie (fade out + slide up)
		local tweenOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, 0, 0, -20),
			BackgroundTransparency = 1
		})
		tweenOut:Play()

		tweenOut.Completed:Wait()
		notif:Destroy()
	end)
end

-- ═══════════════════════════════════════════════════════
-- ANIMATIONS
-- ═══════════════════════════════════════════════════════

function UIController:PulseElement(element)
	local originalSize = element.Size

	local tweenBig = TweenService:Create(element, TweenInfo.new(0.1), {
		Size = UDim2.new(originalSize.X.Scale * 1.05, math.floor(originalSize.X.Offset * 1.05), originalSize.Y.Scale * 1.05, math.floor(originalSize.Y.Offset * 1.05))
	})

	local tweenNormal = TweenService:Create(element, TweenInfo.new(0.1), {
		Size = originalSize
	})

	tweenBig:Play()
	tweenBig.Completed:Wait()
	tweenNormal:Play()
end

function UIController:AnimateCashGain(amount)
	if not self._screenGui then return end

	local floatingText = Instance.new("TextLabel")
	floatingText.Name = "CashGain"
	floatingText.Size = UDim2.new(0, 150, 0, 40)
	floatingText.Position = UDim2.new(0.5, -75, 0.4, 0)
	floatingText.BackgroundTransparency = 1
	floatingText.Text = "+$" .. self:FormatNumber(amount)
	floatingText.TextColor3 = Color3.fromRGB(0, 255, 100)
	floatingText.TextScaled = true
	floatingText.Font = FONTS.Black
	floatingText.TextStrokeTransparency = 0.5
	floatingText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	floatingText.Parent = self._screenGui

	local tweenUp = TweenService:Create(floatingText, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -75, 0.2, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	tweenUp:Play()
	tweenUp.Completed:Connect(function()
		floatingText:Destroy()
	end)
end

function UIController:AnimateCashLoss(amount)
	if not self._screenGui then return end

	local floatingText = Instance.new("TextLabel")
	floatingText.Name = "CashLoss"
	floatingText.Size = UDim2.new(0, 150, 0, 40)
	floatingText.Position = UDim2.new(0.5, -75, 0.4, 0)
	floatingText.BackgroundTransparency = 1
	floatingText.Text = "-$" .. self:FormatNumber(amount)
	floatingText.TextColor3 = Color3.fromRGB(255, 80, 80)
	floatingText.TextScaled = true
	floatingText.Font = FONTS.Black
	floatingText.TextStrokeTransparency = 0.5
	floatingText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	floatingText.Parent = self._screenGui

	local tweenDown = TweenService:Create(floatingText, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, -75, 0.6, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	tweenDown:Play()
	tweenDown.Completed:Connect(function()
		floatingText:Destroy()
	end)
end

function UIController:UpdateCashAnimated(newCash, oldCash, pickupAmount)
	oldCash = oldCash or currentPlayerData.Cash

	local difference = newCash - oldCash

	self:UpdateCash(newCash)

	if difference > 0 then
		self:AnimateCashGain(difference)
		if pickupAmount and pickupAmount > 0 then
			self:PlayCashPickupEffect(pickupAmount)
		end
	elseif difference < 0 then
		self:AnimateCashLoss(math.abs(difference))
	end
end

-- ═══════════════════════════════════════════════════════
-- EFFET DE PICKUP CASH (billets qui volent vers la pilule cash)
-- ═══════════════════════════════════════════════════════

-- UIScale dédié au "pop" de l'icône cash : on l'anime entre 1 et 1.18,
-- jamais cumulatif → plus de croissance infinie même si plusieurs billets arrivent.
function UIController:_GetCashIconPulseScale()
	if not self._cashIcon or not self._cashIcon.Parent then return nil end
	local s = self._cashIcon:FindFirstChild("PickupPulseScale")
	if s and s:IsA("UIScale") then return s end
	s = Instance.new("UIScale")
	s.Name = "PickupPulseScale"
	s.Scale = 1
	s.Parent = self._cashIcon
	return s
end

function UIController:_PulseCashIcon()
	local scale = self:_GetCashIconPulseScale()
	if not scale then return end
	-- Force la taille de départ : si un pulse précédent n'est pas encore revenu à 1,
	-- on saute directement sur 1 avant de remonter (évite tout cumul visuel).
	scale.Scale = 1
	local up = TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.18,
	})
	up:Play()
	up.Completed:Connect(function()
		if scale and scale.Parent then
			TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
end

function UIController:PlayCashPickupEffect(amount)
	if not self._screenGui or not self._cashFrame then return end
	amount = amount or 0
	if amount <= 0 then return end

	-- Son "ramassage d'argent" (un par appel, jamais bloqué)
	local sound = Instance.new("Sound")
	sound.Name = "CashPickupSound"
	sound.SoundId = CASH_PICKUP_SOUND
	sound.Volume = 0.55
	sound.PlayOnRemove = false
	sound.Parent = self._screenGui
	sound:Play()
	task.delay(3, function()
		if sound and sound.Parent then sound:Destroy() end
	end)

	-- Layer dédié (réutilisé entre effets)
	local layer = self._screenGui:FindFirstChild("CashPickupLayer")
	if not layer then
		layer = Instance.new("Frame")
		layer.Name = "CashPickupLayer"
		layer.Size = UDim2.new(1, 0, 1, 0)
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.ZIndex = 100
		layer.Parent = self._screenGui
	end

	-- Cible = centre de la pilule cash (recalculée à chaque billet pour suivre le scale responsive)
	local function getTarget()
		if not self._cashFrame or not self._cashFrame.Parent then return nil end
		return self._cashFrame.AbsolutePosition + self._cashFrame.AbsoluteSize * 0.5
	end

	-- Nombre de billets selon le montant (4..12)
	local billCount = math.clamp(4 + math.floor(math.log10(math.max(amount, 1))) * 2, 4, 12)

	local camera = Workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)

	for i = 1, billCount do
		task.delay((i - 1) * 0.04, function()
			if not layer.Parent then return end
			local target = getTarget()
			if not target then return end

			local bill = Instance.new("ImageLabel")
			bill.Name = "CashBill"
			bill.BackgroundTransparency = 1
			bill.Image = CASH_BILL_IMAGE
			bill.ScaleType = Enum.ScaleType.Fit
			bill.AnchorPoint = Vector2.new(0.5, 0.5)
			bill.Size = UDim2.fromOffset(64, 64)
			bill.ZIndex = 101

			-- Départ : zone aléatoire dans le tiers supérieur/central
			local startX = vp.X * (0.25 + math.random() * 0.5)
			local startY = vp.Y * (0.15 + math.random() * 0.3)
			bill.Position = UDim2.fromOffset(startX, startY)
			bill.Rotation = math.random(-60, 60)
			bill.Parent = layer

			-- Mini apparition (pop) via UIScale enfant -> ne touche pas Size de l'objet animé
			local popScale = Instance.new("UIScale")
			popScale.Scale = 0.4
			popScale.Parent = bill
			TweenService:Create(popScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()

			-- Sommet de l'arc
			local midX = (startX + target.X) * 0.5 + math.random(-60, 60)
			local midY = math.min(startY, target.Y) - math.random(40, 120)
			local spinDir = (math.random() < 0.5) and -1 or 1

			local t1 = TweenService:Create(bill, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(midX, midY),
				Rotation = bill.Rotation + spinDir * math.random(120, 220),
			})
			t1:Play()
			t1.Completed:Connect(function()
				if not bill.Parent then return end
				local finalTarget = getTarget() or target
				local t2 = TweenService:Create(bill, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.fromOffset(finalTarget.X, finalTarget.Y),
					Rotation = bill.Rotation + spinDir * math.random(90, 160),
					ImageTransparency = 0.35,
				})
				t2:Play()
				-- Le shrink à l'arrivée se fait via UIScale (jamais cumulatif sur l'icône cash)
				TweenService:Create(popScale, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Scale = 0.45,
				}):Play()
				t2.Completed:Connect(function()
					if bill and bill.Parent then bill:Destroy() end
					self:_PulseCashIcon()
				end)
			end)
		end)
	end
end

-- ═══════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════

function UIController:FormatNumber(number)
	local n = math.floor(number)
	local negative = n < 0
	if negative then n = -n end
	local prefix = negative and "-" or ""

	if n >= 1e15 then
		return prefix .. string.format("%.1fQ", n / 1e15)
	elseif n >= 1e12 then
		return prefix .. string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then
		return prefix .. string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return prefix .. string.format("%.1fM", n / 1e6)
	elseif n >= 100000 then
		return prefix .. string.format("%.1fK", n / 1e3)
	end

	local formatted = tostring(n)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return prefix .. formatted
end

function UIController:GetRarityColor(setName)
	local setData = BrainrotData.Sets and BrainrotData.Sets[setName]
	if setData then
		local rarity = setData.Rarity or "Common"
		local rarityInfo = BrainrotData.Rarities and BrainrotData.Rarities[rarity]
		if rarityInfo and rarityInfo.Color then
			return rarityInfo.Color
		end
	end
	return Color3.fromRGB(100, 100, 200)
end

function UIController:IsCraftReady()
	return self._craftReady == true
end

function UIController:GetDropButton()
	return self._dropButton
end

function UIController:GetCurrentData()
	return currentPlayerData
end

function UIController:GetScreenGui()
	return self._screenGui
end

return UIController
