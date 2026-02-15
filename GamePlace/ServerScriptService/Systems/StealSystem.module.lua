-- ServerScriptService/Systems/StealSystem.module.lua
-- Système de vol : le voleur porte le brainrot en main et doit le placer sur un slot
local StealSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local DataService = require(script.Parent.Parent.Core["DataService.module"])
local GameConfig = require(ReplicatedStorage.Config["GameConfig.module"])

-- Systèmes injectés
local BrainrotModelSystem = nil
local PlayerService = nil
local PlacementSystem = nil

-- RemoteEvents
local remotes = nil

-- Configuration
local STEAL_MAX_DISTANCE = GameConfig.StealMaxDistance or 15

---
-- Initialisation
-- @param services table - { BrainrotModelSystem, PlayerService, PlacementSystem }
---
function StealSystem:Init(services)
	print("[StealSystem] Initialisation...")
	if services then
		BrainrotModelSystem = services.BrainrotModelSystem
		PlayerService = services.PlayerService
		PlacementSystem = services.PlacementSystem
	end
	remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
	if not remotes then
		warn("[StealSystem] Remotes introuvable!")
	end
	print("[StealSystem] Initialisé!")
end

---
-- Exécute un vol de Brainrot : le voleur porte le brainrot en main
-- @param thief Player
-- @param ownerId number
-- @param slotId number
-- @return boolean
---
function StealSystem:ExecuteSteal(thief, ownerId, slotId)
	local thiefId = thief.UserId
	print(string.format("[StealSystem] ExecuteSteal - thief: %s (id: %d), ownerId: %d, slotId: %s",
		thief.Name, thiefId, ownerId, tostring(slotId)))

	-- 0. On ne peut pas se voler soi-même
	if thiefId == ownerId then
		return false
	end

	-- 1. Vérifier que le voleur ne porte pas déjà un brainrot
	if PlayerService:IsCarryingBrainrot(thief) then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Vous transportez déjà un Brainrot volé!"
		})
		return false
	end

	-- 2. Vérifier que l'inventaire est vide (ne peut pas porter brainrot + pièces)
	local piecesInHand = PlayerService:GetPiecesInHand(thief)
	if #piecesInHand > 0 then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Votre inventaire doit être vide pour voler un Brainrot!"
		})
		return false
	end

	-- 3. Vérifier qu'il a au moins un slot libre
	local availableSlot = PlacementSystem:FindAvailableSlot(thief)
	if not availableSlot then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Aucun slot libre dans votre base!"
		})
		return false
	end

	-- 4. Vérifier que le propriétaire existe
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Propriétaire introuvable."
		})
		return false
	end

	-- 5. Vérifier que le Brainrot existe dans le slot
	local ownerData = DataService:GetPlayerData(owner)
	if not ownerData then
		warn("[StealSystem] Données du propriétaire introuvables!")
		return false
	end

	local slotKey = tostring(slotId)
	local brainrot = ownerData.PlacedBrainrots[slotKey]
	if not brainrot then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Ce slot est vide."
		})
		return false
	end

	-- 6. Vérifier la distance
	if not self:_IsInRange(thief, owner, slotId) then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Vous êtes trop loin du Brainrot."
		})
		return false
	end

	-- 7. Retirer le Brainrot du slot du propriétaire
	ownerData.PlacedBrainrots[slotKey] = nil
	DataService:UpdateValue(owner, "PlacedBrainrots", ownerData.PlacedBrainrots)

	if ownerData.Brainrots then
		ownerData.Brainrots[slotId] = nil
		DataService:UpdateValue(owner, "Brainrots", ownerData.Brainrots)
	end

	-- Détruire le modèle 3D
	if BrainrotModelSystem then
		BrainrotModelSystem:DestroyBrainrotModel(owner, slotId)
	end

	-- 8. Stocker le brainrot comme CarriedBrainrot dans les données runtime du voleur
	local carriedData = {
		HeadSet = brainrot.HeadSet,
		BodySet = brainrot.BodySet,
		LegsSet = brainrot.LegsSet,
		SetName = brainrot.SetName or brainrot.HeadSet,
		StolenAt = os.time(),
		StolenFromUserId = ownerId,
		StolenFromSlotId = slotId,
	}
	PlayerService:SetCarriedBrainrot(thief, carriedData)

	-- 9. Attacher le modèle visuel à la main gauche du voleur
	self:_AttachBrainrotToHand(thief, carriedData)

	-- 10. Sync clients
	-- Propriétaire
	remotes.SyncPlayerData:FireClient(owner, {
		PlacedBrainrots = ownerData.PlacedBrainrots,
		Cash = ownerData.Cash,
	})
	remotes.Notification:FireClient(owner, {
		Type = "Error",
		Message = "Votre Brainrot a été volé!"
	})

	-- Voleur
	local syncCarried = remotes:FindFirstChild("SyncCarriedBrainrot")
	if syncCarried then
		syncCarried:FireClient(thief, carriedData)
	end
	remotes.Notification:FireClient(thief, {
		Type = "Success",
		Message = "Brainrot volé! Allez le placer dans votre base (E sur un slot vide)."
	})

	print(string.format("[StealSystem] %s a volé le Brainrot de %s (slot %d) - porté en main",
		thief.Name, owner.Name, slotId))

	return true
end

---
-- Place le brainrot volé porté en main sur un slot du voleur
-- @param player Player
-- @param slotIndex number
-- @return boolean
---
function StealSystem:PlaceStolenBrainrot(player, slotIndex)
	-- 1. Vérifier que le joueur porte un brainrot
	local carriedData = PlayerService:GetCarriedBrainrot(player)
	if not carriedData then
		remotes.Notification:FireClient(player, {
			Type = "Error",
			Message = "Vous ne transportez pas de Brainrot volé."
		})
		return false
	end

	-- 2. Construire les données pour PlacementSystem
	local brainrotData = {
		SetName = carriedData.SetName,
		SlotIndex = slotIndex,
		PlacedAt = os.time(),
		HeadSet = carriedData.HeadSet,
		BodySet = carriedData.BodySet,
		LegsSet = carriedData.LegsSet,
	}

	-- 3. Placer via PlacementSystem (valide slot + crée modèle 3D)
	local success = PlacementSystem:PlaceBrainrot(player, slotIndex, brainrotData)
	if not success then
		remotes.Notification:FireClient(player, {
			Type = "Error",
			Message = "Impossible de placer le Brainrot ici."
		})
		return false
	end

	-- 4. Vider le CarriedBrainrot
	PlayerService:ClearCarriedBrainrot(player)
	self:_RemoveBrainrotFromHand(player)

	-- 5. Sync client
	local syncCarried = remotes:FindFirstChild("SyncCarriedBrainrot")
	if syncCarried then
		syncCarried:FireClient(player, nil)
	end

	local playerData = DataService:GetPlayerData(player)
	if playerData then
		remotes.SyncPlayerData:FireClient(player, {
			PlacedBrainrots = playerData.PlacedBrainrots,
			Cash = playerData.Cash,
		})
	end

	remotes.Notification:FireClient(player, {
		Type = "Success",
		Message = "Brainrot placé dans votre base!"
	})

	print(string.format("[StealSystem] %s a placé le Brainrot volé dans le slot %d", player.Name, slotIndex))

	return true
end

---
-- Attache un modèle de brainrot à la main gauche du joueur (comme la batte sur la main droite)
-- @param player Player
-- @param carriedData table
---
function StealSystem:_AttachBrainrotToHand(player, carriedData)
	local character = player.Character
	if not character then return end

	-- Main gauche (la batte est sur la droite)
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if not leftHand then
		warn("[StealSystem] Main gauche introuvable!")
		return
	end

	-- Supprimer l'ancien modèle si présent
	local oldModel = character:FindFirstChild("CarriedBrainrot")
	if oldModel then oldModel:Destroy() end

	-- Construire le modèle 3D via BrainrotModelSystem
	if not BrainrotModelSystem then
		warn("[StealSystem] BrainrotModelSystem non disponible")
		return
	end

	local model = BrainrotModelSystem:AssembleBrainrot(carriedData)
	if not model then
		warn("[StealSystem] Échec assemblage du modèle pour porter")
		return
	end

	model.Name = "CarriedBrainrot"

	-- Identifier les parties (head, body, legs)
	local headPart = nil
	local bodyPart = model.PrimaryPart
	local legsPart = nil

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			if part:FindFirstChild("TopAttachment") and not part:FindFirstChild("BottomAttachment") then
				legsPart = part
			end
			if part:FindFirstChild("BottomAttachment") and not part:FindFirstChild("TopAttachment") then
				headPart = part
			end
		end
	end

	-- Réduire la taille (40% de la taille originale)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Size = part.Size * 0.4
			part.CanCollide = false
			part.Anchored = false
		end
	end

	-- Ajouter des Highlights colorés par partie (Head=Rouge, Body=Vert, Legs=Bleu-Violet)
	if headPart then
		local headHighlight = Instance.new("Highlight")
		headHighlight.Name = "HeadHighlight"
		headHighlight.FillColor = Color3.fromRGB(255, 0, 0) -- Rouge
		headHighlight.OutlineColor = Color3.fromRGB(255, 100, 100)
		headHighlight.FillTransparency = 1 -- Seulement le contour
		headHighlight.OutlineTransparency = 0
		headHighlight.Enabled = false -- Désactivé par défaut, activé par le client selon la distance
		headHighlight.Adornee = headPart
		headHighlight.Parent = headPart
		
		-- Label "HEAD"
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TypeLabel"
		billboard.Size = UDim2.new(0, 60, 0, 20)
		billboard.StudsOffset = Vector3.new(0, headPart.Size.Y * 0.4 + 2, 0) -- Encore plus haut
		billboard.AlwaysOnTop = true
		billboard.Enabled = false -- Désactivé par défaut, activé par le client selon la distance
		billboard.Adornee = headPart
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "HEAD"
		label.TextColor3 = Color3.fromRGB(255, 0, 0)
		label.TextScaled = true
		label.Font = Enum.Font.Bangers
		label.TextStrokeTransparency = 0.5
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = billboard
		
		billboard.Parent = headPart
	end

	if bodyPart then
		local bodyHighlight = Instance.new("Highlight")
		bodyHighlight.Name = "BodyHighlight"
		bodyHighlight.FillColor = Color3.fromRGB(0, 255, 0) -- Vert
		bodyHighlight.OutlineColor = Color3.fromRGB(100, 255, 100)
		bodyHighlight.FillTransparency = 1 -- Seulement le contour
		bodyHighlight.OutlineTransparency = 0
		bodyHighlight.Enabled = false -- Désactivé par défaut, activé par le client selon la distance
		bodyHighlight.Adornee = bodyPart
		bodyHighlight.Parent = bodyPart
		
		-- Label "BODY"
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TypeLabel"
		billboard.Size = UDim2.new(0, 60, 0, 20)
		billboard.StudsOffset = Vector3.new(0, bodyPart.Size.Y * 0.4 + 2, 0) -- Encore plus haut
		billboard.AlwaysOnTop = true
		billboard.Enabled = false -- Désactivé par défaut, activé par le client selon la distance
		billboard.Adornee = bodyPart
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "BODY"
		label.TextColor3 = Color3.fromRGB(0, 255, 0)
		label.TextScaled = true
		label.Font = Enum.Font.Bangers
		label.TextStrokeTransparency = 0.5
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = billboard
		
		billboard.Parent = bodyPart
	end

	if legsPart then
		local legsHighlight = Instance.new("Highlight")
		legsHighlight.Name = "LegsHighlight"
		legsHighlight.FillColor = Color3.fromRGB(138, 43, 226) -- Bleu-Violet
		legsHighlight.OutlineColor = Color3.fromRGB(180, 100, 255)
		legsHighlight.FillTransparency = 1 -- Seulement le contour
		legsHighlight.OutlineTransparency = 0
		legsHighlight.Enabled = false -- Désactivé par défaut, activé par le client selon la distance
		legsHighlight.Adornee = legsPart
		legsHighlight.Parent = legsPart
		
		-- Label "LEGS"
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TypeLabel"
		billboard.Size = UDim2.new(0, 60, 0, 20)
		billboard.StudsOffset = Vector3.new(0, legsPart.Size.Y * 0.4 + 2, 0) -- Encore plus haut
		billboard.AlwaysOnTop = true
		billboard.Enabled = false -- Désactivé par défaut, activé par le client selon la distance
		billboard.Adornee = legsPart
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "LEGS"
		label.TextColor3 = Color3.fromRGB(138, 43, 226)
		label.TextScaled = true
		label.Font = Enum.Font.Bangers
		label.TextStrokeTransparency = 0.5
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = billboard
		
		billboard.Parent = legsPart
	end

	-- PrimaryPart (bodyPart)
	local primaryPart = model.PrimaryPart
	if not primaryPart then
		primaryPart = model:FindFirstChildWhichIsA("BasePart")
		model.PrimaryPart = primaryPart
	end

	if not primaryPart then
		warn("[StealSystem] Pas de PrimaryPart pour le modèle porté")
		model:Destroy()
		return
	end

	-- Souder à la main gauche (même pattern que BatSystem)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = leftHand
	weld.Part1 = primaryPart
	weld.Parent = primaryPart

	-- Positionner au-dessus de la main
	primaryPart.CFrame = leftHand.CFrame * CFrame.new(0, 1, 0)

	model.Parent = character

	-- Attribut pour que les autres systèmes sachent
	character:SetAttribute("CarryingBrainrot", true)

	print(string.format("[StealSystem] Brainrot attaché à la main de %s", player.Name))
end

---
-- Retire le modèle de brainrot de la main du joueur
-- @param player Player
---
function StealSystem:_RemoveBrainrotFromHand(player)
	local character = player.Character
	if not character then return end

	local carriedModel = character:FindFirstChild("CarriedBrainrot")
	if carriedModel then
		carriedModel:Destroy()
	end

	character:SetAttribute("CarryingBrainrot", nil)
end

---
-- Vérifie si le voleur est à portée du Brainrot (distance au slot, pas au joueur)
---
function StealSystem:_IsInRange(thief, owner, slotId)
	local thiefChar = thief.Character
	if not thiefChar then return false end

	local thiefRoot = thiefChar:FindFirstChild("HumanoidRootPart")
	if not thiefRoot then return false end

	-- Trouver le slot dans la base du propriétaire
	local basesFolder = game:GetService("Workspace"):FindFirstChild("Bases")
	if not basesFolder then return false end

	for _, base in ipairs(basesFolder:GetChildren()) do
		if base:GetAttribute("OwnerUserId") == owner.UserId then
			local slotsFolder = base:FindFirstChild("Slots")
			if not slotsFolder then return false end

			local slot = slotsFolder:FindFirstChild("Slot_" .. tostring(slotId))
			if not slot then return false end

			local platform = slot:FindFirstChild("Platform")
			local target = platform or slot:FindFirstChildWhichIsA("BasePart")
			if not target then return false end

			local distance = (thiefRoot.Position - target.Position).Magnitude
			return distance <= STEAL_MAX_DISTANCE
		end
	end

	return false
end

return StealSystem
