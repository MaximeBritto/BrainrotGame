-- StarterPlayer/StarterPlayerScripts/Controllers/BatController.client.lua
-- Détecte le clic gauche et envoie BatHit au serveur (pas de Tool = pas de 180°)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Configuration
local COOLDOWN = 1
local MAX_DISTANCE = 10

-- État
local lastSwing = 0
local isSwinging = false

---
-- Animation de swing : tween le bras droit vers l'avant et retour
---
local function PlaySwingAnimation()
	if isSwinging then return end
	isSwinging = true

	local character = player.Character
	if not character then isSwinging = false return end

	-- Trouver le Motor6D du bras droit (R15)
	local rightUpperArm = character:FindFirstChild("RightUpperArm")
	local shoulder = rightUpperArm and rightUpperArm:FindFirstChild("RightShoulder")

	-- Fallback R6
	if not shoulder then
		local torso = character:FindFirstChild("Torso")
		shoulder = torso and torso:FindFirstChild("Right Shoulder")
	end

	if not shoulder then isSwinging = false return end

	local originalC0 = shoulder.C0
	local swingC0 = originalC0 * CFrame.Angles(math.rad(120), 0, 0)

	-- Swing vers le bas
	local tweenDown = TweenService:Create(shoulder, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = swingC0})
	tweenDown:Play()

	tweenDown.Completed:Connect(function()
		-- Retour à la position normale
		local tweenBack = TweenService:Create(shoulder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {C0 = originalC0})
		tweenBack:Play()
		tweenBack.Completed:Connect(function()
			isSwinging = false
		end)
	end)
end

---
-- Détecte le joueur le plus proche à portée
---
local function GetClosestPlayer()
	local character = player.Character
	if not character then return nil end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local closestPlayer = nil
	local closestDistance = MAX_DISTANCE

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local otherChar = otherPlayer.Character
			if otherChar then
				local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
				if otherRoot then
					local distance = (root.Position - otherRoot.Position).Magnitude
					if distance < closestDistance then
						closestPlayer = otherPlayer
						closestDistance = distance
					end
				end
			end
		end
	end

	return closestPlayer
end

---
-- Clic gauche = swing
---
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	-- Vérifier que le joueur a une batte et ne porte pas un brainrot volé
	local character = player.Character
	if not character or not character:GetAttribute("HasBat") then return end
	if character:GetAttribute("CarryingBrainrot") then return end

	-- Cooldown
	local now = tick()
	if now - lastSwing < COOLDOWN then return end
	lastSwing = now

	-- Animation de swing
	PlaySwingAnimation()

	-- Détecter le joueur le plus proche
	local targetPlayer = GetClosestPlayer()

	if targetPlayer then
		remotes.BatHit:FireServer(targetPlayer.UserId)
		print(string.format("[BatController] Coup envoyé vers %s", targetPlayer.Name))
	else
		print("[BatController] Aucun joueur à portée")
	end
end)

print("[BatController] Initialisé!")
