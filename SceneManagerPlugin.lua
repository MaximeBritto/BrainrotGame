local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

-- CONFIGURATION
local SERVER_URL = "http://localhost:3000"

local SERVICES_TO_SYNC = {
	game:GetService("ServerScriptService"),
	game:GetService("ReplicatedStorage"),
	game:GetService("StarterPlayer"),
	game:GetService("StarterGui"),
	game:GetService("Lighting")
}

-- On n'ignore plus la Camera ni le Terrain !
-- On ignore juste les trucs internes de Roblox qu'on ne doit pas toucher
local IGNORE_LIST = {
	["RobloxReplicatedStorage"] = true,
	["TouchTransmitter"] = true, -- Créé automatiquement par Roblox
	["AnimationController"] = true,
	["Animator"] = true,
	["PreloadedTexture"] = true, -- Dossiers internes du Terrain
	["TerrainRegion"] = true, -- Régions internes du Terrain
}

-- Classes à ignorer (objets système créés automatiquement)
local IGNORE_CLASSES = {
	["TouchTransmitter"] = true,
	["JointInstance"] = true,
	["Weld"] = true, -- Les welds sont souvent recréés automatiquement
	["ManualWeld"] = true,
	["Motor6D"] = true, -- Sauf si explicitement voulu
}

-- Types qu'on ne peut pas créer (objets internes Roblox)
local CANNOT_CREATE = {
	["Status"] = true,
	["NetworkReplicator"] = true,
	["NetworkServer"] = true,
	["NetworkClient"] = true,
	["DebuggerManager"] = true,
	["Player"] = true,
	["Players"] = true,
	["Workspace"] = true,
	["Lighting"] = true,
	["ReplicatedStorage"] = true
}

----------------------------------------------------------------------------------
-- STOCKAGE DES LOCKS (VARIABLES GLOBALES)
----------------------------------------------------------------------------------
-- Stockage des scripts verrouillés (pour bloquer les modifications)
local lockedScripts = {} -- { scriptPath = { user = "...", timestamp = ... } }

-- Stockage de l'état original des scripts (pour restaurer après déverrouillage)
local scriptOriginalStates = {} -- { scriptPath = { disabled = bool, source = string } }

----------------------------------------------------------------------------------
-- UI SETUP
----------------------------------------------------------------------------------
local toolbar = plugin:CreateToolbar("Scene Master Ultimate")
local toggleBtn = toolbar:CreateButton("Open", "Ouvrir l'interface", "rbxassetid://4458901886")

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 320, 600, 300, 400)
local widget = plugin:CreateDockWidgetPluginGui("SceneMasterUI", widgetInfo)
widget.Title = "Scene Master"

-- Container principal avec scroll
local mainScroll = Instance.new("ScrollingFrame", widget)
mainScroll.Size = UDim2.fromScale(1, 1)
mainScroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
mainScroll.BorderSizePixel = 0
mainScroll.ScrollBarThickness = 6
mainScroll.CanvasSize = UDim2.new(0, 0, 0, 1200)

local gui = Instance.new("Frame", mainScroll)
gui.Size = UDim2.new(1, 0, 0, 1200)
gui.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", gui)
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", gui).PaddingTop = UDim.new(0, 10)

-- Variable pour stocker la scène sélectionnée
local selectedScene = "MainMap"

-- Variable pour stocker la scène ACTUELLEMENT CHARGÉE (différent de sélectionnée)
local currentLoadedScene = "" -- Vide = aucune scène chargée (scripts par défaut)

-- Variable pour bloquer les actions pendant le chargement
local isLoading = false

-- ELEMENTS UI
local function MakeBtn(text, color, order, parent)
	parent = parent or gui
	local b = Instance.new("TextButton", parent)
	b.Text, b.BackgroundColor3, b.LayoutOrder = text, color, order
	b.Size, b.TextColor3, b.Font = UDim2.new(0.9, 0, 0, 40), Color3.new(1, 1, 1), Enum.Font.SourceSansBold
	b.TextSize = 16
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local function MakeLabel(text, order, size)
	local l = Instance.new("TextLabel", gui)
	l.Text = text
	l.Size = size or UDim2.new(0.9, 0, 0, 25)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(200, 200, 200)
	l.Font = Enum.Font.SourceSansBold
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.LayoutOrder = order
	return l
end

local function MakeSeparator(order)
	local s = Instance.new("Frame", gui)
	s.Size = UDim2.new(0.95, 0, 0, 1)
	s.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	s.BorderSizePixel = 0
	s.LayoutOrder = order
	return s
end

-- ═══════════════════════════════════════════════════════════════
-- SECTION 0: INDICATEUR DE SCÈNE ACTIVE (toujours visible en haut)
-- ═══════════════════════════════════════════════════════════════

-- Container pour l'indicateur de scène active
local activeSceneContainer = Instance.new("Frame", gui)
activeSceneContainer.Size = UDim2.new(0.9, 0, 0, 50)
activeSceneContainer.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
activeSceneContainer.BorderSizePixel = 0
activeSceneContainer.LayoutOrder = 0
Instance.new("UICorner", activeSceneContainer).CornerRadius = UDim.new(0, 8)

-- Icône et label "Scène active"
local activeSceneTitle = Instance.new("TextLabel", activeSceneContainer)
activeSceneTitle.Size = UDim2.new(1, -10, 0, 18)
activeSceneTitle.Position = UDim2.new(0, 5, 0, 5)
activeSceneTitle.BackgroundTransparency = 1
activeSceneTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
activeSceneTitle.Font = Enum.Font.SourceSans
activeSceneTitle.TextSize = 11
activeSceneTitle.Text = "🎮 SCÈNE ACTIVE"
activeSceneTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Nom de la scène chargée
local activeSceneLabel = Instance.new("TextLabel", activeSceneContainer)
activeSceneLabel.Size = UDim2.new(1, -10, 0, 22)
activeSceneLabel.Position = UDim2.new(0, 5, 0, 23)
activeSceneLabel.BackgroundTransparency = 1
activeSceneLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
activeSceneLabel.Font = Enum.Font.SourceSansBold
activeSceneLabel.TextSize = 16
activeSceneLabel.Text = "⚠️ Aucune scène chargée"
activeSceneLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Fonction pour mettre à jour l'indicateur de scène active
local function updateActiveSceneIndicator()
	if isLoading then
		activeSceneContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 40)
		activeSceneLabel.Text = "⏳ Chargement en cours..."
		activeSceneLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	elseif currentLoadedScene == "" then
		activeSceneContainer.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
		activeSceneLabel.Text = "⚠️ Aucune scène chargée"
		activeSceneLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	else
		activeSceneContainer.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
		activeSceneLabel.Text = "✅ " .. currentLoadedScene
		activeSceneLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	end
end

MakeSeparator(1)

-- ═══════════════════════════════════════════════════════════════
-- SECTION 1: CODE SYNC
-- ═══════════════════════════════════════════════════════════════
MakeLabel("📁 CODE SYNC", 2)
local btnDump = MakeBtn("📤 Roblox → Disk", Color3.fromRGB(60, 60, 200), 3)
local btnSync = MakeBtn("📥 Disk → Roblox", Color3.fromRGB(100, 200, 100), 4)

MakeSeparator(5)

-- ═══════════════════════════════════════════════════════════════
-- SECTION 2: SCENES - Liste cliquable
-- ═══════════════════════════════════════════════════════════════
MakeLabel("🎬 SCÈNES", 6)

-- Container pour la liste des scènes
local scenesContainer = Instance.new("Frame", gui)
scenesContainer.Size = UDim2.new(0.9, 0, 0, 120)
scenesContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
scenesContainer.BorderSizePixel = 0
scenesContainer.LayoutOrder = 7
Instance.new("UICorner", scenesContainer).CornerRadius = UDim.new(0, 6)

local scenesScroll = Instance.new("ScrollingFrame", scenesContainer)
scenesScroll.Size = UDim2.new(1, -10, 1, -10)
scenesScroll.Position = UDim2.new(0, 5, 0, 5)
scenesScroll.BackgroundTransparency = 1
scenesScroll.ScrollBarThickness = 4
scenesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local scenesLayout = Instance.new("UIListLayout", scenesScroll)
scenesLayout.Padding = UDim.new(0, 4)

-- Label pour la scène sélectionnée
local selectedLabel = Instance.new("TextLabel", gui)
selectedLabel.Size = UDim2.new(0.9, 0, 0, 25)
selectedLabel.BackgroundTransparency = 1
selectedLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
selectedLabel.Font = Enum.Font.SourceSansBold
selectedLabel.TextSize = 14
selectedLabel.Text = "✓ Sélectionnée: " .. selectedScene
selectedLabel.LayoutOrder = 8

-- Input pour nouvelle scène
local nameInput = Instance.new("TextBox", gui)
nameInput.PlaceholderText = "Nouvelle scène..."
nameInput.Text = ""
nameInput.Size = UDim2.new(0.9, 0, 0, 32)
nameInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
nameInput.TextColor3 = Color3.new(1, 1, 1)
nameInput.Font = Enum.Font.SourceSans
nameInput.TextSize = 14
nameInput.LayoutOrder = 9
Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 6)

-- Boutons Save/Load
local sceneButtonsFrame = Instance.new("Frame", gui)
sceneButtonsFrame.Size = UDim2.new(0.9, 0, 0, 40)
sceneButtonsFrame.BackgroundTransparency = 1
sceneButtonsFrame.LayoutOrder = 10

local btnSave = Instance.new("TextButton", sceneButtonsFrame)
btnSave.Size = UDim2.new(0.48, 0, 1, 0)
btnSave.Position = UDim2.new(0, 0, 0, 0)
btnSave.Text = "�  SAVE (Désactivé)"
btnSave.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
btnSave.TextColor3 = Color3.fromRGB(150, 150, 150)
btnSave.Font = Enum.Font.SourceSansBold
btnSave.TextSize = 16
btnSave.Active = false
btnSave.AutoButtonColor = false
Instance.new("UICorner", btnSave).CornerRadius = UDim.new(0, 6)

local btnLoad = Instance.new("TextButton", sceneButtonsFrame)
btnLoad.Size = UDim2.new(0.48, 0, 1, 0)
btnLoad.Position = UDim2.new(0.52, 0, 0, 0)
btnLoad.Text = "🔒 LOAD (Désactivé)"
btnLoad.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
btnLoad.TextColor3 = Color3.fromRGB(150, 150, 150)
btnLoad.Font = Enum.Font.SourceSansBold
btnLoad.TextSize = 16
btnLoad.Active = false
btnLoad.AutoButtonColor = false
Instance.new("UICorner", btnLoad).CornerRadius = UDim.new(0, 6)

-- Boutons d'action sur les scènes
local sceneActionsFrame = Instance.new("Frame", gui)
sceneActionsFrame.Size = UDim2.new(0.9, 0, 0, 35)
sceneActionsFrame.BackgroundTransparency = 1
sceneActionsFrame.LayoutOrder = 11

local btnRefresh = Instance.new("TextButton", sceneActionsFrame)
btnRefresh.Size = UDim2.new(0.32, -2, 1, 0)
btnRefresh.Position = UDim2.new(0, 0, 0, 0)
btnRefresh.Text = "🔄"
btnRefresh.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
btnRefresh.TextColor3 = Color3.new(1, 1, 1)
btnRefresh.Font = Enum.Font.SourceSansBold
btnRefresh.TextSize = 18
Instance.new("UICorner", btnRefresh).CornerRadius = UDim.new(0, 6)

local btnDuplicate = Instance.new("TextButton", sceneActionsFrame)
btnDuplicate.Size = UDim2.new(0.32, -2, 1, 0)
btnDuplicate.Position = UDim2.new(0.34, 0, 0, 0)
btnDuplicate.Text = "📋 Dupliquer"
btnDuplicate.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
btnDuplicate.TextColor3 = Color3.new(1, 1, 1)
btnDuplicate.Font = Enum.Font.SourceSansBold
btnDuplicate.TextSize = 13
Instance.new("UICorner", btnDuplicate).CornerRadius = UDim.new(0, 6)

local btnDelete = Instance.new("TextButton", sceneActionsFrame)
btnDelete.Size = UDim2.new(0.32, -2, 1, 0)
btnDelete.Position = UDim2.new(0.68, 0, 0, 0)
btnDelete.Text = "🗑️ Supprimer"
btnDelete.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
btnDelete.TextColor3 = Color3.new(1, 1, 1)
btnDelete.Font = Enum.Font.SourceSansBold
btnDelete.TextSize = 13
Instance.new("UICorner", btnDelete).CornerRadius = UDim.new(0, 6)

MakeSeparator(12)

-- ═══════════════════════════════════════════════════════════════
-- SECTION 3: MERGE
-- ═══════════════════════════════════════════════════════════════
MakeLabel("🔀 MERGE", 13)

-- Container pour le merge
local mergeContainer = Instance.new("Frame", gui)
mergeContainer.Size = UDim2.new(0.9, 0, 0, 150)
mergeContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
mergeContainer.BorderSizePixel = 0
mergeContainer.LayoutOrder = 14
Instance.new("UICorner", mergeContainer).CornerRadius = UDim.new(0, 6)

-- Labels dans le merge container
local mergeBaseLabel = Instance.new("TextLabel", mergeContainer)
mergeBaseLabel.Size = UDim2.new(1, -10, 0, 20)
mergeBaseLabel.Position = UDim2.new(0, 5, 0, 5)
mergeBaseLabel.BackgroundTransparency = 1
mergeBaseLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
mergeBaseLabel.Font = Enum.Font.SourceSans
mergeBaseLabel.TextSize = 12
mergeBaseLabel.Text = "Scène de base (recevra le merge):"
mergeBaseLabel.TextXAlignment = Enum.TextXAlignment.Left

local mergeBaseValue = Instance.new("TextLabel", mergeContainer)
mergeBaseValue.Size = UDim2.new(1, -10, 0, 25)
mergeBaseValue.Position = UDim2.new(0, 5, 0, 25)
mergeBaseValue.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
mergeBaseValue.TextColor3 = Color3.fromRGB(100, 255, 100)
mergeBaseValue.Font = Enum.Font.SourceSansBold
mergeBaseValue.TextSize = 14
mergeBaseValue.Text = selectedScene
Instance.new("UICorner", mergeBaseValue).CornerRadius = UDim.new(0, 4)

local mergeFromLabel = Instance.new("TextLabel", mergeContainer)
mergeFromLabel.Size = UDim2.new(1, -10, 0, 20)
mergeFromLabel.Position = UDim2.new(0, 5, 0, 55)
mergeFromLabel.BackgroundTransparency = 1
mergeFromLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
mergeFromLabel.Font = Enum.Font.SourceSans
mergeFromLabel.TextSize = 12
mergeFromLabel.Text = "Scène à fusionner:"
mergeFromLabel.TextXAlignment = Enum.TextXAlignment.Left

local mergeFromDropdown = Instance.new("TextButton", mergeContainer)
mergeFromDropdown.Size = UDim2.new(1, -10, 0, 30)
mergeFromDropdown.Position = UDim2.new(0, 5, 0, 75)
mergeFromDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
mergeFromDropdown.TextColor3 = Color3.fromRGB(200, 200, 200)
mergeFromDropdown.Font = Enum.Font.SourceSans
mergeFromDropdown.TextSize = 14
mergeFromDropdown.Text = "▼ Sélectionner une scène..."
Instance.new("UICorner", mergeFromDropdown).CornerRadius = UDim.new(0, 4)

local mergeSceneSelected = ""

local btnMerge = Instance.new("TextButton", mergeContainer)
btnMerge.Size = UDim2.new(1, -10, 0, 35)
btnMerge.Position = UDim2.new(0, 5, 0, 110)
btnMerge.Text = "🔀 FUSIONNER"
btnMerge.BackgroundColor3 = Color3.fromRGB(156, 89, 182)
btnMerge.TextColor3 = Color3.new(1, 1, 1)
btnMerge.Font = Enum.Font.SourceSansBold
btnMerge.TextSize = 16
Instance.new("UICorner", btnMerge).CornerRadius = UDim.new(0, 6)

MakeSeparator(14)

-- ═══════════════════════════════════════════════════════════════
-- SECTION 4: STATUS
-- ═══════════════════════════════════════════════════════════════
local status = Instance.new("TextLabel", gui)
status.Size = UDim2.new(0.9, 0, 0, 40)
status.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.Font = Enum.Font.SourceSans
status.TextSize = 13
status.Text = "Prêt."
status.TextWrapped = true
status.LayoutOrder = 15
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

local function Log(t, c) 
	print(t)
	status.Text = t
	if c then status.TextColor3 = c end 
end

-- ═══════════════════════════════════════════════════════════════
-- FONCTIONS UI
-- ═══════════════════════════════════════════════════════════════

-- Liste des scènes disponibles
local scenesList = {}

-- Fonction pour rafraîchir la liste des scènes
local function refreshScenesList()
	-- Vider la liste actuelle
	for _, child in ipairs(scenesScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Récupérer les scènes depuis le serveur
	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/list-scenes")
	end)

	if not success then
		Log("❌ Erreur connexion serveur", Color3.fromRGB(255, 100, 100))
		return
	end

	scenesList = HttpService:JSONDecode(response)

	-- Créer les boutons pour chaque scène
	for i, sceneName in ipairs(scenesList) do
		local btn = Instance.new("TextButton", scenesScroll)
		btn.Size = UDim2.new(1, -8, 0, 28)
		btn.BackgroundColor3 = sceneName == selectedScene and Color3.fromRGB(70, 130, 70) or Color3.fromRGB(55, 55, 55)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.SourceSans
		btn.TextSize = 13
		btn.Text = "  🎬 " .. sceneName
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.LayoutOrder = i
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

		btn.MouseButton1Click:Connect(function()
			selectedScene = sceneName
			selectedLabel.Text = "✓ Sélectionnée: " .. selectedScene
			mergeBaseValue.Text = selectedScene
			refreshScenesList() -- Refresh pour mettre à jour la sélection visuelle
		end)
	end

	-- Mettre à jour la taille du canvas
	scenesScroll.CanvasSize = UDim2.new(0, 0, 0, #scenesList * 32)

	Log("📋 " .. #scenesList .. " scène(s) trouvée(s)", Color3.fromRGB(100, 255, 100))
end

-- Dropdown pour sélectionner la scène à merger
local dropdownOpen = false
local dropdownFrame = nil

local function toggleMergeDropdown()
	if dropdownOpen and dropdownFrame then
		dropdownFrame:Destroy()
		dropdownFrame = nil
		dropdownOpen = false
		return
	end

	dropdownFrame = Instance.new("Frame", mergeContainer)
	dropdownFrame.Size = UDim2.new(1, -10, 0, math.min(#scenesList * 28, 120))
	dropdownFrame.Position = UDim2.new(0, 5, 0, 105)
	dropdownFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	dropdownFrame.BorderSizePixel = 1
	dropdownFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	dropdownFrame.ZIndex = 10
	Instance.new("UICorner", dropdownFrame).CornerRadius = UDim.new(0, 4)

	local dropScroll = Instance.new("ScrollingFrame", dropdownFrame)
	dropScroll.Size = UDim2.new(1, 0, 1, 0)
	dropScroll.BackgroundTransparency = 1
	dropScroll.ScrollBarThickness = 4
	dropScroll.CanvasSize = UDim2.new(0, 0, 0, #scenesList * 28)
	dropScroll.ZIndex = 10

	local dropLayout = Instance.new("UIListLayout", dropScroll)
	dropLayout.Padding = UDim.new(0, 2)

	for i, sceneName in ipairs(scenesList) do
		if sceneName ~= selectedScene then -- Ne pas montrer la scène de base
			local btn = Instance.new("TextButton", dropScroll)
			btn.Size = UDim2.new(1, -4, 0, 26)
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.SourceSans
			btn.TextSize = 13
			btn.Text = "  " .. sceneName
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.ZIndex = 10
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)

			btn.MouseButton1Click:Connect(function()
				mergeSceneSelected = sceneName
				mergeFromDropdown.Text = "▼ " .. sceneName
				toggleMergeDropdown()
			end)
		end
	end

	dropdownOpen = true
end

mergeFromDropdown.MouseButton1Click:Connect(toggleMergeDropdown)
btnRefresh.MouseButton1Click:Connect(refreshScenesList)

-- Dupliquer une scène
btnDuplicate.MouseButton1Click:Connect(function()
	if selectedScene == "" then
		Log("❌ Sélectionnez une scène à dupliquer", Color3.fromRGB(255, 100, 100))
		return
	end

	-- Générer un nom pour la copie
	local newName = selectedScene .. "_copy"
	local counter = 1

	-- Vérifier si le nom existe déjà dans la liste
	local function nameExists(name)
		for _, scene in ipairs(scenesList) do
			if scene == name then return true end
		end
		return false
	end

	while nameExists(newName) do
		counter = counter + 1
		newName = selectedScene .. "_copy" .. counter
	end

	Log("⏳ Duplication...", Color3.fromRGB(52, 152, 219))

	local success, response = pcall(function()
		return HttpService:PostAsync(
			SERVER_URL .. "/duplicate-scene",
			HttpService:JSONEncode({
				sourceName = selectedScene,
				newName = newName
			}),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if not success then
		Log("❌ Erreur: " .. tostring(response), Color3.fromRGB(255, 100, 100))
		return
	end

	local result = HttpService:JSONDecode(response)

	if result.success then
		Log("✅ Dupliqué: " .. result.newScene, Color3.fromRGB(100, 255, 100))
		-- Sélectionner la nouvelle scène et rafraîchir
		selectedScene = result.newScene
		selectedLabel.Text = "✓ Sélectionnée: " .. selectedScene
		mergeBaseValue.Text = selectedScene
		refreshScenesList()
	else
		Log("❌ " .. (result.error or "Erreur"), Color3.fromRGB(255, 100, 100))
	end
end)

-- Supprimer une scène
btnDelete.MouseButton1Click:Connect(function()
	if selectedScene == "" then
		Log("❌ Sélectionnez une scène à supprimer", Color3.fromRGB(255, 100, 100))
		return
	end

	-- Confirmation dans la console
	print("⚠️ SUPPRESSION DE LA SCÈNE: " .. selectedScene)
	print("   Cette action est irréversible!")

	Log("⏳ Suppression...", Color3.fromRGB(192, 57, 43))

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = SERVER_URL .. "/delete-scene?name=" .. HttpService:UrlEncode(selectedScene),
			Method = "DELETE"
		})
	end)

	if not success then
		Log("❌ Erreur: " .. tostring(response), Color3.fromRGB(255, 100, 100))
		return
	end

	local result = HttpService:JSONDecode(response.Body)

	if result.success then
		Log("🗑️ Supprimé: " .. selectedScene, Color3.fromRGB(255, 200, 100))
		print("🗑️ Scène supprimée: " .. selectedScene)

		-- Reset la sélection
		selectedScene = ""
		selectedLabel.Text = "✓ Sélectionnée: (aucune)"
		mergeBaseValue.Text = "(aucune)"
		refreshScenesList()

		-- Sélectionner la première scène si disponible
		if #scenesList > 0 then
			selectedScene = scenesList[1]
			selectedLabel.Text = "✓ Sélectionnée: " .. selectedScene
			mergeBaseValue.Text = selectedScene
		end
	else
		Log("❌ " .. (result.error or "Erreur"), Color3.fromRGB(255, 100, 100))
	end
end)

-- Rafraîchir au démarrage
task.spawn(function()
	task.wait(0.5)
	refreshScenesList()
	-- Initialiser l'indicateur de scène active
	updateActiveSceneIndicator()
	print("🎮 Scene Master: Aucune scène chargée - Les scripts actuels sont ceux par défaut du studio")
end)

----------------------------------------------------------------------------------
-- LOGIQUE METIER
----------------------------------------------------------------------------------

-- 1. PROPRIÉTÉS À SAUVEGARDER
local PROPS = {
	Part = {"Position","Size","Color","Transparency","Anchored","CanCollide","Reflectance","CFrame","Material","TopSurface","BottomSurface","Name","Shape","BrickColor"},
	MeshPart = {"Position","Size","Color","Transparency","Anchored","CanCollide","CFrame","Material","MeshId","TextureID","Name","DoubleSided"},
	UnionOperation = {"Position","Size","Color","Transparency","Anchored","CanCollide","CFrame","Material","Name","UsePartColor"},
	TrussPart = {"Position","Size","Color","Transparency","Anchored","CanCollide","CFrame","Material","Name"},
	WedgePart = {"Position","Size","Color","Transparency","Anchored","CanCollide","CFrame","Material","TopSurface","BottomSurface","Name"},
	CornerWedgePart = {"Position","Size","Color","Transparency","Anchored","CanCollide","CFrame","Material","Name"},

	-- Meshes et textures
	SpecialMesh = {"MeshType","MeshId","TextureId","Scale","Offset"},
	Decal = {"Texture","Transparency","Face","Color3"},
	Texture = {"Texture","Transparency","Face","StudsPerTileU","StudsPerTileV"},
	SurfaceAppearance = {"ColorMap","MetalnessMap","NormalMap","RoughnessMap"},

	-- Lumières
	PointLight = {"Brightness","Range","Color","Enabled","Shadows"},
	SpotLight = {"Brightness","Range","Color","Enabled","Shadows","Angle","Face"},
	SurfaceLight = {"Brightness","Range","Color","Enabled","Shadows","Angle","Face"},

	-- Autres
	Folder = {}, 
	Configuration = {},
	Model = {"PrimaryPart"},
	Tool = {"Grip","CanBeDropped","RequiresHandle","ToolTip"},
	Accessory = {"AttachmentPoint"},
	Hat = {"AttachmentPoint"},

	-- Constraints et Welds
	Weld = {"Part0","Part1","C0","C1"},
	Motor6D = {"Part0","Part1","C0","C1","DesiredAngle","MaxVelocity"},
	WeldConstraint = {"Part0","Part1"},
	HingeConstraint = {"Attachment0","Attachment1","LimitsEnabled","UpperAngle","LowerAngle"},

	-- Humanoid et Character
	Humanoid = {"Health","MaxHealth","WalkSpeed","JumpPower","DisplayName","HealthDisplayDistance","NameDisplayDistance"},
	BodyColors = {"HeadColor","LeftArmColor","RightArmColor","LeftLegColor","RightLegColor","TorsoColor"},
	Shirt = {"ShirtTemplate"},
	Pants = {"PantsTemplate"},
	CharacterMesh = {"BodyPart","MeshId","OverlayTextureId","BaseTextureId"},

	-- Values (pour stocker des données)
	NumberValue = {"Value"},
	StringValue = {"Value"},
	BoolValue = {"Value"},
	IntValue = {"Value"},
	Vector3Value = {"Value"},
	Color3Value = {"Value"},
	ObjectValue = {"Value"},
	CFrameValue = {"Value"},

	-- Events et Communication
	RemoteEvent = {},
	RemoteFunction = {},
	BindableEvent = {},
	BindableFunction = {},

	-- Animation
	Animation = {"AnimationId"},
	AnimationController = {},
	Script = {"Source", "Disabled"}, 
	LocalScript = {"Source", "Disabled"}, 
	ModuleScript = {"Source"},
	Attachment = {"Position","Orientation","CFrame"},
	Beam = {"Attachment0","Attachment1","Color","Transparency","Width0","Width1","Enabled"},
	ParticleEmitter = {"Enabled","Rate","Lifetime","Speed","Color","Size","Texture","Transparency"},

	-- Spawn
	SpawnLocation = {"Position","Size","Color","Transparency","Anchored","CanCollide","CFrame","Material","Duration","Enabled","TeamColor"},

	-- GUI (pour les textes sur les objets)
	SurfaceGui = {"Face","Enabled","AlwaysOnTop","LightInfluence","SizingMode","CanvasSize","ZIndexBehavior"},
	BillboardGui = {"Size","StudsOffset","Enabled","AlwaysOnTop","LightInfluence","MaxDistance"},
	ScreenGui = {"Enabled","DisplayOrder","IgnoreGuiInset","ZIndexBehavior"},
	TextLabel = {"Text","TextColor3","TextSize","Font","TextScaled","BackgroundColor3","BackgroundTransparency","Size","Position","AnchorPoint","TextStrokeTransparency","TextStrokeColor3"},
	TextButton = {"Text","TextColor3","TextSize","Font","TextScaled","BackgroundColor3","BackgroundTransparency","Size","Position","AnchorPoint"},
	ImageLabel = {"Image","ImageColor3","ImageTransparency","BackgroundColor3","BackgroundTransparency","Size","Position","AnchorPoint","ScaleType"},
	ImageButton = {"Image","ImageColor3","ImageTransparency","BackgroundColor3","BackgroundTransparency","Size","Position","AnchorPoint"},
	Frame = {"BackgroundColor3","BackgroundTransparency","Size","Position","AnchorPoint","BorderSizePixel"},
	ScrollingFrame = {"BackgroundColor3","BackgroundTransparency","Size","Position","CanvasSize","ScrollBarThickness"},

	-- UI Layout et Constraints
	UICorner = {"CornerRadius"},
	UIGradient = {"Color","Transparency","Rotation","Offset"},
	UIListLayout = {"Padding","FillDirection","HorizontalAlignment","VerticalAlignment","SortOrder"},
	UIGridLayout = {"CellPadding","CellSize","FillDirection","SortOrder"},
	UIPadding = {"PaddingTop","PaddingBottom","PaddingLeft","PaddingRight"},
	UIScale = {"Scale"},
	UIAspectRatioConstraint = {"AspectRatio","AspectType"},
	UISizeConstraint = {"MaxSize","MinSize"},
	UIStroke = {"Color","Thickness","Transparency"},

	-- Camera
	Camera = {"CFrame", "FieldOfView", "HeadLocked", "Name"},

	-- Terrain
	Terrain = {"WaterColor", "WaterReflectance", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed", "Decoration", "MaterialColors"}
}

-- 2. SERIALISATION (avec hiérarchie)

-- Variable pour tracker si des changements ont été faits depuis le dernier save
local hasUnsavedChanges = false
local lastSavedScene = ""

-- Fonction pour collecter tous les scripts des services
local function collectAllScripts()
	local scripts = {}

	local function collectFromService(service, currentPath)
		local myPath = currentPath
		if service.Parent == game then
			myPath = service.Name
		else
			myPath = currentPath .. "/" .. service.Name
		end

		for _, child in ipairs(service:GetChildren()) do
			if child:IsA("LuaSourceContainer") then
				local scriptPath = myPath .. "/" .. child.Name
				local success, source = pcall(function() return child.Source end)
				if success then
					table.insert(scripts, {
						path = scriptPath,
						className = child.ClassName,
						source = source,
						disabled = child:IsA("Script") and child.Disabled or false
					})
					-- DEBUG: Afficher un aperçu du contenu (première ligne)
					local firstLine = string.match(source, "^[^\n]*") or ""
					if #firstLine > 50 then firstLine = string.sub(firstLine, 1, 50) .. "..." end
					print("    📜 Collecté:", scriptPath, "->", firstLine)
				end
			end
			-- Récursif
			collectFromService(child, myPath)
		end
	end

	for _, service in ipairs(SERVICES_TO_SYNC) do
		collectFromService(service, "")
	end

	return scripts
end

-- Fonction pour supprimer tous les scripts des services (avant de charger une nouvelle scène)
local function clearAllScripts()
	print("  🗑️ [clearAllScripts] Suppression des scripts existants...")
	local deleted = 0

	local function deleteScripts(obj)
		for _, child in ipairs(obj:GetChildren()) do
			if child:IsA("LuaSourceContainer") then
				print("    🗑️ Suppression:", child:GetFullName())
				child:Destroy()
				deleted = deleted + 1
			elseif child:IsA("Folder") or child:IsA("ModuleScript") == false then
				-- Récursion dans les dossiers et autres conteneurs (mais pas dans les ModuleScripts)
				deleteScripts(child)
			end
		end
	end

	for _, service in ipairs(SERVICES_TO_SYNC) do
		deleteScripts(service)
	end

	print("  🗑️ " .. deleted .. " scripts supprimés")
	return deleted
end

-- Fonction pour créer un script depuis les données sauvegardées
local function createScriptFromData(scriptInfo)
	local parts = string.split(scriptInfo.path, "/")
	local serviceName = parts[1]

	-- Trouver le service
	local parent = nil
	for _, service in ipairs(SERVICES_TO_SYNC) do
		if service.Name == serviceName then
			parent = service
			break
		end
	end

	if not parent then
		print("    ✗ Service non trouvé:", serviceName)
		return false
	end

	-- Créer/naviguer les dossiers intermédiaires
	for i = 2, #parts - 1 do
		local folderName = parts[i]
		local folder = parent:FindFirstChild(folderName)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = folderName
			folder.Parent = parent
			print("    📁 Dossier créé:", folderName)
		end
		parent = folder
	end

	-- Créer le script
	local scriptName = parts[#parts]
	-- Enlever l'extension .lua si présente
	if string.sub(scriptName, -4) == ".lua" then
		scriptName = string.sub(scriptName, 1, -5)
	end

	-- Déterminer le type de script (className est sauvegardé par collectAllScripts)
	local scriptType = scriptInfo.className or scriptInfo.scriptType or "Script"
	local newScript

	if scriptType == "LocalScript" then
		newScript = Instance.new("LocalScript")
	elseif scriptType == "ModuleScript" then
		newScript = Instance.new("ModuleScript")
	else
		newScript = Instance.new("Script")
	end

	newScript.Name = scriptName

	local success = pcall(function()
		newScript.Source = scriptInfo.source
		if newScript:IsA("Script") and scriptInfo.disabled ~= nil then
			newScript.Disabled = scriptInfo.disabled
		end
	end)

	if success then
		newScript.Parent = parent
		-- DEBUG: Afficher un aperçu du contenu (première ligne)
		local firstLine = string.match(scriptInfo.source or "", "^[^\n]*") or ""
		if #firstLine > 50 then firstLine = string.sub(firstLine, 1, 50) .. "..." end
		print("    ✓ Script créé:", scriptInfo.path, "->", firstLine)
		return true
	else
		print("    ✗ Erreur création:", scriptInfo.path)
		return false
	end
end

-- Fonction pour restaurer les scripts depuis les données sauvegardées
local function restoreScripts(scriptsData)
	if not scriptsData or #scriptsData == 0 then 
		print("  📜 [restoreScripts] Aucun script à restaurer")
		return 0 
	end

	print("  📜 [restoreScripts] Tentative de restauration de", #scriptsData, "scripts...")

	local restored = 0
	local notFound = {}

	for _, scriptInfo in ipairs(scriptsData) do
		-- Parser le chemin pour trouver le script
		local parts = string.split(scriptInfo.path, "/")
		local serviceName = parts[1]

		-- Trouver le service
		local current = nil
		for _, service in ipairs(SERVICES_TO_SYNC) do
			if service.Name == serviceName then
				current = service
				break
			end
		end

		if not current then
			table.insert(notFound, scriptInfo.path .. " (service '" .. serviceName .. "' non trouvé)")
		else
			-- Naviguer jusqu'au script
			local failedAt = nil
			for i = 2, #parts do
				local child = current:FindFirstChild(parts[i])
				if child then
					current = child
				else
					failedAt = parts[i]
					current = nil
					break
				end
			end

			if not current then
				table.insert(notFound, scriptInfo.path .. " ('" .. (failedAt or "?") .. "' non trouvé)")
			elseif not current:IsA("LuaSourceContainer") then
				table.insert(notFound, scriptInfo.path .. " (n'est pas un script)")
			else
				-- Mettre à jour le source si trouvé
				local success = pcall(function()
					current.Source = scriptInfo.source
					if current:IsA("Script") and scriptInfo.disabled ~= nil then
						current.Disabled = scriptInfo.disabled
					end
				end)
				if success then
					restored = restored + 1
					print("    ✓ Restauré:", scriptInfo.path)
				else
					table.insert(notFound, scriptInfo.path .. " (erreur écriture)")
				end
			end
		end
	end

	if #notFound > 0 then
		print("  ⚠️ Scripts NON restaurés:", #notFound)
		for i = 1, math.min(10, #notFound) do
			print("    ✗", notFound[i])
		end
		if #notFound > 10 then
			print("    ... et", #notFound - 10, "autres")
		end
	end

	return restored
end

-- Table pour détecter les IDs dupliqués pendant la sérialisation
local usedIDs = {}

local function SerializeRecursive(obj, parentID)
	-- On ignore les trucs système bizarres
	if IGNORE_LIST[obj.Name] then return {} end

	-- On ignore les types qu'on ne peut pas recréer
	if CANNOT_CREATE[obj.ClassName] then return {} end

	-- On ignore certaines classes système
	if IGNORE_CLASSES[obj.ClassName] then return {} end

	-- On ignore les enfants du Terrain (chunks internes de Roblox)
	if obj.Parent and obj.Parent:IsA("Terrain") then return {} end

	-- Pour la Camera et le Terrain, on utilise des IDs spéciaux
	local id = obj:GetAttribute("SceneID")
	if obj:IsA("Terrain") then 
		id = "TERRAIN_ID"
	elseif obj:IsA("Camera") then 
		id = "CAMERA_ID"
	elseif not id then
		-- Pas d'ID : en générer un nouveau
		id = HttpService:GenerateGUID(false)
		obj:SetAttribute("SceneID", id)
	elseif usedIDs[id] then
		-- ID dupliqué détecté (objet cloné) : générer un nouvel ID
		print("⚠️ ID dupliqué détecté pour", obj.Name, "- Génération d'un nouvel ID")
		id = HttpService:GenerateGUID(false)
		obj:SetAttribute("SceneID", id)
	end

	-- Marquer cet ID comme utilisé
	usedIDs[id] = true

	local d = {ID=id, Name=obj.Name, ClassName=obj.ClassName, ParentID=parentID, Properties={}}
	local w = PROPS[obj.ClassName]

	-- Si on a une liste de propriétés, on les sauvegarde
	if w then
		for _,p in ipairs(w) do
			local s,v = pcall(function() return obj[p] end)
			if s and v ~= nil then
				if typeof(v)=="Vector3" then 
					v={v.X,v.Y,v.Z} 
				elseif typeof(v)=="Vector2" then
					v={v.X,v.Y}
				elseif typeof(v)=="UDim2" then
					v={v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset}
				elseif typeof(v)=="UDim" then
					v={v.Scale, v.Offset}
				elseif typeof(v)=="Color3" then 
					v=v:ToHex() 
				elseif typeof(v)=="CFrame" then 
					v={v:GetComponents()} 
				elseif typeof(v)=="EnumItem" then 
					v=v.Name
				elseif typeof(v)=="BrickColor" then
					v=v.Name
				elseif typeof(v)=="Instance" then
					-- Pour Part0, Part1, Attachment0, etc. on sauvegarde juste le nom
					v=v.Name
				elseif typeof(v)=="ColorSequence" then
					-- Pour UIGradient.Color
					local keypoints = {}
					for _, k in ipairs(v.Keypoints) do
						table.insert(keypoints, {k.Time, k.Value:ToHex()})
					end
					v=keypoints
				elseif typeof(v)=="NumberSequence" then
					-- Pour UIGradient.Transparency
					local keypoints = {}
					for _, k in ipairs(v.Keypoints) do
						table.insert(keypoints, {k.Time, k.Value})
					end
					v=keypoints
				end
				d.Properties[p]=v
			end
		end
	else
		-- Type inconnu : on sauvegarde quand même (sans propriétés pour l'instant)
		-- Au moins la hiérarchie sera préservée
		warn("⚠️ Type non géré:", obj.ClassName, "-", obj.Name)
	end

	-- Sérialiser les enfants récursivement
	-- SAUF pour le Terrain (ses enfants sont des chunks internes de Roblox)
	local result = {d}

	if not obj:IsA("Terrain") then
		local children = obj:GetChildren()
		if #children > 0 and #children < 100 then
			-- N'afficher que pour les objets avec peu d'enfants (éviter spam)
			print("  📁", obj.Name, "a", #children, "enfants")
		end
		for _, child in ipairs(children) do
			local childData = SerializeRecursive(child, id)
			for _, item in ipairs(childData) do
				table.insert(result, item)
			end
		end
	end

	return result
end

-- 3. UNPACK
local function Unpack(n,v)
	if n=="Color" or n=="WaterColor" or n=="TextColor3" or n=="BackgroundColor3" or n=="ImageColor3" or n=="TextStrokeColor3" then 
		return Color3.fromHex(v) 
	elseif n=="Value" then
		-- Value peut être de différents types selon le ValueObject
		if type(v) == "table" then
			if #v == 3 then return Vector3.new(unpack(v))
			elseif #v == 12 then return CFrame.new(unpack(v))
			elseif v.r and v.g and v.b then return Color3.new(v.r, v.g, v.b)
			end
		end
		return v
	elseif n=="Position" then
		-- Position peut être Vector3 (pour les Parts) ou UDim2 (pour les GUI)
		if type(v) == "table" and #v == 3 then
			return Vector3.new(unpack(v))
		elseif type(v) == "table" and #v == 4 then
			return UDim2.new(v[1], v[2], v[3], v[4])
		end
	elseif n=="Size" then
		-- Size peut être Vector3 (pour les Parts) ou UDim2 (pour les GUI)
		if type(v) == "table" and #v == 3 then
			return Vector3.new(unpack(v))
		elseif type(v) == "table" and #v == 4 then
			return UDim2.new(v[1], v[2], v[3], v[4])
		end
	elseif n=="AnchorPoint" or n=="StudsOffset" or n=="Offset" then
		if type(v) == "table" and #v == 2 then
			return Vector2.new(v[1], v[2])
		end
	elseif n=="CanvasSize" or n=="CellPadding" or n=="CellSize" or n=="MaxSize" or n=="MinSize" then
		if type(v) == "table" and #v == 4 then
			return UDim2.new(v[1], v[2], v[3], v[4])
		end
	elseif n=="Padding" or n=="PaddingTop" or n=="PaddingBottom" or n=="PaddingLeft" or n=="PaddingRight" or n=="CornerRadius" then
		if type(v) == "table" and #v == 2 then
			return UDim.new(v[1], v[2])
		end
	elseif n=="CFrame" or n=="C0" or n=="C1" then 
		if type(v) == "table" then
			return CFrame.new(unpack(v))
		end
	elseif n=="Material" then 
		return Enum.Material[v] 
	elseif n=="TopSurface" or n=="BottomSurface" then 
		return Enum.SurfaceType[v]
	elseif n=="Face" then
		return Enum.NormalId[v]
	elseif n=="Font" then
		return Enum.Font[v]
	elseif n=="ScaleType" then
		return Enum.ScaleType[v]
	elseif n=="FillDirection" then
		return Enum.FillDirection[v]
	elseif n=="HorizontalAlignment" then
		return Enum.HorizontalAlignment[v]
	elseif n=="VerticalAlignment" then
		return Enum.VerticalAlignment[v]
	elseif n=="SortOrder" then
		return Enum.SortOrder[v]
	elseif n=="BodyPart" then
		return Enum.BodyPart[v]
	elseif n=="AspectType" then
		return Enum.AspectType[v]
	elseif n=="HeadColor" or n=="LeftArmColor" or n=="RightArmColor" or n=="LeftLegColor" or n=="RightLegColor" or n=="TorsoColor" then
		return BrickColor.new(v)
	end
	return v
end

-- 4. DUMP CODE (utilisé uniquement par le bouton Dump, pas automatiquement)
local function ScanAndSync(obj, currentPath)
	local myPath = currentPath
	if obj.Parent == game then myPath = obj.Name else myPath = currentPath .. "/" .. obj.Name end

	if obj:IsA("LuaSourceContainer") then
		local s, source = pcall(function() return obj.Source end)
		if s then
			pcall(function()
				HttpService:PostAsync(SERVER_URL .. "/sync-script", HttpService:JSONEncode({path=myPath..".lua", content=source}), Enum.HttpContentType.ApplicationJson)
			end)
		end
	end
	for _, child in ipairs(obj:GetChildren()) do ScanAndSync(child, myPath) end
end

-- 4b. SYNC SCRIPTS GLOBAUX - Nouveau système avec détection de conflits
-- Les scripts sont sauvegardés dans le dossier GLOBAL (pas dupliqués par scène)
-- On garde juste un hash pour détecter les conflits

-- Variable pour stocker les conflits détectés lors de la sauvegarde
local pendingScriptConflicts = {}
local pendingScriptSave = nil

local function SyncScriptsForScene(sceneName)
	local scriptsToSync = {}

	-- Collecter tous les scripts des services
	local function collectScripts(obj, currentPath)
		local myPath = currentPath
		if obj.Parent == game then 
			myPath = obj.Name 
		else 
			myPath = currentPath .. "/" .. obj.Name 
		end

		if obj:IsA("LuaSourceContainer") then
			local s, source = pcall(function() return obj.Source end)
			if s then
				table.insert(scriptsToSync, {
					path = myPath .. ".lua",
					source = source
				})
			end
		end
		for _, child in ipairs(obj:GetChildren()) do 
			collectScripts(child, myPath) 
		end
	end

	for _, service in ipairs(SERVICES_TO_SYNC) do 
		collectScripts(service, "") 
	end

	if #scriptsToSync == 0 then
		print("  📜 Aucun script a synchroniser")
		return 0
	end

	print("  📜 Sauvegarde de " .. #scriptsToSync .. " scripts globaux...")

	-- Envoyer les scripts en chunks pour eviter "Post data too large"
	local CHUNK_SIZE = 5 -- 5 scripts par chunk (ils peuvent etre gros)
	local totalChunks = math.ceil(#scriptsToSync / CHUNK_SIZE)
	local totalSaved = 0
	local allConflicts = {}

	for chunkIndex = 0, totalChunks - 1 do
		local startIdx = chunkIndex * CHUNK_SIZE + 1
		local endIdx = math.min((chunkIndex + 1) * CHUNK_SIZE, #scriptsToSync)
		local chunk = {}

		for j = startIdx, endIdx do
			table.insert(chunk, scriptsToSync[j])
		end

		-- Envoyer ce chunk
		local success, response = pcall(function()
			return HttpService:PostAsync(
				SERVER_URL .. "/save-global-scripts",
				HttpService:JSONEncode({
					sceneName = sceneName,
					scripts = chunk
				}),
				Enum.HttpContentType.ApplicationJson
			)
		end)

		if not success then
			warn("  Erreur chunk " .. (chunkIndex + 1) .. "/" .. totalChunks .. ":", response)
		else
			local result = HttpService:JSONDecode(response)
			totalSaved = totalSaved + (result.savedCount or #chunk)

			-- Collecter les conflits
			if result.hasConflicts and result.conflicts then
				for _, conflict in ipairs(result.conflicts) do
					table.insert(allConflicts, conflict)
				end
			end
		end

		-- Petit delai entre les chunks
		if chunkIndex < totalChunks - 1 then
			task.wait(0.05)
		end
	end

	-- Gerer les conflits
	if #allConflicts > 0 then
		print("  " .. #allConflicts .. " CONFLIT(S) DE SCRIPTS DETECTE(S)!")
		for _, conflict in ipairs(allConflicts) do
			print("     " .. conflict.path .. " - Modifie par quelqu'un d'autre!")
		end

		pendingScriptConflicts = allConflicts
		pendingScriptSave = {
			sceneName = sceneName,
			scripts = scriptsToSync
		}

		Log(" " .. #allConflicts .. " conflit(s) de scripts! Voir console", Color3.fromRGB(255, 200, 100))
	else
		print("  " .. totalSaved .. " scripts sauvegardes (globaux)")
		pendingScriptConflicts = {}
	end

	return totalSaved
end

-- Fonction pour forcer la sauvegarde d'un script en conflit
local function ForceScriptSave(sceneName, scriptPath, content)
	local success, response = pcall(function()
		return HttpService:PostAsync(
			SERVER_URL .. "/force-save-script",
			HttpService:JSONEncode({
				sceneName = sceneName,
				scriptPath = scriptPath,
				content = content
			}),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if success then
		local result = HttpService:JSONDecode(response)
		if result.success then
			print("  ✅ Script forcé: " .. scriptPath)
			return true
		end
	end
	return false
end

----------------------------------------------------------------------------------
-- ACTIONS
----------------------------------------------------------------------------------

-- A. DUMP CODE (Roblox → Disk)
btnDump.MouseButton1Click:Connect(function()
	Log("⏳ Sync du code...", Color3.fromRGB(100,200,255))
	for _, s in ipairs(SERVICES_TO_SYNC) do ScanAndSync(s, "") end
	Log("✅ Code synchronisé !", Color3.fromRGB(100,255,100))
end)

-- A2. SYNC CODE (Disk → Roblox)
btnSync.MouseButton1Click:Connect(function()
	Log("⏳ Chargement depuis le disque...", Color3.fromRGB(100,200,255))

	-- Récupérer tous les scripts depuis le disque
	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/list-all-scripts")
	end)

	if not success then
		Log("❌ Erreur connexion serveur", Color3.fromRGB(255,0,0))
		return
	end

	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not decodeSuccess or not data.scripts then
		Log("❌ Erreur décodage réponse", Color3.fromRGB(255,0,0))
		return
	end

	local sharedCount = data.sharedScripts or 0
	print("📥 " .. #data.scripts .. " scripts trouvés sur le disque (" .. sharedCount .. " partagés)")

	-- Créer un set des chemins de scripts sur le disque pour détecter les suppressions
	local diskScriptPaths = {}
	for _, scriptInfo in ipairs(data.scripts) do
		diskScriptPaths[scriptInfo.path] = true
	end

	-- ÉTAPE 1: Supprimer les scripts qui n'existent plus sur le disque
	local deleted = 0
	local function checkAndDeleteScripts(parent, currentPath)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("LuaSourceContainer") then
				-- Construire le chemin complet du script
				local scriptPath = currentPath .. "/" .. child.Name .. ".lua"
				
				-- Si ce script n'existe pas sur le disque, le supprimer
				if not diskScriptPaths[scriptPath] then
					print("🗑️ Suppression (n'existe plus sur disque):", scriptPath)
					child:Destroy()
					deleted = deleted + 1
				end
			elseif child:IsA("Folder") then
				-- Récursion dans les dossiers
				checkAndDeleteScripts(child, currentPath .. "/" .. child.Name)
			end
		end
	end

	-- Parcourir tous les services pour détecter les scripts à supprimer
	for _, service in ipairs(SERVICES_TO_SYNC) do
		checkAndDeleteScripts(service, service.Name)
	end

	if deleted > 0 then
		print("🗑️ " .. deleted .. " script(s) supprimé(s) (n'existent plus sur le disque)")
	end

	-- ÉTAPE 2: Créer/Mettre à jour les scripts depuis le disque
	local created = 0
	local updated = 0
	local sharedImported = 0

	for _, scriptInfo in ipairs(data.scripts) do
		-- Parser le chemin
		local parts = string.split(scriptInfo.path, "/")
		local serviceName = parts[1]

		-- Trouver le service
		local parent = nil
		for _, service in ipairs(SERVICES_TO_SYNC) do
			if service.Name == serviceName then
				parent = service
				break
			end
		end

		if parent then
			-- Naviguer/créer les dossiers intermédiaires
			for i = 2, #parts - 1 do
				local folderName = parts[i]
				local folder = parent:FindFirstChild(folderName)
				if not folder then
					folder = Instance.new("Folder")
					folder.Name = folderName
					folder.Parent = parent
				end
				parent = folder
			end

			-- Nom du script (sans .lua)
			local scriptName = parts[#parts]
			if string.sub(scriptName, -4) == ".lua" then
				scriptName = string.sub(scriptName, 1, -5)
			end

			-- Vérifier si le script existe déjà
			local existingScript = parent:FindFirstChild(scriptName)

			local isShared = scriptInfo.isShared or false
			local prefix = isShared and "🔗 [PARTAGÉ] " or "  "
			
			if existingScript and existingScript:IsA("LuaSourceContainer") then
				-- Mettre à jour le script existant
				pcall(function()
					existingScript.Source = scriptInfo.content
				end)
				updated = updated + 1
				if isShared then sharedImported = sharedImported + 1 end
				print(prefix .. "✓ Mis à jour:", scriptInfo.path)
			else
				-- Créer un nouveau script
				local scriptType = scriptInfo.className or "Script"
				local newScript

				if scriptType == "LocalScript" then
					newScript = Instance.new("LocalScript")
				elseif scriptType == "ModuleScript" then
					newScript = Instance.new("ModuleScript")
				else
					newScript = Instance.new("Script")
				end

				newScript.Name = scriptName
				pcall(function()
					newScript.Source = scriptInfo.content
				end)
				newScript.Parent = parent
				created = created + 1
				if isShared then sharedImported = sharedImported + 1 end
				print(prefix .. "+ Créé:", scriptInfo.path)
			end
		end
	end

	local sharedMsg = sharedImported > 0 and (" (" .. sharedImported .. " partagés)") or ""
	local deleteMsg = deleted > 0 and (", " .. deleted .. " supprimés") or ""
	Log("✅ " .. created .. " créés, " .. updated .. " mis à jour" .. deleteMsg .. sharedMsg, Color3.fromRGB(100,255,100))
end)

-- B. SAVE (Inclus Camera & Terrain avec hiérarchie complète)
btnSave.MouseButton1Click:Connect(function()
	-- Utiliser le nom dans l'input OU la scène sélectionnée
	local name = nameInput.Text ~= "" and nameInput.Text or selectedScene
	if name == "" then Log("❌ Nom requis", Color3.fromRGB(255,50,50)) return end
	Log("⏳ Sauvegarde de '" .. name .. "'...", Color3.fromRGB(255,170,0))

	-- Réinitialiser la table des IDs utilisés pour détecter les doublons
	usedIDs = {}

	-- 1. Créer/mettre à jour le dossier de templates pour les MeshParts
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local templateFolder = replicatedStorage:FindFirstChild("MeshPartTemplates")
	if not templateFolder then
		templateFolder = Instance.new("Folder")
		templateFolder.Name = "MeshPartTemplates"
		templateFolder.Parent = replicatedStorage
		print("📁 Dossier MeshPartTemplates créé dans ReplicatedStorage")
	end

	-- Scanner tous les MeshParts du Workspace et les ajouter aux templates
	local meshPartsAdded = 0
	local meshPartsUpdated = 0
	local function scanForMeshParts(parent)
		for _, obj in ipairs(parent:GetChildren()) do
			if obj:IsA("MeshPart") and obj.MeshId and obj.MeshId ~= "" then
				-- Vérifier si ce MeshId existe déjà dans les templates
				local existingTemplate = nil
				for _, template in ipairs(templateFolder:GetDescendants()) do
					if template:IsA("MeshPart") and template.MeshId == obj.MeshId then
						existingTemplate = template
						break
					end
				end

				if not existingTemplate then
					-- Créer un nouveau template
					local template = obj:Clone()
					template.Name = obj.Name .. "_Template"
					template.Parent = templateFolder
					-- Nettoyer les enfants inutiles (garder juste le mesh)
					for _, child in ipairs(template:GetChildren()) do
						if not child:IsA("Attachment") then
							child:Destroy()
						end
					end
					meshPartsAdded = meshPartsAdded + 1
				else
					meshPartsUpdated = meshPartsUpdated + 1
				end
			end
			-- Récursif
			scanForMeshParts(obj)
		end
	end

	scanForMeshParts(Workspace)

	if meshPartsAdded > 0 then
		print("  ✨ " .. meshPartsAdded .. " nouveaux templates MeshPart ajoutés")
	end
	if meshPartsUpdated > 0 then
		print("  ✓ " .. meshPartsUpdated .. " templates MeshPart déjà existants")
	end

	local export = {}
	local stats = {Parts=0, Models=0, Folders=0, Scripts=0, Lights=0, Other=0}

	-- Sauvegarder tous les objets du Workspace avec leur hiérarchie
	for _, obj in ipairs(Workspace:GetChildren()) do
		local data = SerializeRecursive(obj, "WORKSPACE")
		for _, item in ipairs(data) do
			table.insert(export, item)
			-- Compter les types
			if item.ClassName:match("Part") then stats.Parts = stats.Parts + 1
			elseif item.ClassName == "Model" then stats.Models = stats.Models + 1
			elseif item.ClassName == "Folder" then stats.Folders = stats.Folders + 1
			elseif item.ClassName:match("Script") then stats.Scripts = stats.Scripts + 1
			elseif item.ClassName:match("Light") then stats.Lights = stats.Lights + 1
			else stats.Other = stats.Other + 1
			end
		end
	end

	-- Sauvegarder la caméra si elle n'est pas déjà dans la liste
	if workspace.CurrentCamera then
		local camData = SerializeRecursive(workspace.CurrentCamera, "WORKSPACE")
		for _, item in ipairs(camData) do
			table.insert(export, item)
		end
	end

	print("📦 SAUVEGARDE:", #export, "objets")
	print("  ├─ Parts:", stats.Parts)
	print("  ├─ Models:", stats.Models)
	print("  ├─ Folders:", stats.Folders)
	print("  ├─ Scripts:", stats.Scripts)
	print("  ├─ Lights:", stats.Lights)
	print("  └─ Autres:", stats.Other)

	-- Compteur détaillé par classe (pour debug)
	local classCounts = {}
	for _, item in ipairs(export) do
		classCounts[item.ClassName] = (classCounts[item.ClassName] or 0) + 1
	end

	-- Afficher les 10 classes les plus fréquentes
	local sortedClasses = {}
	for className, count in pairs(classCounts) do
		table.insert(sortedClasses, {name = className, count = count})
	end
	table.sort(sortedClasses, function(a, b) return a.count > b.count end)

	print("  📊 Top classes:")
	for i = 1, math.min(10, #sortedClasses) do
		print("     " .. sortedClasses[i].count .. "x " .. sortedClasses[i].name)
	end

	-- Envoyer en chunks si trop gros (limite Roblox: 1MB)
	-- Réduire la taille pour éviter les erreurs "Post data too large"
	local CHUNK_SIZE = 50 -- Objets par chunk (réduit de 200 à 50)
	local totalChunks = math.ceil(#export / CHUNK_SIZE)

	-- NOTE: Les scripts ne sont plus envoyés avec les chunks
	-- Ils seront sauvegardés globalement via SyncScriptsForScene() à la fin

	if totalChunks > 1 then
		print("📤 Envoi en", totalChunks, "morceaux (objets uniquement)...")

		for i = 0, totalChunks - 1 do
			local startIdx = i * CHUNK_SIZE + 1
			local endIdx = math.min((i + 1) * CHUNK_SIZE, #export)
			local chunk = {}
			for j = startIdx, endIdx do
				table.insert(chunk, export[j])
			end

			-- Payload sans scripts (ils sont globaux maintenant)
			local payload = {
				sceneName = name,
				chunkIndex = i,
				totalChunks = totalChunks,
				data = chunk
			}

			-- Attendre un peu entre chaque chunk pour éviter le rate limit
			if i > 0 then
				task.wait(0.1) -- 100ms entre chaque chunk
			end

			local s, err = pcall(function()
				HttpService:PostAsync(SERVER_URL .. "/save-scene-chunk", HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
			end)

			if not s then
				Log("❌ Erreur chunk " .. (i+1) .. ": " .. tostring(err), Color3.fromRGB(255,0,0))
				return
			end
			print("  ✓ Chunk", i+1, "/", totalChunks)
		end
		-- Synchroniser les scripts GLOBAUX (nouveau système)
		local scriptCount = SyncScriptsForScene(name)

		Log("✅ Sauvegardé: " .. #export .. " objets, " .. scriptCount .. " scripts (globaux)", Color3.fromRGB(100,255,100))
		-- Rafraîchir la liste et sélectionner la nouvelle scène
		selectedScene = name
		lastSavedScene = name
		currentLoadedScene = name -- Mettre à jour la scène active
		hasUnsavedChanges = false
		selectedLabel.Text = "✓ Sélectionnée: " .. selectedScene
		mergeBaseValue.Text = selectedScene
		nameInput.Text = ""
		updateActiveSceneIndicator()
		refreshScenesList()
	else
		-- Nouveau format : UNIQUEMENT les objets (les scripts sont globaux maintenant)
		local sceneData = {
			objects = export
			-- scripts ne sont plus sauvegardés ici, ils sont globaux
		}

		-- Envoi direct si petit
		local s, err = pcall(function() 
			HttpService:PostAsync(SERVER_URL .. "/save-scene?name=" .. name, HttpService:JSONEncode(sceneData), Enum.HttpContentType.ApplicationJson) 
		end)

		if s then 
			-- Synchroniser les scripts GLOBAUX (nouveau système)
			local scriptCount = SyncScriptsForScene(name)

			Log("✅ Sauvegardé: " .. #export .. " objets, " .. scriptCount .. " scripts (globaux)", Color3.fromRGB(100,255,100))
			-- Rafraîchir la liste et sélectionner la nouvelle scène
			selectedScene = name
			lastSavedScene = name
			currentLoadedScene = name -- Mettre à jour la scène active
			hasUnsavedChanges = false
			selectedLabel.Text = "✓ Sélectionnée: " .. selectedScene
			mergeBaseValue.Text = selectedScene
			nameInput.Text = ""
			updateActiveSceneIndicator()
			refreshScenesList()
		else 
			Log("❌ Erreur: " .. tostring(err), Color3.fromRGB(255,0,0))
			print("ERREUR DÉTAILLÉE:", err)
		end
	end
end)

-- Popup de confirmation avant LOAD
local confirmWidget = plugin:CreateDockWidgetPluginGui(
	"ConfirmSaveUI",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 350, 180, 300, 150)
)
confirmWidget.Title = "⚠️ Changements non sauvegardés"

local confirmGui = Instance.new("Frame", confirmWidget)
confirmGui.Size = UDim2.fromScale(1, 1)
confirmGui.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local confirmText = Instance.new("TextLabel", confirmGui)
confirmText.Size = UDim2.new(1, -20, 0, 80)
confirmText.Position = UDim2.new(0, 10, 0, 10)
confirmText.BackgroundTransparency = 1
confirmText.TextColor3 = Color3.new(1, 1, 1)
confirmText.Font = Enum.Font.SourceSans
confirmText.TextSize = 14
confirmText.TextWrapped = true
confirmText.Text = "Voulez-vous sauvegarder la scène actuelle avant de charger une autre scène ?\n\nLes modifications non sauvegardées seront perdues."

local confirmBtnsFrame = Instance.new("Frame", confirmGui)
confirmBtnsFrame.Size = UDim2.new(1, -20, 0, 40)
confirmBtnsFrame.Position = UDim2.new(0, 10, 0, 100)
confirmBtnsFrame.BackgroundTransparency = 1

local btnSaveFirst = Instance.new("TextButton", confirmBtnsFrame)
btnSaveFirst.Size = UDim2.new(0.32, -2, 1, 0)
btnSaveFirst.Position = UDim2.new(0, 0, 0, 0)
btnSaveFirst.Text = "💾 Sauvegarder"
btnSaveFirst.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
btnSaveFirst.TextColor3 = Color3.new(1, 1, 1)
btnSaveFirst.Font = Enum.Font.SourceSansBold
btnSaveFirst.TextSize = 12
Instance.new("UICorner", btnSaveFirst).CornerRadius = UDim.new(0, 6)

local btnLoadAnyway = Instance.new("TextButton", confirmBtnsFrame)
btnLoadAnyway.Size = UDim2.new(0.32, -2, 1, 0)
btnLoadAnyway.Position = UDim2.new(0.34, 0, 0, 0)
btnLoadAnyway.Text = "⚠️ Charger"
btnLoadAnyway.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
btnLoadAnyway.TextColor3 = Color3.new(1, 1, 1)
btnLoadAnyway.Font = Enum.Font.SourceSansBold
btnLoadAnyway.TextSize = 12
Instance.new("UICorner", btnLoadAnyway).CornerRadius = UDim.new(0, 6)

local btnCancelLoad = Instance.new("TextButton", confirmBtnsFrame)
btnCancelLoad.Size = UDim2.new(0.32, -2, 1, 0)
btnCancelLoad.Position = UDim2.new(0.68, 0, 0, 0)
btnCancelLoad.Text = "❌ Annuler"
btnCancelLoad.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
btnCancelLoad.TextColor3 = Color3.new(1, 1, 1)
btnCancelLoad.Font = Enum.Font.SourceSansBold
btnCancelLoad.TextSize = 12
Instance.new("UICorner", btnCancelLoad).CornerRadius = UDim.new(0, 6)

local pendingLoadScene = ""

-- Fonction pour effectuer le chargement
local function performLoad(name)
	-- Vérifier si un chargement est déjà en cours
	if isLoading then
		Log("⚠️ Chargement déjà en cours, patientez...", Color3.fromRGB(255, 200, 100))
		return
	end

	-- Activer le verrouillage
	isLoading = true
	updateActiveSceneIndicator()

	-- Désactiver les boutons pendant le chargement
	btnLoad.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	btnLoad.Text = "⏳ Chargement..."
	btnSave.BackgroundColor3 = Color3.fromRGB(100, 100, 100)

	Log("⏳ Chargement de '" .. name .. "'...", Color3.fromRGB(255,170,0))

	-- 1. Récupérer les métadonnées (combien de chunks ?)
	local s, res = pcall(function() return HttpService:GetAsync(SERVER_URL .. "/load-scene?name=" .. name) end)
	if not s then 
		Log("❌ Fichier introuvable", Color3.fromRGB(255,0,0))
		-- Déverrouiller en cas d'erreur
		isLoading = false
		updateActiveSceneIndicator()
		btnLoad.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
		btnLoad.Text = "♻️ LOAD"
		btnSave.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		return 
	end

	local metadata = HttpService:JSONDecode(res)
	local totalChunks = metadata.totalChunks

	print("📂 CHARGEMENT:", metadata.totalObjects, "objets en", totalChunks, "chunks")

	-- ÉTAPE 1: Supprimer TOUS les scripts existants dans les services
	clearAllScripts()

	-- Nettoyer les états de lock (les scripts vont être recréés)
	scriptOriginalStates = {}
	lockedScripts = {}

	-- ÉTAPE 2: Charger les scripts GLOBAUX (nouveau système)
	print("  📜 Chargement des scripts globaux...")
	local scriptsData = {}
	local globalSuccess, globalRes = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/get-global-scripts")
	end)

	if globalSuccess then
		local globalData = HttpService:JSONDecode(globalRes)
		if globalData.scripts and #globalData.scripts > 0 then
			scriptsData = globalData.scripts
			print("  ✓ " .. #scriptsData .. " scripts globaux récupérés")
		else
			print("  ⚠️ Aucun script global trouvé")
		end
	else
		print("  ⚠️ Erreur récupération scripts globaux:", globalRes)
	end

	-- ÉTAPE 3: Créer les scripts depuis les données globales
	if #scriptsData > 0 then
		print("  📜 Création de", #scriptsData, "scripts...")
		local created = 0
		for _, scriptInfo in ipairs(scriptsData) do
			if createScriptFromData(scriptInfo) then
				created = created + 1
			end
		end
		print("  📜 Scripts créés:", created, "/", #scriptsData)
	end

	-- 2. Charger tous les chunks
	local allData = {}
	for i = 0, totalChunks - 1 do
		-- Délai entre les chunks pour éviter le rate limit
		if i > 0 then
			task.wait(0.15) -- 150ms entre chaque chunk
		end

		local chunkSuccess, chunkRes = pcall(function() 
			return HttpService:GetAsync(SERVER_URL .. "/load-scene?name=" .. name .. "&chunk=" .. i) 
		end)

		if not chunkSuccess then
			Log("❌ Erreur chunk " .. (i+1) .. ": " .. tostring(chunkRes), Color3.fromRGB(255,0,0))
			-- Déverrouiller en cas d'erreur
			isLoading = false
			updateActiveSceneIndicator()
			btnLoad.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
			btnLoad.Text = "♻️ LOAD"
			btnSave.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			return
		end

		local chunkData = HttpService:JSONDecode(chunkRes)
		for _, item in ipairs(chunkData.data) do
			table.insert(allData, item)
		end

		print("  ✓ Chunk", i+1, "/", totalChunks, "chargé")
		Log("⏳ Chargement " .. math.floor((i+1)/totalChunks*100) .. "%...", Color3.fromRGB(255,170,0))
	end

	local data = allData
	ChangeHistoryService:SetWaypoint("Load Scene")

	print("📂 TOTAL CHARGÉ:", #data, "objets")

	-- 1. Nettoyage : On détruit tout SAUF Terrain et Camera
	local deleted = 0
	for _, obj in ipairs(Workspace:GetChildren()) do
		if not IGNORE_LIST[obj.Name] and not obj:IsA("Terrain") and not obj:IsA("Camera") then
			obj:Destroy()
			deleted = deleted + 1
		end
	end
	print("  🗑️ Supprimés:", deleted, "objets")

	-- 2. Première passe : Créer tous les objets (sans parent encore)
	local objectMap = {}
	local stats = {Parts=0, Models=0, Folders=0, Scripts=0, Lights=0, Other=0, Skipped=0}

	for _, d in ipairs(data) do
		local obj

		-- IGNORER les types qu'on ne peut pas créer
		if CANNOT_CREATE[d.ClassName] then
			stats.Skipped = stats.Skipped + 1
			-- Ne pas ajouter à objectMap, on skip complètement

			-- CAS SPÉCIAL 1 : TERRAIN (On ne crée pas, on met à jour)
		elseif d.ClassName == "Terrain" then
			obj = Workspace.Terrain
			objectMap[d.ID] = obj
			print("  ♻️ Terrain mis à jour")

			-- CAS SPÉCIAL 2 : CAMERA (On ne crée pas, on met à jour)
		elseif d.ClassName == "Camera" then
			obj = Workspace.CurrentCamera
			objectMap[d.ID] = obj
			print("  📷 Camera mise à jour")

			-- CAS STANDARD : Création d'objet
		else
			-- Pour MeshPart : chercher un template dans ReplicatedStorage
			if d.ClassName == "MeshPart" and d.Properties.MeshId then
				local meshId = d.Properties.MeshId

				-- Chercher un MeshPart existant avec le même MeshId dans ReplicatedStorage
				local templateFolder = game:GetService("ReplicatedStorage"):FindFirstChild("MeshPartTemplates")
				local template = nil

				if templateFolder then
					for _, child in ipairs(templateFolder:GetDescendants()) do
						if child:IsA("MeshPart") and child.MeshId == meshId then
							template = child
							break
						end
					end
				end

				if template then
					-- Cloner le template
					obj = template:Clone()
					obj.Name = d.Name
					obj:SetAttribute("SceneID", d.ID)
					objectMap[d.ID] = obj
				else
					-- Pas de template trouvé - créer un MeshPart vide avec un warning
					warn("⚠️ Aucun template trouvé pour MeshPart:", d.Name, "- MeshId:", meshId)
					warn("   💡 Créez un dossier 'MeshPartTemplates' dans ReplicatedStorage et ajoutez-y vos MeshParts")

					local success, result = pcall(function()
						return Instance.new(d.ClassName)
					end)

					if success then
						obj = result
						obj.Name = d.Name
						obj:SetAttribute("SceneID", d.ID)
						-- Stocker le MeshId comme attribut pour référence
						obj:SetAttribute("_OriginalMeshId", meshId)
						objectMap[d.ID] = obj
					else
						warn("⚠️ Impossible de créer:", d.ClassName, "-", result)
						stats.Skipped = stats.Skipped + 1
					end
				end
			else
				-- Objet normal
				local success, result = pcall(function()
					return Instance.new(d.ClassName)
				end)

				if success then
					obj = result
					obj.Name = d.Name
					obj:SetAttribute("SceneID", d.ID)
					objectMap[d.ID] = obj

					-- Compter les types
					if d.ClassName:match("Part") then stats.Parts = stats.Parts + 1
					elseif d.ClassName == "Model" then stats.Models = stats.Models + 1
					elseif d.ClassName == "Folder" then stats.Folders = stats.Folders + 1
					elseif d.ClassName:match("Script") then stats.Scripts = stats.Scripts + 1
					elseif d.ClassName:match("Light") then stats.Lights = stats.Lights + 1
					else stats.Other = stats.Other + 1
					end
				else
					warn("⚠️ Impossible de créer:", d.ClassName, "-", result)
					stats.Skipped = stats.Skipped + 1
				end
			end
		end

		-- Application des propriétés (sauf Name qui est déjà set)
		-- Pour MeshPart, MeshId et TextureID sont déjà appliqués
		if obj then
			local propCount = 0

			for p,v in pairs(d.Properties) do 
				if p ~= "Name" then
					-- Sauter MeshId et TextureID pour MeshPart (déjà appliqués)
					if d.ClassName == "MeshPart" and (p == "MeshId" or p == "TextureID") then
						-- Déjà appliqué lors de la création
					else
						local success = pcall(function() obj[p]=Unpack(p,v) end)
						if success then 
							propCount = propCount + 1 
						end
					end
				end
			end

			if propCount > 0 and (d.ClassName:match("Gui") or d.ClassName:match("Label") or d.ClassName:match("Button")) then
				print("    ✓", d.ClassName, d.Name, "-", propCount, "propriétés")
			end
		end
	end

	-- Compter et vérifier les MeshParts pour debug
	local meshPartCount = 0
	local meshPartWithMesh = 0
	for _, d in ipairs(data) do
		if d.ClassName == "MeshPart" and objectMap[d.ID] then
			meshPartCount = meshPartCount + 1
			local mp = objectMap[d.ID]
			if mp.MeshId and mp.MeshId ~= "" then
				meshPartWithMesh = meshPartWithMesh + 1
			end
		end
	end

	print("  ✨ Créés:")
	print("    ├─ Parts:", stats.Parts)
	print("    ├─ Models:", stats.Models)
	print("    ├─ Folders:", stats.Folders)
	print("    ├─ Scripts:", stats.Scripts)
	print("    ├─ Lights:", stats.Lights)
	print("    ├─ Autres:", stats.Other)
	if meshPartCount > 0 then
		print("    ├─ 🎨 MeshParts:", meshPartCount, "(" .. meshPartWithMesh .. " avec mesh)")
	end
	if stats.Skipped > 0 then
		print("    └─ ⚠️ Ignorés:", stats.Skipped, "(types non créables)")
	end

	-- 3. Deuxième passe : Reconstruire la hiérarchie (parent-enfant)
	print("  🔗 Reconstruction de la hiérarchie...")
	local parentCount = 0
	local orphanCount = 0
	for _, d in ipairs(data) do
		local obj = objectMap[d.ID]
		-- Ne pas essayer de changer le parent du Terrain ou de la Camera (ils sont déjà au bon endroit)
		if obj and d.ParentID and not obj:IsA("Terrain") and not obj:IsA("Camera") then
			if d.ParentID == "WORKSPACE" then
				obj.Parent = Workspace
				parentCount = parentCount + 1
			elseif objectMap[d.ParentID] then
				obj.Parent = objectMap[d.ParentID]
				parentCount = parentCount + 1
			else
				warn("⚠️ Parent introuvable pour:", d.Name, "- ParentID:", d.ParentID)
				orphanCount = orphanCount + 1
				-- Mettre dans Workspace par défaut
				obj.Parent = Workspace
			end
		end
	end
	print("    ✓", parentCount, "objets parentés")
	if orphanCount > 0 then
		print("    ⚠️", orphanCount, "orphelins (parent manquant)")
	end

	-- Les MeshParts ont déjà leur MeshId et TextureID appliqués lors de la création
	print("  ✅ MeshParts créés avec leurs meshes")

	Log("✅ Chargé: " .. #data .. " objets, " .. #scriptsData .. " scripts", Color3.fromRGB(100,255,100))

	-- Marquer comme sauvegardé (on vient de charger)
	lastSavedScene = name
	hasUnsavedChanges = false

	-- Mettre à jour la scène actuellement chargée
	currentLoadedScene = name

	-- ⭐ NOUVEAU: Mettre à jour l'état connu pour la sync bidirectionnelle
	-- Cela permet de détecter les futurs conflits
	if #scriptsData > 0 then
		task.spawn(function()
			local scriptsToUpdate = {}
			for _, scriptInfo in ipairs(scriptsData) do
				table.insert(scriptsToUpdate, {
					path = scriptInfo.path,
					content = scriptInfo.source or ""
				})
			end

			pcall(function()
				HttpService:PostAsync(
					SERVER_URL .. "/update-known-state",
					HttpService:JSONEncode({ scripts = scriptsToUpdate }),
					Enum.HttpContentType.ApplicationJson
				)
			end)
			print("  📋 État de sync mis à jour pour " .. #scriptsToUpdate .. " scripts")
		end)
	end

	-- Désactiver le verrouillage
	isLoading = false
	updateActiveSceneIndicator()

	-- Réactiver les boutons
	btnLoad.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	btnLoad.Text = "♻️ LOAD"
	btnSave.BackgroundColor3 = Color3.fromRGB(46, 204, 113)

	print("  ✅ Scène '" .. name .. "' chargée avec succès")
end

-- Fonction pour sauvegarder rapidement (appelée par la popup)
local function quickSave(sceneName)
	if sceneName == "" then return false end

	Log("⏳ Sauvegarde rapide de '" .. sceneName .. "'...", Color3.fromRGB(255,170,0))
	usedIDs = {}

	local export = {}
	for _, obj in ipairs(Workspace:GetChildren()) do
		if not IGNORE_LIST[obj.Name] and not obj:IsA("Terrain") and not obj:IsA("Camera") then
			local data = SerializeRecursive(obj, "WORKSPACE")
			for _, item in ipairs(data) do
				table.insert(export, item)
			end
		end
	end

	-- NOTE: Les scripts ne sont plus envoyés avec les chunks, ils sont globaux

	-- Utiliser le système de chunks si trop gros
	local CHUNK_SIZE = 50
	local totalChunks = math.ceil(#export / CHUNK_SIZE)

	if totalChunks > 1 then
		print("📤 Sauvegarde rapide en", totalChunks, "morceaux (objets uniquement)...")

		for i = 0, totalChunks - 1 do
			local startIdx = i * CHUNK_SIZE + 1
			local endIdx = math.min((i + 1) * CHUNK_SIZE, #export)
			local chunk = {}
			for j = startIdx, endIdx do
				table.insert(chunk, export[j])
			end

			local payload = {
				sceneName = sceneName,
				chunkIndex = i,
				totalChunks = totalChunks,
				data = chunk
			}

			if i > 0 then task.wait(0.1) end

			local s, err = pcall(function()
				HttpService:PostAsync(SERVER_URL .. "/save-scene-chunk", HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
			end)

			if not s then
				Log("❌ Erreur chunk " .. (i+1) .. ": " .. tostring(err), Color3.fromRGB(255,0,0))
				return false
			end
		end

		-- Sauvegarder les scripts globaux
		local scriptCount = SyncScriptsForScene(sceneName)
		Log("✅ Sauvegardé: " .. #export .. " objets, " .. scriptCount .. " scripts (globaux)", Color3.fromRGB(100,255,100))
		hasUnsavedChanges = false
		return true
	else
		-- Petit fichier : envoi direct (sans scripts, ils sont globaux)
		local sceneData = { objects = export }

		local s, err = pcall(function() 
			HttpService:PostAsync(SERVER_URL .. "/save-scene?name=" .. sceneName, HttpService:JSONEncode(sceneData), Enum.HttpContentType.ApplicationJson) 
		end)

		if s then
			local scriptCount = SyncScriptsForScene(sceneName)
			Log("✅ Sauvegardé: " .. #export .. " objets, " .. scriptCount .. " scripts (globaux)", Color3.fromRGB(100,255,100))
			hasUnsavedChanges = false
			return true
		else
			Log("❌ Erreur: " .. tostring(err), Color3.fromRGB(255,0,0))
			return false
		end
	end
end

-- Handlers pour la popup de confirmation
btnSaveFirst.MouseButton1Click:Connect(function()
	confirmWidget.Enabled = false
	-- Sauvegarder d'abord
	if lastSavedScene ~= "" then
		quickSave(lastSavedScene)
	end
	-- Puis charger
	task.wait(0.5)
	performLoad(pendingLoadScene)
end)

btnLoadAnyway.MouseButton1Click:Connect(function()
	confirmWidget.Enabled = false
	performLoad(pendingLoadScene)
end)

btnCancelLoad.MouseButton1Click:Connect(function()
	confirmWidget.Enabled = false
	pendingLoadScene = ""
	Log("❌ Chargement annulé", Color3.fromRGB(255, 200, 100))
end)

-- C. LOAD (avec confirmation si changements non sauvegardés)
btnLoad.MouseButton1Click:Connect(function()
	-- Vérifier si un chargement est déjà en cours
	if isLoading then
		Log("⚠️ Chargement déjà en cours, patientez...", Color3.fromRGB(255, 200, 100))
		return
	end

	-- Utiliser la scène sélectionnée
	local name = selectedScene
	if name == "" then Log("❌ Sélectionnez une scène", Color3.fromRGB(255,50,50)) return end

	-- Si c'est la même scène, charger directement
	if name == lastSavedScene then
		performLoad(name)
		return
	end

	-- Si des changements non sauvegardés, demander confirmation
	if hasUnsavedChanges and lastSavedScene ~= "" then
		pendingLoadScene = name
		confirmText.Text = "Voulez-vous sauvegarder '" .. lastSavedScene .. "' avant de charger '" .. name .. "' ?\n\nLes modifications non sauvegardées seront perdues."
		confirmWidget.Enabled = true
		return
	end

	-- Sinon charger directement
	performLoad(name)
end)

toggleBtn.Click:Connect(function() widget.Enabled = not widget.Enabled end)

-- Détecter les changements dans le Workspace pour marquer comme "non sauvegardé"
local function setupChangeTracking()
	-- Tracker les ajouts/suppressions dans le Workspace
	Workspace.DescendantAdded:Connect(function(obj)
		if lastSavedScene ~= "" and not obj:IsA("Camera") then
			hasUnsavedChanges = true
		end
	end)

	Workspace.DescendantRemoving:Connect(function(obj)
		if lastSavedScene ~= "" and not obj:IsA("Camera") then
			hasUnsavedChanges = true
		end
	end)

	-- Tracker les modifications de scripts
	for _, service in ipairs(SERVICES_TO_SYNC) do
		service.DescendantAdded:Connect(function(obj)
			if obj:IsA("LuaSourceContainer") and lastSavedScene ~= "" then
				hasUnsavedChanges = true
			end
		end)
	end
end

-- Activer le tracking au démarrage
task.spawn(setupChangeTracking)

----------------------------------------------------------------------------------
-- MERGE SYSTEM - Fusion de scènes avec détection de conflits
----------------------------------------------------------------------------------

-- Variables pour la résolution de conflits
local currentConflicts = {}
local conflictResolutions = {}
local pendingMergeData = nil

-- Créer la popup de résolution de conflits
local conflictWidget = plugin:CreateDockWidgetPluginGui(
	"ConflictResolverUI",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 450, 500, 400, 400)
)
conflictWidget.Title = "⚠️ Résolution de Conflits"

local conflictGui = Instance.new("Frame", conflictWidget)
conflictGui.Size = UDim2.fromScale(1, 1)
conflictGui.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

-- Header
local conflictHeader = Instance.new("TextLabel", conflictGui)
conflictHeader.Size = UDim2.new(1, 0, 0, 50)
conflictHeader.BackgroundColor3 = Color3.fromRGB(156, 89, 182)
conflictHeader.TextColor3 = Color3.new(1, 1, 1)
conflictHeader.Font = Enum.Font.SourceSansBold
conflictHeader.TextSize = 16
conflictHeader.Text = "⚠️ Conflits détectés"

-- Liste des conflits
local conflictScroll = Instance.new("ScrollingFrame", conflictGui)
conflictScroll.Size = UDim2.new(1, -20, 1, -120)
conflictScroll.Position = UDim2.new(0, 10, 0, 60)
conflictScroll.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
conflictScroll.BorderSizePixel = 0
conflictScroll.ScrollBarThickness = 6
Instance.new("UICorner", conflictScroll).CornerRadius = UDim.new(0, 6)

local conflictLayout = Instance.new("UIListLayout", conflictScroll)
conflictLayout.Padding = UDim.new(0, 8)
local conflictPadding = Instance.new("UIPadding", conflictScroll)
conflictPadding.PaddingTop = UDim.new(0, 8)
conflictPadding.PaddingLeft = UDim.new(0, 8)
conflictPadding.PaddingRight = UDim.new(0, 8)

-- Boutons en bas
local conflictButtonsFrame = Instance.new("Frame", conflictGui)
conflictButtonsFrame.Size = UDim2.new(1, -20, 0, 50)
conflictButtonsFrame.Position = UDim2.new(0, 10, 1, -60)
conflictButtonsFrame.BackgroundTransparency = 1

local btnApplyMerge = Instance.new("TextButton", conflictButtonsFrame)
btnApplyMerge.Size = UDim2.new(0.48, 0, 0, 40)
btnApplyMerge.Position = UDim2.new(0, 0, 0, 0)
btnApplyMerge.Text = "✅ Appliquer le Merge"
btnApplyMerge.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
btnApplyMerge.TextColor3 = Color3.new(1, 1, 1)
btnApplyMerge.Font = Enum.Font.SourceSansBold
btnApplyMerge.TextSize = 14
Instance.new("UICorner", btnApplyMerge).CornerRadius = UDim.new(0, 6)

local btnCancelMerge = Instance.new("TextButton", conflictButtonsFrame)
btnCancelMerge.Size = UDim2.new(0.48, 0, 0, 40)
btnCancelMerge.Position = UDim2.new(0.52, 0, 0, 0)
btnCancelMerge.Text = "❌ Annuler"
btnCancelMerge.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
btnCancelMerge.TextColor3 = Color3.new(1, 1, 1)
btnCancelMerge.Font = Enum.Font.SourceSansBold
btnCancelMerge.TextSize = 14
Instance.new("UICorner", btnCancelMerge).CornerRadius = UDim.new(0, 6)

-- Fonction pour formater une valeur de manière lisible
local function formatValue(val, propName)
	if val == nil then return "∅" end

	-- Si c'est une table (array)
	if type(val) == "table" then
		-- CFrame (12 composants)
		if #val == 12 then
			-- Afficher juste la position (X, Y, Z)
			return string.format("Pos(%.1f, %.1f, %.1f)", val[1] or 0, val[2] or 0, val[3] or 0)
			-- Vector3 (3 composants)
		elseif #val == 3 then
			return string.format("(%.1f, %.1f, %.1f)", val[1] or 0, val[2] or 0, val[3] or 0)
			-- UDim2 (4 composants)
		elseif #val == 4 then
			return string.format("(%.2f, %d, %.2f, %d)", val[1] or 0, val[2] or 0, val[3] or 0, val[4] or 0)
			-- Vector2 (2 composants)
		elseif #val == 2 then
			return string.format("(%.1f, %.1f)", val[1] or 0, val[2] or 0)
			-- ColorSequence ou autre
		else
			return "[" .. #val .. " éléments]"
		end
	end

	-- Si c'est un string (couleur hex, enum, etc.)
	if type(val) == "string" then
		-- Couleur hex
		if val:match("^%x%x%x%x%x%x$") then
			return "#" .. val:upper()
		end
		-- Tronquer si trop long
		if #val > 20 then
			return val:sub(1, 17) .. "..."
		end
		return val
	end

	-- Nombre
	if type(val) == "number" then
		if val == math.floor(val) then
			return tostring(math.floor(val))
		else
			return string.format("%.2f", val)
		end
	end

	-- Boolean
	if type(val) == "boolean" then
		return val and "✓ Oui" or "✗ Non"
	end

	return tostring(val):sub(1, 20)
end

-- Fonction pour afficher les différences de propriétés
local function getChangedProperties(props1, props2)
	local changes = {}

	-- Propriétés modifiées ou ajoutées dans scene2
	for key, val2 in pairs(props2) do
		local val1 = props1[key]
		if val1 == nil then
			table.insert(changes, {prop = key, base = "∅", merge = formatValue(val2, key)})
		elseif tostring(val1) ~= tostring(val2) then
			table.insert(changes, {prop = key, base = formatValue(val1, key), merge = formatValue(val2, key)})
		end
	end

	return changes
end

-- Fonction pour créer un item de conflit dans la liste
local function createConflictItem(conflict, index)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, -16, 0, 0) -- Hauteur auto
	item.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	item.BorderSizePixel = 0
	item.LayoutOrder = index
	Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)

	-- Header de l'item
	local itemHeader = Instance.new("Frame", item)
	itemHeader.Size = UDim2.new(1, 0, 0, 35)
	itemHeader.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
	itemHeader.BorderSizePixel = 0
	Instance.new("UICorner", itemHeader).CornerRadius = UDim.new(0, 6)

	local itemTitle = Instance.new("TextLabel", itemHeader)
	itemTitle.Size = UDim2.new(0.7, 0, 1, 0)
	itemTitle.Position = UDim2.new(0, 10, 0, 0)
	itemTitle.BackgroundTransparency = 1
	itemTitle.TextColor3 = Color3.new(1, 1, 1)
	itemTitle.Font = Enum.Font.SourceSansBold
	itemTitle.TextSize = 13
	itemTitle.Text = "📦 " .. conflict.name .. " (" .. conflict.className .. ")"
	itemTitle.TextXAlignment = Enum.TextXAlignment.Left

	-- Boutons de choix
	local choiceFrame = Instance.new("Frame", itemHeader)
	choiceFrame.Size = UDim2.new(0.3, -10, 0, 25)
	choiceFrame.Position = UDim2.new(0.7, 0, 0, 5)
	choiceFrame.BackgroundTransparency = 1

	local btnBase = Instance.new("TextButton", choiceFrame)
	btnBase.Size = UDim2.new(0.48, 0, 1, 0)
	btnBase.Position = UDim2.new(0, 0, 0, 0)
	btnBase.Text = "Base"
	btnBase.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	btnBase.TextColor3 = Color3.new(1, 1, 1)
	btnBase.Font = Enum.Font.SourceSansBold
	btnBase.TextSize = 11
	Instance.new("UICorner", btnBase).CornerRadius = UDim.new(0, 4)

	local btnMergeChoice = Instance.new("TextButton", choiceFrame)
	btnMergeChoice.Size = UDim2.new(0.48, 0, 1, 0)
	btnMergeChoice.Position = UDim2.new(0.52, 0, 0, 0)
	btnMergeChoice.Text = "Merge"
	btnMergeChoice.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	btnMergeChoice.TextColor3 = Color3.new(1, 1, 1)
	btnMergeChoice.Font = Enum.Font.SourceSansBold
	btnMergeChoice.TextSize = 11
	Instance.new("UICorner", btnMergeChoice).CornerRadius = UDim.new(0, 4)

	-- Liste des propriétés changées
	local changes = getChangedProperties(conflict.scene1Props, conflict.scene2Props)
	local propsHeight = math.min(#changes, 5) * 22

	local propsFrame = Instance.new("Frame", item)
	propsFrame.Size = UDim2.new(1, -10, 0, propsHeight)
	propsFrame.Position = UDim2.new(0, 5, 0, 40)
	propsFrame.BackgroundTransparency = 1

	local propsLayout = Instance.new("UIListLayout", propsFrame)
	propsLayout.Padding = UDim.new(0, 2)

	for i, change in ipairs(changes) do
		if i <= 5 then
			local propLine = Instance.new("TextLabel", propsFrame)
			propLine.Size = UDim2.new(1, 0, 0, 20)
			propLine.BackgroundTransparency = 1
			propLine.TextColor3 = Color3.fromRGB(180, 180, 180)
			propLine.Font = Enum.Font.SourceSans
			propLine.TextSize = 11
			propLine.Text = "  • " .. change.prop .. ": " .. change.base .. " → " .. change.merge
			propLine.TextXAlignment = Enum.TextXAlignment.Left
		end
	end

	if #changes > 5 then
		local moreLabel = Instance.new("TextLabel", propsFrame)
		moreLabel.Size = UDim2.new(1, 0, 0, 20)
		moreLabel.BackgroundTransparency = 1
		moreLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		moreLabel.Font = Enum.Font.SourceSans
		moreLabel.TextSize = 11
		moreLabel.Text = "  ... et " .. (#changes - 5) .. " autres propriétés"
		moreLabel.TextXAlignment = Enum.TextXAlignment.Left
	end

	-- Hauteur totale de l'item
	item.Size = UDim2.new(1, -16, 0, 45 + propsHeight)

	-- Logique des boutons
	local currentChoice = "base" -- Par défaut
	conflictResolutions[conflict.id] = "base"

	local function updateButtons()
		if currentChoice == "base" then
			btnBase.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			btnMergeChoice.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		else
			btnBase.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			btnMergeChoice.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
		end
	end

	btnBase.MouseButton1Click:Connect(function()
		currentChoice = "base"
		conflictResolutions[conflict.id] = "base"
		updateButtons()
	end)

	btnMergeChoice.MouseButton1Click:Connect(function()
		currentChoice = "merge"
		conflictResolutions[conflict.id] = "merge"
		updateButtons()
	end)

	return item
end

-- Fonction pour afficher la popup de conflits
local function showConflictResolver(conflicts, baseScene, mergeScene)
	currentConflicts = conflicts
	conflictResolutions = {}

	-- Vider la liste
	for _, child in ipairs(conflictScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Mettre à jour le header
	conflictHeader.Text = "⚠️ " .. #conflicts .. " conflit(s) - " .. baseScene .. " ← " .. mergeScene

	-- Créer les items
	local totalHeight = 8
	for i, conflict in ipairs(conflicts) do
		local item = createConflictItem(conflict, i)
		item.Parent = conflictScroll
		totalHeight = totalHeight + item.Size.Y.Offset + 8
	end

	conflictScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

	-- Afficher la popup
	conflictWidget.Enabled = true
end

-- Bouton Appliquer le merge
btnApplyMerge.MouseButton1Click:Connect(function()
	if not pendingMergeData then return end

	Log("⏳ Application du merge...", Color3.fromRGB(156, 89, 182))

	local mergeSuccess, mergeResponse = pcall(function()
		return HttpService:PostAsync(
			SERVER_URL .. "/merge-scenes",
			HttpService:JSONEncode({
				baseScene = pendingMergeData.baseScene,
				mergeScene = pendingMergeData.mergeScene,
				conflictResolutions = conflictResolutions,
				outputScene = pendingMergeData.baseScene
			}),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if not mergeSuccess then
		Log("❌ Erreur merge: " .. tostring(mergeResponse), Color3.fromRGB(255,0,0))
		return
	end

	local mergeResult = HttpService:JSONDecode(mergeResponse)

	if mergeResult.success then
		Log("✅ Fusionné! " .. mergeResult.totalObjects .. " objets, " .. (mergeResult.totalScripts or 0) .. " scripts", Color3.fromRGB(100,255,100))
		print("🎉 MERGE TERMINÉ avec résolution de conflits!")

		-- Compter les choix
		local baseCount, mergeCount = 0, 0
		for _, choice in pairs(conflictResolutions) do
			if choice == "base" then baseCount = baseCount + 1
			else mergeCount = mergeCount + 1 end
		end
		print("   Conflits résolus: " .. baseCount .. " base, " .. mergeCount .. " merge")

		-- Sauvegarder le nom de la scène avant reset
		local sceneToReload = pendingMergeData.baseScene

		-- Reset
		mergeSceneSelected = ""
		mergeFromDropdown.Text = "▼ Sélectionner une scène..."
		pendingMergeData = nil
		conflictWidget.Enabled = false

		-- Recharger automatiquement la scène après le merge
		print("🔄 Rechargement automatique de la scène fusionnée...")
		task.wait(0.5)
		performLoad(sceneToReload)
	else
		Log("❌ Erreur lors du merge", Color3.fromRGB(255,0,0))
	end
end)

-- Bouton Annuler
btnCancelMerge.MouseButton1Click:Connect(function()
	pendingMergeData = nil
	conflictWidget.Enabled = false
	Log("❌ Merge annulé", Color3.fromRGB(255, 200, 100))
end)

-- E. MERGE DE SCÈNES (nouvelle interface user-friendly)
btnMerge.MouseButton1Click:Connect(function()
	local baseScene = selectedScene
	local mergeScene = mergeSceneSelected

	if baseScene == "" then
		Log("❌ Sélectionnez une scène de base", Color3.fromRGB(255,50,50))
		return
	end

	if mergeScene == "" then
		Log("❌ Sélectionnez une scène à fusionner", Color3.fromRGB(255,50,50))
		return
	end

	if baseScene == mergeScene then
		Log("❌ Les deux scènes doivent être différentes", Color3.fromRGB(255,50,50))
		return
	end

	Log("⏳ Comparaison...", Color3.fromRGB(156, 89, 182))

	-- 1. Comparer les scènes
	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/compare-scenes?scene1=" .. baseScene .. "&scene2=" .. mergeScene)
	end)

	if not success then
		Log("❌ Erreur: " .. tostring(response), Color3.fromRGB(255,0,0))
		return
	end

	local comparison = HttpService:JSONDecode(response)

	-- Afficher le résumé
	print("═══════════════════════════════════════════")
	print("🔀 MERGE: " .. baseScene .. " ← " .. mergeScene)
	print("═══════════════════════════════════════════")
	print("  📦 Objets à ajouter: " .. #comparison.onlyInScene2)
	print("  ⚠️  Conflits: " .. #comparison.conflicts)
	print("  ✓  Identiques: " .. comparison.identical)

	-- Si des conflits existent, ouvrir la popup de résolution
	if #comparison.conflicts > 0 then
		Log("⚠️ " .. #comparison.conflicts .. " conflit(s) - Résolvez-les", Color3.fromRGB(255, 200, 100))
		pendingMergeData = {
			baseScene = baseScene,
			mergeScene = mergeScene,
			comparison = comparison
		}
		showConflictResolver(comparison.conflicts, baseScene, mergeScene)
		return
	end

	-- Pas de conflits : merger directement
	Log("⏳ Fusion dans '" .. baseScene .. "'...", Color3.fromRGB(156, 89, 182))

	local mergeSuccess, mergeResponse = pcall(function()
		return HttpService:PostAsync(
			SERVER_URL .. "/merge-scenes",
			HttpService:JSONEncode({
				baseScene = baseScene,
				mergeScene = mergeScene,
				conflictResolutions = {},
				outputScene = baseScene
			}),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if not mergeSuccess then
		Log("❌ Erreur merge: " .. tostring(mergeResponse), Color3.fromRGB(255,0,0))
		return
	end

	local mergeResult = HttpService:JSONDecode(mergeResponse)

	if mergeResult.success then
		Log("✅ Fusionné! " .. mergeResult.totalObjects .. " objets, " .. (mergeResult.totalScripts or 0) .. " scripts", Color3.fromRGB(100,255,100))
		print("")
		print("🎉 MERGE TERMINÉ!")
		print("   Scène: " .. baseScene)
		print("   Total: " .. mergeResult.totalObjects .. " objets, " .. (mergeResult.totalScripts or 0) .. " scripts")
		print("   +" .. #comparison.onlyInScene2 .. " nouveaux objets ajoutés")

		mergeSceneSelected = ""
		mergeFromDropdown.Text = "▼ Sélectionner une scène..."

		-- Recharger automatiquement la scène après le merge
		print("🔄 Rechargement automatique de la scène fusionnée...")
		task.wait(0.5)
		performLoad(baseScene)
	else
		Log("❌ Erreur lors du merge", Color3.fromRGB(255,0,0))
	end
end)

----------------------------------------------------------------------------------
-- DOSSIERS PARTAGÉS - Système style Rojo multi-place
-- Permet de partager du code entre plusieurs projets/places
-- Note: Variables regroupées dans SharedUI pour économiser les registres locaux
----------------------------------------------------------------------------------

MakeSeparator(16)
MakeLabel("📁 DOSSIERS PARTAGÉS", 17)

-- Table pour regrouper toutes les variables UI des dossiers partagés (économise ~30 local)
local SharedUI = {}
SharedUI.foldersList = {}

-- Container principal
SharedUI.container = Instance.new("Frame", gui)
SharedUI.container.Size = UDim2.new(0.9, 0, 0, 220)
SharedUI.container.BackgroundColor3 = Color3.fromRGB(45, 50, 55)
SharedUI.container.BorderSizePixel = 0
SharedUI.container.LayoutOrder = 18
Instance.new("UICorner", SharedUI.container).CornerRadius = UDim.new(0, 6)

-- Header
SharedUI.header = Instance.new("Frame", SharedUI.container)
SharedUI.header.Size = UDim2.new(1, 0, 0, 30)
SharedUI.header.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
SharedUI.header.BorderSizePixel = 0
Instance.new("UICorner", SharedUI.header).CornerRadius = UDim.new(0, 6)

SharedUI.headerLabel = Instance.new("TextLabel", SharedUI.header)
SharedUI.headerLabel.Size = UDim2.new(1, -60, 1, 0)
SharedUI.headerLabel.Position = UDim2.new(0, 10, 0, 0)
SharedUI.headerLabel.BackgroundTransparency = 1
SharedUI.headerLabel.TextColor3 = Color3.new(1, 1, 1)
SharedUI.headerLabel.Font = Enum.Font.SourceSansBold
SharedUI.headerLabel.TextSize = 12
SharedUI.headerLabel.Text = "🔗 Dossiers partagés entre places"
SharedUI.headerLabel.TextXAlignment = Enum.TextXAlignment.Left

SharedUI.badge = Instance.new("TextLabel", SharedUI.header)
SharedUI.badge.Size = UDim2.new(0, 50, 0, 20)
SharedUI.badge.Position = UDim2.new(1, -55, 0.5, -10)
SharedUI.badge.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
SharedUI.badge.TextColor3 = Color3.new(1, 1, 1)
SharedUI.badge.Font = Enum.Font.SourceSansBold
SharedUI.badge.TextSize = 10
SharedUI.badge.Text = "0 actif"
Instance.new("UICorner", SharedUI.badge).CornerRadius = UDim.new(0, 10)

-- Liste scroll
SharedUI.scroll = Instance.new("ScrollingFrame", SharedUI.container)
SharedUI.scroll.Size = UDim2.new(1, -10, 0, 110)
SharedUI.scroll.Position = UDim2.new(0, 5, 0, 35)
SharedUI.scroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SharedUI.scroll.BorderSizePixel = 0
SharedUI.scroll.ScrollBarThickness = 4
SharedUI.scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", SharedUI.scroll).CornerRadius = UDim.new(0, 4)
Instance.new("UIListLayout", SharedUI.scroll).Padding = UDim.new(0, 3)

-- Fonction pour rafraîchir la liste
SharedUI.refresh = function()
	for _, child in ipairs(SharedUI.scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/shared-folders/status")
	end)
	
	if not success then
		Log("❌ Erreur récupération dossiers partagés", Color3.fromRGB(255, 100, 100))
		return
	end
	
	local data = HttpService:JSONDecode(response)
	SharedUI.foldersList = data.folders or {}
	
	local activeCount = 0
	for _, folder in ipairs(SharedUI.foldersList) do
		if folder.enabled then activeCount = activeCount + 1 end
	end
	SharedUI.badge.Text = activeCount .. " actif" .. (activeCount > 1 and "s" or "")
	SharedUI.badge.BackgroundColor3 = activeCount > 0 and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(149, 165, 166)
	
	for i, folder in ipairs(SharedUI.foldersList) do
		local f = Instance.new("Frame", SharedUI.scroll)
		f.Size = UDim2.new(1, -6, 0, 32)
		f.BackgroundColor3 = folder.enabled and Color3.fromRGB(50, 70, 50) or Color3.fromRGB(55, 55, 55)
		f.BorderSizePixel = 0
		f.LayoutOrder = i
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
		
		local toggle = Instance.new("TextButton", f)
		toggle.Size, toggle.Position = UDim2.new(0, 24, 0, 24), UDim2.new(0, 4, 0.5, -12)
		toggle.BackgroundColor3 = folder.enabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(100, 100, 100)
		toggle.TextColor3, toggle.Font, toggle.TextSize = Color3.new(1,1,1), Enum.Font.SourceSansBold, 14
		toggle.Text = folder.enabled and "✓" or ""
		Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
		
		toggle.MouseButton1Click:Connect(function()
			pcall(function()
				HttpService:PostAsync(SERVER_URL .. "/shared-folders/" .. folder.name .. "/toggle",
					HttpService:JSONEncode({ enabled = not folder.enabled }), Enum.HttpContentType.ApplicationJson)
			end)
			SharedUI.refresh()
			Log("📁 " .. folder.name .. (folder.enabled and " désactivé" or " activé"), Color3.fromRGB(100, 255, 100))
		end)
		
		local n = Instance.new("TextLabel", f)
		n.Size, n.Position = UDim2.new(0.5, -35, 0.5, 0), UDim2.new(0, 32, 0, 2)
		n.BackgroundTransparency, n.TextColor3 = 1, Color3.new(1, 1, 1)
		n.Font, n.TextSize, n.Text = Enum.Font.SourceSansBold, 11, "📁 " .. folder.name
		n.TextXAlignment = Enum.TextXAlignment.Left
		
		local t = Instance.new("TextLabel", f)
		t.Size, t.Position = UDim2.new(0.5, -35, 0.5, 0), UDim2.new(0, 32, 0.5, 0)
		t.BackgroundTransparency, t.TextColor3 = 1, Color3.fromRGB(150, 150, 150)
		t.Font, t.TextSize, t.Text = Enum.Font.SourceSans, 9, "→ " .. folder.target
		t.TextXAlignment = Enum.TextXAlignment.Left
		
		local s = Instance.new("TextLabel", f)
		s.Size, s.Position = UDim2.new(0, 80, 1, 0), UDim2.new(1, -85, 0, 0)
		s.BackgroundTransparency = 1
		s.TextColor3 = folder.exists and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
		s.Font, s.TextSize = Enum.Font.SourceSans, 10
		s.Text = folder.exists and (folder.scriptCount .. " scripts") or "⚠️ Introuvable"
		s.TextXAlignment = Enum.TextXAlignment.Right
	end
	
	SharedUI.scroll.CanvasSize = UDim2.new(0, 0, 0, #SharedUI.foldersList * 35)
	
	if #SharedUI.foldersList == 0 then
		local e = Instance.new("TextLabel", SharedUI.scroll)
		e.Size, e.BackgroundTransparency = UDim2.new(1, 0, 0, 40), 1
		e.TextColor3, e.Font, e.TextSize = Color3.fromRGB(120, 120, 120), Enum.Font.SourceSansItalic, 11
		e.Text = "Aucun dossier partagé configuré"
	end
end

-- Boutons d'action
SharedUI.buttonsFrame = Instance.new("Frame", SharedUI.container)
SharedUI.buttonsFrame.Size = UDim2.new(1, -10, 0, 35)
SharedUI.buttonsFrame.Position = UDim2.new(0, 5, 0, 150)
SharedUI.buttonsFrame.BackgroundTransparency = 1

SharedUI.btnRefresh = Instance.new("TextButton", SharedUI.buttonsFrame)
SharedUI.btnRefresh.Size, SharedUI.btnRefresh.Position = UDim2.new(0.32, -2, 1, 0), UDim2.new(0, 0, 0, 0)
SharedUI.btnRefresh.Text, SharedUI.btnRefresh.BackgroundColor3 = "🔄 Rafraîchir", Color3.fromRGB(52, 152, 219)
SharedUI.btnRefresh.TextColor3, SharedUI.btnRefresh.Font, SharedUI.btnRefresh.TextSize = Color3.new(1,1,1), Enum.Font.SourceSansBold, 11
Instance.new("UICorner", SharedUI.btnRefresh).CornerRadius = UDim.new(0, 6)
SharedUI.btnRefresh.MouseButton1Click:Connect(function() SharedUI.refresh() end)

SharedUI.btnImport = Instance.new("TextButton", SharedUI.buttonsFrame)
SharedUI.btnImport.Size, SharedUI.btnImport.Position = UDim2.new(0.32, -2, 1, 0), UDim2.new(0.34, 0, 0, 0)
SharedUI.btnImport.Text, SharedUI.btnImport.BackgroundColor3 = "📥 Importer", Color3.fromRGB(46, 204, 113)
SharedUI.btnImport.TextColor3, SharedUI.btnImport.Font, SharedUI.btnImport.TextSize = Color3.new(1,1,1), Enum.Font.SourceSansBold, 11
Instance.new("UICorner", SharedUI.btnImport).CornerRadius = UDim.new(0, 6)

SharedUI.btnImport.MouseButton1Click:Connect(function()
	Log("📥 Importation des scripts partagés...", Color3.fromRGB(100, 200, 255))
	local success, response = pcall(function() return HttpService:GetAsync(SERVER_URL .. "/shared-folders/scripts") end)
	if not success then Log("❌ Erreur récupération scripts", Color3.fromRGB(255, 100, 100)) return end
	
	local data = HttpService:JSONDecode(response)
	local importedCount = 0
	
	for _, script in ipairs(data.scripts or {}) do
		local parts = string.split(script.path, "/")
		local parent = nil
		for _, service in ipairs(SERVICES_TO_SYNC) do
			if service.Name == parts[1] then parent = service break end
		end
		if parent then
			for i = 2, #parts - 1 do
				local folder = parent:FindFirstChild(parts[i])
				if not folder then folder = Instance.new("Folder") folder.Name = parts[i] folder.Parent = parent end
				parent = folder
			end
			local scriptName = parts[#parts]:gsub("%.lua$", "")
			local existing = parent:FindFirstChild(scriptName)
			if existing then existing.Source = script.content
			else
				local new = Instance.new(script.className or "ModuleScript")
				new.Name, new.Source, new.Parent = scriptName, script.content, parent
			end
			importedCount = importedCount + 1
		end
	end
	ChangeHistoryService:SetWaypoint("Import scripts partagés")
	Log("✅ " .. importedCount .. " scripts partagés importés", Color3.fromRGB(100, 255, 100))
end)

SharedUI.btnConfig = Instance.new("TextButton", SharedUI.buttonsFrame)
SharedUI.btnConfig.Size, SharedUI.btnConfig.Position = UDim2.new(0.32, -2, 1, 0), UDim2.new(0.68, 0, 0, 0)
SharedUI.btnConfig.Text, SharedUI.btnConfig.BackgroundColor3 = "⚙️ Configurer", Color3.fromRGB(155, 89, 182)
SharedUI.btnConfig.TextColor3, SharedUI.btnConfig.Font, SharedUI.btnConfig.TextSize = Color3.new(1,1,1), Enum.Font.SourceSansBold, 11
Instance.new("UICorner", SharedUI.btnConfig).CornerRadius = UDim.new(0, 6)

-- Widget de configuration
SharedUI.configWidget = plugin:CreateDockWidgetPluginGui("SharedFoldersConfigUI",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 450, 400, 400, 350))
SharedUI.configWidget.Title = "⚙️ Configuration des Dossiers Partagés"

SharedUI.configGui = Instance.new("Frame", SharedUI.configWidget)
SharedUI.configGui.Size, SharedUI.configGui.BackgroundColor3 = UDim2.fromScale(1, 1), Color3.fromRGB(35, 35, 35)
Instance.new("UIListLayout", SharedUI.configGui).Padding = UDim.new(0, 8)
Instance.new("UIPadding", SharedUI.configGui).PaddingTop = UDim.new(0, 10)

-- Titre config
do
	local title = Instance.new("TextLabel", SharedUI.configGui)
	title.Size, title.BackgroundTransparency = UDim2.new(1, 0, 0, 30), 1
	title.TextColor3, title.Font, title.TextSize = Color3.new(1, 1, 1), Enum.Font.SourceSansBold, 16
	title.Text, title.LayoutOrder = "📁 Ajouter un dossier partagé", 1
end

-- Input nom
SharedUI.nameFrame = Instance.new("Frame", SharedUI.configGui)
SharedUI.nameFrame.Size, SharedUI.nameFrame.BackgroundTransparency, SharedUI.nameFrame.LayoutOrder = UDim2.new(0.9, 0, 0, 50), 1, 2
do
	local lbl = Instance.new("TextLabel", SharedUI.nameFrame)
	lbl.Size, lbl.BackgroundTransparency = UDim2.new(1, 0, 0, 18), 1
	lbl.TextColor3, lbl.Font, lbl.TextSize = Color3.fromRGB(180, 180, 180), Enum.Font.SourceSans, 12
	lbl.Text, lbl.TextXAlignment = "Nom du dossier :", Enum.TextXAlignment.Left
end
SharedUI.nameInput = Instance.new("TextBox", SharedUI.nameFrame)
SharedUI.nameInput.Size, SharedUI.nameInput.Position = UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 20)
SharedUI.nameInput.BackgroundColor3, SharedUI.nameInput.TextColor3 = Color3.fromRGB(50, 50, 50), Color3.new(1, 1, 1)
SharedUI.nameInput.PlaceholderText, SharedUI.nameInput.Font, SharedUI.nameInput.TextSize = "Ex: SharedModules", Enum.Font.SourceSans, 14
SharedUI.nameInput.Text = ""
Instance.new("UICorner", SharedUI.nameInput).CornerRadius = UDim.new(0, 4)

-- Input path
SharedUI.pathFrame = Instance.new("Frame", SharedUI.configGui)
SharedUI.pathFrame.Size, SharedUI.pathFrame.BackgroundTransparency, SharedUI.pathFrame.LayoutOrder = UDim2.new(0.9, 0, 0, 50), 1, 3
do
	local lbl = Instance.new("TextLabel", SharedUI.pathFrame)
	lbl.Size, lbl.BackgroundTransparency = UDim2.new(1, 0, 0, 18), 1
	lbl.TextColor3, lbl.Font, lbl.TextSize = Color3.fromRGB(180, 180, 180), Enum.Font.SourceSans, 12
	lbl.Text, lbl.TextXAlignment = "Chemin source (relatif) :", Enum.TextXAlignment.Left
end
SharedUI.pathInput = Instance.new("TextBox", SharedUI.pathFrame)
SharedUI.pathInput.Size, SharedUI.pathInput.Position = UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 20)
SharedUI.pathInput.BackgroundColor3, SharedUI.pathInput.TextColor3 = Color3.fromRGB(50, 50, 50), Color3.new(1, 1, 1)
SharedUI.pathInput.PlaceholderText, SharedUI.pathInput.Font, SharedUI.pathInput.TextSize = "Ex: ../shared_code/Modules", Enum.Font.SourceSans, 14
SharedUI.pathInput.Text = ""
Instance.new("UICorner", SharedUI.pathInput).CornerRadius = UDim.new(0, 4)

-- Input target
SharedUI.targetFrame = Instance.new("Frame", SharedUI.configGui)
SharedUI.targetFrame.Size, SharedUI.targetFrame.BackgroundTransparency, SharedUI.targetFrame.LayoutOrder = UDim2.new(0.9, 0, 0, 50), 1, 4
do
	local lbl = Instance.new("TextLabel", SharedUI.targetFrame)
	lbl.Size, lbl.BackgroundTransparency = UDim2.new(1, 0, 0, 18), 1
	lbl.TextColor3, lbl.Font, lbl.TextSize = Color3.fromRGB(180, 180, 180), Enum.Font.SourceSans, 12
	lbl.Text, lbl.TextXAlignment = "Chemin cible dans Roblox :", Enum.TextXAlignment.Left
end
SharedUI.targetInput = Instance.new("TextBox", SharedUI.targetFrame)
SharedUI.targetInput.Size, SharedUI.targetInput.Position = UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 20)
SharedUI.targetInput.BackgroundColor3, SharedUI.targetInput.TextColor3 = Color3.fromRGB(50, 50, 50), Color3.new(1, 1, 1)
SharedUI.targetInput.PlaceholderText, SharedUI.targetInput.Font, SharedUI.targetInput.TextSize = "Ex: ReplicatedStorage/Shared", Enum.Font.SourceSans, 14
SharedUI.targetInput.Text = ""
Instance.new("UICorner", SharedUI.targetInput).CornerRadius = UDim.new(0, 4)

-- Bouton ajouter
SharedUI.btnAdd = Instance.new("TextButton", SharedUI.configGui)
SharedUI.btnAdd.Size, SharedUI.btnAdd.BackgroundColor3 = UDim2.new(0.9, 0, 0, 40), Color3.fromRGB(46, 204, 113)
SharedUI.btnAdd.TextColor3, SharedUI.btnAdd.Font, SharedUI.btnAdd.TextSize = Color3.new(1, 1, 1), Enum.Font.SourceSansBold, 14
SharedUI.btnAdd.Text, SharedUI.btnAdd.LayoutOrder = "➕ Ajouter le dossier partagé", 5
Instance.new("UICorner", SharedUI.btnAdd).CornerRadius = UDim.new(0, 6)

SharedUI.btnAdd.MouseButton1Click:Connect(function()
	local n, p, t = SharedUI.nameInput.Text, SharedUI.pathInput.Text, SharedUI.targetInput.Text
	if n == "" or p == "" or t == "" then Log("❌ Remplir tous les champs", Color3.fromRGB(255, 100, 100)) return end
	
	local success, response = pcall(function()
		return HttpService:PostAsync(SERVER_URL .. "/shared-folders/add",
			HttpService:JSONEncode({name = n, path = p, target = t, description = ""}),
			Enum.HttpContentType.ApplicationJson)
	end)
	
	if success then
		local result = HttpService:JSONDecode(response)
		if result.success then
			Log("✅ Dossier partagé ajouté: " .. n, Color3.fromRGB(100, 255, 100))
			SharedUI.nameInput.Text, SharedUI.pathInput.Text, SharedUI.targetInput.Text = "", "", ""
			SharedUI.refresh()
		else Log("❌ " .. (result.error or "Erreur"), Color3.fromRGB(255, 100, 100)) end
	else Log("❌ Erreur serveur", Color3.fromRGB(255, 100, 100)) end
end)

-- Séparateur et info
do
	local sep = Instance.new("Frame", SharedUI.configGui)
	sep.Size, sep.BackgroundColor3, sep.BorderSizePixel, sep.LayoutOrder = UDim2.new(0.9, 0, 0, 1), Color3.fromRGB(60, 60, 60), 0, 6
	
	local info = Instance.new("TextLabel", SharedUI.configGui)
	info.Size, info.BackgroundColor3 = UDim2.new(0.9, 0, 0, 80), Color3.fromRGB(40, 50, 60)
	info.TextColor3, info.Font, info.TextSize = Color3.fromRGB(180, 200, 220), Enum.Font.SourceSans, 11
	info.Text = "💡 Structure recommandée :\n\n/MonProjet           (projet actuel)\n/shared_code         (code partagé)\n  └── /Modules       (modules communs)\n/AutreProjet         (autre place)"
	info.TextWrapped, info.TextXAlignment, info.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	info.LayoutOrder = 7
	Instance.new("UICorner", info).CornerRadius = UDim.new(0, 6)
	Instance.new("UIPadding", info).PaddingLeft = UDim.new(0, 8)
end

SharedUI.btnConfig.MouseButton1Click:Connect(function() SharedUI.configWidget.Enabled = true end)

-- Info en bas
do
	local infoLbl = Instance.new("TextLabel", SharedUI.container)
	infoLbl.Size, infoLbl.Position = UDim2.new(1, -10, 0, 25), UDim2.new(0, 5, 1, -30)
	infoLbl.BackgroundTransparency = 1
	infoLbl.TextColor3, infoLbl.Font, infoLbl.TextSize = Color3.fromRGB(120, 140, 160), Enum.Font.SourceSansItalic, 10
	infoLbl.Text, infoLbl.TextXAlignment = "💡 Modifiez shared_folders.json pour la config avancée", Enum.TextXAlignment.Center
end

-- Rafraîchir au démarrage
task.spawn(function() task.wait(1) SharedUI.refresh() end)

----------------------------------------------------------------------------------
-- SCRIPT CONFLICT DETECTION - Détection des conflits de scripts entre scènes
-- Comme Unity/Unreal : chaque scène a ses propres scripts isolés
----------------------------------------------------------------------------------

-- UI pour la détection de conflits de scripts
MakeSeparator(19)
MakeLabel("🔍 CONFLITS SCRIPTS", 20)

-- Container pour les conflits
local conflictDetectionContainer = Instance.new("Frame", gui)
conflictDetectionContainer.Size = UDim2.new(0.9, 0, 0, 180)
conflictDetectionContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
conflictDetectionContainer.BorderSizePixel = 0
conflictDetectionContainer.LayoutOrder = 21
Instance.new("UICorner", conflictDetectionContainer).CornerRadius = UDim.new(0, 6)

-- Bouton pour vérifier les changements (Roblox vs Disque)
local btnCheckChanges = Instance.new("TextButton", conflictDetectionContainer)
btnCheckChanges.Size = UDim2.new(0.48, -3, 0, 35)
btnCheckChanges.Position = UDim2.new(0, 5, 0, 5)
btnCheckChanges.Text = "Verifier sync"
btnCheckChanges.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
btnCheckChanges.TextColor3 = Color3.new(1, 1, 1)
btnCheckChanges.Font = Enum.Font.SourceSansBold
btnCheckChanges.TextSize = 12
Instance.new("UICorner", btnCheckChanges).CornerRadius = UDim.new(0, 6)

-- Bouton pour scanner les conflits entre scènes (ancien système)
local btnScanConflicts = Instance.new("TextButton", conflictDetectionContainer)
btnScanConflicts.Size = UDim2.new(0.48, -3, 0, 35)
btnScanConflicts.Position = UDim2.new(0.52, 0, 0, 5)
btnScanConflicts.Text = "🔍 Scanner scènes"
btnScanConflicts.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
btnScanConflicts.TextColor3 = Color3.new(1, 1, 1)
btnScanConflicts.Font = Enum.Font.SourceSansBold
btnScanConflicts.TextSize = 12
Instance.new("UICorner", btnScanConflicts).CornerRadius = UDim.new(0, 6)

-- Label de résultat
local conflictResultLabel = Instance.new("TextLabel", conflictDetectionContainer)
conflictResultLabel.Size = UDim2.new(1, -10, 0, 25)
conflictResultLabel.Position = UDim2.new(0, 5, 0, 45)
conflictResultLabel.BackgroundTransparency = 1
conflictResultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
conflictResultLabel.Font = Enum.Font.SourceSans
conflictResultLabel.TextSize = 12
conflictResultLabel.Text = "Cliquez pour scanner..."
conflictResultLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Liste scrollable des conflits détectés
local conflictListScroll = Instance.new("ScrollingFrame", conflictDetectionContainer)
conflictListScroll.Size = UDim2.new(1, -10, 0, 100)
conflictListScroll.Position = UDim2.new(0, 5, 0, 75)
conflictListScroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
conflictListScroll.BorderSizePixel = 0
conflictListScroll.ScrollBarThickness = 4
conflictListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", conflictListScroll).CornerRadius = UDim.new(0, 4)

local conflictListLayout = Instance.new("UIListLayout", conflictListScroll)
conflictListLayout.Padding = UDim.new(0, 2)

local conflictListPadding = Instance.new("UIPadding", conflictListScroll)
conflictListPadding.PaddingTop = UDim.new(0, 4)
conflictListPadding.PaddingLeft = UDim.new(0, 4)
conflictListPadding.PaddingRight = UDim.new(0, 4)

-- Stockage des conflits détectés
local detectedScriptConflicts = {}

-- Fonction pour créer un item de conflit dans la liste
local function createScriptConflictItem(conflict, index)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, -8, 0, 45)
	item.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
	item.BorderSizePixel = 0
	item.LayoutOrder = index
	Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

	-- Nom du script
	local scriptNameLabel = Instance.new("TextLabel", item)
	scriptNameLabel.Size = UDim2.new(1, -10, 0, 18)
	scriptNameLabel.Position = UDim2.new(0, 5, 0, 2)
	scriptNameLabel.BackgroundTransparency = 1
	scriptNameLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
	scriptNameLabel.Font = Enum.Font.SourceSansBold
	scriptNameLabel.TextSize = 11
	scriptNameLabel.Text = "📜 " .. conflict.scriptPath
	scriptNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	scriptNameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	-- Scènes concernées
	local scenesLabel = Instance.new("TextLabel", item)
	scenesLabel.Size = UDim2.new(1, -10, 0, 12)
	scenesLabel.Position = UDim2.new(0, 5, 0, 18)
	scenesLabel.BackgroundTransparency = 1
	scenesLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	scenesLabel.Font = Enum.Font.SourceSans
	scenesLabel.TextSize = 10
	scenesLabel.Text = "Scènes: " .. table.concat(conflict.scenes, ", ")
	scenesLabel.TextXAlignment = Enum.TextXAlignment.Left
	scenesLabel.TextTruncate = Enum.TextTruncate.AtEnd

	-- Nombre de versions
	local versionsLabel = Instance.new("TextLabel", item)
	versionsLabel.Size = UDim2.new(1, -10, 0, 12)
	versionsLabel.Position = UDim2.new(0, 5, 0, 30)
	versionsLabel.BackgroundTransparency = 1
	versionsLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	versionsLabel.Font = Enum.Font.SourceSans
	versionsLabel.TextSize = 10
	versionsLabel.Text = "⚠️ " .. conflict.versions .. " versions différentes"
	versionsLabel.TextXAlignment = Enum.TextXAlignment.Left

	return item
end

-- Fonction pour scanner les conflits de scripts entre toutes les scènes
local function scanScriptConflicts()
	Log("⏳ Analyse des conflits...", Color3.fromRGB(231, 76, 60))
	conflictResultLabel.Text = "Analyse en cours..."
	conflictResultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

	-- Vider la liste actuelle
	for _, child in ipairs(conflictListScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Appeler l'API de détection de conflits
	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/detect-all-script-conflicts")
	end)

	if not success then
		Log("❌ Erreur connexion serveur", Color3.fromRGB(255, 100, 100))
		conflictResultLabel.Text = "❌ Erreur serveur"
		conflictResultLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end

	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not decodeSuccess then
		Log("❌ Erreur décodage", Color3.fromRGB(255, 100, 100))
		conflictResultLabel.Text = "❌ Erreur décodage"
		conflictResultLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end

	detectedScriptConflicts = data.conflicts or {}

	-- Afficher le résultat
	if #detectedScriptConflicts == 0 then
		Log("✅ Aucun conflit de script détecté!", Color3.fromRGB(100, 255, 100))
		conflictResultLabel.Text = "✅ Aucun conflit! (" .. data.totalScripts .. " scripts, " .. #data.scenes .. " scènes)"
		conflictResultLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

		-- Afficher un message positif
		local noConflictItem = Instance.new("TextLabel", conflictListScroll)
		noConflictItem.Size = UDim2.new(1, -8, 0, 40)
		noConflictItem.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
		noConflictItem.TextColor3 = Color3.fromRGB(100, 255, 100)
		noConflictItem.Font = Enum.Font.SourceSans
		noConflictItem.TextSize = 12
		noConflictItem.Text = "🎉 Tous vos scripts sont cohérents\nentre les différentes scènes!"
		noConflictItem.TextWrapped = true
		Instance.new("UICorner", noConflictItem).CornerRadius = UDim.new(0, 4)

		conflictListScroll.CanvasSize = UDim2.new(0, 0, 0, 50)
	else
		Log("⚠️ " .. #detectedScriptConflicts .. " conflit(s) détecté(s)!", Color3.fromRGB(255, 200, 100))
		conflictResultLabel.Text = "⚠️ " .. #detectedScriptConflicts .. " conflit(s) sur " .. data.totalScripts .. " scripts"
		conflictResultLabel.TextColor3 = Color3.fromRGB(255, 200, 100)

		-- Créer les items de conflit
		local totalHeight = 8
		for i, conflict in ipairs(detectedScriptConflicts) do
			local item = createScriptConflictItem(conflict, i)
			item.Parent = conflictListScroll
			totalHeight = totalHeight + 47
		end

		conflictListScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

		-- Afficher les détails dans la console
		print("═══════════════════════════════════════════")
		print("🔍 CONFLITS DE SCRIPTS DÉTECTÉS")
		print("═══════════════════════════════════════════")
		for i, conflict in ipairs(detectedScriptConflicts) do
			print("")
			print("⚠️ Conflit #" .. i .. ": " .. conflict.scriptPath)
			print("   Scènes concernées: " .. table.concat(conflict.scenes, ", "))
			print("   Versions différentes: " .. conflict.versions)
			if conflict.details then
				for _, detail in ipairs(conflict.details) do
					print("   📄 " .. detail.scene .. ": " .. detail.lines .. " lignes")
				end
			end
		end
		print("═══════════════════════════════════════════")
		print("💡 CONSEIL: Utilisez des noms de scripts uniques par scène")
		print("   ou synchronisez les scripts entre les scènes.")
		print("═══════════════════════════════════════════")
	end
end

-- Connecter le bouton de scan des scènes
btnScanConflicts.MouseButton1Click:Connect(scanScriptConflicts)

-- Fonction pour vérifier les changements entre Roblox et le disque
local function checkLocalVsDiskChanges()
	Log("⏳ Comparaison Roblox ↔ Disque...", Color3.fromRGB(52, 152, 219))
	conflictResultLabel.Text = "Comparaison en cours..."
	conflictResultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

	-- Vider la liste actuelle
	for _, child in ipairs(conflictListScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	-- Collecter les scripts locaux (dans Roblox)
	local localScripts = {}
	local function collectLocal(obj, currentPath)
		local myPath = currentPath
		if obj.Parent == game then 
			myPath = obj.Name 
		else 
			myPath = currentPath .. "/" .. obj.Name 
		end

		if obj:IsA("LuaSourceContainer") then
			local s, source = pcall(function() return obj.Source end)
			if s then
				localScripts[myPath .. ".lua"] = source
			end
		end
		for _, child in ipairs(obj:GetChildren()) do 
			collectLocal(child, myPath) 
		end
	end

	for _, service in ipairs(SERVICES_TO_SYNC) do 
		collectLocal(service, "") 
	end

	-- Récupérer les scripts du disque
	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/get-global-scripts")
	end)

	if not success then
		Log("❌ Erreur connexion serveur", Color3.fromRGB(255, 100, 100))
		conflictResultLabel.Text = "❌ Erreur serveur"
		return
	end

	local diskData = HttpService:JSONDecode(response)
	local diskScripts = {}
	for _, script in ipairs(diskData.scripts or {}) do
		diskScripts[script.path] = script.source
	end

	-- Comparer
	local modifiedLocally = {}  -- Scripts modifiés dans Roblox
	local modifiedOnDisk = {}   -- Scripts modifiés sur le disque
	local onlyLocal = {}        -- Scripts uniquement dans Roblox
	local onlyDisk = {}         -- Scripts uniquement sur le disque

	for path, localSource in pairs(localScripts) do
		if diskScripts[path] then
			if localSource ~= diskScripts[path] then
				table.insert(modifiedLocally, path)
			end
		else
			table.insert(onlyLocal, path)
		end
	end

	for path, _ in pairs(diskScripts) do
		if not localScripts[path] then
			table.insert(onlyDisk, path)
		end
	end

	-- Afficher les résultats
	local totalChanges = #modifiedLocally + #onlyLocal + #onlyDisk

	if totalChanges == 0 then
		Log("✅ Tout est synchronisé!", Color3.fromRGB(100, 255, 100))
		conflictResultLabel.Text = "✅ Roblox et Disque sont synchronisés"
		conflictResultLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

		local syncItem = Instance.new("TextLabel", conflictListScroll)
		syncItem.Size = UDim2.new(1, -8, 0, 40)
		syncItem.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
		syncItem.TextColor3 = Color3.fromRGB(100, 255, 100)
		syncItem.Font = Enum.Font.SourceSans
		syncItem.TextSize = 12
		syncItem.Text = "🎉 Tous les scripts sont identiques\nentre Roblox et le disque!"
		syncItem.TextWrapped = true
		Instance.new("UICorner", syncItem).CornerRadius = UDim.new(0, 4)
		conflictListScroll.CanvasSize = UDim2.new(0, 0, 0, 50)
	else
		Log("⚠️ " .. totalChanges .. " différence(s) détectée(s)", Color3.fromRGB(255, 200, 100))
		conflictResultLabel.Text = "⚠️ " .. #modifiedLocally .. " modifié(s), " .. #onlyLocal .. " nouveau(x), " .. #onlyDisk .. " sur disque"
		conflictResultLabel.TextColor3 = Color3.fromRGB(255, 200, 100)

		local totalHeight = 8

		-- Scripts modifiés
		for _, path in ipairs(modifiedLocally) do
			local item = Instance.new("Frame", conflictListScroll)
			item.Size = UDim2.new(1, -8, 0, 25)
			item.BackgroundColor3 = Color3.fromRGB(60, 60, 40)
			Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

			local label = Instance.new("TextLabel", item)
			label.Size = UDim2.new(1, -10, 1, 0)
			label.Position = UDim2.new(0, 5, 0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 200, 100)
			label.Font = Enum.Font.SourceSans
			label.TextSize = 10
			label.Text = "📝 " .. path
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextTruncate = Enum.TextTruncate.AtEnd

			totalHeight = totalHeight + 27
		end

		-- Scripts uniquement locaux
		for _, path in ipairs(onlyLocal) do
			local item = Instance.new("Frame", conflictListScroll)
			item.Size = UDim2.new(1, -8, 0, 25)
			item.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
			Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

			local label = Instance.new("TextLabel", item)
			label.Size = UDim2.new(1, -10, 1, 0)
			label.Position = UDim2.new(0, 5, 0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(100, 255, 100)
			label.Font = Enum.Font.SourceSans
			label.TextSize = 10
			label.Text = "➕ " .. path .. " (nouveau)"
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextTruncate = Enum.TextTruncate.AtEnd

			totalHeight = totalHeight + 27
		end

		-- Scripts uniquement sur disque
		for _, path in ipairs(onlyDisk) do
			local item = Instance.new("Frame", conflictListScroll)
			item.Size = UDim2.new(1, -8, 0, 25)
			item.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
			Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

			local label = Instance.new("TextLabel", item)
			label.Size = UDim2.new(1, -10, 1, 0)
			label.Position = UDim2.new(0, 5, 0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 150, 150)
			label.Font = Enum.Font.SourceSans
			label.TextSize = 10
			label.Text = "💾 " .. path .. " (sur disque)"
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextTruncate = Enum.TextTruncate.AtEnd

			totalHeight = totalHeight + 27
		end

		conflictListScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

		-- Afficher dans la console
		print("═══════════════════════════════════════════")
		print("🔄 COMPARAISON ROBLOX ↔ DISQUE")
		print("═══════════════════════════════════════════")
		if #modifiedLocally > 0 then
			print("📝 Scripts modifiés dans Roblox:")
			for _, p in ipairs(modifiedLocally) do print("   " .. p) end
		end
		if #onlyLocal > 0 then
			print("➕ Scripts uniquement dans Roblox:")
			for _, p in ipairs(onlyLocal) do print("   " .. p) end
		end
		if #onlyDisk > 0 then
			print("💾 Scripts uniquement sur le disque:")
			for _, p in ipairs(onlyDisk) do print("   " .. p) end
		end
		print("═══════════════════════════════════════════")
	end
end

-- Connecter le bouton de vérification
btnCheckChanges.MouseButton1Click:Connect(checkLocalVsDiskChanges)

-- Bouton pour comparer deux scènes spécifiques
local btnCompareScenes = Instance.new("TextButton", gui)
btnCompareScenes.Size = UDim2.new(0.9, 0, 0, 30)
btnCompareScenes.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
btnCompareScenes.TextColor3 = Color3.new(1, 1, 1)
btnCompareScenes.Font = Enum.Font.SourceSans
btnCompareScenes.TextSize = 12
btnCompareScenes.Text = "📊 Comparer scripts: " .. (selectedScene ~= "" and selectedScene or "?") .. " vs " .. (mergeSceneSelected ~= "" and mergeSceneSelected or "?")
btnCompareScenes.LayoutOrder = 22
Instance.new("UICorner", btnCompareScenes).CornerRadius = UDim.new(0, 6)

-- Mettre à jour le texte du bouton quand les scènes changent
local function updateCompareButtonText()
	local scene1 = selectedScene ~= "" and selectedScene or "?"
	local scene2 = mergeSceneSelected ~= "" and mergeSceneSelected or "?"
	btnCompareScenes.Text = "📊 Comparer scripts: " .. scene1 .. " vs " .. scene2
end

-- Fonction pour comparer les scripts de deux scènes
btnCompareScenes.MouseButton1Click:Connect(function()
	if selectedScene == "" or mergeSceneSelected == "" then
		Log("❌ Sélectionnez deux scènes à comparer", Color3.fromRGB(255, 100, 100))
		return
	end

	if selectedScene == mergeSceneSelected then
		Log("❌ Choisissez deux scènes différentes", Color3.fromRGB(255, 100, 100))
		return
	end

	Log("⏳ Comparaison des scripts...", Color3.fromRGB(52, 152, 219))

	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/compare-scripts?scene1=" .. HttpService:UrlEncode(selectedScene) .. "&scene2=" .. HttpService:UrlEncode(mergeSceneSelected))
	end)

	if not success then
		Log("❌ Erreur: " .. tostring(response), Color3.fromRGB(255, 100, 100))
		return
	end

	local data = HttpService:JSONDecode(response)

	-- Afficher le résultat dans la console
	print("═══════════════════════════════════════════")
	print("📊 COMPARAISON SCRIPTS: " .. selectedScene .. " vs " .. mergeSceneSelected)
	print("═══════════════════════════════════════════")
	print("📁 Scripts dans " .. selectedScene .. ": " .. data.summary.scene1Total)
	print("📁 Scripts dans " .. mergeSceneSelected .. ": " .. data.summary.scene2Total)
	print("")
	print("📌 Uniquement dans " .. selectedScene .. ": " .. data.summary.onlyInScene1)
	if #data.onlyInScene1 > 0 then
		for _, path in ipairs(data.onlyInScene1) do
			print("   📜 " .. path)
		end
	end
	print("")
	print("📌 Uniquement dans " .. mergeSceneSelected .. ": " .. data.summary.onlyInScene2)
	if #data.onlyInScene2 > 0 then
		for _, path in ipairs(data.onlyInScene2) do
			print("   📜 " .. path)
		end
	end
	print("")
	print("⚠️ Conflits (même chemin, contenu différent): " .. data.summary.conflicts)
	if #data.conflicts > 0 then
		for _, conflict in ipairs(data.conflicts) do
			print("   ⚠️ " .. conflict.path)
			print("      " .. selectedScene .. ": " .. conflict.linesScene1 .. " lignes")
			print("      " .. mergeSceneSelected .. ": " .. conflict.linesScene2 .. " lignes")
			if conflict.diffs and #conflict.diffs > 0 then
				print("      Différences:")
				for _, diff in ipairs(conflict.diffs) do
					print("         L" .. diff.line .. ": '" .. tostring(diff.scene1):sub(1, 30) .. "' → '" .. tostring(diff.scene2):sub(1, 30) .. "'")
				end
			end
		end
	end
	print("")
	print("✅ Scripts identiques: " .. data.summary.identical)
	print("═══════════════════════════════════════════")

	-- Message de résumé
	if data.summary.conflicts > 0 then
		Log("⚠️ " .. data.summary.conflicts .. " conflit(s) de scripts!", Color3.fromRGB(255, 200, 100))
	else
		Log("✅ Pas de conflit de scripts", Color3.fromRGB(100, 255, 100))
	end
end)

MakeSeparator(23)

----------------------------------------------------------------------------------
-- HOT RELOAD - Auto-sync des scripts depuis l'éditeur
----------------------------------------------------------------------------------

local hotReloadEnabled = false
local hotReloadInterval = 2 -- Vérifier toutes les 2 secondes

-- Créer un toggle pour activer/désactiver l'auto-sync (IDE → Roblox)
local hotReloadBtn = Instance.new("TextButton", gui)
hotReloadBtn.Size = UDim2.new(1, -20, 0, 40)
hotReloadBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
hotReloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hotReloadBtn.Font = Enum.Font.SourceSansBold
hotReloadBtn.TextSize = 14
hotReloadBtn.Text = "🔄 Auto-Sync: OFF"
hotReloadBtn.BorderSizePixel = 0
hotReloadBtn.LayoutOrder = 24
local hotReloadCorner = Instance.new("UICorner", hotReloadBtn)
hotReloadCorner.CornerRadius = UDim.new(0, 6)

-- Indicateur de statut de l'auto-sync
local statusLabel = Instance.new("TextLabel", gui)
statusLabel.Size = UDim2.new(1, -20, 0, 60)
statusLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 12
statusLabel.Text = "💡 Activez Auto-Sync pour créer\ndes scripts depuis votre IDE"
statusLabel.TextWrapped = true
statusLabel.BorderSizePixel = 0
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.LayoutOrder = 25
local statusCorner = Instance.new("UICorner", statusLabel)
statusCorner.CornerRadius = UDim.new(0, 6)
local statusPadding = Instance.new("UIPadding", statusLabel)
statusPadding.PaddingTop = UDim.new(0, 5)
statusPadding.PaddingLeft = UDim.new(0, 5)
statusPadding.PaddingRight = UDim.new(0, 5)

-- Fonction pour synchroniser un script depuis le serveur
local function syncScriptFromServer(scriptPath, scriptObj)
	print("🔍 Vérification:", scriptPath)

	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/get-script?path=" .. HttpService:UrlEncode(scriptPath))
	end)

	if not success then
		warn("❌ Erreur HTTP pour", scriptPath, ":", response)
		return false, scriptObj
	end

	if not response then
		warn("❌ Pas de réponse pour", scriptPath)
		return false, scriptObj
	end

	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not decodeSuccess then
		warn("❌ Erreur décodage JSON pour", scriptPath, ":", data)
		return false, scriptObj
	end

	if not data.content then
		warn("❌ Pas de contenu pour", scriptPath)
		return false, scriptObj
	end

	-- Vérifier si le contenu a changé
	if data.content == scriptObj.Source then
		-- Pas de changement
		return false, scriptObj
	end

	print("✨ Changement détecté pour:", scriptPath)
	print("   Ancien:", string.sub(scriptObj.Source, 1, 50) .. "...")
	print("   Nouveau:", string.sub(data.content, 1, 50) .. "...")

	-- Comme Rojo : on remplace complètement le script
	local parent = scriptObj.Parent
	local name = scriptObj.Name
	local className = scriptObj.ClassName

	-- Sauvegarder les propriétés importantes
	local properties = {
		Disabled = scriptObj.Disabled or false
	}

	-- Détruire l'ancien script
	scriptObj:Destroy()

	-- Créer un nouveau script avec le nouveau code
	local newScript = Instance.new(className)
	newScript.Name = name
	newScript.Source = data.content
	newScript.Disabled = properties.Disabled
	newScript.Parent = parent

	print("✅ Script rechargé:", scriptPath)
	return true, newScript
end

-- Créer un index de tous les scripts pour un accès rapide
local scriptIndex = {}

local function rebuildScriptIndex()
	scriptIndex = {}

	local function indexScripts(obj, currentPath)
		local myPath = currentPath
		if obj.Parent == game then 
			myPath = obj.Name 
		else 
			myPath = currentPath .. "/" .. obj.Name 
		end

		if obj:IsA("LuaSourceContainer") then
			local scriptPath = myPath .. ".lua"
			scriptIndex[scriptPath] = obj
		end

		for _, child in ipairs(obj:GetChildren()) do 
			indexScripts(child, myPath) 
		end
	end

	for _, service in ipairs(SERVICES_TO_SYNC) do 
		indexScripts(service, "") 
	end

	-- Compter les scripts (scriptIndex est une table avec clés string, pas un array)
	local count = 0
	for _ in pairs(scriptIndex) do count = count + 1 end
	print("📋 Index créé:", count, "scripts")

	-- Debug : afficher quelques scripts trouvés
	if count > 0 then
		local shown = 0
		for path, _ in pairs(scriptIndex) do
			if shown < 3 then
				print("  📄", path)
				shown = shown + 1
			end
		end
		if count > 3 then
			print("  ... et", count - 3, "autres")
		end
	end
end

-- Système de timestamps pour détecter les changements
local lastKnownTimestamps = {}

-- Fonction pour créer un nouveau script depuis le disque (utilisée par le hot reload)
local function createNewScriptFromDisk(scriptInfo)
	local parts = string.split(scriptInfo.path, "/")
	local serviceName = parts[1]

	-- Trouver le service
	local parent = nil
	for _, service in ipairs(SERVICES_TO_SYNC) do
		if service.Name == serviceName then
			parent = service
			break
		end
	end

	if not parent then
		print("    ✗ Service non trouvé:", serviceName)
		return nil
	end

	-- Créer/naviguer les dossiers intermédiaires
	for i = 2, #parts - 1 do
		local folderName = parts[i]
		local folder = parent:FindFirstChild(folderName)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = folderName
			folder.Parent = parent
			print("    📁 Dossier créé:", folderName)
		end
		parent = folder
	end

	-- Créer le script
	local scriptName = parts[#parts]
	-- Enlever l'extension .lua si présente
	if string.sub(scriptName, -4) == ".lua" then
		scriptName = string.sub(scriptName, 1, -5)
	end

	-- Déterminer le type de script
	local scriptType = scriptInfo.className or "Script"
	local newScript

	if scriptType == "LocalScript" then
		newScript = Instance.new("LocalScript")
	elseif scriptType == "ModuleScript" then
		newScript = Instance.new("ModuleScript")
	else
		newScript = Instance.new("Script")
	end

	newScript.Name = scriptName

	local success = pcall(function()
		newScript.Source = scriptInfo.content or scriptInfo.source or ""
	end)

	if success then
		newScript.Parent = parent
		print("    ✨ NOUVEAU script créé:", scriptInfo.path)
		return newScript
	else
		print("    ✗ Erreur création:", scriptInfo.path)
		return nil
	end
end

-- Fonction OPTIMISÉE pour vérifier les changements ET les nouveaux scripts
local function checkForChanges()
	if not hotReloadEnabled then return end

	-- Reconstruire l'index si vide
	if not next(scriptIndex) then
		rebuildScriptIndex()
	end

	-- 🚀 ÉTAPE 1 : Récupérer TOUS les scripts du disque (pour détecter les nouveaux)
	local diskSuccess, diskResponse = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/list-all-scripts")
	end)

	if not diskSuccess then
		warn("❌ Erreur récupération scripts disque:", diskResponse)
		statusLabel.Text = "❌ Erreur serveur"
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end

	local diskDecodeSuccess, diskData = pcall(function()
		return HttpService:JSONDecode(diskResponse)
	end)

	if not diskDecodeSuccess or not diskData.scripts then
		warn("❌ Erreur décodage scripts disque")
		return
	end

	local diskScripts = diskData.scripts or {}
	local scriptsCreated = 0
	local scriptsUpdated = 0
	local scriptsDeleted = 0

	-- Créer un set des chemins de scripts sur le disque pour recherche rapide
	local diskScriptPaths = {}
	for _, scriptInfo in ipairs(diskScripts) do
		diskScriptPaths[scriptInfo.path] = true
	end

	-- 🚀 ÉTAPE 2 : Détecter et créer les NOUVEAUX scripts (ceux sur le disque mais pas dans Roblox)
	for _, scriptInfo in ipairs(diskScripts) do
		local scriptPath = scriptInfo.path

		if not scriptIndex[scriptPath] then
			-- Ce script existe sur le disque mais PAS dans Roblox → le créer !
			local newScript = createNewScriptFromDisk(scriptInfo)
			if newScript then
				scriptIndex[scriptPath] = newScript
				scriptsCreated = scriptsCreated + 1
				-- Enregistrer le timestamp pour éviter de le recréer
				lastKnownTimestamps[scriptPath] = os.time() * 1000
			end
		end
	end

	-- 🚀 ÉTAPE 2.5 : Détecter et SUPPRIMER les scripts qui n'existent plus sur le disque
	local scriptsToDelete = {}
	for scriptPath, scriptObj in pairs(scriptIndex) do
		if not diskScriptPaths[scriptPath] then
			-- Ce script existe dans Roblox mais PLUS sur le disque → le supprimer !
			table.insert(scriptsToDelete, { path = scriptPath, obj = scriptObj })
		end
	end

	for _, toDelete in ipairs(scriptsToDelete) do
		local scriptPath = toDelete.path
		local scriptObj = toDelete.obj

		if scriptObj and scriptObj.Parent then
			print("    🗑️ Script supprimé:", scriptPath)
			scriptObj:Destroy()
			scriptsDeleted = scriptsDeleted + 1
		end

		-- Retirer de l'index
		scriptIndex[scriptPath] = nil
		lastKnownTimestamps[scriptPath] = nil
	end

	-- 🚀 ÉTAPE 3 : Vérifier les modifications des scripts EXISTANTS via timestamps
	local scriptsToCheck = {}
	for scriptPath, _ in pairs(scriptIndex) do
		table.insert(scriptsToCheck, scriptPath)
	end

	if #scriptsToCheck > 0 then
		local success, response = pcall(function()
			return HttpService:PostAsync(
				SERVER_URL .. "/check-timestamps",
				HttpService:JSONEncode({ scripts = scriptsToCheck }),
				Enum.HttpContentType.ApplicationJson
			)
		end)

		if success then
			local decodeSuccess, data = pcall(function()
				return HttpService:JSONDecode(response)
			end)

			if decodeSuccess and data.timestamps then
				-- Vérifier quels scripts ont changé
				local scriptsToReload = {}
				for scriptPath, newTimestamp in pairs(data.timestamps) do
					local lastTimestamp = lastKnownTimestamps[scriptPath] or 0

					if newTimestamp > lastTimestamp then
						table.insert(scriptsToReload, scriptPath)
						lastKnownTimestamps[scriptPath] = newTimestamp
					else
						lastKnownTimestamps[scriptPath] = newTimestamp
					end
				end

				-- Recharger uniquement les scripts modifiés
				for _, scriptPath in ipairs(scriptsToReload) do
					local scriptObj = scriptIndex[scriptPath]
					if scriptObj then
						local updated, newScript = syncScriptFromServer(scriptPath, scriptObj)
						if updated then
							scriptsUpdated = scriptsUpdated + 1
							scriptIndex[scriptPath] = newScript
						end
					end
				end
			end
		end
	end

	-- 🚀 ÉTAPE 4 : Afficher le résultat
	local totalChanges = scriptsCreated + scriptsUpdated + scriptsDeleted

	if totalChanges > 0 then
		local messageParts = {}
		if scriptsCreated > 0 then
			table.insert(messageParts, "✨" .. scriptsCreated .. " créé(s)")
		end
		if scriptsUpdated > 0 then
			table.insert(messageParts, "🔄" .. scriptsUpdated .. " modifié(s)")
		end
		if scriptsDeleted > 0 then
			table.insert(messageParts, "🗑️" .. scriptsDeleted .. " supprimé(s)")
		end

		local message = table.concat(messageParts, ", ") .. "\n🕐 " .. os.date("%H:%M:%S")
		Log("✨ " .. totalChanges .. " changement(s) appliqué(s)", Color3.fromRGB(100, 255, 100))
		statusLabel.Text = message
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		-- Compter les scripts indexés
		local count = 0
		for _ in pairs(scriptIndex) do count = count + 1 end
		statusLabel.Text = "✅ Synchronisé (" .. count .. " scripts)\n🕐 " .. os.date("%H:%M:%S")
		statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	end
end

-- Fonction pour scanner et synchroniser tous les scripts (ancienne fonction, gardée pour compatibilité)
local function hotReloadScripts()
	checkForChanges()

	-- Faire clignoter le bouton
	task.spawn(function()
		for i = 1, 3 do
			hotReloadBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
			task.wait(0.1)
			hotReloadBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			task.wait(0.1)
		end
	end)
end

-- Toggle du hot-reload
hotReloadBtn.MouseButton1Click:Connect(function()
	hotReloadEnabled = not hotReloadEnabled

	if hotReloadEnabled then
		hotReloadBtn.Text = "🔄 Auto-Sync: ON"
		hotReloadBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		statusLabel.Text = "✅ Auto-Sync activé\n📋 Indexation des scripts..."
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		Log("✅ Auto-Sync activé - Vérification toutes les " .. hotReloadInterval .. "s", Color3.fromRGB(100, 255, 100))
		Log("💡 Créez ou modifiez vos scripts dans l'IDE, ils seront synchronisés automatiquement !", Color3.fromRGB(200, 200, 200))
		print("📁 Dossiers surveillés: ServerScriptService, ReplicatedStorage, StarterPlayer, StarterGui")

		-- Construire l'index des scripts
		task.spawn(function()
			rebuildScriptIndex()

			-- Compter les scripts indexés
			local count = 0
			for _ in pairs(scriptIndex) do count = count + 1 end

			statusLabel.Text = "✅ Auto-Sync activé\n✓ " .. count .. " scripts indexés\n🔍 Surveillance active..."

			-- Faire une vérification immédiate
			task.wait(0.5)
			hotReloadScripts()
		end)
	else
		hotReloadBtn.Text = "🔄 Auto-Sync: OFF"
		hotReloadBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		statusLabel.Text = "⏸️ Auto-Sync désactivé"
		statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		Log("⏸️ Auto-Sync désactivé", Color3.fromRGB(200, 200, 200))
	end
end)

-- Boucle de vérification
task.spawn(function()
	while true do
		task.wait(hotReloadInterval)
		if hotReloadEnabled then
			hotReloadScripts()
		end
	end
end)

----------------------------------------------------------------------------------
-- SYNC BIDIRECTIONNELLE - Roblox → Disque (Nouvelle fonctionnalité)
----------------------------------------------------------------------------------

MakeSeparator(26)
MakeLabel("🔄 SYNC BIDIRECTIONNELLE", 27)

-- Container pour la sync bidirectionnelle
local bidirSyncContainer = Instance.new("Frame", gui)
bidirSyncContainer.Size = UDim2.new(0.9, 0, 0, 200)
bidirSyncContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
bidirSyncContainer.BorderSizePixel = 0
bidirSyncContainer.LayoutOrder = 28
Instance.new("UICorner", bidirSyncContainer).CornerRadius = UDim.new(0, 6)

-- Label explicatif
local bidirExplainLabel = Instance.new("TextLabel", bidirSyncContainer)
bidirExplainLabel.Size = UDim2.new(1, -10, 0, 35)
bidirExplainLabel.Position = UDim2.new(0, 5, 0, 5)
bidirExplainLabel.BackgroundTransparency = 1
bidirExplainLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
bidirExplainLabel.Font = Enum.Font.SourceSans
bidirExplainLabel.TextSize = 11
bidirExplainLabel.Text = "🔄 Sync automatique dans les 2 sens:\nRoblox ↔ Disque (comme Git/Rojo)"
bidirExplainLabel.TextWrapped = true
bidirExplainLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Toggle pour activer la sync Roblox → Disque
local robloxToDiskEnabled = false
local btnRobloxToDisk = Instance.new("TextButton", bidirSyncContainer)
btnRobloxToDisk.Size = UDim2.new(1, -10, 0, 35)
btnRobloxToDisk.Position = UDim2.new(0, 5, 0, 42)
btnRobloxToDisk.Text = "📤 Auto-Save Roblox→Disque: OFF"
btnRobloxToDisk.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
btnRobloxToDisk.TextColor3 = Color3.new(1, 1, 1)
btnRobloxToDisk.Font = Enum.Font.SourceSansBold
btnRobloxToDisk.TextSize = 12
Instance.new("UICorner", btnRobloxToDisk).CornerRadius = UDim.new(0, 6)

-- Bouton pour vérifier les conflits avant sync
local btnCheckConflicts = Instance.new("TextButton", bidirSyncContainer)
btnCheckConflicts.Size = UDim2.new(1, -10, 0, 35)
btnCheckConflicts.Position = UDim2.new(0, 5, 0, 82)
btnCheckConflicts.Text = "⚠️ Vérifier conflits avant sync"
btnCheckConflicts.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
btnCheckConflicts.TextColor3 = Color3.new(1, 1, 1)
btnCheckConflicts.Font = Enum.Font.SourceSansBold
btnCheckConflicts.TextSize = 12
Instance.new("UICorner", btnCheckConflicts).CornerRadius = UDim.new(0, 6)

-- Label de statut de la sync bidirectionnelle
local bidirStatusLabel = Instance.new("TextLabel", bidirSyncContainer)
bidirStatusLabel.Size = UDim2.new(1, -10, 0, 70)
bidirStatusLabel.Position = UDim2.new(0, 5, 0, 122)
bidirStatusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
bidirStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
bidirStatusLabel.Font = Enum.Font.SourceSans
bidirStatusLabel.TextSize = 11
bidirStatusLabel.Text = "💡 Activez Auto-Save pour sauvegarder\nautomatiquement vos modifications\nRoblox vers le disque"
bidirStatusLabel.TextWrapped = true
bidirStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
Instance.new("UICorner", bidirStatusLabel).CornerRadius = UDim.new(0, 4)
local bidirPadding = Instance.new("UIPadding", bidirStatusLabel)
bidirPadding.PaddingTop = UDim.new(0, 5)
bidirPadding.PaddingLeft = UDim.new(0, 5)

-- Stockage des hashes locaux pour détecter les modifications
local localScriptHashes = {}
local scriptConnections = {} -- Connexions pour détecter les changements de Source

-- Nom de l'utilisateur actuel (sera rempli depuis l'input dans la section Locks)
local currentUserName = ""

-- Fonction pour récupérer le nom d'utilisateur actuel
local function getCurrentUserName()
	if currentUserName ~= "" then
		return currentUserName
	end
	-- Essayer de récupérer le nom du joueur local
	local success, name = pcall(function()
		return game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Name or "StudioUser"
	end)
	if success and name then
		return name
	end
	-- Fallback: nom de la machine
	return "RobloxStudio"
end

-- Fonction pour calculer un hash simple d'un string (pour comparaison)
local function simpleHash(str)
	if not str or str == "" then return "empty" end
	local hash = 0
	for i = 1, #str do
		hash = (hash * 31 + string.byte(str, i)) % 2147483647
	end
	return tostring(hash)
end

-- Fonction pour sauvegarder un script modifié vers le disque
local function saveScriptToDisk(scriptPath, content, scriptObj)
	local userName = getCurrentUserName()

	local success, response = pcall(function()
		return HttpService:PostAsync(
			SERVER_URL .. "/save-script-from-roblox",
			HttpService:JSONEncode({
				path = scriptPath,
				content = content,
				className = scriptObj.ClassName,
				timestamp = os.time() * 1000,
				user = userName,
				machine = "RobloxStudio"
			}),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if success then
		local result = HttpService:JSONDecode(response)
		if result.locked then
			-- Script verrouillé par quelqu'un d'autre !
			print("🔒 BLOQUÉ - Script verrouillé par " .. (result.lockedBy or "?") .. ":", scriptPath)
			Log("🔒 Bloqué par " .. (result.lockedBy or "?"), Color3.fromRGB(255, 150, 50))
			return false, result
		elseif result.conflict then
			-- Conflit détecté !
			print("⚠️ CONFLIT pour", scriptPath)
			return false, result
		else
			print("✅ Sauvegardé:", scriptPath)
			localScriptHashes[scriptPath] = simpleHash(content)
			return true, result
		end
	else
		print("❌ Erreur sauvegarde:", scriptPath, response)
		return false, nil
	end
end

-- Fonction pour vérifier si un script est verrouillé
local function isScriptLocked(scriptPath)
	return lockedScripts[scriptPath] ~= nil
end

-- Fonction pour vérifier si un script est verrouillé par quelqu'un d'autre
local function isScriptLockedByOther(scriptPath)
	local lock = lockedScripts[scriptPath]
	if not lock then return false end

	-- Si notre nom n'est pas défini, on ne peut pas savoir si c'est nous
	-- Dans ce cas, on ne bloque pas (on suppose que c'est nous)
	if currentUserName == "" then
		print("⚠️ Nom d'utilisateur non défini - pas de blocage pour:", scriptPath)
		return false
	end

	-- Comparaison insensible à la casse pour éviter les problèmes
	return lock.user:lower() ~= currentUserName:lower()
end

-- Fonction pour bloquer les modifications d'un script dans Roblox (SEULEMENT si verrouillé par quelqu'un d'autre)
local function blockScriptModifications(scriptObj, scriptPath, lockedBy)
	if not scriptObj or not scriptObj.Parent then return end

	-- Vérifier si c'est vraiment quelqu'un d'autre qui a verrouillé
	if not isScriptLockedByOther(scriptPath) then
		-- C'est nous qui avons verrouillé, ne rien faire (pas de message)
		return
	end

	print("🔒 Blocage du script verrouillé par " .. lockedBy .. ":", scriptPath)

	-- Stocker l'état original AVANT de modifier
	if not scriptOriginalStates[scriptPath] then
		local originalDisabled = false
		if scriptObj:IsA("Script") then
			pcall(function() originalDisabled = scriptObj.Disabled end)
		end
		local originalSource = ""
		pcall(function() originalSource = scriptObj.Source end)

		scriptOriginalStates[scriptPath] = {
			disabled = originalDisabled,
			source = originalSource
		}

		print("  📝 État original sauvegardé (Disabled = " .. tostring(originalDisabled) .. ")")
	end

	-- Désactiver le script pour empêcher son exécution (SEULEMENT si Script, pas LocalScript)
	if scriptObj:IsA("Script") then
		pcall(function()
			scriptObj.Disabled = true
			scriptObj:SetAttribute("_DisabledByLock", true) -- Marquer comme disabled par le lock
			print("  ⛔ Script désactivé")
		end)
	end

	-- Stocker le contenu original pour le restaurer si modifié
	local originalSource = scriptOriginalStates[scriptPath].source

	-- Surveiller les changements et restaurer si modifié
	local restoreConnection = scriptObj:GetPropertyChangedSignal("Source"):Connect(function()
		if isScriptLockedByOther(scriptPath) then
			-- Quelqu'un essaie de modifier un script verrouillé !
			print("🔒 TENTATIVE DE MODIFICATION BLOQUÉE - Script verrouillé par " .. lockedBy .. ":", scriptPath)
			warn("⚠️ Ce script est verrouillé par " .. lockedBy .. ". Tes modifications ont été annulées.")

			-- Restaurer le contenu original
			task.wait(0.1) -- Petit délai pour laisser Roblox finir sa modification
			pcall(function()
				scriptObj.Source = originalSource
			end)

			-- Afficher un message dans le statut
			Log("🔒 Modification bloquée - Script verrouillé par " .. lockedBy, Color3.fromRGB(255, 100, 100))
		end
	end)

	-- Stocker la connexion pour pouvoir la déconnecter plus tard
	if not scriptObj:GetAttribute("_LockRestoreConnection") then
		scriptObj:SetAttribute("_LockRestoreConnection", tostring(restoreConnection))
	end
end

-- Fonction pour débloquer un script (restaurer l'état original)
local function unblockScriptModifications(scriptObj, scriptPath)
	if not scriptObj or not scriptObj.Parent then return end

	-- Restaurer l'état Disabled original
	if scriptOriginalStates[scriptPath] then
		local originalDisabled = scriptOriginalStates[scriptPath].disabled

		if scriptObj:IsA("Script") then
			pcall(function()
				scriptObj.Disabled = originalDisabled
				print("🔓 État restauré pour " .. scriptPath .. " (Disabled = " .. tostring(originalDisabled) .. ")")
			end)
		end

		-- Nettoyer le stockage
		scriptOriginalStates[scriptPath] = nil
	else
		-- Pas d'état stocké - si le script est disabled, c'est probablement une erreur
		-- On le réactive pour ne pas bloquer l'utilisateur
		if scriptObj:IsA("Script") then
			local isDisabled = false
			pcall(function() isDisabled = scriptObj.Disabled end)

			if isDisabled then
				pcall(function()
					scriptObj.Disabled = false
					print("🔓 Script réactivé (pas d'état stocké, était disabled par erreur):", scriptPath)
				end)
			end
		end
	end

	-- Déconnecter la connexion de restauration si elle existe
	local connId = scriptObj:GetAttribute("_LockRestoreConnection")
	if connId then
		scriptObj:SetAttribute("_LockRestoreConnection", nil)
	end

	-- Nettoyer aussi l'attribut de source verrouillée
	pcall(function()
		scriptObj:SetAttribute("_LockedSource", nil)
	end)
end

-- Fonction pour vérifier et appliquer les locks sur tous les scripts
local function checkAndApplyLocks()
	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/locks")
	end)

	if not success then return end

	local data = HttpService:JSONDecode(response)
	local locks = data.locks or {}

	-- Parcourir tous les scripts et vérifier s'ils sont verrouillés
	local function checkService(service, currentPath)
		local myPath = currentPath
		if service.Parent == game then
			myPath = service.Name
		else
			myPath = currentPath .. "/" .. service.Name
		end

		for _, child in ipairs(service:GetChildren()) do
			if child:IsA("LuaSourceContainer") then
				local scriptPath = myPath .. "/" .. child.Name .. ".lua"
				local lock = locks[scriptPath]

				if lock then
					-- Script verrouillé
					lockedScripts[scriptPath] = lock

					-- Utiliser isScriptLockedByOther pour une vérification correcte
					-- (prend en compte le cas où currentUserName est vide)
					if isScriptLockedByOther(scriptPath) then
						-- Verrouillé par quelqu'un d'autre - BLOQUER (désactiver + empêcher modifications)
						print("🔒 Script verrouillé par " .. lock.user .. " - Blocage:", scriptPath)
						blockScriptModifications(child, scriptPath, lock.user)
					else
						-- Verrouillé par nous - NE PAS BLOQUER (on peut modifier)
						print("✅ Script verrouillé par nous - Modifications autorisées:", scriptPath)
					end
				else
					-- Pas verrouillé - débloquer si nécessaire
					if lockedScripts[scriptPath] then
						print("🔓 Script déverrouillé - Restauration:", scriptPath)
						lockedScripts[scriptPath] = nil
						unblockScriptModifications(child, scriptPath)
					else
						-- Vérifier si le script a été disabled par le système de lock (via attribut)
						local wasLockedBySystem = child:GetAttribute("_DisabledByLock")
						if wasLockedBySystem then
							pcall(function()
								child.Disabled = false
								child:SetAttribute("_DisabledByLock", nil)
								print("🔓 Script réactivé (attribut _DisabledByLock):", scriptPath)
							end)
						end
					end
				end
			end
			-- Récursif
			checkService(child, myPath)
		end
	end

	for _, service in ipairs(SERVICES_TO_SYNC) do
		checkService(service, "")
	end
end

-- Fonction pour connecter un script à la détection de changements
local function connectScriptToAutoSave(scriptObj, scriptPath)
	-- Déconnecter l'ancienne connexion si elle existe
	if scriptConnections[scriptPath] then
		scriptConnections[scriptPath]:Disconnect()
	end

	-- Calculer le hash initial
	local initialSource = ""
	pcall(function() initialSource = scriptObj.Source end)
	localScriptHashes[scriptPath] = simpleHash(initialSource)

	-- Vérifier si le script est verrouillé avant de connecter
	if isScriptLockedByOther(scriptPath) then
		local lock = lockedScripts[scriptPath]
		blockScriptModifications(scriptObj, scriptPath, lock.user)
		return -- Ne pas connecter l'auto-save si verrouillé par quelqu'un d'autre
	end

	-- Connecter au changement de Source
	local connection = scriptObj:GetPropertyChangedSignal("Source"):Connect(function()
		if not robloxToDiskEnabled then return end

		-- Vérifier si le script est toujours déverrouillé
		if isScriptLockedByOther(scriptPath) then
			local lock = lockedScripts[scriptPath]
			warn("🔒 Modification annulée - Script verrouillé par " .. lock.user)
			return
		end

		local newSource = ""
		pcall(function() newSource = scriptObj.Source end)
		local newHash = simpleHash(newSource)

		-- Vérifier si le contenu a vraiment changé
		if newHash ~= localScriptHashes[scriptPath] then
			print("📝 Script modifié dans Roblox:", scriptPath)

			-- Sauvegarder vers le disque avec un petit délai (debounce)
			task.delay(1, function()
				-- Revérifier que le script existe encore et n'est pas verrouillé
				if scriptObj and scriptObj.Parent and not isScriptLockedByOther(scriptPath) then
					local currentSource = ""
					pcall(function() currentSource = scriptObj.Source end)
					saveScriptToDisk(scriptPath, currentSource, scriptObj)
				end
			end)
		end
	end)

	scriptConnections[scriptPath] = connection
end

-- Fonction pour connecter tous les scripts existants
local function connectAllScriptsToAutoSave()
	-- Déconnecter toutes les anciennes connexions
	for path, conn in pairs(scriptConnections) do
		if conn then conn:Disconnect() end
	end
	scriptConnections = {}
	localScriptHashes = {}

	local count = 0

	local function connectService(service, currentPath)
		local myPath = currentPath
		if service.Parent == game then
			myPath = service.Name
		else
			myPath = currentPath .. "/" .. service.Name
		end

		for _, child in ipairs(service:GetChildren()) do
			if child:IsA("LuaSourceContainer") then
				local scriptPath = myPath .. "/" .. child.Name .. ".lua"
				connectScriptToAutoSave(child, scriptPath)
				count = count + 1
			end
			-- Récursif
			connectService(child, myPath)
		end
	end

	for _, service in ipairs(SERVICES_TO_SYNC) do
		connectService(service, "")
	end

	print("🔗 " .. count .. " scripts connectés pour auto-save")
	return count
end

-- Écouter les nouveaux scripts ajoutés
local function setupNewScriptListener()
	for _, service in ipairs(SERVICES_TO_SYNC) do
		service.DescendantAdded:Connect(function(obj)
			if obj:IsA("LuaSourceContainer") and robloxToDiskEnabled then
				-- Calculer le chemin du script
				local path = obj.Name .. ".lua"
				local current = obj.Parent
				while current and current ~= game do
					path = current.Name .. "/" .. path
					current = current.Parent
				end

				task.wait(0.5) -- Attendre que le script soit complètement initialisé
				connectScriptToAutoSave(obj, path)

				-- Sauvegarder immédiatement le nouveau script
				local source = ""
				pcall(function() source = obj.Source end)
				if source and source ~= "" then
					saveScriptToDisk(path, source, obj)
					print("✨ Nouveau script détecté et sauvegardé:", path)
				end
			end
		end)
	end
end

-- Toggle du Roblox → Disque
btnRobloxToDisk.MouseButton1Click:Connect(function()
	robloxToDiskEnabled = not robloxToDiskEnabled

	if robloxToDiskEnabled then
		btnRobloxToDisk.Text = "📤 Auto-Save Roblox→Disque: ON"
		btnRobloxToDisk.BackgroundColor3 = Color3.fromRGB(50, 150, 50)

		local count = connectAllScriptsToAutoSave()

		-- Vérifier et appliquer les locks immédiatement
		task.spawn(function()
			task.wait(0.5)
			checkAndApplyLocks()
		end)

		bidirStatusLabel.Text = "✅ Auto-Save activé!\n" .. count .. " scripts surveillés\n\n📝 Vos modifications Roblox seront\nsauvegardées automatiquement"
		bidirStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

		Log("✅ Auto-Save Roblox→Disque activé", Color3.fromRGB(100, 255, 100))
	else
		btnRobloxToDisk.Text = "📤 Auto-Save Roblox→Disque: OFF"
		btnRobloxToDisk.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

		-- Déconnecter tous les scripts
		for path, conn in pairs(scriptConnections) do
			if conn then conn:Disconnect() end
		end
		scriptConnections = {}

		bidirStatusLabel.Text = "⏸️ Auto-Save désactivé\n\n💡 Vos modifications ne seront\npas sauvegardées automatiquement"
		bidirStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)

		Log("⏸️ Auto-Save Roblox→Disque désactivé", Color3.fromRGB(200, 200, 200))
	end
end)

-- Initialiser l'écoute des nouveaux scripts
task.spawn(setupNewScriptListener)

----------------------------------------------------------------------------------
-- DÉTECTION DE CONFLITS - Popup de résolution
----------------------------------------------------------------------------------

-- Widget pour la résolution de conflits de scripts
local scriptConflictWidget = plugin:CreateDockWidgetPluginGui(
	"ScriptConflictUI",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 500, 400, 450, 350)
)
scriptConflictWidget.Title = "⚠️ Conflit de Script"

local scriptConflictGui = Instance.new("Frame", scriptConflictWidget)
scriptConflictGui.Size = UDim2.fromScale(1, 1)
scriptConflictGui.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

-- Header
local conflictScriptHeader = Instance.new("TextLabel", scriptConflictGui)
conflictScriptHeader.Size = UDim2.new(1, 0, 0, 50)
conflictScriptHeader.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
conflictScriptHeader.TextColor3 = Color3.new(1, 1, 1)
conflictScriptHeader.Font = Enum.Font.SourceSansBold
conflictScriptHeader.TextSize = 14
conflictScriptHeader.Text = "⚠️ CONFLIT DÉTECTÉ"
conflictScriptHeader.TextWrapped = true

-- Nom du script en conflit
local conflictScriptName = Instance.new("TextLabel", scriptConflictGui)
conflictScriptName.Size = UDim2.new(1, -20, 0, 30)
conflictScriptName.Position = UDim2.new(0, 10, 0, 55)
conflictScriptName.BackgroundTransparency = 1
conflictScriptName.TextColor3 = Color3.fromRGB(255, 200, 100)
conflictScriptName.Font = Enum.Font.SourceSansBold
conflictScriptName.TextSize = 14
conflictScriptName.Text = "📜 Script: ..."
conflictScriptName.TextXAlignment = Enum.TextXAlignment.Left

-- Message explicatif
local conflictExplain = Instance.new("TextLabel", scriptConflictGui)
conflictExplain.Size = UDim2.new(1, -20, 0, 50)
conflictExplain.Position = UDim2.new(0, 10, 0, 85)
conflictExplain.BackgroundTransparency = 1
conflictExplain.TextColor3 = Color3.fromRGB(200, 200, 200)
conflictExplain.Font = Enum.Font.SourceSans
conflictExplain.TextSize = 12
conflictExplain.Text = "Ce script a été modifié à la fois dans Roblox et sur le disque.\nQuelle version voulez-vous garder ?"
conflictExplain.TextWrapped = true
conflictExplain.TextXAlignment = Enum.TextXAlignment.Left

-- Frame pour les aperçus
local previewFrame = Instance.new("Frame", scriptConflictGui)
previewFrame.Size = UDim2.new(1, -20, 0, 150)
previewFrame.Position = UDim2.new(0, 10, 0, 140)
previewFrame.BackgroundTransparency = 1

-- Aperçu Roblox (gauche)
local robloxPreviewFrame = Instance.new("Frame", previewFrame)
robloxPreviewFrame.Size = UDim2.new(0.48, 0, 1, 0)
robloxPreviewFrame.BackgroundColor3 = Color3.fromRGB(45, 60, 45)
Instance.new("UICorner", robloxPreviewFrame).CornerRadius = UDim.new(0, 6)

local robloxPreviewTitle = Instance.new("TextLabel", robloxPreviewFrame)
robloxPreviewTitle.Size = UDim2.new(1, 0, 0, 25)
robloxPreviewTitle.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
robloxPreviewTitle.TextColor3 = Color3.new(1, 1, 1)
robloxPreviewTitle.Font = Enum.Font.SourceSansBold
robloxPreviewTitle.TextSize = 12
robloxPreviewTitle.Text = "📗 Version ROBLOX"
Instance.new("UICorner", robloxPreviewTitle).CornerRadius = UDim.new(0, 6)

local robloxPreviewText = Instance.new("TextLabel", robloxPreviewFrame)
robloxPreviewText.Size = UDim2.new(1, -10, 1, -30)
robloxPreviewText.Position = UDim2.new(0, 5, 0, 28)
robloxPreviewText.BackgroundTransparency = 1
robloxPreviewText.TextColor3 = Color3.fromRGB(200, 200, 200)
robloxPreviewText.Font = Enum.Font.Code
robloxPreviewText.TextSize = 10
robloxPreviewText.Text = "..."
robloxPreviewText.TextWrapped = true
robloxPreviewText.TextXAlignment = Enum.TextXAlignment.Left
robloxPreviewText.TextYAlignment = Enum.TextYAlignment.Top

-- Aperçu Disque (droite)
local diskPreviewFrame = Instance.new("Frame", previewFrame)
diskPreviewFrame.Size = UDim2.new(0.48, 0, 1, 0)
diskPreviewFrame.Position = UDim2.new(0.52, 0, 0, 0)
diskPreviewFrame.BackgroundColor3 = Color3.fromRGB(60, 45, 45)
Instance.new("UICorner", diskPreviewFrame).CornerRadius = UDim.new(0, 6)

local diskPreviewTitle = Instance.new("TextLabel", diskPreviewFrame)
diskPreviewTitle.Size = UDim2.new(1, 0, 0, 25)
diskPreviewTitle.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
diskPreviewTitle.TextColor3 = Color3.new(1, 1, 1)
diskPreviewTitle.Font = Enum.Font.SourceSansBold
diskPreviewTitle.TextSize = 12
diskPreviewTitle.Text = "💾 Version DISQUE"
Instance.new("UICorner", diskPreviewTitle).CornerRadius = UDim.new(0, 6)

local diskPreviewText = Instance.new("TextLabel", diskPreviewFrame)
diskPreviewText.Size = UDim2.new(1, -10, 1, -30)
diskPreviewText.Position = UDim2.new(0, 5, 0, 28)
diskPreviewText.BackgroundTransparency = 1
diskPreviewText.TextColor3 = Color3.fromRGB(200, 200, 200)
diskPreviewText.Font = Enum.Font.Code
diskPreviewText.TextSize = 10
diskPreviewText.Text = "..."
diskPreviewText.TextWrapped = true
diskPreviewText.TextXAlignment = Enum.TextXAlignment.Left
diskPreviewText.TextYAlignment = Enum.TextYAlignment.Top

-- Boutons de résolution
local scriptConflictButtonsFrame = Instance.new("Frame", scriptConflictGui)
scriptConflictButtonsFrame.Size = UDim2.new(1, -20, 0, 45)
scriptConflictButtonsFrame.Position = UDim2.new(0, 10, 0, 300)
scriptConflictButtonsFrame.BackgroundTransparency = 1

local btnKeepRoblox = Instance.new("TextButton", scriptConflictButtonsFrame)
btnKeepRoblox.Size = UDim2.new(0.32, -3, 0, 40)
btnKeepRoblox.Position = UDim2.new(0, 0, 0, 0)
btnKeepRoblox.Text = "📗 Garder Roblox"
btnKeepRoblox.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
btnKeepRoblox.TextColor3 = Color3.new(1, 1, 1)
btnKeepRoblox.Font = Enum.Font.SourceSansBold
btnKeepRoblox.TextSize = 12
Instance.new("UICorner", btnKeepRoblox).CornerRadius = UDim.new(0, 6)

local btnKeepDisk = Instance.new("TextButton", scriptConflictButtonsFrame)
btnKeepDisk.Size = UDim2.new(0.32, -3, 0, 40)
btnKeepDisk.Position = UDim2.new(0.34, 0, 0, 0)
btnKeepDisk.Text = "💾 Garder Disque"
btnKeepDisk.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
btnKeepDisk.TextColor3 = Color3.new(1, 1, 1)
btnKeepDisk.Font = Enum.Font.SourceSansBold
btnKeepDisk.TextSize = 12
Instance.new("UICorner", btnKeepDisk).CornerRadius = UDim.new(0, 6)

local btnSkipConflict = Instance.new("TextButton", scriptConflictButtonsFrame)
btnSkipConflict.Size = UDim2.new(0.32, -3, 0, 40)
btnSkipConflict.Position = UDim2.new(0.68, 0, 0, 0)
btnSkipConflict.Text = "⏭️ Ignorer"
btnSkipConflict.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
btnSkipConflict.TextColor3 = Color3.new(1, 1, 1)
btnSkipConflict.Font = Enum.Font.SourceSansBold
btnSkipConflict.TextSize = 12
Instance.new("UICorner", btnSkipConflict).CornerRadius = UDim.new(0, 6)

-- Variables pour stocker le conflit en cours
local currentScriptConflict = nil
local conflictQueue = {} -- File d'attente des conflits à résoudre

-- Fonction pour afficher un conflit
local function showScriptConflict(conflict)
	currentScriptConflict = conflict

	conflictScriptName.Text = "📜 " .. conflict.path

	-- Aperçu du contenu (premières lignes)
	local robloxPreview = conflict.robloxContent or ""
	local diskPreview = conflict.diskContent or ""

	-- Limiter l'aperçu à 10 lignes
	local function limitLines(text, maxLines)
		local lines = {}
		for line in text:gmatch("[^\n]*") do
			if #lines >= maxLines then
				table.insert(lines, "...")
				break
			end
			table.insert(lines, line)
		end
		return table.concat(lines, "\n")
	end

	robloxPreviewText.Text = limitLines(robloxPreview, 8)
	diskPreviewText.Text = limitLines(diskPreview, 8)

	scriptConflictWidget.Enabled = true
end

-- Fonction pour traiter le prochain conflit dans la queue
local function processNextConflict()
	if #conflictQueue > 0 then
		local nextConflict = table.remove(conflictQueue, 1)
		showScriptConflict(nextConflict)
	else
		scriptConflictWidget.Enabled = false
		currentScriptConflict = nil
		Log("✅ Tous les conflits résolus!", Color3.fromRGB(100, 255, 100))
	end
end

-- Garder la version Roblox (écraser le disque)
btnKeepRoblox.MouseButton1Click:Connect(function()
	if not currentScriptConflict then return end

	local conflict = currentScriptConflict
	Log("⏳ Sauvegarde version Roblox...", Color3.fromRGB(46, 204, 113))

	local success, response = pcall(function()
		return HttpService:PostAsync(
			SERVER_URL .. "/force-save-script",
			HttpService:JSONEncode({
				scriptPath = conflict.path,
				content = conflict.robloxContent,
				source = "roblox"
			}),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if success then
		Log("✅ Version Roblox sauvegardée: " .. conflict.path, Color3.fromRGB(100, 255, 100))
		localScriptHashes[conflict.path] = simpleHash(conflict.robloxContent)
	else
		Log("❌ Erreur: " .. tostring(response), Color3.fromRGB(255, 100, 100))
	end

	processNextConflict()
end)

-- Garder la version Disque (écraser Roblox)
btnKeepDisk.MouseButton1Click:Connect(function()
	if not currentScriptConflict then return end

	local conflict = currentScriptConflict
	Log("⏳ Chargement version Disque...", Color3.fromRGB(52, 152, 219))

	-- Trouver le script dans Roblox et le mettre à jour
	local scriptObj = scriptIndex[conflict.path]
	if scriptObj and scriptObj.Parent then
		local success = pcall(function()
			scriptObj.Source = conflict.diskContent
		end)

		if success then
			Log("✅ Version Disque appliquée: " .. conflict.path, Color3.fromRGB(100, 255, 100))
			localScriptHashes[conflict.path] = simpleHash(conflict.diskContent)
		else
			Log("❌ Impossible de modifier le script", Color3.fromRGB(255, 100, 100))
		end
	else
		Log("⚠️ Script non trouvé dans Roblox", Color3.fromRGB(255, 200, 100))
	end

	processNextConflict()
end)

-- Ignorer ce conflit
btnSkipConflict.MouseButton1Click:Connect(function()
	if currentScriptConflict then
		Log("⏭️ Conflit ignoré: " .. currentScriptConflict.path, Color3.fromRGB(200, 200, 200))
	end
	processNextConflict()
end)

-- Bouton pour vérifier tous les conflits
btnCheckConflicts.MouseButton1Click:Connect(function()
	Log("⏳ Vérification des conflits...", Color3.fromRGB(231, 76, 60))
	bidirStatusLabel.Text = "🔍 Analyse en cours..."
	bidirStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)

	-- Collecter tous les scripts locaux avec leur contenu
	local localScripts = {}

	local function collectLocal(obj, currentPath)
		local myPath = currentPath
		if obj.Parent == game then 
			myPath = obj.Name 
		else 
			myPath = currentPath .. "/" .. obj.Name 
		end

		if obj:IsA("LuaSourceContainer") then
			local scriptPath = myPath .. ".lua"
			local source = ""
			pcall(function() source = obj.Source end)
			localScripts[scriptPath] = {
				content = source,
				hash = simpleHash(source),
				className = obj.ClassName
			}
		end
		for _, child in ipairs(obj:GetChildren()) do 
			collectLocal(child, myPath) 
		end
	end

	for _, service in ipairs(SERVICES_TO_SYNC) do 
		collectLocal(service, "") 
	end

	-- Envoyer au serveur pour comparaison
	local scriptsToCheck = {}
	for path, data in pairs(localScripts) do
		table.insert(scriptsToCheck, {
			path = path,
			hash = data.hash,
			content = data.content
		})
	end

	local success, response = pcall(function()
		return HttpService:PostAsync(
			SERVER_URL .. "/check-bidirectional-conflicts",
			HttpService:JSONEncode({ scripts = scriptsToCheck }),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if not success then
		Log("❌ Erreur serveur: " .. tostring(response), Color3.fromRGB(255, 100, 100))
		bidirStatusLabel.Text = "❌ Erreur serveur"
		bidirStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end

	local result = HttpService:JSONDecode(response)

	if result.conflicts and #result.conflicts > 0 then
		Log("⚠️ " .. #result.conflicts .. " conflit(s) détecté(s)!", Color3.fromRGB(255, 200, 100))
		bidirStatusLabel.Text = "⚠️ " .. #result.conflicts .. " conflit(s) détecté(s)!\n\nRésolvez-les un par un..."
		bidirStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)

		-- Ajouter les conflits à la queue
		conflictQueue = {}
		for _, conflict in ipairs(result.conflicts) do
			-- Récupérer le contenu Roblox
			local robloxContent = ""
			if localScripts[conflict.path] then
				robloxContent = localScripts[conflict.path].content
			end

			table.insert(conflictQueue, {
				path = conflict.path,
				robloxContent = robloxContent,
				diskContent = conflict.diskContent,
				diskHash = conflict.diskHash
			})
		end

		-- Afficher le premier conflit
		processNextConflict()
	else
		Log("✅ Aucun conflit! Tout est synchronisé.", Color3.fromRGB(100, 255, 100))
		bidirStatusLabel.Text = "✅ Aucun conflit!\n\n" .. (result.synced or 0) .. " scripts synchronisés\n" .. (result.modified or 0) .. " modifiés localement\n" .. (result.onlyOnDisk or 0) .. " uniquement sur disque"
		bidirStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

		-- Afficher les détails dans la console
		if result.details then
			print("═══════════════════════════════════════════")
			print("🔄 RÉSULTAT DE LA VÉRIFICATION")
			print("═══════════════════════════════════════════")
			if result.details.synced and #result.details.synced > 0 then
				print("✅ Scripts synchronisés: " .. #result.details.synced)
			end
			if result.details.modifiedLocally and #result.details.modifiedLocally > 0 then
				print("📝 Modifiés localement (Roblox):")
				for _, path in ipairs(result.details.modifiedLocally) do
					print("   " .. path)
				end
			end
			if result.details.onlyOnDisk and #result.details.onlyOnDisk > 0 then
				print("💾 Uniquement sur disque:")
				for _, path in ipairs(result.details.onlyOnDisk) do
					print("   " .. path)
				end
			end
			if result.details.onlyInRoblox and #result.details.onlyInRoblox > 0 then
				print("📗 Uniquement dans Roblox:")
				for _, path in ipairs(result.details.onlyInRoblox) do
					print("   " .. path)
				end
			end
			print("═══════════════════════════════════════════")
		end
	end
end)

----------------------------------------------------------------------------------
-- HISTORIQUE DES MODIFICATIONS
----------------------------------------------------------------------------------

MakeSeparator(29)
MakeLabel("📜 HISTORIQUE", 30)

-- Container pour l'historique
local historyContainer = Instance.new("Frame", gui)
historyContainer.Size = UDim2.new(0.9, 0, 0, 180)
historyContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
historyContainer.BorderSizePixel = 0
historyContainer.LayoutOrder = 31
Instance.new("UICorner", historyContainer).CornerRadius = UDim.new(0, 6)

-- Bouton pour rafraîchir l'historique
local btnRefreshHistory = Instance.new("TextButton", historyContainer)
btnRefreshHistory.Size = UDim2.new(1, -10, 0, 30)
btnRefreshHistory.Position = UDim2.new(0, 5, 0, 5)
btnRefreshHistory.Text = "📜 Voir l'historique des modifications"
btnRefreshHistory.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
btnRefreshHistory.TextColor3 = Color3.new(1, 1, 1)
btnRefreshHistory.Font = Enum.Font.SourceSansBold
btnRefreshHistory.TextSize = 12
Instance.new("UICorner", btnRefreshHistory).CornerRadius = UDim.new(0, 6)

-- Liste scrollable de l'historique
local historyScroll = Instance.new("ScrollingFrame", historyContainer)
historyScroll.Size = UDim2.new(1, -10, 0, 135)
historyScroll.Position = UDim2.new(0, 5, 0, 40)
historyScroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
historyScroll.BorderSizePixel = 0
historyScroll.ScrollBarThickness = 4
historyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", historyScroll).CornerRadius = UDim.new(0, 4)

local historyLayout = Instance.new("UIListLayout", historyScroll)
historyLayout.Padding = UDim.new(0, 2)

local historyPadding = Instance.new("UIPadding", historyScroll)
historyPadding.PaddingTop = UDim.new(0, 4)
historyPadding.PaddingLeft = UDim.new(0, 4)

-- Fonction pour créer un item d'historique
local function createHistoryItem(entry, index)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, -12, 0, 40)
	item.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	item.BorderSizePixel = 0
	item.LayoutOrder = index
	Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

	-- Icône selon l'action
	local icons = {
		modified = "📝",
		created = "✨",
		deleted = "🗑️",
		locked = "🔒",
		unlocked = "🔓",
		conflict_resolved = "✅"
	}
	local icon = icons[entry.action] or "📄"

	-- Couleur selon l'action
	local colors = {
		modified = Color3.fromRGB(255, 200, 100),
		created = Color3.fromRGB(100, 255, 100),
		deleted = Color3.fromRGB(255, 100, 100),
		locked = Color3.fromRGB(255, 150, 50),
		unlocked = Color3.fromRGB(100, 200, 255),
		conflict_resolved = Color3.fromRGB(100, 255, 150)
	}

	-- Première ligne : action + script
	local actionLabel = Instance.new("TextLabel", item)
	actionLabel.Size = UDim2.new(1, -8, 0, 18)
	actionLabel.Position = UDim2.new(0, 4, 0, 2)
	actionLabel.BackgroundTransparency = 1
	actionLabel.TextColor3 = colors[entry.action] or Color3.fromRGB(200, 200, 200)
	actionLabel.Font = Enum.Font.SourceSansBold
	actionLabel.TextSize = 11
	actionLabel.Text = icon .. " " .. (entry.scriptPath or "?")
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.TextTruncate = Enum.TextTruncate.AtEnd

	-- Deuxième ligne : utilisateur + date
	local detailsLabel = Instance.new("TextLabel", item)
	detailsLabel.Size = UDim2.new(1, -8, 0, 16)
	detailsLabel.Position = UDim2.new(0, 4, 0, 20)
	detailsLabel.BackgroundTransparency = 1
	detailsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	detailsLabel.Font = Enum.Font.SourceSans
	detailsLabel.TextSize = 10

	-- Formater la date
	local dateStr = entry.date or ""
	if entry.timestamp then
		local now = os.time()
		local diff = now - math.floor(entry.timestamp / 1000)
		if diff < 60 then
			dateStr = "Il y a " .. diff .. "s"
		elseif diff < 3600 then
			dateStr = "Il y a " .. math.floor(diff / 60) .. " min"
		elseif diff < 86400 then
			dateStr = "Il y a " .. math.floor(diff / 3600) .. "h"
		else
			dateStr = "Il y a " .. math.floor(diff / 86400) .. "j"
		end
	end

	detailsLabel.Text = "👤 " .. (entry.user or "?") .. " • " .. dateStr
	detailsLabel.TextXAlignment = Enum.TextXAlignment.Left

	return item
end

-- Fonction pour charger l'historique
local function loadHistory()
	Log("⏳ Chargement de l'historique...", Color3.fromRGB(52, 73, 94))

	-- Vider la liste
	for _, child in ipairs(historyScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/history?limit=30")
	end)

	if not success then
		Log("❌ Erreur chargement historique", Color3.fromRGB(255, 100, 100))
		return
	end

	local data = HttpService:JSONDecode(response)
	local entries = data.entries or {}

	if #entries == 0 then
		local noHistoryLabel = Instance.new("TextLabel", historyScroll)
		noHistoryLabel.Size = UDim2.new(1, -8, 0, 30)
		noHistoryLabel.BackgroundTransparency = 1
		noHistoryLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		noHistoryLabel.Font = Enum.Font.SourceSans
		noHistoryLabel.TextSize = 12
		noHistoryLabel.Text = "Aucun historique disponible"
		historyScroll.CanvasSize = UDim2.new(0, 0, 0, 40)
	else
		local totalHeight = 8
		for i, entry in ipairs(entries) do
			local item = createHistoryItem(entry, i)
			item.Parent = historyScroll
			totalHeight = totalHeight + 42
		end
		historyScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
		Log("📜 " .. #entries .. " entrées d'historique chargées", Color3.fromRGB(100, 255, 100))
	end
end

btnRefreshHistory.MouseButton1Click:Connect(loadHistory)

----------------------------------------------------------------------------------
-- SYSTÈME DE VERROUILLAGE (LOCKS)
----------------------------------------------------------------------------------

MakeSeparator(32)
MakeLabel("🔒 VERROUILLAGE DE SCRIPTS", 33)

-- Container pour les locks
local locksContainer = Instance.new("Frame", gui)
locksContainer.Size = UDim2.new(0.9, 0, 0, 180)
locksContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
locksContainer.BorderSizePixel = 0
locksContainer.LayoutOrder = 34
Instance.new("UICorner", locksContainer).CornerRadius = UDim.new(0, 6)

-- Nom d'utilisateur (pour identifier qui verrouille)
local userNameLabel = Instance.new("TextLabel", locksContainer)
userNameLabel.Size = UDim2.new(0.3, -5, 0, 25)
userNameLabel.Position = UDim2.new(0, 5, 0, 5)
userNameLabel.BackgroundTransparency = 1
userNameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
userNameLabel.Font = Enum.Font.SourceSans
userNameLabel.TextSize = 11
userNameLabel.Text = "Votre nom:"
userNameLabel.TextXAlignment = Enum.TextXAlignment.Left

local userNameInput = Instance.new("TextBox", locksContainer)
userNameInput.Size = UDim2.new(0.68, -5, 0, 25)
userNameInput.Position = UDim2.new(0.32, 0, 0, 5)
userNameInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
userNameInput.TextColor3 = Color3.new(1, 1, 1)
userNameInput.Font = Enum.Font.SourceSans
userNameInput.TextSize = 12
userNameInput.PlaceholderText = "Entrez votre nom..."
userNameInput.Text = ""
Instance.new("UICorner", userNameInput).CornerRadius = UDim.new(0, 4)

-- Tenter de récupérer le nom d'utilisateur système
pcall(function()
	local players = game:GetService("Players")
	if players.LocalPlayer then
		userNameInput.Text = players.LocalPlayer.Name
		currentUserName = players.LocalPlayer.Name
	end
end)

-- Mettre à jour le nom d'utilisateur global quand l'input change
userNameInput:GetPropertyChangedSignal("Text"):Connect(function()
	currentUserName = userNameInput.Text
end)

-- Boutons de lock
local lockButtonsFrame = Instance.new("Frame", locksContainer)
lockButtonsFrame.Size = UDim2.new(1, -10, 0, 30)
lockButtonsFrame.Position = UDim2.new(0, 5, 0, 35)
lockButtonsFrame.BackgroundTransparency = 1

local btnRefreshLocks = Instance.new("TextButton", lockButtonsFrame)
btnRefreshLocks.Size = UDim2.new(0.48, -2, 1, 0)
btnRefreshLocks.Position = UDim2.new(0, 0, 0, 0)
btnRefreshLocks.Text = "🔄 Voir les locks"
btnRefreshLocks.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
btnRefreshLocks.TextColor3 = Color3.new(1, 1, 1)
btnRefreshLocks.Font = Enum.Font.SourceSansBold
btnRefreshLocks.TextSize = 11
Instance.new("UICorner", btnRefreshLocks).CornerRadius = UDim.new(0, 6)

local btnLockSelected = Instance.new("TextButton", lockButtonsFrame)
btnLockSelected.Size = UDim2.new(0.48, -2, 1, 0)
btnLockSelected.Position = UDim2.new(0.52, 0, 0, 0)
btnLockSelected.Text = "🔒 Verrouiller sélection"
btnLockSelected.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
btnLockSelected.TextColor3 = Color3.new(1, 1, 1)
btnLockSelected.Font = Enum.Font.SourceSansBold
btnLockSelected.TextSize = 11
Instance.new("UICorner", btnLockSelected).CornerRadius = UDim.new(0, 6)

-- Liste des locks actifs
local locksScroll = Instance.new("ScrollingFrame", locksContainer)
locksScroll.Size = UDim2.new(1, -10, 0, 105)
locksScroll.Position = UDim2.new(0, 5, 0, 70)
locksScroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
locksScroll.BorderSizePixel = 0
locksScroll.ScrollBarThickness = 4
locksScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", locksScroll).CornerRadius = UDim.new(0, 4)

local locksLayout = Instance.new("UIListLayout", locksScroll)
locksLayout.Padding = UDim.new(0, 2)

local locksPadding = Instance.new("UIPadding", locksScroll)
locksPadding.PaddingTop = UDim.new(0, 4)
locksPadding.PaddingLeft = UDim.new(0, 4)

-- Forward declaration pour refreshLocks (utilisée dans createLockItem)
local refreshLocks

-- Fonction pour créer un item de lock
local function createLockItem(scriptPath, lockInfo, index)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, -12, 0, 35)
	item.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
	item.BorderSizePixel = 0
	item.LayoutOrder = index
	Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

	-- Nom du script
	local scriptLabel = Instance.new("TextLabel", item)
	scriptLabel.Size = UDim2.new(0.65, -4, 0, 16)
	scriptLabel.Position = UDim2.new(0, 4, 0, 2)
	scriptLabel.BackgroundTransparency = 1
	scriptLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	scriptLabel.Font = Enum.Font.SourceSansBold
	scriptLabel.TextSize = 10
	scriptLabel.Text = "🔒 " .. scriptPath
	scriptLabel.TextXAlignment = Enum.TextXAlignment.Left
	scriptLabel.TextTruncate = Enum.TextTruncate.AtEnd

	-- Info du lock
	local lockInfoLabel = Instance.new("TextLabel", item)
	lockInfoLabel.Size = UDim2.new(0.65, -4, 0, 14)
	lockInfoLabel.Position = UDim2.new(0, 4, 0, 18)
	lockInfoLabel.BackgroundTransparency = 1
	lockInfoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	lockInfoLabel.Font = Enum.Font.SourceSans
	lockInfoLabel.TextSize = 9
	lockInfoLabel.Text = "👤 " .. (lockInfo.user or "?") .. " • " .. (lockInfo.machine or "")
	lockInfoLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Bouton de déverrouillage
	local btnUnlock = Instance.new("TextButton", item)
	btnUnlock.Size = UDim2.new(0.32, -4, 0, 25)
	btnUnlock.Position = UDim2.new(0.68, 0, 0, 5)
	btnUnlock.Text = "🔓"
	btnUnlock.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	btnUnlock.TextColor3 = Color3.new(1, 1, 1)
	btnUnlock.Font = Enum.Font.SourceSansBold
	btnUnlock.TextSize = 14
	Instance.new("UICorner", btnUnlock).CornerRadius = UDim.new(0, 4)

	-- Vérifier si c'est notre lock
	local currentUser = userNameInput.Text
	local isOurLock = lockInfo.user == currentUser

	if not isOurLock then
		btnUnlock.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
		btnUnlock.Text = "⚠️"
	end

	btnUnlock.MouseButton1Click:Connect(function()
		local force = not isOurLock
		local success, response = pcall(function()
			return HttpService:PostAsync(
				SERVER_URL .. "/unlock",
				HttpService:JSONEncode({
					scriptPath = scriptPath,
					user = currentUser,
					force = force
				}),
				Enum.HttpContentType.ApplicationJson
			)
		end)

		if success then
			local result = HttpService:JSONDecode(response)
			if result.success then
				Log("🔓 Déverrouillé: " .. scriptPath, Color3.fromRGB(100, 255, 100))

				-- Trouver le script dans Roblox et le débloquer immédiatement
				local function findAndUnblockScript(path)
					local parts = string.split(path, "/")
					local serviceName = parts[1]

					local service = nil
					for _, s in ipairs(SERVICES_TO_SYNC) do
						if s.Name == serviceName then
							service = s
							break
						end
					end

					if service then
						local current = service
						for i = 2, #parts do
							local name = parts[i]
							if i == #parts then
								-- C'est le nom du script (sans .lua)
								name = string.gsub(name, "%.lua$", "")
							end
							local child = current:FindFirstChild(name)
							if child then
								current = child
							else
								return
							end
						end

						-- Débloquer le script
						if current:IsA("LuaSourceContainer") then
							unblockScriptModifications(current, path)
						end
					end
				end

				findAndUnblockScript(scriptPath)

				refreshLocks()
			else
				Log("❌ " .. (result.error or "Erreur"), Color3.fromRGB(255, 100, 100))
			end
		end
	end)

	return item
end

-- Flag pour éviter les appels concurrents
local isRefreshingLocks = false

-- Fonction pour rafraîchir la liste des locks
refreshLocks = function()
	-- Éviter les appels concurrents
	if isRefreshingLocks then return end
	isRefreshingLocks = true

	-- Vider TOUTE la liste (y compris les TextLabel)
	for _, child in ipairs(locksScroll:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	local success, response = pcall(function()
		return HttpService:GetAsync(SERVER_URL .. "/locks")
	end)

	if not success then
		Log("❌ Erreur chargement locks", Color3.fromRGB(255, 100, 100))
		isRefreshingLocks = false
		return
	end

	local data = HttpService:JSONDecode(response)
	local locks = data.locks or {}

	-- Mettre à jour le cache des locks
	lockedScripts = locks

	local count = 0
	for path, info in pairs(locks) do
		count = count + 1
	end

	if count == 0 then
		local noLocksLabel = Instance.new("TextLabel", locksScroll)
		noLocksLabel.Size = UDim2.new(1, -8, 0, 30)
		noLocksLabel.BackgroundTransparency = 1
		noLocksLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		noLocksLabel.Font = Enum.Font.SourceSans
		noLocksLabel.TextSize = 12
		noLocksLabel.Text = "✅ Aucun script verrouillé"
		locksScroll.CanvasSize = UDim2.new(0, 0, 0, 40)
		Log("🔓 Aucun lock actif", Color3.fromRGB(100, 255, 100))
	else
		local totalHeight = 8
		local index = 1
		for path, info in pairs(locks) do
			local item = createLockItem(path, info, index)
			item.Parent = locksScroll
			totalHeight = totalHeight + 37
			index = index + 1
		end
		locksScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
		Log("🔒 " .. count .. " script(s) verrouillé(s)", Color3.fromRGB(255, 200, 100))
	end

	isRefreshingLocks = false
end

-- Boucle périodique pour vérifier les locks toutes les 5 secondes
-- Vérification périodique des locks (TOUJOURS actif, même sans auto-save)
task.spawn(function()
	while true do
		task.wait(5) -- Vérifier toutes les 5 secondes
		-- Toujours vérifier les locks pour que TOUS les utilisateurs voient les verrouillages
		checkAndApplyLocks()
	end
end)

btnRefreshLocks.MouseButton1Click:Connect(refreshLocks)

-- Verrouiller le script sélectionné dans le Studio
btnLockSelected.MouseButton1Click:Connect(function()
	local userName = userNameInput.Text
	if userName == "" then
		Log("❌ Entrez votre nom d'abord!", Color3.fromRGB(255, 100, 100))
		return
	end

	-- Récupérer la sélection dans le Studio
	local selection = game:GetService("Selection"):Get()
	if #selection == 0 then
		Log("❌ Sélectionnez un script dans l'Explorer", Color3.fromRGB(255, 100, 100))
		return
	end

	local lockedCount = 0
	for _, obj in ipairs(selection) do
		if obj:IsA("LuaSourceContainer") then
			-- Calculer le chemin
			local path = obj.Name .. ".lua"
			local current = obj.Parent
			while current and current ~= game do
				path = current.Name .. "/" .. path
				current = current.Parent
			end

			-- Verrouiller
			local success, response = pcall(function()
				return HttpService:PostAsync(
					SERVER_URL .. "/lock",
					HttpService:JSONEncode({
						scriptPath = path,
						user = userName,
						machine = "RobloxStudio"
					}),
					Enum.HttpContentType.ApplicationJson
				)
			end)

			if success then
				local result = HttpService:JSONDecode(response)
				if result.success then
					lockedCount = lockedCount + 1
					print("🔒 Verrouillé:", path)
				elseif result.error == "already_locked" then
					Log("⚠️ Déjà verrouillé par " .. result.lockedBy, Color3.fromRGB(255, 200, 100))
				end
			end
		end
	end

	if lockedCount > 0 then
		Log("🔒 " .. lockedCount .. " script(s) verrouillé(s)", Color3.fromRGB(255, 150, 50))
		refreshLocks()
	end
end)

----------------------------------------------------------------------------------
-- DIFF VISUEL DÉTAILLÉ
----------------------------------------------------------------------------------

-- Widget pour afficher le diff détaillé
local diffWidget = plugin:CreateDockWidgetPluginGui(
	"DiffViewerUI",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 700, 500, 600, 400)
)
diffWidget.Title = "📊 Diff Détaillé"

local diffGui = Instance.new("Frame", diffWidget)
diffGui.Size = UDim2.fromScale(1, 1)
diffGui.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

-- Header avec le nom du fichier
local diffHeader = Instance.new("Frame", diffGui)
diffHeader.Size = UDim2.new(1, 0, 0, 40)
diffHeader.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

local diffTitle = Instance.new("TextLabel", diffHeader)
diffTitle.Size = UDim2.new(1, -10, 1, 0)
diffTitle.Position = UDim2.new(0, 5, 0, 0)
diffTitle.BackgroundTransparency = 1
diffTitle.TextColor3 = Color3.new(1, 1, 1)
diffTitle.Font = Enum.Font.SourceSansBold
diffTitle.TextSize = 14
diffTitle.Text = "📊 Comparaison: ..."
diffTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Résumé des changements
local diffSummary = Instance.new("TextLabel", diffHeader)
diffSummary.Size = UDim2.new(0.4, 0, 1, 0)
diffSummary.Position = UDim2.new(0.6, 0, 0, 0)
diffSummary.BackgroundTransparency = 1
diffSummary.TextColor3 = Color3.fromRGB(180, 180, 180)
diffSummary.Font = Enum.Font.SourceSans
diffSummary.TextSize = 11
diffSummary.Text = ""
diffSummary.TextXAlignment = Enum.TextXAlignment.Right

-- Container pour les deux colonnes (regroupé dans une table pour éviter la limite de 200 locals)
local DiffColumns = {}
DiffColumns.frame = Instance.new("Frame", diffGui)
DiffColumns.frame.Size = UDim2.new(1, 0, 1, -40)
DiffColumns.frame.Position = UDim2.new(0, 0, 0, 40)
DiffColumns.frame.BackgroundTransparency = 1

-- Colonne gauche (Roblox/Original)
DiffColumns.leftColumn = Instance.new("Frame", DiffColumns.frame)
DiffColumns.leftColumn.Size = UDim2.new(0.5, -2, 1, 0)
DiffColumns.leftColumn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

DiffColumns.leftHeader = Instance.new("TextLabel", DiffColumns.leftColumn)
DiffColumns.leftHeader.Size = UDim2.new(1, 0, 0, 25)
DiffColumns.leftHeader.BackgroundColor3 = Color3.fromRGB(50, 80, 50)
DiffColumns.leftHeader.TextColor3 = Color3.new(1, 1, 1)
DiffColumns.leftHeader.Font = Enum.Font.SourceSansBold
DiffColumns.leftHeader.TextSize = 12
DiffColumns.leftHeader.Text = "📗 ROBLOX"

DiffColumns.leftScroll = Instance.new("ScrollingFrame", DiffColumns.leftColumn)
DiffColumns.leftScroll.Size = UDim2.new(1, 0, 1, -25)
DiffColumns.leftScroll.Position = UDim2.new(0, 0, 0, 25)
DiffColumns.leftScroll.BackgroundTransparency = 1
DiffColumns.leftScroll.ScrollBarThickness = 6
DiffColumns.leftScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

DiffColumns.leftLayout = Instance.new("UIListLayout", DiffColumns.leftScroll)
DiffColumns.leftLayout.Padding = UDim.new(0, 0)

-- Colonne droite (Disque/Nouveau)
DiffColumns.rightColumn = Instance.new("Frame", DiffColumns.frame)
DiffColumns.rightColumn.Size = UDim2.new(0.5, -2, 1, 0)
DiffColumns.rightColumn.Position = UDim2.new(0.5, 2, 0, 0)
DiffColumns.rightColumn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

DiffColumns.rightHeader = Instance.new("TextLabel", DiffColumns.rightColumn)
DiffColumns.rightHeader.Size = UDim2.new(1, 0, 0, 25)
DiffColumns.rightHeader.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
DiffColumns.rightHeader.TextColor3 = Color3.new(1, 1, 1)
DiffColumns.rightHeader.Font = Enum.Font.SourceSansBold
DiffColumns.rightHeader.TextSize = 12
DiffColumns.rightHeader.Text = "💾 DISQUE"

DiffColumns.rightScroll = Instance.new("ScrollingFrame", DiffColumns.rightColumn)
DiffColumns.rightScroll.Size = UDim2.new(1, 0, 1, -25)
DiffColumns.rightScroll.Position = UDim2.new(0, 0, 0, 25)
DiffColumns.rightScroll.BackgroundTransparency = 1
DiffColumns.rightScroll.ScrollBarThickness = 6
DiffColumns.rightScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

DiffColumns.rightLayout = Instance.new("UIListLayout", DiffColumns.rightScroll)
DiffColumns.rightLayout.Padding = UDim.new(0, 0)

-- Synchroniser le scroll des deux colonnes
DiffColumns.leftScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	DiffColumns.rightScroll.CanvasPosition = DiffColumns.leftScroll.CanvasPosition
end)
DiffColumns.rightScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	DiffColumns.leftScroll.CanvasPosition = DiffColumns.rightScroll.CanvasPosition
end)

-- Fonction pour créer une ligne de diff
local function createDiffLine(lineNum, content, diffType, side)
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 18)
	line.BorderSizePixel = 0

	-- Couleur selon le type
	if diffType == "added" then
		line.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
	elseif diffType == "removed" then
		line.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
	elseif diffType == "modified" then
		line.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
	else
		line.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	end

	-- Numéro de ligne
	local lineNumLabel = Instance.new("TextLabel", line)
	lineNumLabel.Size = UDim2.new(0, 35, 1, 0)
	lineNumLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	lineNumLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
	lineNumLabel.Font = Enum.Font.Code
	lineNumLabel.TextSize = 10
	lineNumLabel.Text = tostring(lineNum)
	lineNumLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- Indicateur de changement
	local indicator = Instance.new("TextLabel", line)
	indicator.Size = UDim2.new(0, 15, 1, 0)
	indicator.Position = UDim2.new(0, 35, 0, 0)
	indicator.BackgroundTransparency = 1
	indicator.Font = Enum.Font.SourceSansBold
	indicator.TextSize = 12

	if diffType == "added" then
		indicator.Text = "+"
		indicator.TextColor3 = Color3.fromRGB(100, 255, 100)
	elseif diffType == "removed" then
		indicator.Text = "-"
		indicator.TextColor3 = Color3.fromRGB(255, 100, 100)
	elseif diffType == "modified" then
		indicator.Text = "~"
		indicator.TextColor3 = Color3.fromRGB(255, 255, 100)
	else
		indicator.Text = ""
	end

	-- Contenu de la ligne
	local contentLabel = Instance.new("TextLabel", line)
	contentLabel.Size = UDim2.new(1, -55, 1, 0)
	contentLabel.Position = UDim2.new(0, 52, 0, 0)
	contentLabel.BackgroundTransparency = 1
	contentLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	contentLabel.Font = Enum.Font.Code
	contentLabel.TextSize = 11
	contentLabel.Text = content or ""
	contentLabel.TextXAlignment = Enum.TextXAlignment.Left
	contentLabel.TextTruncate = Enum.TextTruncate.AtEnd

	return line
end

-- Fonction pour afficher le diff détaillé
local function showDetailedDiff(scriptPath, robloxContent, diskContent)
	diffTitle.Text = "📊 " .. scriptPath

	-- Vider les colonnes
	for _, child in ipairs(DiffColumns.leftScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for _, child in ipairs(DiffColumns.rightScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	-- Demander le diff au serveur
	local success, response = pcall(function()
		return HttpService:PostAsync(
			SERVER_URL .. "/compute-diff",
			HttpService:JSONEncode({
				content1 = robloxContent,
				content2 = diskContent,
				path1 = "Roblox",
				path2 = "Disque"
			}),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if not success then
		Log("❌ Erreur calcul diff", Color3.fromRGB(255, 100, 100))
		return
	end

	local data = HttpService:JSONDecode(response)
	local diff = data.diff or {}
	local summary = data.summary or {}

	-- Afficher le résumé
	diffSummary.Text = string.format("+%d  -%d  ~%d", 
		summary.added or 0, 
		summary.removed or 0, 
		summary.modified or 0
	)

	-- Créer les lignes de diff
	local leftLineNum = 0
	local rightLineNum = 0
	local totalHeight = 0

	for i, entry in ipairs(diff) do
		if entry.type == "unchanged" then
			leftLineNum = leftLineNum + 1
			rightLineNum = rightLineNum + 1

			local leftLine = createDiffLine(leftLineNum, entry.content, "unchanged", "left")
			leftLine.LayoutOrder = i
			leftLine.Parent = DiffColumns.leftScroll

			local rightLine = createDiffLine(rightLineNum, entry.content, "unchanged", "right")
			rightLine.LayoutOrder = i
			rightLine.Parent = DiffColumns.rightScroll

		elseif entry.type == "added" then
			rightLineNum = rightLineNum + 1

			-- Ligne vide à gauche
			local leftLine = createDiffLine("", "", "removed", "left")
			leftLine.LayoutOrder = i
			leftLine.Parent = DiffColumns.leftScroll

			local rightLine = createDiffLine(rightLineNum, entry.content, "added", "right")
			rightLine.LayoutOrder = i
			rightLine.Parent = DiffColumns.rightScroll

		elseif entry.type == "removed" then
			leftLineNum = leftLineNum + 1

			local leftLine = createDiffLine(leftLineNum, entry.content, "removed", "left")
			leftLine.LayoutOrder = i
			leftLine.Parent = DiffColumns.leftScroll

			-- Ligne vide à droite
			local rightLine = createDiffLine("", "", "added", "right")
			rightLine.LayoutOrder = i
			rightLine.Parent = DiffColumns.rightScroll

		elseif entry.type == "modified" then
			leftLineNum = leftLineNum + 1
			rightLineNum = rightLineNum + 1

			local leftLine = createDiffLine(leftLineNum, entry.oldContent, "modified", "left")
			leftLine.LayoutOrder = i
			leftLine.Parent = DiffColumns.leftScroll

			local rightLine = createDiffLine(rightLineNum, entry.newContent, "modified", "right")
			rightLine.LayoutOrder = i
			rightLine.Parent = DiffColumns.rightScroll
		end

		totalHeight = totalHeight + 18
	end

	DiffColumns.leftScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
	DiffColumns.rightScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

	diffWidget.Enabled = true
end

-- Ajouter un bouton "Voir Diff" à la popup de conflit
local btnViewDiff = Instance.new("TextButton", scriptConflictGui)
btnViewDiff.Size = UDim2.new(0.5, -15, 0, 30)
btnViewDiff.Position = UDim2.new(0.25, 0, 0, 350)
btnViewDiff.Text = "📊 Voir le Diff Détaillé"
btnViewDiff.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
btnViewDiff.TextColor3 = Color3.new(1, 1, 1)
btnViewDiff.Font = Enum.Font.SourceSansBold
btnViewDiff.TextSize = 12
Instance.new("UICorner", btnViewDiff).CornerRadius = UDim.new(0, 6)

btnViewDiff.MouseButton1Click:Connect(function()
	if currentScriptConflict then
		showDetailedDiff(
			currentScriptConflict.path,
			currentScriptConflict.robloxContent,
			currentScriptConflict.diskContent
		)
	end
end)

-- Mettre à jour la taille du canvas pour le scroll (agrandi pour les nouvelles sections)
mainScroll.CanvasSize = UDim2.new(0, 0, 0, 2000)
