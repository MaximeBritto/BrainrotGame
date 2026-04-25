--[[
    LoadingScreen.client.lua — léger
    - Retire l'écran Roblox par défaut, affiche logo + barre, fonce dès que le place est chargé.
    - Pas de scan global / PreloadAsync sur tout le jeu (c'était le principal coût).
]]

local LOGO_IMAGE_ID      = "rbxassetid://137990593829302"
local BAR_BACKGROUND_ID  = "rbxassetid://114349368090243"
local BAR_FRAME_IMAGE_ID = "rbxassetid://101184665163721"

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService    = game:GetService("TweenService")
local Players         = game:GetService("Players")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "LoadingScreen"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 1000
screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
screen.Enabled = true
screen.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
background.BorderSizePixel = 0
background.ZIndex = 1
background.Parent = screen

local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(18, 22, 36)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(6, 8, 14)),
})
bgGradient.Rotation = 90
bgGradient.Parent = background

local logo = Instance.new("ImageLabel")
logo.Name = "Logo"
logo.Size = UDim2.fromScale(1, 1)
logo.BackgroundTransparency = 1
logo.Image = LOGO_IMAGE_ID
logo.ScaleType = Enum.ScaleType.Crop
logo.ZIndex = 2
logo.Parent = screen

local bottomFade = Instance.new("Frame")
bottomFade.AnchorPoint = Vector2.new(0.5, 1)
bottomFade.Position = UDim2.fromScale(0.5, 1)
bottomFade.Size = UDim2.fromScale(1, 0.35)
bottomFade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bottomFade.BorderSizePixel = 0
bottomFade.BackgroundTransparency = 0.4
bottomFade.ZIndex = 2
bottomFade.Parent = screen
local fgrad = Instance.new("UIGradient")
fgrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0.0, 1.0),
	NumberSequenceKeypoint.new(1.0, 0.2),
})
fgrad.Rotation = 90
fgrad.Parent = bottomFade

local barContainer = Instance.new("Frame")
barContainer.AnchorPoint = Vector2.new(0.5, 0.5)
barContainer.Position = UDim2.fromScale(0.5, 0.84)
barContainer.Size = UDim2.fromScale(0.9, 0.13)
barContainer.BackgroundTransparency = 1
barContainer.ZIndex = 3
barContainer.Parent = screen
local barAspect = Instance.new("UIAspectRatioConstraint")
barAspect.AspectRatio = 7
barAspect.DominantAxis = Enum.DominantAxis.Width
barAspect.Parent = barContainer

local barBackground = Instance.new("ImageLabel")
barBackground.Size = UDim2.fromScale(1, 1)
barBackground.BackgroundTransparency = 1
barBackground.Image = BAR_BACKGROUND_ID
barBackground.ScaleType = Enum.ScaleType.Stretch
barBackground.ZIndex = 3
barBackground.Parent = barContainer

local barInterior = Instance.new("Frame")
barInterior.AnchorPoint = Vector2.new(0.5, 0.5)
barInterior.Position = UDim2.fromScale(0.51, 0.5)
barInterior.Size = UDim2.fromScale(0.83, 0.45)
barInterior.BackgroundTransparency = 1
barInterior.ClipsDescendants = true
barInterior.ZIndex = 4
barInterior.Parent = barContainer

local fill = Instance.new("Frame")
fill.AnchorPoint = Vector2.new(0, 0.5)
fill.Position = UDim2.fromScale(0, 0.5)
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
fill.BorderSizePixel = 0
fill.ZIndex = 6
fill.Parent = barInterior
local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 215, 100)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 215, 100)),
})
fillGradient.Parent = fill

local barFrame = Instance.new("ImageLabel")
barFrame.Size = UDim2.fromScale(1, 1)
barFrame.BackgroundTransparency = 1
barFrame.Image = BAR_FRAME_IMAGE_ID
barFrame.ScaleType = Enum.ScaleType.Stretch
barFrame.ImageRectOffset = Vector2.new(128, 275)
barFrame.ImageRectSize = Vector2.new(770, 110)
barFrame.ZIndex = 5
barFrame.Parent = barContainer

local percentLabel = Instance.new("TextLabel")
percentLabel.AnchorPoint = Vector2.new(0.5, 0.5)
percentLabel.Position = UDim2.fromScale(0.5, 0.5)
percentLabel.Size = UDim2.fromScale(1, 0.7)
percentLabel.BackgroundTransparency = 1
percentLabel.Text = "0%"
percentLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
percentLabel.Font = Enum.Font.GothamBold
percentLabel.TextScaled = true
percentLabel.TextStrokeTransparency = 0.2
percentLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
percentLabel.ZIndex = 7
percentLabel.Parent = barContainer

local statusLabel = Instance.new("TextLabel")
statusLabel.AnchorPoint = Vector2.new(0.5, 1)
statusLabel.Position = UDim2.fromScale(0.5, 0.68)
statusLabel.Size = UDim2.fromScale(0.6, 0.035)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "..."
statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextScaled = true
statusLabel.TextStrokeTransparency = 0.5
statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
statusLabel.ZIndex = 2
statusLabel.Parent = screen

local function setProgress(p)
	p = math.clamp(p, 0, 1)
	fill.Size = UDim2.fromScale(p, 1)
	percentLabel.Text = math.floor(p * 100 + 0.5) .. "%"
end

local FADE_OUT = 0.22

task.spawn(function()
	statusLabel.Text = "Chargement..."
	setProgress(0.15)

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	setProgress(0.55)

	-- Dossiers RS souvent prêts avec le place ; court timeout seulement pour éviter bloquer
	local rs = game:GetService("ReplicatedStorage")
	pcall(function()
		rs:WaitForChild("Remotes", 5)
	end)
	setProgress(0.9)

	setProgress(1)
	statusLabel.Text = "C'est parti !"

	local ti = TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(background, ti, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(logo, ti, { ImageTransparency = 1 }):Play()
	TweenService:Create(bottomFade, ti, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(barBackground, ti, { ImageTransparency = 1 }):Play()
	TweenService:Create(barFrame, ti, { ImageTransparency = 1 }):Play()
	TweenService:Create(fill, ti, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(percentLabel, ti, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	TweenService:Create(statusLabel, ti, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.wait(FADE_OUT)
	screen:Destroy()
end)
