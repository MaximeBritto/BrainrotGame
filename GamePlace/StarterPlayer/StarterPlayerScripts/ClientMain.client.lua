--[[
    ClientMain.lua (LocalScript)
    Point d'entrée principal du client

    Ce script initialise tous les contrôleurs et connecte les RemoteEvents
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig.module"))

-- Contrôleurs (charger depuis le même dossier)
local UIController = require(script.Parent:WaitForChild("UIController.module"))
local DoorController = require(script.Parent:WaitForChild("DoorController.module"))
local EconomyController = require(script.Parent:WaitForChild("EconomyController.module"))
local ArenaController = require(script.Parent:WaitForChild("ArenaController.module"))
local CodexController = require(script.Parent:WaitForChild("CodexController.module"))
local PreviewBrainrotController = require(script.Parent:WaitForChild("PreviewBrainrotController.module"))
local ShopController = require(script.Parent:WaitForChild("ShopController.module"))

-- Son (optionnel : si Assets/Sounds n'existe pas, pas d'erreur)
local SoundHelper = nil
do
	local ok, mod = pcall(function()
		return require(Shared:WaitForChild("SoundHelper.module"))
	end)
	if ok and mod then SoundHelper = mod end
end

-- Attendre les Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ═══════════════════════════════════════════════════════
-- INITIALISATION DU HUD (programmatique)
-- ═══════════════════════════════════════════════════════

-- Initialiser le HUD principal (crée le ScreenGui GameHUD)
UIController:Init()

-- Phase 6 : CodexController
CodexController:Init()

-- Preview Brainrot 3D
PreviewBrainrotController:Init()

-- Précharger les audios config (évite le décalage au 1er Play)
if SoundHelper and GameConfig.Sounds then
	SoundHelper.PrecacheConfigSounds(GameConfig.Sounds)
end

-- Musique d'ambiance (config GameConfig.Sounds)
if SoundHelper and GameConfig.Sounds and GameConfig.Sounds.BackgroundMusic and GameConfig.Sounds.BackgroundMusic ~= "" then
	SoundHelper.StartBackgroundMusic(
		GameConfig.Sounds.BackgroundMusic,
		GameConfig.Sounds.BackgroundMusicVolume
	)
end

-- ═══════════════════════════════════════════════════════
-- CONNEXION AUX REMOTES (Serveur → Client)
-- ═══════════════════════════════════════════════════════

-- SyncPlayerData
local syncPlayerData = Remotes:WaitForChild("SyncPlayerData")
syncPlayerData.OnClientEvent:Connect(function(data)
	local newCash = data.Cash
	local oldCash = UIController:GetCurrentData().Cash

	-- Le cash est animé séparément : si UpdateAll le met à jour avant,
	-- oldCash devient déjà égal à newCash et l'effet de ramassage est raté.
	local updateData = data
	if newCash ~= nil then
		updateData = {}
		for key, value in pairs(data) do
			if key ~= "Cash" then
				updateData[key] = value
			end
		end
	end

	UIController:UpdateAll(updateData)

	if data.OwnedSlots or data.SlotCash or data.UnlockedFloor or data.PermanentJumpBonus ~= nil then
		EconomyController:UpdateData(data)
	end

	if newCash ~= nil then
		if oldCash and oldCash ~= newCash then
			UIController:UpdateCashAnimated(newCash, oldCash, data.CashPickupAmount)
		else
			UIController:UpdateCash(newCash)
		end
	end
end)

-- SyncInventory
local syncInventory = Remotes:WaitForChild("SyncInventory")
syncInventory.OnClientEvent:Connect(function(pieces)
	UIController:UpdateInventory(pieces)
	PreviewBrainrotController:UpdatePreview(pieces)
end)

-- Notification
local notification = Remotes:WaitForChild("Notification")
notification.OnClientEvent:Connect(function(data)
	UIController:ShowNotification(data.Type, data.Message, data.Duration)
	if SoundHelper then
		local msg = data.Message or ""
		if data.Type == "Success" then
			-- Le ramassage cash a maintenant son propre son dans PlayCashPickupEffect.
			if not string.find(msg, "collected") and (string.find(msg, "purchased") or string.find(msg, "Slot")) then
				SoundHelper.Play("SlotBuy")
			end
		elseif data.Type == "Error" and string.find(msg, "money") then
			SoundHelper.Play("NotEnoughMoney")
		end
	end
end)

-- SyncDoorState
local syncDoorState = Remotes:WaitForChild("SyncDoorState")
syncDoorState.OnClientEvent:Connect(function(data)
	DoorController:UpdateDoorState(data.State, data.ReopenTime)
end)

-- ═══════════════════════════════════════════════════════
-- REMOTES (Client → Serveur)
-- ═══════════════════════════════════════════════════════

local pickupPiece = Remotes:WaitForChild("PickupPiece")
local craft = Remotes:WaitForChild("Craft")
local buySlot = Remotes:WaitForChild("BuySlot")
local activateDoor = Remotes:WaitForChild("ActivateDoor")
local dropPieces = Remotes:WaitForChild("DropPieces")
local collectSlotCash = Remotes:WaitForChild("CollectSlotCash")

-- Le craft se fait maintenant via ProximityPrompt sur les slots (voir StealController)

-- ═══════════════════════════════════════════════════════
-- BOUTON DROP
-- ═══════════════════════════════════════════════════════

local dropButton = UIController:GetDropButton()
if dropButton then
	dropButton.MouseButton1Click:Connect(function()
		dropPieces:FireServer()
	end)
end

-- ═══════════════════════════════════════════════════════
-- BOUTONS CODEX & SHOP (côté gauche, empilés)
-- ═══════════════════════════════════════════════════════

local hudGui = UIController:GetScreenGui()
if hudGui then
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

	-- Style cases 2x2 (réf. type "Index / Store" : brun-olive sombre, semi-transp., léger dégradé)
	local TILE_BG = Color3.fromRGB(45, 40, 30)
	local TILE_T = 0.48
	local TILE_HOVER = Color3.fromRGB(55, 50, 40)
	local TILE_T_HOVER = 0.4
	local TILE_DIM = Color3.fromRGB(32, 30, 25)
	local TILE_T_DIM = 0.58
	local TILE_HOVER_DIM = Color3.fromRGB(44, 40, 34)
	local TILE_T_HOVER_DIM = 0.5

	local function styleTileButton(button, cornerRadius)
		button.ClipsDescendants = false

		local corner = button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, cornerRadius or 12)
		corner.Parent = button

		local stroke = button:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 2
		stroke.Transparency = 0.1
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = button

		return stroke
	end

	-- ICON ASSET IDS (style "brainrot UI" demandé par le joueur)
	local ICON_CODEX = "rbxassetid://115478214680093"
	local ICON_SHOP  = "rbxassetid://14736132184"
	local ICON_SPEED = "rbxassetid://122934603221227"
	local ICON_JUMP  = "rbxassetid://95177557341280"

	-- Survol : effet uniquement sur l'icône (pas la case) — micro zoom + légère rotation
	local function attachIconHoverVfx(button, icon, tileName)
		if not icon then
			return
		end
		icon.Rotation = 0
		local rotSign = 1
		if tileName and #tileName > 0 then
			rotSign = (string.byte(tileName, 1) % 2 == 0) and 1 or -1
		end
		local hoverRot = 8 * rotSign
		local hoverTime = 0.11
		local leaveTime = 0.14
		local hoverScale = 1.12

		local uis = Instance.new("UIScale")
		uis.Name = "IconHoverScale"
		uis.Scale = 1
		uis.Parent = icon

		local function playHoverIn()
			TweenService:Create(
				icon,
				TweenInfo.new(hoverTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Rotation = hoverRot }
			):Play()
			TweenService:Create(
				uis,
				TweenInfo.new(hoverTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = hoverScale }
			):Play()
		end
		local function playHoverOut()
			TweenService:Create(
				icon,
				TweenInfo.new(leaveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Rotation = 0 }
			):Play()
			TweenService:Create(
				uis,
				TweenInfo.new(leaveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
		button.MouseEnter:Connect(playHoverIn)
		button.MouseLeave:Connect(playHoverOut)
	end

	-- Helper : crée un bouton carré "tile" (fond unifié sombre, icône + label)
	local function createSquareTile(parent, name, position, iconAsset, labelText, bgColor, bgTransparency)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 90, 0, 90)
		btn.Position = position
		btn.AnchorPoint = Vector2.new(0, 0)
		btn.BackgroundColor3 = bgColor or TILE_BG
		btn.BackgroundTransparency = bgTransparency ~= nil and bgTransparency or TILE_T
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = parent
		styleTileButton(btn, 12)

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		-- Grand sans empiéter sur le label du bas (bouton 90px de haut)
		icon.Size = UDim2.new(0, 74, 0, 74)
		icon.Position = UDim2.new(0.5, 0, 0.5, -9)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = iconAsset
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 2
		icon.Parent = btn
		attachIconHoverVfx(btn, icon, name)

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, -6, 0, 20)
		label.Position = UDim2.new(0, 3, 1, -22)
		label.BackgroundTransparency = 1
		label.Text = labelText
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 16
		label.Font = Enum.Font.GothamBlack
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 2
		label.Parent = btn
		addTextOutline(label, 2.5, 0)

		return btn, icon, label
	end

	-- Helper : crée le toggle visuel (track + knob) en tant que SIBLING du bouton
	local function createToggleSibling(parent, name, position)
		local track = Instance.new("Frame")
		track.Name = name .. "Track"
		track.Size = UDim2.new(0, 60, 0, 24)
		track.Position = position
		track.AnchorPoint = Vector2.new(0.5, 0)
		track.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
		track.BorderSizePixel = 0
		track.Parent = parent

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track

		local trackStroke = Instance.new("UIStroke")
		trackStroke.Color = Color3.fromRGB(0, 0, 0)
		trackStroke.Thickness = 2
		trackStroke.Transparency = 0.05
		trackStroke.Parent = track

		local knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.new(0, 18, 0, 18)
		knob.Position = UDim2.new(1, -21, 0.5, 0)
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		knob.BorderSizePixel = 0
		knob.Parent = track

		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(1, 0)
		knobCorner.Parent = knob

		return track, knob
	end

	-- Container 2x2 (positionnement absolu, pas de UIListLayout)
	local sideButtonsContainer = Instance.new("Frame")
	sideButtonsContainer.Name = "SideButtons"
	sideButtonsContainer.Size = UDim2.new(0, 200, 0, 240)
	sideButtonsContainer.Position = UDim2.new(0, 16, 0.5, -120)
	sideButtonsContainer.BackgroundTransparency = 1
	sideButtonsContainer.BorderSizePixel = 0
	sideButtonsContainer.Parent = hudGui

	-- Positions : grid 2x2, chaque case 90x90 espacée de 10px,
	-- ligne du bas un peu plus basse pour laisser place au toggle.
	local POS_CODEX = UDim2.new(0, 0,   0, 0)
	local POS_SHOP  = UDim2.new(0, 100, 0, 0)
	local POS_SPEED = UDim2.new(0, 0,   0, 100)
	local POS_JUMP  = UDim2.new(0, 100, 0, 100)

	-- ── BOUTON CODEX ──
	local codexButton, _, _codexText = createSquareTile(
		sideButtonsContainer, "CodexButton", POS_CODEX, ICON_CODEX, "CODEX", TILE_BG, TILE_T
	)
	local _codexStroke = codexButton:FindFirstChildOfClass("UIStroke")

	codexButton.MouseEnter:Connect(function()
		TweenService:Create(codexButton, TweenInfo.new(0.15), {
			BackgroundColor3 = TILE_HOVER,
			BackgroundTransparency = TILE_T_HOVER,
		}):Play()
	end)
	codexButton.MouseLeave:Connect(function()
		TweenService:Create(codexButton, TweenInfo.new(0.15), {
			BackgroundColor3 = TILE_BG,
			BackgroundTransparency = TILE_T,
		}):Play()
	end)

	codexButton.MouseButton1Click:Connect(function()
		CodexController:Open()
	end)

	-- Badge pastille sur le bouton Codex (coin supérieur droit)
	local codexBadge = Instance.new("TextLabel")
	codexBadge.Name = "Badge"
	codexBadge.Size = UDim2.new(0, 22, 0, 22)
	codexBadge.Position = UDim2.new(1, -4, 0, -4)
	codexBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	codexBadge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	codexBadge.BorderSizePixel = 0
	codexBadge.Text = "0"
	codexBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	codexBadge.TextSize = 12
	codexBadge.Font = Enum.Font.GothamBold
	codexBadge.ZIndex = 5
	codexBadge.Visible = false
	codexBadge.Parent = codexButton
	Instance.new("UICorner", codexBadge).CornerRadius = UDim.new(1, 0)
	CodexController._codexButtonBadge = codexBadge

	-- ── BOUTON SHOP ──
	local shopButton, _, _shopText = createSquareTile(
		sideButtonsContainer, "ShopButton", POS_SHOP, ICON_SHOP, "SHOP", TILE_BG, TILE_T
	)
	local _shopStroke = shopButton:FindFirstChildOfClass("UIStroke")

	shopButton.MouseEnter:Connect(function()
		TweenService:Create(shopButton, TweenInfo.new(0.15), {
			BackgroundColor3 = TILE_HOVER,
			BackgroundTransparency = TILE_T_HOVER,
		}):Play()
	end)
	shopButton.MouseLeave:Connect(function()
		TweenService:Create(shopButton, TweenInfo.new(0.15), {
			BackgroundColor3 = TILE_BG,
			BackgroundTransparency = TILE_T,
		}):Play()
	end)

	shopButton.MouseButton1Click:Connect(function()
		ShopController:Toggle()
	end)

	-- ── BOUTON SPEED TOGGLE ──
	local speedBoosted = true -- état par défaut (vitesse boostée)

	local speedButton, _, speedText = createSquareTile(
		sideButtonsContainer, "SpeedToggleButton", POS_SPEED, ICON_SPEED, "SPEED", TILE_BG, TILE_T
	)
	local speedStroke = speedButton:FindFirstChildOfClass("UIStroke")

	-- Multiplicateur "x1.5" affiché au-dessus du label, dans le coin haut-droit du carré
	local speedMultiplierLabel = Instance.new("TextLabel")
	speedMultiplierLabel.Name = "MultiplierLabel"
	speedMultiplierLabel.Size = UDim2.new(0, 50, 0, 18)
	speedMultiplierLabel.Position = UDim2.new(1, -4, 0, 4)
	speedMultiplierLabel.AnchorPoint = Vector2.new(1, 0)
	speedMultiplierLabel.BackgroundTransparency = 1
	speedMultiplierLabel.Text = ""
	speedMultiplierLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	speedMultiplierLabel.TextSize = 14
	speedMultiplierLabel.Font = Enum.Font.GothamBlack
	speedMultiplierLabel.TextXAlignment = Enum.TextXAlignment.Right
	speedMultiplierLabel.ZIndex = 3
	speedMultiplierLabel.Parent = speedButton
	addTextOutline(speedMultiplierLabel, 2, 0)

	-- Toggle ON/OFF : SIBLING du bouton, positionné JUSTE EN DESSOUS du carré
	local toggleTrack, toggleKnob = createToggleSibling(
		sideButtonsContainer, "Speed",
		UDim2.new(0, 45, 0, 196) -- centré sous le bouton speed (POS_SPEED.x + 45)
	)

	local function updateSpeedButtonVisual()
		local color = speedBoosted and TILE_BG or TILE_DIM
		local bgT = speedBoosted and TILE_T or TILE_T_DIM
		local strokeColor = Color3.fromRGB(0, 0, 0)
		local trackColor = speedBoosted and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(120, 120, 120)
		local knobPos = speedBoosted and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		TweenService:Create(speedButton, TweenInfo.new(0.2), {
			BackgroundColor3 = color,
			BackgroundTransparency = bgT,
		}):Play()
		TweenService:Create(toggleTrack, TweenInfo.new(0.2), {
			BackgroundColor3 = trackColor,
		}):Play()
		TweenService:Create(toggleKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = knobPos,
		}):Play()
		speedStroke.Color = strokeColor
		speedText.Text = speedBoosted and "SPEED" or "SLOW"

		-- Afficher le multiplicateur de speed quand activé
		if speedBoosted then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local walkSpeed = humanoid and humanoid.WalkSpeed or 16
			speedMultiplierLabel.Text = "x" .. string.format("%.1f", walkSpeed / 16)
			speedMultiplierLabel.Visible = true
		else
			speedMultiplierLabel.Visible = false
		end
	end

	speedButton.MouseEnter:Connect(function()
		local c = speedBoosted and TILE_HOVER or TILE_HOVER_DIM
		local t = speedBoosted and TILE_T_HOVER or TILE_T_HOVER_DIM
		TweenService:Create(speedButton, TweenInfo.new(0.15), {
			BackgroundColor3 = c,
			BackgroundTransparency = t,
		}):Play()
	end)
	speedButton.MouseLeave:Connect(function()
		local c = speedBoosted and TILE_BG or TILE_DIM
		local t = speedBoosted and TILE_T or TILE_T_DIM
		TweenService:Create(speedButton, TweenInfo.new(0.15), {
			BackgroundColor3 = c,
			BackgroundTransparency = t,
		}):Play()
	end)

	local toggleSpeedRemote = Remotes:WaitForChild("ToggleSpeed")
	speedButton.MouseButton1Click:Connect(function()
		toggleSpeedRemote:FireServer()
	end)

	toggleSpeedRemote.OnClientEvent:Connect(function(newState)
		speedBoosted = newState
		-- Petit délai pour laisser le serveur appliquer le WalkSpeed
		task.delay(0.15, updateSpeedButtonVisual)
	end)

	-- Rafraîchir le label x1.0/x2.0 dès que le serveur change WalkSpeed
	-- (ex: achat cheat menu, boost permanent, respawn, carrying brainrot)
	local function hookSpeedHumanoid(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(updateSpeedButtonVisual)
		end
	end
	if player.Character then hookSpeedHumanoid(player.Character) end
	player.CharacterAdded:Connect(hookSpeedHumanoid)

	-- Init: afficher le multiplicateur après que le personnage soit chargé
	task.delay(1, updateSpeedButtonVisual)

	-- ── BOUTON JUMP TOGGLE ──
	local jumpBoosted = true -- choix manuel (on/off)
	local inNoBoostZone = false -- override serveur quand le joueur est dans une SpawnZone taggée NoJumpBoost

	local jumpButton, _, jumpText = createSquareTile(
		sideButtonsContainer, "JumpToggleButton", POS_JUMP, ICON_JUMP, "JUMP", TILE_BG, TILE_T
	)
	local jumpStroke = jumpButton:FindFirstChildOfClass("UIStroke")

	local jumpMultiplierLabel = Instance.new("TextLabel")
	jumpMultiplierLabel.Name = "MultiplierLabel"
	jumpMultiplierLabel.Size = UDim2.new(0, 50, 0, 18)
	jumpMultiplierLabel.Position = UDim2.new(1, -4, 0, 4)
	jumpMultiplierLabel.AnchorPoint = Vector2.new(1, 0)
	jumpMultiplierLabel.BackgroundTransparency = 1
	jumpMultiplierLabel.Text = ""
	jumpMultiplierLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
	jumpMultiplierLabel.TextSize = 14
	jumpMultiplierLabel.Font = Enum.Font.GothamBlack
	jumpMultiplierLabel.TextXAlignment = Enum.TextXAlignment.Right
	jumpMultiplierLabel.ZIndex = 3
	jumpMultiplierLabel.Parent = jumpButton
	addTextOutline(jumpMultiplierLabel, 2, 0)

	-- Toggle ON/OFF : SIBLING du bouton, positionné JUSTE EN DESSOUS du carré
	local jumpToggleTrack, jumpToggleKnob = createToggleSibling(
		sideButtonsContainer, "Jump",
		UDim2.new(0, 145, 0, 196) -- centré sous le bouton jump (POS_JUMP.x + 45)
	)

	local function updateJumpButtonVisual()
		-- L'affichage "on" n'apparaît que si le joueur a activé le boost ET n'est pas dans une zone de respawn
		local effectiveOn = jumpBoosted and not inNoBoostZone
		local color = effectiveOn and TILE_BG or TILE_DIM
		local bgT = effectiveOn and TILE_T or TILE_T_DIM
		local strokeColor = Color3.fromRGB(0, 0, 0)
		local trackColor = effectiveOn and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(120, 120, 120)
		local knobPos = effectiveOn and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		TweenService:Create(jumpButton, TweenInfo.new(0.2), {
			BackgroundColor3 = color,
			BackgroundTransparency = bgT,
		}):Play()
		TweenService:Create(jumpToggleTrack, TweenInfo.new(0.2), {
			BackgroundColor3 = trackColor,
		}):Play()
		TweenService:Create(jumpToggleKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = knobPos,
		}):Play()
		jumpStroke.Color = strokeColor
		if inNoBoostZone then
			jumpText.Text = "SAFE"
		else
			jumpText.Text = jumpBoosted and "JUMP" or "LOW"
		end

		if effectiveOn then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local basePower = (GameConfig.Jump and GameConfig.Jump.BasePower) or 50
			local jumpPower = humanoid and humanoid.JumpPower or basePower
			jumpMultiplierLabel.Text = "x" .. string.format("%.1f", jumpPower / basePower)
			jumpMultiplierLabel.Visible = true
		else
			jumpMultiplierLabel.Visible = false
		end
	end

	jumpButton.MouseEnter:Connect(function()
		local effectiveOn = jumpBoosted and not inNoBoostZone
		local c = effectiveOn and TILE_HOVER or TILE_HOVER_DIM
		local t = effectiveOn and TILE_T_HOVER or TILE_T_HOVER_DIM
		TweenService:Create(jumpButton, TweenInfo.new(0.15), {
			BackgroundColor3 = c,
			BackgroundTransparency = t,
		}):Play()
	end)
	jumpButton.MouseLeave:Connect(function()
		local effectiveOn = jumpBoosted and not inNoBoostZone
		local c = effectiveOn and TILE_BG or TILE_DIM
		local t = effectiveOn and TILE_T or TILE_T_DIM
		TweenService:Create(jumpButton, TweenInfo.new(0.15), {
			BackgroundColor3 = c,
			BackgroundTransparency = t,
		}):Play()
	end)

	local toggleJumpRemote = Remotes:WaitForChild("ToggleJump")
	jumpButton.MouseButton1Click:Connect(function()
		if inNoBoostZone then return end -- pas de toggle dans la zone de respawn
		toggleJumpRemote:FireServer()
	end)

	toggleJumpRemote.OnClientEvent:Connect(function(newState)
		jumpBoosted = newState
		task.delay(0.15, updateJumpButtonVisual)
	end)

	local syncJumpZoneRemote = Remotes:WaitForChild("SyncJumpZone")
	syncJumpZoneRemote.OnClientEvent:Connect(function(inZone)
		inNoBoostZone = inZone and true or false
		updateJumpButtonVisual()
	end)

	-- Rafraîchir le label x1.0/x2.0 dès que le serveur change JumpPower
	local function hookJumpHumanoid(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid:GetPropertyChangedSignal("JumpPower"):Connect(updateJumpButtonVisual)
		end
	end
	if player.Character then hookJumpHumanoid(player.Character) end
	player.CharacterAdded:Connect(hookJumpHumanoid)

	task.delay(1, updateJumpButtonVisual)
end

-- ═══════════════════════════════════════════════════════
-- BOOST MULTIPLIER TIMER UI (X2)
-- ═══════════════════════════════════════════════════════

local boostTimerFrame = nil
local boostTimerLabel = nil
local boostRemainingSeconds = 0
local boostTimerActive = false

if hudGui then
	-- Conteneur du timer boost (au-dessus du cash display)
	boostTimerFrame = Instance.new("Frame")
	boostTimerFrame.Name = "BoostTimerFrame"
	boostTimerFrame.Size = UDim2.new(0, 170, 0, 40)
	boostTimerFrame.Position = UDim2.new(0, 15, 1, -78)
	boostTimerFrame.AnchorPoint = Vector2.new(0, 1)
	boostTimerFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	boostTimerFrame.BackgroundTransparency = 0.2
	boostTimerFrame.BorderSizePixel = 0
	boostTimerFrame.Visible = false
	boostTimerFrame.Parent = hudGui

	local boostCorner = Instance.new("UICorner")
	boostCorner.CornerRadius = UDim.new(0, 10)
	boostCorner.Parent = boostTimerFrame

	local boostStroke = Instance.new("UIStroke")
	boostStroke.Color = Color3.fromRGB(255, 215, 0)
	boostStroke.Thickness = 2
	boostStroke.Parent = boostTimerFrame

	-- Label "X2" à gauche
	local boostIcon = Instance.new("TextLabel")
	boostIcon.Name = "BoostIcon"
	boostIcon.Size = UDim2.new(0, 55, 1, 0)
	boostIcon.Position = UDim2.new(0, 8, 0, 0)
	boostIcon.BackgroundTransparency = 1
	boostIcon.Text = "$ X2"
	boostIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
	boostIcon.TextSize = 22
	boostIcon.Font = Enum.Font.GothamBlack
	boostIcon.TextXAlignment = Enum.TextXAlignment.Left
	boostIcon.Parent = boostTimerFrame

	-- Timer à droite
	boostTimerLabel = Instance.new("TextLabel")
	boostTimerLabel.Name = "BoostTimer"
	boostTimerLabel.Size = UDim2.new(0, 90, 1, 0)
	boostTimerLabel.Position = UDim2.new(1, -95, 0, 0)
	boostTimerLabel.BackgroundTransparency = 1
	boostTimerLabel.Text = "00:00"
	boostTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	boostTimerLabel.TextSize = 20
	boostTimerLabel.Font = Enum.Font.GothamBold
	boostTimerLabel.TextXAlignment = Enum.TextXAlignment.Right
	boostTimerLabel.Parent = boostTimerFrame
end

local function formatBoostTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", mins, secs)
end

local function updateBoostTimerUI()
	if not boostTimerFrame or not boostTimerLabel then return end

	if boostTimerActive and boostRemainingSeconds > 0 then
		boostTimerFrame.Visible = true
		boostTimerLabel.Text = formatBoostTime(boostRemainingSeconds)
	else
		boostTimerFrame.Visible = false
		boostTimerActive = false
	end
end

local function startBoostCountdown(seconds)
	boostRemainingSeconds = seconds
	boostTimerActive = true
	updateBoostTimerUI()

	if boostTimerFrame then
		boostTimerFrame.Size = UDim2.new(0, 0, 0, 0)
		boostTimerFrame.Visible = true
		TweenService:Create(boostTimerFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 170, 0, 40),
		}):Play()
	end
end

local function stopBoostTimer()
	boostTimerActive = false
	boostRemainingSeconds = 0
	if boostTimerFrame then
		local tweenOut = TweenService:Create(boostTimerFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
		})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			boostTimerFrame.Visible = false
		end)
	end
end

-- Boucle de countdown
task.spawn(function()
	while true do
		task.wait(1)
		if boostTimerActive and boostRemainingSeconds > 0 then
			boostRemainingSeconds = boostRemainingSeconds - 1
			updateBoostTimerUI()
			if boostRemainingSeconds <= 0 then
				stopBoostTimer()
			end
		end
	end
end)

-- SyncMultiplierBoost
local syncMultiplierBoost = Remotes:FindFirstChild("SyncMultiplierBoost")
if syncMultiplierBoost then
	syncMultiplierBoost.OnClientEvent:Connect(function(data)
		if data.Active and data.RemainingSeconds and data.RemainingSeconds > 0 then
			startBoostCountdown(data.RemainingSeconds)
		else
			stopBoostTimer()
		end
	end)
end

-- ═══════════════════════════════════════════════════════
-- FONCTIONS PUBLIQUES
-- ═══════════════════════════════════════════════════════

local ClientMain = {}

function ClientMain:RequestPickupPiece(pieceId)
	pickupPiece:FireServer(pieceId)
end

function ClientMain:RequestCraft()
	craft:FireServer()
end

function ClientMain:RequestBuySlot()
	buySlot:FireServer()
end

function ClientMain:RequestActivateDoor()
	activateDoor:FireServer()
end

function ClientMain:RequestDropPieces()
	dropPieces:FireServer()
end

function ClientMain:RequestCollectSlotCash(slotIndex)
	collectSlotCash:FireServer(slotIndex)
end

function ClientMain:GetFullPlayerData()
	local getFullPlayerData = Remotes:WaitForChild("GetFullPlayerData")
	return getFullPlayerData:InvokeServer()
end

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

-- Demander les données initiales au serveur
task.spawn(function()
	task.wait(1)

	local fullData = ClientMain:GetFullPlayerData()

	if fullData then
		UIController:UpdateAll(fullData)
		EconomyController:UpdateData(fullData)
		if fullData.PiecesInHand then
			PreviewBrainrotController:UpdatePreview(fullData.PiecesInHand)
		end
		if fullData.CodexUnlocked then
			-- Mark initial data as "seen" so no badge on first load
			CodexController._codexUnlocked = fullData.CodexUnlocked
			pcall(function() CodexController:_MarkCodexAsSeen() end)
			CodexController:UpdateCodex(fullData.CodexUnlocked)
		end
		-- Fusion data
		if fullData.DiscoveredFusions then
			local count = 0
			for _ in pairs(fullData.DiscoveredFusions) do count = count + 1 end
			CodexController._fusionData = {
				DiscoveredFusions = fullData.DiscoveredFusions,
				ClaimedFusionRewards = fullData.ClaimedFusionRewards or {},
				FusionCount = count,
			}
			pcall(function() CodexController:RefreshBadges() end)
		end
		if fullData.MultiplierBoostActive and fullData.MultiplierBoostRemaining and fullData.MultiplierBoostRemaining > 0 then
			startBoostCountdown(fullData.MultiplierBoostRemaining)
		end
		if fullData.DoorState then
			DoorController:UpdateDoorState(fullData.DoorState, fullData.DoorReopenTime or 0, true)
		end
	else
		warn("[ClientMain] No data received from server")
	end
end)

-- ═══════════════════════════════════════════════════════
-- TERMINÉ - Initialiser les autres contrôleurs
-- ═══════════════════════════════════════════════════════

DoorController:Init()
EconomyController:Init(UIController)
ArenaController:Init()
ShopController:Init()

-- ═══════════════════════════════════════════════════════
-- PROXIMITÉ SHOP ET COLLECTPADS
-- ═══════════════════════════════════════════════════════

local ProximityPromptService = game:GetService("ProximityPromptService")

local function isOnPlayerBase(instance)
	local current = instance
	while current do
		if current:GetAttribute("OwnerUserId") == player.UserId then
			return true
		end
		current = current.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then return end

	if not isOnPlayerBase(prompt) then return end

	local parent = prompt.Parent

	if parent and parent.Name == "Sign" then
		local grandParent = parent.Parent
		if grandParent and grandParent.Name == "SlotShop" then
			EconomyController:OpenShop()
		elseif grandParent and grandParent.Name == "JumpShop" then
			EconomyController:RequestBuyJumpLevel()
		end
	end

	if parent and parent.Name == "CollectPad" then
		local slot = parent.Parent
		if slot then
			local slotIndex = slot:GetAttribute("SlotIndex")
			if not slotIndex and slot.Name:match("^Slot_(%d+)$") then
				slotIndex = tonumber(slot.Name:match("^Slot_(%d+)$"))
			end
			if slotIndex then
				EconomyController:RequestCollectSlot(slotIndex)
			end
		end
	end
end)

return ClientMain
