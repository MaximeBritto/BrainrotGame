-- StarterPlayer/StarterPlayerScripts/Controllers/StealController.client.lua
-- Gère le vol de Brainrot (StealPrompt) et le placement du brainrot volé (PlacePrompt)
-- + Affichage du modèle 3D porté en main (côté client, même approche que PreviewBrainrotController)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

-- Variables
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- État local
local _isCarrying = false
local _placePrompts = {} -- ProximityPrompts créés pour les slots vides

-- Le modèle 3D porté est désormais géré côté serveur (StealSystem)
-- pour être visible par tous les joueurs

-- ═══════════════════════════════════════════════════════
-- Le modèle 3D est créé côté serveur et soudé à la main gauche
-- (visible par tous les joueurs automatiquement)
-- ═══════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════
-- STEAL PROMPTS (inchangé)
-- ═══════════════════════════════════════════════════════

---
-- Cache les StealPrompts sur les Brainrots du joueur local
---
local function hideOwnStealPrompt(prompt)
	if prompt.Name == "StealPrompt" and prompt:GetAttribute("OwnerId") == player.UserId then
		prompt.Enabled = false
	end
end

-- Cacher les prompts déjà existants
for _, desc in ipairs(Workspace:GetDescendants()) do
	if desc:IsA("ProximityPrompt") then
		hideOwnStealPrompt(desc)
	end
end

-- Cacher les prompts ajoutés dynamiquement
Workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("ProximityPrompt") then
		hideOwnStealPrompt(desc)
	end
end)

-- ═══════════════════════════════════════════════════════
-- PLACE PROMPTS (inchangé)
-- ═══════════════════════════════════════════════════════

---
-- Trouve la base du joueur local via l'attribut OwnerUserId
---
local function findPlayerBase()
	local basesFolder = Workspace:FindFirstChild("Bases")
	if not basesFolder then return nil end

	for _, base in ipairs(basesFolder:GetChildren()) do
		if base:IsA("Model") and base:GetAttribute("OwnerUserId") == player.UserId then
			return base
		end
	end
	return nil
end

---
-- Crée des ProximityPrompts "PlacePrompt" sur les slots vides de la base du joueur
---
local function createPlacePrompts()
	-- D'abord nettoyer les anciens
	for _, prompt in ipairs(_placePrompts) do
		if prompt and prompt.Parent then
			prompt:Destroy()
		end
	end
	_placePrompts = {}

	local playerBase = findPlayerBase()
	if not playerBase then return end

	local slotsFolder = playerBase:FindFirstChild("Slots")
	if not slotsFolder then return end

	for _, slot in ipairs(slotsFolder:GetChildren()) do
		local slotIndex = tonumber(slot.Name:match("^Slot_(%d+)$"))
		if slotIndex then
			-- Vérifier si le slot est vide (pas de modèle Brainrot_ dedans)
			local hasBrainrot = false
			for _, child in ipairs(slot:GetChildren()) do
				if child:IsA("Model") and child.Name:match("^Brainrot_") then
					hasBrainrot = true
					break
				end
			end

			-- Vérifier que le slot est visible (pas caché = pas encore acheté)
			local platform = slot:FindFirstChild("Platform")
			if platform and not hasBrainrot and platform.Transparency < 1 then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "PlacePrompt"
				prompt.ActionText = "Placer"
				prompt.ObjectText = "Brainrot volé"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 8
				prompt.RequiresLineOfSight = false
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt:SetAttribute("SlotIndex", slotIndex)
				prompt.Parent = platform
				table.insert(_placePrompts, prompt)
			end
		end
	end
end

---
-- Supprime tous les PlacePrompts
---
local function removePlacePrompts()
	for _, prompt in ipairs(_placePrompts) do
		if prompt and prompt.Parent then
			prompt:Destroy()
		end
	end
	_placePrompts = {}
end

-- ═══════════════════════════════════════════════════════
-- ÉVÉNEMENTS REMOTES
-- ═══════════════════════════════════════════════════════

---
-- Écoute SyncCarriedBrainrot pour savoir si on porte un brainrot
---
local syncCarried = remotes:WaitForChild("SyncCarriedBrainrot")
syncCarried.OnClientEvent:Connect(function(carriedData)
	if carriedData then
		_isCarrying = true
		createPlacePrompts()
	else
		_isCarrying = false
		removePlacePrompts()
	end
end)

---
-- Écoute tous les ProximityPrompts déclenchés
---
ProximityPromptService.PromptTriggered:Connect(function(promptObject, playerWhoTriggered)
	-- Vérifier que c'est nous qui avons déclenché le prompt
	if playerWhoTriggered ~= player then return end

	-- Handle StealPrompt (vol de brainrot adverse)
	if promptObject.Name == "StealPrompt" then
		local ownerId = promptObject:GetAttribute("OwnerId")
		local slotId = promptObject:GetAttribute("SlotId")

		-- Ne pas voler ses propres Brainrots
		if ownerId == player.UserId then return end

		if ownerId and slotId then
			remotes.StealBrainrot:FireServer(ownerId, slotId)
			print(string.format("[StealController] Vol envoyé au serveur (owner: %d, slot: %d)", ownerId, slotId))
		end
		return
	end

	-- Handle PlacePrompt (placer le brainrot volé sur un slot)
	if promptObject.Name == "PlacePrompt" then
		if not _isCarrying then return end

		local slotIndex = promptObject:GetAttribute("SlotIndex")
		if slotIndex then
			remotes.PlaceStolenBrainrot:FireServer(slotIndex)
			print(string.format("[StealController] Placement envoyé au serveur (slot: %d)", slotIndex))
		end
		return
	end
end)

print("[StealController] Initialisé!")
