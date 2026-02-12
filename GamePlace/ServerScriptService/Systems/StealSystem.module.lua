-- ServerScriptService/Systems/StealSystem.module.lua
-- VERSION SIMPLIFIÉE : Le ProximityPrompt gère le timing côté client
local StealSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local DataService = require(script.Parent.Parent.Core["DataService.module"])
local PlayerService = require(script.Parent.Parent.Core["PlayerService.module"])
local GameConfig = require(ReplicatedStorage.Config["GameConfig.module"])
local BrainrotData = require(ReplicatedStorage.Data["BrainrotData.module"])

-- Systèmes injectés
local BrainrotModelSystem = nil

-- RemoteEvents (initialisé dans Init, après que NetworkSetup ait créé le dossier)
local remotes = nil

-- Configuration
local STEAL_MAX_DISTANCE = GameConfig.StealMaxDistance or 15 -- studs

---
-- Initialisation
-- @param services table - { BrainrotModelSystem = ... }
---
function StealSystem:Init(services)
	print("[StealSystem] Initialisation...")
	if services then
		BrainrotModelSystem = services.BrainrotModelSystem
	end
	remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
	if not remotes then
		warn("[StealSystem] Remotes introuvable!")
	end
	print("[StealSystem] Initialisé!")
end

---
-- Exécute un vol de Brainrot (appelé après ProximityPrompt.Triggered)
-- @param thief Player - Le voleur
-- @param ownerId number - UserId du propriétaire
-- @param slotId number - ID du slot à voler
-- @return boolean - Success
---
function StealSystem:ExecuteSteal(thief, ownerId, slotId)
	local thiefId = thief.UserId
	print(string.format("[StealSystem] ExecuteSteal - thief: %s (id: %d), ownerId: %d, slotId: %s",
		thief.Name, thiefId, ownerId, tostring(slotId)))

	-- 0. On ne peut pas se voler soi-même
	if thiefId == ownerId then
		return false
	end

	-- 1. Vérifier que le voleur a assez de place dans son inventaire (PiecesInHand)
	local piecesInHand = PlayerService:GetPiecesInHand(thief)
	local maxPieces = GameConfig.Inventory.MaxPiecesInHand or 3
	local currentPieces = #piecesInHand

	print(string.format("[StealSystem] Inventaire du voleur: %d/%d pièces", currentPieces, maxPieces))

	-- Un brainrot volé donne 3 pièces (Head, Body, Legs)
	-- Donc l'inventaire doit être complètement vide
	if currentPieces > 0 then
		print("[StealSystem] ÉCHEC: Inventaire non vide")
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Votre inventaire doit être vide pour voler un Brainrot! (3 pièces)"
		})
		return false
	end

	-- 2. Vérifier que le propriétaire existe
	local owner = Players:GetPlayerByUserId(ownerId)
	print(string.format("[StealSystem] Propriétaire trouvé: %s", owner and owner.Name or "nil"))
	if not owner then
		print("[StealSystem] ÉCHEC: Propriétaire introuvable")
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Propriétaire introuvable."
		})
		return false
	end

	-- 3. Vérifier que le Brainrot existe dans le slot
	local ownerData = DataService:GetPlayerData(owner)
	if not ownerData then
		warn("[StealSystem] Données du propriétaire introuvables!")
		return false
	end

	-- PlacedBrainrots utilise des clés string ("1", "2", etc.)
	local slotKey = tostring(slotId)
	local brainrot = ownerData.PlacedBrainrots[slotKey]
	print(string.format("[StealSystem] Brainrot dans slot %s: %s", slotKey, brainrot and "OUI" or "NON"))
	if not brainrot then
		print("[StealSystem] ÉCHEC: Slot vide")
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Ce slot est vide."
		})
		return false
	end

	-- 4. Vérifier la distance (sécurité anti-hack)
	local inRange = self:_IsInRange(thief, owner, slotId)
	print(string.format("[StealSystem] À portée: %s", tostring(inRange)))
	if not inRange then
		print("[StealSystem] ÉCHEC: Trop loin")
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Vous êtes trop loin du Brainrot."
		})
		return false
	end

	-- 5. Retirer le Brainrot du slot du propriétaire
	print(string.format("[StealSystem] Retrait du brainrot - Set: %s/%s/%s",
		brainrot.HeadSet, brainrot.BodySet, brainrot.LegsSet))
	ownerData.PlacedBrainrots[slotKey] = nil
	DataService:UpdateValue(owner, "PlacedBrainrots", ownerData.PlacedBrainrots)

	-- Aussi nettoyer la table Brainrots (compatibilité EconomySystem)
	if ownerData.Brainrots then
		ownerData.Brainrots[slotId] = nil
		DataService:UpdateValue(owner, "Brainrots", ownerData.Brainrots)
	end

	-- Détruire le modèle 3D du Brainrot volé
	if BrainrotModelSystem then
		BrainrotModelSystem:DestroyBrainrotModel(owner, slotId)
	end

	-- 6. Ajouter à l'inventaire du voleur comme pièces séparées (PiecesInHand)
	print(string.format("[StealSystem] Ajout des 3 pièces à l'inventaire - Set: %s/%s/%s",
		brainrot.HeadSet, brainrot.BodySet, brainrot.LegsSet))

	-- Récupérer les infos de prix depuis BrainrotData
	local headSetData = BrainrotData[brainrot.HeadSet]
	local bodySetData = BrainrotData[brainrot.BodySet]
	local legsSetData = BrainrotData[brainrot.LegsSet]

	-- Créer les 3 pieceData au bon format {SetName, PieceType, Price, DisplayName}
	local headPiece = {
		SetName = brainrot.HeadSet,
		PieceType = "Head",
		Price = headSetData and headSetData.Price or 0,
		DisplayName = headSetData and headSetData.DisplayName or brainrot.HeadSet
	}
	local bodyPiece = {
		SetName = brainrot.BodySet,
		PieceType = "Body",
		Price = bodySetData and bodySetData.Price or 0,
		DisplayName = bodySetData and bodySetData.DisplayName or brainrot.BodySet
	}
	local legsPiece = {
		SetName = brainrot.LegsSet,
		PieceType = "Legs",
		Price = legsSetData and legsSetData.Price or 0,
		DisplayName = legsSetData and legsSetData.DisplayName or brainrot.LegsSet
	}

	-- Ajouter les 3 pièces à l'inventaire runtime (PiecesInHand)
	PlayerService:AddPieceToHand(thief, headPiece)
	PlayerService:AddPieceToHand(thief, bodyPiece)
	PlayerService:AddPieceToHand(thief, legsPiece)

	print("[StealSystem] 3 pièces ajoutées à l'inventaire runtime")

	-- 7. Sync clients
	if owner then
		remotes.SyncPlayerData:FireClient(owner, {
			PlacedBrainrots = ownerData.PlacedBrainrots,
			Cash = ownerData.Cash,
		})
		remotes.Notification:FireClient(owner, {
			Type = "Error",
			Message = "Votre Brainrot a été volé!"
		})
	end

	-- Sync l'inventaire du voleur (PiecesInHand)
	local updatedInventory = PlayerService:GetPiecesInHand(thief)
	remotes.SyncInventory:FireClient(thief, updatedInventory)
	remotes.Notification:FireClient(thief, {
		Type = "Success",
		Message = "Brainrot volé! Allez le placer dans votre base."
	})

	print(string.format("[StealSystem] %s a volé le Brainrot de %s (slot %d) - %d pièces en main",
		thief.Name, owner.Name, slotId, #updatedInventory))

	return true
end

---
-- Calcule le nombre de slots libres d'un joueur
---
function StealSystem:_GetAvailableSlots(userId)
	local data = DataService:GetPlayerData(userId)
	if not data then return 0 end

	local usedSlots = 0
	for _ in pairs(data.PlacedBrainrots) do
		usedSlots = usedSlots + 1
	end

	return data.OwnedSlots - usedSlots
end

---
-- Vérifie si le voleur est à portée du Brainrot
---
function StealSystem:_IsInRange(thief, owner, slotId)
	local thiefChar = thief.Character
	local ownerChar = owner.Character

	if not thiefChar or not ownerChar then return false end

	local thiefRoot = thiefChar:FindFirstChild("HumanoidRootPart")
	local ownerRoot = ownerChar:FindFirstChild("HumanoidRootPart")

	if not thiefRoot or not ownerRoot then return false end

	-- Pour simplifier, on vérifie juste la distance au propriétaire
	local distance = (thiefRoot.Position - ownerRoot.Position).Magnitude
	return distance <= STEAL_MAX_DISTANCE
end

return StealSystem
