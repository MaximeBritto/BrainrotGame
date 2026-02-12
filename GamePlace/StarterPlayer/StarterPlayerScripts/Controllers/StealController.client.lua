-- StarterPlayer/StarterPlayerScripts/Controllers/StealController.client.lua
-- Écoute les ProximityPrompts des Brainrots et envoie au serveur

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Workspace = game:GetService("Workspace")

-- Variables
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

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

---
-- Écoute tous les ProximityPrompts déclenchés
---
ProximityPromptService.PromptTriggered:Connect(function(promptObject, playerWhoTriggered)
	-- Vérifier que c'est nous qui avons déclenché le prompt
	if playerWhoTriggered ~= player then return end

	-- Vérifier que c'est un StealPrompt
	if promptObject.Name ~= "StealPrompt" then return end

	-- Récupérer les infos du propriétaire depuis les Attributes
	local ownerId = promptObject:GetAttribute("OwnerId")
	local slotId = promptObject:GetAttribute("SlotId")

	-- Ne pas voler ses propres Brainrots
	if ownerId == player.UserId then return end

	if ownerId and slotId then
		-- Envoyer au serveur
		remotes.StealBrainrot:FireServer(ownerId, slotId)
		print(string.format("[StealController] Vol envoyé au serveur (owner: %d, slot: %d)", ownerId, slotId))
	else
		warn("[StealController] ProximityPrompt sans OwnerId/SlotId!")
	end
end)

print("[StealController] Initialisé!")
