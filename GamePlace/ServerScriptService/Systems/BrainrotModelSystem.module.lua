--[[
    BrainrotModelSystem.module.lua
    Gestion des modèles 3D de Brainrots dans les slots
    
    Responsabilités:
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
    
    print("[BrainrotModelSystem] Initialisation...")
    
    BaseSystem = services.BaseSystem
    
    if not BaseSystem then
        error("[BrainrotModelSystem] BaseSystem manquant!")
    end
    
    -- Charger BrainrotData
    local Data = ReplicatedStorage:WaitForChild("Data")
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
    
    self._initialized = true
    print("[BrainrotModelSystem] Initialisé")
end

--[[
    Crée un modèle 3D de Brainrot dans un slot
    @param player: Player
    @param slotIndex: number
    @param brainrotData: table - {SetName, SlotIndex, PlacedAt}
    @return boolean - true si succès
]]
function BrainrotModelSystem:CreateBrainrotModel(player, slotIndex, brainrotData)
    -- 1. Récupérer la base du joueur
    local base = BaseSystem:GetPlayerBase(player)
    if not base then
        warn("[BrainrotModelSystem] Base introuvable pour " .. player.Name)
        return false
    end
    
    -- 2. Trouver le slot
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
    
    -- 3. Assembler le Brainrot à partir des templates avec Attachments
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        warn("[BrainrotModelSystem] Assets folder introuvable")
        return false
    end
    
    local templatesFolder = assetsFolder:FindFirstChild("BodyPartTemplates")
    if not templatesFolder then
        warn("[BrainrotModelSystem] BodyPartTemplates folder introuvable")
        return false
    end
    
    -- Récupérer les 3 templates
    local headTemplateFolder = templatesFolder:FindFirstChild("HeadTemplate")
    local bodyTemplateFolder = templatesFolder:FindFirstChild("BodyTemplate")
    local legsTemplateFolder = templatesFolder:FindFirstChild("LegsTemplate")
    
    if not headTemplateFolder or not bodyTemplateFolder or not legsTemplateFolder then
        warn("[BrainrotModelSystem] Template folders manquants")
        return false
    end
    
    -- Récupérer les modèles spécifiques via TemplateName de chaque pièce
    local headSetData = BrainrotData.Sets[brainrotData.HeadSet]
    local bodySetData = BrainrotData.Sets[brainrotData.BodySet]
    local legsSetData = BrainrotData.Sets[brainrotData.LegsSet]
    
    if not headSetData or not bodySetData or not legsSetData then
        warn("[BrainrotModelSystem] SetData manquant pour un des sets")
        return false
    end
    
    local headTemplateName = headSetData.Head.TemplateName
    local bodyTemplateName = bodySetData.Body.TemplateName
    local legsTemplateName = legsSetData.Legs.TemplateName
    
    if not headTemplateName or headTemplateName == "" then
        warn("[BrainrotModelSystem] TemplateName manquant pour Head: " .. brainrotData.HeadSet)
        return false
    end
    if not bodyTemplateName or bodyTemplateName == "" then
        warn("[BrainrotModelSystem] TemplateName manquant pour Body: " .. brainrotData.BodySet)
        return false
    end
    if not legsTemplateName or legsTemplateName == "" then
        warn("[BrainrotModelSystem] TemplateName manquant pour Legs: " .. brainrotData.LegsSet)
        return false
    end
    
    local headTemplate = headTemplateFolder:FindFirstChild(headTemplateName)
    local bodyTemplate = bodyTemplateFolder:FindFirstChild(bodyTemplateName)
    local legsTemplate = legsTemplateFolder:FindFirstChild(legsTemplateName)
    
    if not headTemplate then
        warn("[BrainrotModelSystem] Head template introuvable: " .. headTemplateName)
        return false
    end
    if not bodyTemplate then
        warn("[BrainrotModelSystem] Body template introuvable: " .. bodyTemplateName)
        return false
    end
    if not legsTemplate then
        warn("[BrainrotModelSystem] Legs template introuvable: " .. legsTemplateName)
        return false
    end
    
    -- Cloner les 3 templates
    local headModel = headTemplate:Clone()
    local bodyModel = bodyTemplate:Clone()
    local legsModel = legsTemplate:Clone()
    
    -- Extraire les PrimaryParts
    local headPart = headModel.PrimaryPart
    local bodyPart = bodyModel.PrimaryPart
    local legsPart = legsModel.PrimaryPart
    
    if not headPart or not bodyPart or not legsPart then
        warn("[BrainrotModelSystem] PrimaryParts manquants dans les templates")
        return false
    end
    
    -- Créer le Model conteneur avec nom concaténé des templates
    local model = Instance.new("Model")
    local brainrotName = headTemplateName .. " " .. bodyTemplateName .. " " .. legsTemplateName
    model.Name = "Brainrot_" .. brainrotName
    
    -- Parent toutes les parts au conteneur et supprimer les BillboardGui individuels
    for _, child in ipairs(headModel:GetChildren()) do
        child.Parent = model
        -- Supprimer BillboardGui des pièces individuelles
        if child:IsA("BasePart") then
            local billboard = child:FindFirstChildOfClass("BillboardGui")
            if billboard then
                billboard:Destroy()
            end
        end
    end
    for _, child in ipairs(bodyModel:GetChildren()) do
        child.Parent = model
        if child:IsA("BasePart") then
            local billboard = child:FindFirstChildOfClass("BillboardGui")
            if billboard then
                billboard:Destroy()
            end
        end
    end
    for _, child in ipairs(legsModel:GetChildren()) do
        child.Parent = model
        if child:IsA("BasePart") then
            local billboard = child:FindFirstChildOfClass("BillboardGui")
            if billboard then
                billboard:Destroy()
            end
        end
    end
    
    -- Détruire les models vides
    headModel:Destroy()
    bodyModel:Destroy()
    legsModel:Destroy()
    
    -- Positionner les Legs d'abord (base du Brainrot)
    -- Les Legs doivent être posées SUR la plateforme avec la même orientation
    local platformTop = platform.Position.Y + platform.Size.Y / 2
    local legsBottomY = platformTop + legsPart.Size.Y / 2
    
    -- Utiliser l'orientation de la plateforme pour orienter le Brainrot
    local platformRotation = platform.CFrame.Rotation
    
    -- Utiliser l'orientation du TopAttachment des Legs pour définir leur rotation
    local legsTopAtt = legsPart:FindFirstChild("TopAttachment")
    if legsTopAtt then
        -- Positionner les Legs avec l'orientation de la plateforme + leur TopAttachment
        local legsOrientation = legsTopAtt.CFrame.Rotation
        legsPart.CFrame = CFrame.new(platform.Position.X, legsBottomY, platform.Position.Z) * platformRotation * legsOrientation
    else
        -- Fallback: utiliser seulement l'orientation de la plateforme
        legsPart.CFrame = CFrame.new(platform.Position.X, legsBottomY, platform.Position.Z) * platformRotation
    end
    legsPart.Anchored = false
    
    print("[BrainrotModelSystem] Legs positioned at:", legsPart.Position)
    print("[BrainrotModelSystem] Legs orientation from Platform + TopAttachment")
    
    -- Connecter Body → Legs via Attachments
    local bodyBottomAtt = bodyPart:FindFirstChild("BottomAttachment")
    local legsTopAtt = legsPart:FindFirstChild("TopAttachment")
    
    if bodyBottomAtt and legsTopAtt then
        -- Positionner le Body au-dessus des Legs via Attachments
        bodyPart.CFrame = legsPart.CFrame * legsTopAtt.CFrame * bodyBottomAtt.CFrame:Inverse()
        bodyPart.Anchored = true  -- Anchor le Body pour que tout reste en place
        
        -- Souder
        local legsWeld = Instance.new("WeldConstraint")
        legsWeld.Part0 = bodyPart
        legsWeld.Part1 = legsPart
        legsWeld.Parent = legsPart
        
        print("[BrainrotModelSystem] Legs connectées au Body via Attachments")
        print("[BrainrotModelSystem] Body CFrame:", bodyPart.CFrame)
    else
        warn("[BrainrotModelSystem] Attachments manquants pour Body-Legs")
        -- Fallback: positionnement manuel
        local bodyBottomY = legsBottomY + legsPart.Size.Y / 2 + bodyPart.Size.Y / 2
        bodyPart.CFrame = CFrame.new(platform.Position.X, bodyBottomY, platform.Position.Z)
        bodyPart.Anchored = true
        
        local legsWeld = Instance.new("WeldConstraint")
        legsWeld.Part0 = bodyPart
        legsWeld.Part1 = legsPart
        legsWeld.Parent = legsPart
    end
    
    -- Connecter Head → Body via Attachments (le Body est déjà positionné)
    local headBottomAtt = headPart:FindFirstChild("BottomAttachment")
    local bodyTopAtt = bodyPart:FindFirstChild("TopAttachment")
    
    if headBottomAtt and bodyTopAtt then
        -- Aligner les attachments
        headPart.CFrame = bodyPart.CFrame * bodyTopAtt.CFrame * headBottomAtt.CFrame:Inverse()
        headPart.Anchored = false  -- Ne pas anchor les autres parts
        
        -- Souder
        local headWeld = Instance.new("WeldConstraint")
        headWeld.Part0 = bodyPart
        headWeld.Part1 = headPart
        headWeld.Parent = headPart
        
        print("[BrainrotModelSystem] Head connecté au Body via Attachments")
        print("[BrainrotModelSystem] Head CFrame:", headPart.CFrame)
    else
        warn("[BrainrotModelSystem] Attachments manquants pour Head-Body")
        -- Fallback: positionnement manuel
        local headOffset = bodyPart.Size.Y / 2 + headPart.Size.Y / 2
        headPart.CFrame = bodyPart.CFrame * CFrame.new(0, headOffset, 0)
        headPart.Anchored = false
        
        local headWeld = Instance.new("WeldConstraint")
        headWeld.Part0 = bodyPart
        headWeld.Part1 = headPart
        headWeld.Parent = headPart
    end
    
    -- Définir le PrimaryPart
    model.PrimaryPart = bodyPart
    
    -- 4. Créer un BillboardGui unique pour le Brainrot complet
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BrainrotInfo"
    billboard.Size = UDim2.new(0, 200, 0, 100)
    billboard.StudsOffset = Vector3.new(0, headPart.Size.Y + 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = headPart
    
    -- Nom du Brainrot (concaténation des templates)
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
    
    -- Revenu total (somme des 3 pièces)
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
    
    billboard.Parent = headPart
    
    print("[BrainrotModelSystem] BillboardGui créé: " .. brainrotName .. " - $" .. totalRevenue .. "/s")
    
    -- 5. Définir les attributs
    model:SetAttribute("SetName", brainrotData.SetName)
    model:SetAttribute("SlotIndex", slotIndex)
    model:SetAttribute("OwnerUserId", player.UserId)
    model:SetAttribute("HeadSet", brainrotData.HeadSet)
    model:SetAttribute("BodySet", brainrotData.BodySet)
    model:SetAttribute("LegsSet", brainrotData.LegsSet)
    
    -- 5. Appliquer la visibilité (seul le propriétaire voit)
    self:_ApplyOwnerVisibility(model, player.UserId)
    
    -- 6. Parent le modèle au slot
    model.Parent = slot
    
    -- 7. Stocker la référence
    if not self._models[player.UserId] then
        self._models[player.UserId] = {}
    end
    self._models[player.UserId][slotIndex] = model
    
    print("[BrainrotModelSystem] Brainrot assemblé: " .. player.Name .. " slot " .. slotIndex)
    print("  Head: " .. brainrotData.HeadSet .. ", Body: " .. brainrotData.BodySet .. ", Legs: " .. brainrotData.LegsSet)
    
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
    
    print("[BrainrotModelSystem] Modèle détruit: " .. player.Name .. " slot " .. slotIndex)
    
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
    Seul le propriétaire voit son Brainrot
    @param model: Model
    @param ownerUserId: number
]]
function BrainrotModelSystem:_ApplyOwnerVisibility(model, ownerUserId)
    -- Pour chaque BasePart du modèle, on utilise LocalTransparencyModifier
    -- Cela rend le modèle invisible pour les autres joueurs
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            -- LocalTransparencyModifier = 1 rend invisible localement
            -- Le propriétaire verra le modèle normalement
            -- Les autres joueurs le verront transparent
            descendant.LocalTransparencyModifier = 0 -- Visible par défaut
            
            -- Note: La vraie logique de visibilité sera gérée côté client
            -- en filtrant les modèles par OwnerUserId
        end
    end
end

return BrainrotModelSystem
