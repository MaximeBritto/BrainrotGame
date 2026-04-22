--[[
    BaseSystem.lua
    Gestion des bases et assignation aux joueurs
    
    Responsabilités:
    - Assigner une base libre à chaque joueur
    - Téléporter le joueur à sa base
    - Gérer les slots et placement de Brainrots
    - Débloquer les étages progressivement
    - Libérer la base quand le joueur quitte
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local Constants = require(Shared["Constants.module"])
local GameConfig = require(Config["GameConfig.module"])

-- Services (seront injectés)
local DataService = nil
local PlayerService = nil
local NetworkSetup = nil

local BaseSystem = {}
BaseSystem._initialized = false
BaseSystem._assignedBases = {} -- {[userId] = {Base = model, BaseIndex = number}}
BaseSystem._availableBases = {} -- Liste des indices de bases libres

--[[
    Initialise le système
    @param services: table - {DataService, PlayerService, NetworkSetup}
]]
function BaseSystem:Init(services)
    if self._initialized then
        warn("[BaseSystem] Déjà initialisé!")
        return
    end
    
    -- print("[BaseSystem] Initialisation...")
    
    -- Récupérer les services
    DataService = services.DataService
    PlayerService = services.PlayerService
    NetworkSetup = services.NetworkSetup
    
    -- Initialiser les bases disponibles
    self:_InitializeBases()
    
    self._initialized = true
    -- print("[BaseSystem] Initialisé! Bases disponibles: " .. #self._availableBases)
end

--[[
    Initialise la liste des bases disponibles
]]
function BaseSystem:_InitializeBases()
    local workspace = game:GetService("Workspace")
    local basesFolder = workspace:FindFirstChild(Constants.WorkspaceNames.BasesFolder)
    
    if not basesFolder then
        warn("[BaseSystem] Dossier Bases introuvable dans Workspace!")
        return
    end
    
    -- Compter les bases disponibles
    for _, base in ipairs(basesFolder:GetChildren()) do
        if base:IsA("Model") and string.match(base.Name, "^Base_%d+$") then
            local baseIndex = tonumber(string.match(base.Name, "%d+"))
            if baseIndex then
                table.insert(self._availableBases, baseIndex)
            end
        end
    end
    
    table.sort(self._availableBases)

    -- Créer les labels "Empty" sur toutes les bases + cacher étages/slots non-défaut
    for _, base in ipairs(basesFolder:GetChildren()) do
        if base:IsA("Model") and string.match(base.Name, "^Base_%d+$") then
            self:_UpdateBaseLabel(base, "Empty")
            self:_ApplyDefaultVisibility(base)
        end
    end

    -- print("[BaseSystem] " .. #self._availableBases .. " base(s) trouvée(s)")
end

--[[
    Assigne une base libre à un joueur
    @param player: Player
    @return Model | nil - La base assignée, ou nil si aucune disponible
]]
function BaseSystem:AssignBase(player)
    -- print("[BaseSystem] AssignBase appelé pour " .. player.Name)
    
    -- Vérifier si le joueur a déjà une base
    if self._assignedBases[player.UserId] then
        warn("[BaseSystem] " .. player.Name .. " a déjà une base!")
        return self._assignedBases[player.UserId].Base
    end
    
    -- Vérifier s'il reste des bases
    if #self._availableBases == 0 then
        warn("[BaseSystem] Aucune base disponible pour " .. player.Name)
        return nil
    end
    
    -- Prendre la première base disponible
    local baseIndex = table.remove(self._availableBases, 1)
    -- print("[BaseSystem] Base index sélectionné: " .. baseIndex)
    
    -- Trouver le Model de la base
    local workspace = game:GetService("Workspace")
    local basesFolder = workspace:FindFirstChild(Constants.WorkspaceNames.BasesFolder)
    local baseModel = basesFolder:FindFirstChild("Base_" .. baseIndex)
    
    if not baseModel then
        warn("[BaseSystem] Base_" .. baseIndex .. " introuvable!")
        return nil
    end
    
    -- print("[BaseSystem] Base Model trouvé: " .. baseModel.Name)
    
    -- Assigner la base
    self._assignedBases[player.UserId] = {
        Base = baseModel,
        BaseIndex = baseIndex,
    }
    
    -- Attribut pour que le client trouve sa base (EconomyController, etc.)
    baseModel:SetAttribute("OwnerUserId", player.UserId)

    -- Afficher le nom du joueur au-dessus de la base
    self:_UpdateBaseLabel(baseModel, player.DisplayName)

    -- Afficher le multiplicateur par défaut (x1.0)
    self:UpdateMultiplierDisplay(baseModel, 1.0)

    -- Créer (ou réutiliser) le pad JumpShop de l'autre côté de la porte
    self:_EnsureJumpShop(baseModel)

    -- Mettre à jour les données runtime du joueur
    local runtimeData = PlayerService:GetRuntimeData(player)
    if runtimeData then
        runtimeData.AssignedBase = baseModel
        runtimeData.BaseIndex = baseIndex
        -- print("[BaseSystem] Runtime data mis à jour")
    end
    
    -- print("[BaseSystem] Base_" .. baseIndex .. " assignée à " .. player.Name)
    
    return baseModel
end

--[[
    Libère la base d'un joueur
    @param player: Player
]]
function BaseSystem:ReleaseBase(player)
    local assignment = self._assignedBases[player.UserId]
    
    if not assignment then
        return
    end
    
    -- Nettoyer les Brainrots visuels de la base
    self:_CleanupBaseBrainrots(assignment.Base)

    -- Retirer l'attribut pour que le client ne prenne plus cette base
    assignment.Base:SetAttribute("OwnerUserId", nil)

    -- Remettre le label à "Empty"
    self:_UpdateBaseLabel(assignment.Base, "Empty")

    -- Cacher les étages/slots non-défaut pour que la base redevienne visuellement "vide"
    self:_ApplyDefaultVisibility(assignment.Base)

    -- Masquer le multiplicateur
    local doorFolder = assignment.Base:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
    if doorFolder then
        local multBillboard = doorFolder:FindFirstChild("MultiplierBillboard")
        if multBillboard then
            multBillboard:Destroy()
        end
    end

    -- Remettre la base dans les disponibles
    table.insert(self._availableBases, assignment.BaseIndex)
    table.sort(self._availableBases)
    
    -- Retirer de la table des assignations
    self._assignedBases[player.UserId] = nil
    
    -- print("[BaseSystem] Base_" .. assignment.BaseIndex .. " libérée par " .. player.Name)
end

--[[
    Récupère la base d'un joueur
    @param player: Player
    @return Model | nil
]]
function BaseSystem:GetPlayerBase(player)
    local assignment = self._assignedBases[player.UserId]
    return assignment and assignment.Base or nil
end

--[[
    Téléporte le joueur à sa base
    @param player: Player
    @return boolean - true si succès
]]
function BaseSystem:SpawnPlayerAtBase(player)
    -- print("[BaseSystem] SpawnPlayerAtBase appelé pour " .. player.Name)
    
    local base = self:GetPlayerBase(player)
    
    if not base then
        warn("[BaseSystem] " .. player.Name .. " n'a pas de base assignée!")
        return false
    end
    
    -- print("[BaseSystem] Base trouvée: " .. base.Name)
    
    local spawnPoint = base:FindFirstChild(Constants.WorkspaceNames.SpawnPoint)
    
    if not spawnPoint then
        warn("[BaseSystem] SpawnPoint introuvable dans " .. base.Name)
        return false
    end
    
    -- print("[BaseSystem] SpawnPoint trouvé: " .. spawnPoint.Name)
    
    -- Attendre que le personnage soit prêt
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)

    if not humanoidRootPart then
        warn("[BaseSystem] HumanoidRootPart introuvable pour " .. player.Name)
        return false
    end

    -- Construire une CFrame upright (yaw seul du SpawnPoint) pour éviter
    -- que le personnage hérite d'un tilt qui le ferait clip dans le sol.
    local topOffset = (spawnPoint:IsA("BasePart") and spawnPoint.Size.Y / 2 or 0) + 3
    local targetPos = spawnPoint.Position + Vector3.new(0, topOffset, 0)
    local lookV = spawnPoint.CFrame.LookVector
    local flatLook = Vector3.new(lookV.X, 0, lookV.Z)
    if flatLook.Magnitude < 0.01 then
        flatLook = Vector3.new(0, 0, -1)
    else
        flatLook = flatLook.Unit
    end
    local targetCFrame = CFrame.lookAt(targetPos, targetPos + flatLook)

    -- PivotTo déplace atomiquement tout le modèle (HRP + parts liées) en une seule étape
    character:PivotTo(targetCFrame)

    -- Zéro les vélocités pour ne pas conserver la chute accumulée avant le téléport,
    -- sinon le personnage peut traverser le sol à l'atterrissage.
    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    humanoidRootPart.AssemblyAngularVelocity = Vector3.zero

    return true
end

--[[
    Récupère le premier slot libre dans la base d'un joueur
    @param player: Player
    @return number | nil - Index du slot libre (1-30), ou nil si tous occupés
]]
function BaseSystem:GetFirstFreeSlot(player)
    local playerData = DataService:GetPlayerData(player)
    
    if not playerData then
        return nil
    end
    
    -- Parcourir les slots de 1 à OwnedSlots
    for i = 1, playerData.OwnedSlots do
        if not playerData.PlacedBrainrots[i] then
            return i
        end
    end
    
    return nil
end

--[[
    Place un Brainrot sur un slot
    @param player: Player
    @param slotIndex: number - Index du slot (1-30)
    @param brainrotData: table - {Name, HeadSet, BodySet, LegsSet, CreatedAt}
    @return boolean - true si succès
]]
function BaseSystem:PlaceBrainrotOnSlot(player, slotIndex, brainrotData)
    local base = self:GetPlayerBase(player)
    
    if not base then
        warn("[BaseSystem] Pas de base pour " .. player.Name)
        return false
    end
    
    -- Trouver le slot
    local slotsFolder = base:FindFirstChild(Constants.WorkspaceNames.SlotsFolder)
    if not slotsFolder then
        warn("[BaseSystem] Dossier Slots introuvable!")
        return false
    end
    
    local slot = slotsFolder:FindFirstChild("Slot_" .. slotIndex)
    if not slot then
        warn("[BaseSystem] Slot_" .. slotIndex .. " introuvable!")
        return false
    end
    
    -- Retirer l'ancien Brainrot visuel sur ce slot (évite les doublons)
    for _, child in ipairs(slot:GetChildren()) do
        if child:IsA("Model") and child.Name:match("^Brainrot_") then
            child:Destroy()
        end
    end
    
    -- Créer le Model visuel du Brainrot
    local brainrotModel = self:_CreateBrainrotModel(brainrotData)
    
    -- Positionner sur le slot
    local platform = slot:FindFirstChild(Constants.WorkspaceNames.SlotPlatform)
    if platform then
        brainrotModel:SetPrimaryPartCFrame(platform.CFrame + Vector3.new(0, 2, 0))
    end
    
    brainrotModel.Parent = slot
    
    -- Sauvegarder dans les données
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return false end
    if not playerData.PlacedBrainrots then playerData.PlacedBrainrots = {} end
    playerData.PlacedBrainrots[slotIndex] = brainrotData
    DataService:UpdateValue(player, "PlacedBrainrots", playerData.PlacedBrainrots)
    
    -- print("[BaseSystem] Brainrot placé sur Slot_" .. slotIndex .. " pour " .. player.Name)
    
    -- Vérifier déblocage d'étage
    self:CheckFloorUnlock(player)
    
    return true
end

--[[
    Vérifie et débloque les étages si nécessaire
    @param player: Player
    @return number | nil - Numéro de l'étage débloqué, ou nil
]]
function BaseSystem:CheckFloorUnlock(player)
    local playerData = DataService:GetPlayerData(player)
    local base = self:GetPlayerBase(player)
    
    if not playerData or not base then
        return nil
    end
    
    local ownedSlots = playerData.OwnedSlots
    local floorsFolder = base:FindFirstChild(Constants.WorkspaceNames.FloorsFolder)
    
    if not floorsFolder then
        return nil
    end
    
    -- Vérifier chaque seuil de déblocage
    for floorNum, threshold in pairs(GameConfig.Base.FloorUnlockThresholds) do
        if ownedSlots == threshold then
            local floor = floorsFolder:FindFirstChild("Floor_" .. floorNum)
            if floor then
                self:_SetFloorVisible(floor, true)
                local remotes = NetworkSetup:GetAllRemotes()
                if remotes and remotes.Notification then
                    remotes.Notification:FireClient(player, {
                        Type = "Success",
                        Message = "Floor " .. floorNum .. " unlocked!",
                        Duration = 3,
                    })
                end
                -- print("[BaseSystem] Floor_" .. floorNum .. " débloqué pour " .. player.Name)
                return floorNum
            end
        end
    end
    
    return nil
end

--[[
    Applique la visibilité par défaut d'une base non-assignée :
    seuls Floor_0 et les slots 1..StartingSlots sont visibles.
    @param baseModel: Model
]]
function BaseSystem:_ApplyDefaultVisibility(baseModel)
    local startingSlots = GameConfig.Base.StartingSlots

    local floorsFolder = baseModel:FindFirstChild(Constants.WorkspaceNames.FloorsFolder)
    if floorsFolder then
        for floorNum, _threshold in pairs(GameConfig.Base.FloorUnlockThresholds) do
            local floor = floorsFolder:FindFirstChild("Floor_" .. floorNum)
            if floor then
                self:_SetFloorVisible(floor, false)
            end
        end
    end

    local slotsFolder = baseModel:FindFirstChild(Constants.WorkspaceNames.SlotsFolder)
    if slotsFolder then
        for _, slot in ipairs(slotsFolder:GetChildren()) do
            local num = slot.Name:match("^Slot_(%d+)$")
            if num then
                local slotIndex = tonumber(num)
                self:_SetFloorVisible(slot, slotIndex <= startingSlots)
            end
        end
    end
end

--[[
    Réapplique la visibilité des étages selon OwnedSlots (sauvegardé).
    À appeler au chargement du joueur / spawn pour que les étages débloqués restent visibles après reconnexion.
    @param player: Player
]]
function BaseSystem:ApplyFloorVisibility(player)
    local base = self:GetPlayerBase(player)
    if not base then return end
    
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return end
    
    local ownedSlots = playerData.OwnedSlots or GameConfig.Base.StartingSlots
    local floorsFolder = base:FindFirstChild(Constants.WorkspaceNames.FloorsFolder)
    if not floorsFolder then return end
    
    for floorNum, threshold in pairs(GameConfig.Base.FloorUnlockThresholds) do
        if ownedSlots >= threshold then
            local floor = floorsFolder:FindFirstChild("Floor_" .. floorNum)
            if floor then
                self:_SetFloorVisible(floor, true)
            end
        end
    end
end

--[[
    Réapplique la visibilité des slots selon OwnedSlots (slots 1..ownedSlots visibles, reste cachés).
    À appeler au chargement du joueur et après chaque achat de slot.
    @param player: Player
]]
function BaseSystem:ApplySlotVisibility(player)
    local base = self:GetPlayerBase(player)
    if not base then return end
    
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return end
    
    local ownedSlots = playerData.OwnedSlots or GameConfig.Base.StartingSlots
    local slotsFolder = base:FindFirstChild(Constants.WorkspaceNames.SlotsFolder)
    if not slotsFolder then return end
    
    for _, slot in ipairs(slotsFolder:GetChildren()) do
        local num = slot.Name:match("^Slot_(%d+)$")
        if num then
            local slotIndex = tonumber(num)
            local visible = (slotIndex <= ownedSlots)
            self:_SetFloorVisible(slot, visible)
        end
    end
end

--[[
    Débloque et affiche un étage dans la base du joueur (appelé par EconomySystem à l'achat du slot).
    @param player: Player
    @param floorNum: number - Numéro de l'étage (1 = Floor_1, 2 = Floor_2)
    @return boolean - true si l'étage a été affiché
]]
function BaseSystem:UnlockFloor(player, floorNum)
    local base = self:GetPlayerBase(player)
    if not base then return false end
    
    local floorsFolder = base:FindFirstChild(Constants.WorkspaceNames.FloorsFolder)
    if not floorsFolder then
        warn("[BaseSystem] Floors folder not found in base " .. base.Name)
        return false
    end
    
    local floor = floorsFolder:FindFirstChild("Floor_" .. floorNum)
    if not floor then
        warn("[BaseSystem] Floor_" .. floorNum .. " not found in " .. floorsFolder:GetFullName())
        return false
    end
    
    self:_SetFloorVisible(floor, true)
    -- print("[BaseSystem] Floor_" .. floorNum .. " unlocked (visible) for " .. player.Name)
    return true
end

--[[
    Rend un étage visible ou invisible (Part unique ou Model avec plusieurs Parts).
    @param floor: Instance - Part, Model ou Folder contenant des BaseParts
    @param visible: boolean
]]
function BaseSystem:_SetFloorVisible(floor, visible)
    if floor:IsA("BasePart") then
        floor.Transparency = visible and 0 or 1
        floor.CanCollide = visible
        return
    end

    if floor:IsA("Model") or floor:IsA("Folder") then
        for _, desc in ipairs(floor:GetDescendants()) do
            if self:_IsInsideBrainrotModel(desc) then
                -- Skip: managed by BrainrotModelSystem
            elseif desc:IsA("BasePart") then
                desc.Transparency = visible and 0 or 1
                desc.CanCollide = visible
            elseif desc:IsA("SurfaceGui") or desc:IsA("BillboardGui") then
                desc.Enabled = visible
            elseif desc:IsA("Decal") or desc:IsA("Texture") then
                desc.Transparency = visible and 0 or 1
            end
        end
        return
    end

    -- Fallback: un seul enfant Part
    for _, child in ipairs(floor:GetChildren()) do
        self:_SetFloorVisible(child, visible)
    end
end

--[[
    Checks if a part is inside a Brainrot model (should not be affected by slot visibility).
    @param part: BasePart
    @return boolean
]]
function BaseSystem:_IsInsideBrainrotModel(part)
    local current = part.Parent
    while current do
        if current:IsA("Model") and current.Name:match("^Brainrot_") then
            return true
        end
        current = current.Parent
    end
    return false
end

--[[
    Compte le nombre de Brainrots placés dans la base
    @param player: Player
    @return number
]]
function BaseSystem:GetPlacedBrainrotCount(player)
    local playerData = DataService:GetPlayerData(player)
    
    if not playerData or not playerData.PlacedBrainrots then
        return 0
    end
    
    local count = 0
    for _ in pairs(playerData.PlacedBrainrots) do
        count = count + 1
    end
    
    return count
end

--[[
    Crée le Model visuel d'un Brainrot
    @param brainrotData: table
    @return Model
]]
function BaseSystem:_CreateBrainrotModel(brainrotData)
    -- TODO Phase 5: Créer le vrai modèle avec les meshes
    -- Pour l'instant, créer un placeholder
    
    local model = Instance.new("Model")
    model.Name = "Brainrot_" .. brainrotData.Name
    
    local part = Instance.new("Part")
    part.Name = "PrimaryPart"
    part.Size = Vector3.new(2, 4, 2)
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.Random()
    part.Parent = model
    
    model.PrimaryPart = part
    
    return model
end

--[[
    Crée ou met à jour le BillboardGui au-dessus d'une base avec le nom du propriétaire
    @param baseModel: Model - La base
    @param text: string - Texte à afficher (nom du joueur ou "Empty")
]]
function BaseSystem:_UpdateBaseLabel(baseModel, text)
    -- Trouver la porte pour positionner le label au-dessus
    local doorFolder = baseModel:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
    if not doorFolder then return end

    local bars = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorBars)
    if not bars then return end

    -- Créer ou réutiliser un Part invisible centré sur la porte comme ancre
    local anchor = doorFolder:FindFirstChild("_LabelAnchor")
    if not anchor then
        anchor = Instance.new("Part")
        anchor.Name = "_LabelAnchor"
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.Transparency = 1
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false

        -- Calculer le centre de la porte
        if bars:IsA("Model") then
            local cf, size = bars:GetBoundingBox()
            anchor.CFrame = cf
        elseif bars:IsA("BasePart") then
            anchor.CFrame = bars.CFrame
        end

        anchor.Parent = doorFolder
    end

    local billboard = doorFolder:FindFirstChild("OwnerBillboard")
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "OwnerBillboard"
        billboard.Adornee = anchor
        billboard.Size = UDim2.new(14, 0, 3, 0)
        billboard.StudsOffset = Vector3.new(0, 8, 0)
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.MaxDistance = 100
        billboard.Parent = doorFolder

        local label = Instance.new("TextLabel")
        label.Name = "NameLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.3
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Parent = billboard
    end

    local label = billboard:FindFirstChild("NameLabel")
    if label then
        label.Text = text
        label.TextColor3 = (text == "Empty")
            and Color3.fromRGB(150, 150, 150)
            or Color3.fromRGB(255, 255, 255)
    end
end

--[[
    Renvoie la position monde d'un Model ou BasePart (centre/pivot).
    @return Vector3 | nil
]]
function BaseSystem:_GetInstancePosition(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then
        return instance.Position
    elseif instance:IsA("Model") then
        local ok, cf = pcall(function() return instance:GetPivot() end)
        if ok and cf then
            return cf.Position
        end
        if instance.PrimaryPart then
            return instance.PrimaryPart.Position
        end
        local okBB, cf2 = pcall(function()
            local c, _ = instance:GetBoundingBox()
            return c
        end)
        if okBB and cf2 then
            return cf2.Position
        end
    end
    return nil
end

--[[
    Translate un Model ou BasePart d'un offset donné (en monde).
]]
function BaseSystem:_TranslateInstance(instance, offset)
    if not instance or not offset then return end
    if instance:IsA("BasePart") then
        instance.CFrame = instance.CFrame + offset
    elseif instance:IsA("Model") then
        local ok, pivot = pcall(function() return instance:GetPivot() end)
        if ok and pivot then
            instance:PivotTo(pivot + offset)
        elseif instance.PrimaryPart then
            instance:SetPrimaryPartCFrame(instance.PrimaryPart.CFrame + offset)
        end
    end
end

--[[
    Crée (ou réutilise) le pad JumpShop dans la base, en miroir du SlotShop
    par rapport au centre de la porte.
    @param baseModel: Model
    @return Instance | nil - Le JumpShop
]]
function BaseSystem:_EnsureJumpShop(baseModel)
    if not baseModel then return nil end

    -- Déjà présent (placé manuellement ou créé précédemment) → rien à faire
    local existing = baseModel:FindFirstChild(Constants.WorkspaceNames.JumpShop)
    if existing then
        self:_ConfigureJumpShopVisuals(existing)
        return existing
    end

    local slotShop = baseModel:FindFirstChild(Constants.WorkspaceNames.SlotShop)
    if not slotShop then
        -- Pas de SlotShop de référence : on ne peut pas calculer la position miroir
        return nil
    end

    local doorFolder = baseModel:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
    local doorPos = nil
    if doorFolder then
        local anchor = doorFolder:FindFirstChild("_LabelAnchor")
        if anchor and anchor:IsA("BasePart") then
            doorPos = anchor.Position
        else
            local bars = doorFolder:FindFirstChild(Constants.WorkspaceNames.DoorBars)
            doorPos = self:_GetInstancePosition(bars)
        end
    end

    local slotShopPos = self:_GetInstancePosition(slotShop)
    if not doorPos or not slotShopPos then
        return nil
    end

    -- Centre de la base (pour la rotation tangentielle, base ronde)
    local baseCenter
    local spawnPoint = baseModel:FindFirstChild(Constants.WorkspaceNames.SpawnPoint)
    if spawnPoint and spawnPoint:IsA("BasePart") then
        baseCenter = spawnPoint.Position
    else
        local ok, cf = pcall(function() return baseModel:GetPivot() end)
        baseCenter = (ok and cf and cf.Position) or slotShopPos
    end
    baseCenter = Vector3.new(baseCenter.X, slotShopPos.Y, baseCenter.Z)

    -- Cloner le SlotShop pour réutiliser la même structure (Sign + Display + UI)
    local jumpShop = slotShop:Clone()
    jumpShop.Name = Constants.WorkspaceNames.JumpShop
    jumpShop.Parent = baseModel

    -- Miroir : nouvelle position = 2 * doorPos - slotShopPos, dans le plan XZ
    local slotShopPosFlat = Vector3.new(slotShopPos.X, slotShopPos.Y, slotShopPos.Z)
    local mirrorPos = Vector3.new(
        2 * doorPos.X - slotShopPos.X,
        slotShopPos.Y,
        2 * doorPos.Z - slotShopPos.Z
    )
    local offset = mirrorPos - slotShopPosFlat
    self:_TranslateInstance(jumpShop, offset)

    -- Base ronde : tourner le panneau de l'angle entre (centre → SlotShop) et
    -- (centre → JumpShop), pour qu'il reste tangent au mur circulaire.
    local vecSlot = Vector3.new(slotShopPos.X - baseCenter.X, 0, slotShopPos.Z - baseCenter.Z)
    local vecJump = Vector3.new(mirrorPos.X - baseCenter.X, 0, mirrorPos.Z - baseCenter.Z)
    if vecSlot.Magnitude > 0.01 and vecJump.Magnitude > 0.01 then
        local angleDelta = math.atan2(vecJump.X, vecJump.Z) - math.atan2(vecSlot.X, vecSlot.Z)
        self:_RotateInstanceY(jumpShop, angleDelta)
    end

    self:_ConfigureJumpShopVisuals(jumpShop)
    return jumpShop
end

--[[
    Fait pivoter un Model ou BasePart de `angle` radians autour de son propre
    axe Y (rotation sur place).
]]
function BaseSystem:_RotateInstanceY(instance, angle)
    if not instance or not angle then return end
    if instance:IsA("BasePart") then
        instance.CFrame = CFrame.new(instance.Position) * CFrame.Angles(0, angle, 0) * (instance.CFrame - instance.Position)
        return
    end
    if instance:IsA("Model") then
        local ok, pivot = pcall(function() return instance:GetPivot() end)
        if ok and pivot then
            local pos = pivot.Position
            local newPivot = CFrame.new(pos) * CFrame.Angles(0, angle, 0) * (pivot - pos)
            instance:PivotTo(newPivot)
        end
    end
end

--[[
    Adapte les visuels/prompts d'un JumpShop (cloné du SlotShop) pour qu'il
    affiche le contenu "multiplicateur de saut" au lieu de "slot".
]]
function BaseSystem:_ConfigureJumpShopVisuals(jumpShop)
    if not jumpShop then return end

    local sign = jumpShop:FindFirstChild(Constants.WorkspaceNames.SlotShopSign)
    if sign then
        local prompt = sign:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            prompt.ActionText = "Buy Jump"
            prompt.ObjectText = "Jump Multiplier"
            -- Maintenir E pendant 1s pour confirmer l'achat
            prompt.HoldDuration = 1
        end
    end

    local display = jumpShop:FindFirstChild(Constants.WorkspaceNames.SlotShopDisplay)
    if display then
        -- Remplacer tous les labels de titre (hors PriceLabel, qui est mis à
        -- jour dynamiquement par EconomyController) par un libellé jump.
        for _, desc in ipairs(display:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Name ~= "PriceLabel" then
                desc.Text = "Upgrade Jump"
            end
        end
    end
end

--[[
    Crée ou met à jour le BillboardGui du multiplicateur sur une base
    @param baseModel: Model - La base
    @param multiplier: number - Le multiplicateur à afficher (ex: 1.0, 1.5, 2.0)
]]
function BaseSystem:UpdateMultiplierDisplay(baseModel, multiplier)
    local doorFolder = baseModel:FindFirstChild(Constants.WorkspaceNames.DoorFolder)
    if not doorFolder then return end

    -- Réutiliser le _LabelAnchor créé par _UpdateBaseLabel
    local anchor = doorFolder:FindFirstChild("_LabelAnchor")
    if not anchor then return end

    local billboard = doorFolder:FindFirstChild("MultiplierBillboard")
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "MultiplierBillboard"
        billboard.Adornee = anchor
        billboard.Size = UDim2.new(8, 0, 2, 0)
        billboard.StudsOffset = Vector3.new(0, 5, 0)
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.MaxDistance = 100
        billboard.Parent = doorFolder

        local label = Instance.new("TextLabel")
        label.Name = "MultiplierLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.TextColor3 = Color3.fromRGB(255, 215, 0)
        label.TextStrokeTransparency = 0.3
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Parent = billboard
    end

    local label = billboard:FindFirstChild("MultiplierLabel")
    if label then
        local text = string.format("Multiplier x%.1f", multiplier)
        label.Text = text
        -- Couleur dorée si > 1, gris sinon
        if multiplier > 1 then
            label.TextColor3 = Color3.fromRGB(255, 215, 0)
        else
            label.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end
end

--[[
    Nettoie les Brainrots visuels d'une base
    @param base: Model
]]
function BaseSystem:_CleanupBaseBrainrots(base)
    local slotsFolder = base:FindFirstChild(Constants.WorkspaceNames.SlotsFolder)
    
    if not slotsFolder then
        return
    end
    
    for _, slot in ipairs(slotsFolder:GetChildren()) do
        for _, child in ipairs(slot:GetChildren()) do
            if child:IsA("Model") and string.match(child.Name, "^Brainrot_") then
                child:Destroy()
            end
        end
    end
end

return BaseSystem
