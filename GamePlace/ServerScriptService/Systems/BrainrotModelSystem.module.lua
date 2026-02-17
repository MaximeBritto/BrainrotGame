--[[
    BrainrotModelSystem.module.lua
    Gestion des modèles 3D de Brainrots dans les slots

    Responsabilités:
    - Assembler un modèle 3D de Brainrot (Head+Body+Legs via Attachments)
    - Créer un modèle 3D de Brainrot dans un slot
    - Détruire un modèle 3D de Brainrot
    - Gérer la visibilité (seul le propriétaire voit ses Brainrots)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BrainrotData = nil
local BaseSystem = nil

local BrainrotModelSystem = {}
BrainrotModelSystem._initialized = false
BrainrotModelSystem._models = {} -- [userId][slotIndex] = model

--[[
    Initialise le système de modèles Brainrot
    @param services: table - {BaseSystem}
]]
function BrainrotModelSystem:Init(services)
    if self._initialized then
        warn("[BrainrotModelSystem] Déjà initialisé!")
        return
    end

    BaseSystem = services.BaseSystem

    if not BaseSystem then
        error("[BrainrotModelSystem] BaseSystem manquant!")
    end

    -- Charger BrainrotData
    local Data = ReplicatedStorage:WaitForChild("Data")
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))

    self._initialized = true
end

--[[
    Assemble un modèle 3D de Brainrot à partir des templates (sans positionnement sur slot)
    Méthode réutilisable par CreateBrainrotModel et par StealSystem (porter en main)
    @param brainrotData: table - {HeadSet, BodySet, LegsSet}
    @return Model | nil, string | nil - Le modèle assemblé ou nil + nom du brainrot
]]
function BrainrotModelSystem:AssembleBrainrot(brainrotData)
    -- 1. Trouver les dossiers de templates
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        warn("[BrainrotModelSystem] Assets folder introuvable")
        return nil, nil
    end

    local templatesFolder = assetsFolder:FindFirstChild("BodyPartTemplates")
    if not templatesFolder then
        warn("[BrainrotModelSystem] BodyPartTemplates folder introuvable")
        return nil, nil
    end

    local headTemplateFolder = templatesFolder:FindFirstChild("HeadTemplate")
    local bodyTemplateFolder = templatesFolder:FindFirstChild("BodyTemplate")
    local legsTemplateFolder = templatesFolder:FindFirstChild("LegsTemplate")

    if not headTemplateFolder or not bodyTemplateFolder or not legsTemplateFolder then
        warn("[BrainrotModelSystem] Template folders manquants")
        return nil, nil
    end

    -- 2. Récupérer les noms de templates via BrainrotData
    local headSetData = BrainrotData.Sets[brainrotData.HeadSet]
    local bodySetData = BrainrotData.Sets[brainrotData.BodySet]
    local legsSetData = BrainrotData.Sets[brainrotData.LegsSet]

    if not headSetData or not bodySetData or not legsSetData then
        warn("[BrainrotModelSystem] SetData manquant pour un des sets")
        return nil, nil
    end

    local headTemplateName = headSetData.Head.TemplateName
    local bodyTemplateName = bodySetData.Body.TemplateName
    local legsTemplateName = legsSetData.Legs.TemplateName

    if not headTemplateName or headTemplateName == "" then
        warn("[BrainrotModelSystem] TemplateName manquant pour Head: " .. brainrotData.HeadSet)
        return nil, nil
    end
    if not bodyTemplateName or bodyTemplateName == "" then
        warn("[BrainrotModelSystem] TemplateName manquant pour Body: " .. brainrotData.BodySet)
        return nil, nil
    end
    if not legsTemplateName or legsTemplateName == "" then
        warn("[BrainrotModelSystem] TemplateName manquant pour Legs: " .. brainrotData.LegsSet)
        return nil, nil
    end

    -- 3. Cloner les templates
    local headTemplate = headTemplateFolder:FindFirstChild(headTemplateName)
    local bodyTemplate = bodyTemplateFolder:FindFirstChild(bodyTemplateName)
    local legsTemplate = legsTemplateFolder:FindFirstChild(legsTemplateName)

    if not headTemplate then
        warn("[BrainrotModelSystem] Head template introuvable: " .. headTemplateName)
        return nil, nil
    end
    if not bodyTemplate then
        warn("[BrainrotModelSystem] Body template introuvable: " .. bodyTemplateName)
        return nil, nil
    end
    if not legsTemplate then
        warn("[BrainrotModelSystem] Legs template introuvable: " .. legsTemplateName)
        return nil, nil
    end

    local headModel = headTemplate:Clone()
    local bodyModel = bodyTemplate:Clone()
    local legsModel = legsTemplate:Clone()

    -- 4. Extraire les PrimaryParts
    local headPart = headModel.PrimaryPart
    local bodyPart = bodyModel.PrimaryPart
    local legsPart = legsModel.PrimaryPart

    if not headPart or not bodyPart or not legsPart then
        warn("[BrainrotModelSystem] PrimaryParts manquants dans les templates")
        headModel:Destroy()
        bodyModel:Destroy()
        legsModel:Destroy()
        return nil, nil
    end

    -- 5. Créer le Model conteneur
    local brainrotName = headTemplateName .. " " .. bodyTemplateName .. " " .. legsTemplateName
    local model = Instance.new("Model")
    model.Name = "Brainrot_" .. brainrotName

    -- Parent toutes les parts au conteneur et supprimer les BillboardGui individuels
    for _, child in ipairs(headModel:GetChildren()) do
        child.Parent = model
        if child:IsA("BasePart") then
            local billboard = child:FindFirstChildOfClass("BillboardGui")
            if billboard then billboard:Destroy() end
        end
    end
    for _, child in ipairs(bodyModel:GetChildren()) do
        child.Parent = model
        if child:IsA("BasePart") then
            local billboard = child:FindFirstChildOfClass("BillboardGui")
            if billboard then billboard:Destroy() end
        end
    end
    for _, child in ipairs(legsModel:GetChildren()) do
        child.Parent = model
        if child:IsA("BasePart") then
            local billboard = child:FindFirstChildOfClass("BillboardGui")
            if billboard then billboard:Destroy() end
        end
    end

    -- Détruire les models vides
    headModel:Destroy()
    bodyModel:Destroy()
    legsModel:Destroy()

    -- 6. Positionner les Legs à l'origine
    legsPart.CFrame = CFrame.new(0, legsPart.Size.Y / 2, 0)
    legsPart.Anchored = false

    -- 7. Connecter Body → Legs via Attachments
    local bodyBottomAtt = bodyPart:FindFirstChild("BottomAttachment")
    local legsTopAtt = legsPart:FindFirstChild("TopAttachment")

    if bodyBottomAtt and legsTopAtt then
        bodyPart.CFrame = legsPart.CFrame * legsTopAtt.CFrame * bodyBottomAtt.CFrame:Inverse()
        bodyPart.Anchored = true

        local legsWeld = Instance.new("WeldConstraint")
        legsWeld.Part0 = bodyPart
        legsWeld.Part1 = legsPart
        legsWeld.Parent = legsPart
    else
        warn("[BrainrotModelSystem] Attachments manquants pour Body-Legs")
        local bodyBottomY = legsPart.Size.Y + bodyPart.Size.Y / 2
        bodyPart.CFrame = CFrame.new(0, bodyBottomY, 0)
        bodyPart.Anchored = true

        local legsWeld = Instance.new("WeldConstraint")
        legsWeld.Part0 = bodyPart
        legsWeld.Part1 = legsPart
        legsWeld.Parent = legsPart
    end

    -- 8. Connecter Head → Body via Attachments
    local headBottomAtt = headPart:FindFirstChild("BottomAttachment")
    local bodyTopAtt = bodyPart:FindFirstChild("TopAttachment")

    if headBottomAtt and bodyTopAtt then
        headPart.CFrame = bodyPart.CFrame * bodyTopAtt.CFrame * headBottomAtt.CFrame:Inverse()
        headPart.Anchored = false

        local headWeld = Instance.new("WeldConstraint")
        headWeld.Part0 = bodyPart
        headWeld.Part1 = headPart
        headWeld.Parent = headPart
    else
        warn("[BrainrotModelSystem] Attachments manquants pour Head-Body")
        local headOffset = bodyPart.Size.Y / 2 + headPart.Size.Y / 2
        headPart.CFrame = bodyPart.CFrame * CFrame.new(0, headOffset, 0)
        headPart.Anchored = false

        local headWeld = Instance.new("WeldConstraint")
        headWeld.Part0 = bodyPart
        headWeld.Part1 = headPart
        headWeld.Parent = headPart
    end

    -- 9. Définir le PrimaryPart
    model.PrimaryPart = bodyPart

    return model, brainrotName
end

--[[
    Crée un modèle 3D de Brainrot dans un slot
    @param player: Player
    @param slotIndex: number
    @param brainrotData: table - {SetName, SlotIndex, PlacedAt, HeadSet, BodySet, LegsSet}
    @return boolean - true si succès
]]
function BrainrotModelSystem:CreateBrainrotModel(player, slotIndex, brainrotData)
    -- 0. Détruire l'ancien modèle s'il existe (évite les doublons au respawn)
    if self._models[player.UserId] and self._models[player.UserId][slotIndex] then
        local oldModel = self._models[player.UserId][slotIndex]
        if oldModel and oldModel.Parent then
            oldModel:Destroy()
        end
        self._models[player.UserId][slotIndex] = nil
    end

    -- 1. Récupérer la base du joueur
    local base = BaseSystem:GetPlayerBase(player)
    if not base then
        warn("[BrainrotModelSystem] Base introuvable pour " .. player.Name)
        return false
    end

    -- 2. Trouver le slot et la platform
    local slotsFolder = base:FindFirstChild("Slots")
    if not slotsFolder then
        warn("[BrainrotModelSystem] Slots folder introuvable")
        return false
    end

    local slot = slotsFolder:FindFirstChild("Slot_" .. slotIndex)
    if not slot then
        warn("[BrainrotModelSystem] Slot_" .. slotIndex .. " introuvable")
        return false
    end

    local platform = slot:FindFirstChild("Platform")
    if not platform then
        warn("[BrainrotModelSystem] Platform introuvable dans Slot_" .. slotIndex)
        return false
    end

    -- 3. Assembler le modèle
    local model, brainrotName = self:AssembleBrainrot(brainrotData)
    if not model then
        return false
    end

    -- 4. Repositionner sur la plateforme du slot
    local bodyPart = model.PrimaryPart
    local legsPart = nil
    local headPart = nil

    -- Retrouver les parts (legs = celle avec TopAttachment sans BottomAttachment, ou la plus basse)
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

    -- Positionner les Legs sur la plateforme
    if legsPart then
        local platformTop = platform.Position.Y + platform.Size.Y / 2
        local legsBottomY = platformTop + legsPart.Size.Y / 2
        local platformRotation = platform.CFrame.Rotation

        local legsTopAtt = legsPart:FindFirstChild("TopAttachment")
        if legsTopAtt then
            local legsOrientation = legsTopAtt.CFrame.Rotation
            legsPart.CFrame = CFrame.new(platform.Position.X, legsBottomY, platform.Position.Z) * platformRotation * legsOrientation
        else
            legsPart.CFrame = CFrame.new(platform.Position.X, legsBottomY, platform.Position.Z) * platformRotation
        end

        -- Recalculer Body et Head via Attachments
        local bodyBottomAtt = bodyPart:FindFirstChild("BottomAttachment")
        local legsTopAtt2 = legsPart:FindFirstChild("TopAttachment")
        if bodyBottomAtt and legsTopAtt2 then
            bodyPart.CFrame = legsPart.CFrame * legsTopAtt2.CFrame * bodyBottomAtt.CFrame:Inverse()
        end

        if headPart then
            local headBottomAtt = headPart:FindFirstChild("BottomAttachment")
            local bodyTopAtt = bodyPart:FindFirstChild("TopAttachment")
            if headBottomAtt and bodyTopAtt then
                headPart.CFrame = bodyPart.CFrame * bodyTopAtt.CFrame * headBottomAtt.CFrame:Inverse()
            end
        end
    end

    -- 5. BillboardGui
    if not headPart then
        -- Trouver la head part par défaut (la plus haute)
        for _, part in ipairs(model:GetChildren()) do
            if part:IsA("BasePart") and part ~= bodyPart and part ~= legsPart then
                headPart = part
                break
            end
        end
    end

    local adornPart = headPart or bodyPart
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BrainrotInfo"
    billboard.Size = UDim2.new(0, 200, 0, 100)
    billboard.StudsOffset = Vector3.new(0, adornPart.Size.Y + 2, 0)
    billboard.AlwaysOnTop = false  -- Ne traverse plus les murs
    billboard.MaxDistance = 50      -- Visible seulement à 50 studs max
    billboard.Adornee = adornPart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = brainrotName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard

    -- Revenu total
    local headSetData = BrainrotData.Sets[brainrotData.HeadSet]
    local bodySetData = BrainrotData.Sets[brainrotData.BodySet]
    local legsSetData = BrainrotData.Sets[brainrotData.LegsSet]

    local totalRevenue = 0
    if headSetData and headSetData.Head then
        totalRevenue = totalRevenue + (headSetData.Head.Price or 0)
    end
    if bodySetData and bodySetData.Body then
        totalRevenue = totalRevenue + (bodySetData.Body.Price or 0)
    end
    if legsSetData and legsSetData.Legs then
        totalRevenue = totalRevenue + (legsSetData.Legs.Price or 0)
    end

    local revenueLabel = Instance.new("TextLabel")
    revenueLabel.Name = "RevenueLabel"
    revenueLabel.Size = UDim2.new(1, 0, 0.5, 0)
    revenueLabel.Position = UDim2.new(0, 0, 0.5, 0)
    revenueLabel.BackgroundTransparency = 1
    revenueLabel.Text = "$" .. totalRevenue .. "/s"
    revenueLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    revenueLabel.TextScaled = true
    revenueLabel.Font = Enum.Font.Gotham
    revenueLabel.Parent = billboard

    billboard.Parent = adornPart

    -- 6. Définir les attributs
    model:SetAttribute("SetName", brainrotData.SetName)
    model:SetAttribute("SlotIndex", slotIndex)
    model:SetAttribute("OwnerUserId", player.UserId)
    model:SetAttribute("HeadSet", brainrotData.HeadSet)
    model:SetAttribute("BodySet", brainrotData.BodySet)
    model:SetAttribute("LegsSet", brainrotData.LegsSet)

    -- 7. Appliquer la visibilité
    self:_ApplyOwnerVisibility(model, player.UserId)

    -- 8. ProximityPrompt pour vol de Brainrot
    local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        local proximityPrompt = Instance.new("ProximityPrompt")
        proximityPrompt.Name = "StealPrompt"
        proximityPrompt.ActionText = "Voler"
        proximityPrompt.ObjectText = "Brainrot"
        proximityPrompt.HoldDuration = 3
        proximityPrompt.MaxActivationDistance = 15
        proximityPrompt.RequiresLineOfSight = false
        proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
        proximityPrompt.Parent = primaryPart

        proximityPrompt:SetAttribute("OwnerId", player.UserId)
        proximityPrompt:SetAttribute("SlotId", slotIndex)

        print(string.format("[BrainrotModelSystem] ProximityPrompt ajouté au Brainrot de %d (slot %d)", player.UserId, slotIndex))
    end

    -- 9. Désactiver les collisions pour permettre de passer à travers
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    -- 10. Parent le modèle au slot
    model.Parent = slot

    -- 11. Stocker la référence
    if not self._models[player.UserId] then
        self._models[player.UserId] = {}
    end
    self._models[player.UserId][slotIndex] = model

    return true
end

--[[
    Détruit un modèle 3D de Brainrot
    @param player: Player
    @param slotIndex: number
    @return boolean - true si succès
]]
function BrainrotModelSystem:DestroyBrainrotModel(player, slotIndex)
    if not self._models[player.UserId] then
        return false
    end

    local model = self._models[player.UserId][slotIndex]
    if not model then
        return false
    end

    model:Destroy()
    self._models[player.UserId][slotIndex] = nil

    return true
end

--[[
    Récupère le modèle 3D d'un Brainrot
    @param player: Player
    @param slotIndex: number
    @return Model | nil
]]
function BrainrotModelSystem:GetBrainrotModel(player, slotIndex)
    if not self._models[player.UserId] then
        return nil
    end
    return self._models[player.UserId][slotIndex]
end

--[[
    Applique la visibilité par propriétaire
    @param model: Model
    @param ownerUserId: number
]]
function BrainrotModelSystem:_ApplyOwnerVisibility(model, ownerUserId)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.LocalTransparencyModifier = 0
        end
    end
end

return BrainrotModelSystem
