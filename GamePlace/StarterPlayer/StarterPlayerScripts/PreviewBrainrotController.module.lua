--[[
    PreviewBrainrotController.module.lua
    Affiche un modèle 3D "preview" du brainrot en cours d'assemblage
    qui flotte à gauche/derrière le personnage du joueur.

    Responsabilités:
    - Assembler un modèle partiel (1, 2 ou 3 pièces) côté client
    - Positionner le modèle à gauche et légèrement derrière le joueur
    - Suivre le joueur en temps réel (RunService.Heartbeat)
    - Détruire le modèle quand l'inventaire est vidé (craft / drop / mort)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Modules
local Data = ReplicatedStorage:WaitForChild("Data")
local BrainrotData = require(Data:WaitForChild("BrainrotData.module"))

-- État
local PreviewBrainrotController = {}
PreviewBrainrotController._currentModel = nil   -- Le Model preview actuel
PreviewBrainrotController._heartbeatConn = nil   -- Connexion Heartbeat
PreviewBrainrotController._characterConn = nil   -- Connexion CharacterAdded
PreviewBrainrotController._lastPieces = {}       -- Cache des dernières pièces

-- ═══════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════

local PREVIEW_SCALE = 1.0        -- 100% pour conserver les offsets/welds exacts des templates
local OFFSET = CFrame.new(-3.5, 0, 1.5)  -- Gauche (-X), derrière (+Z)
local BOB_SPEED = 2              -- Vitesse du flottement (oscillation)
local BOB_AMPLITUDE = 0.3        -- Amplitude du flottement vertical
local ROTATION_SPEED = 0.5       -- Vitesse de rotation lente (rad/s)

-- DEBUG : mettre à true pour voir les logs détaillés dans la console F9
local DEBUG_PREVIEW = true

-- Les templates sont visiblement en axe différent du monde Roblox (Y-up),
-- on applique une correction fixe pour garder le preview debout (tête en haut, pieds en bas).
local ORIENTATION_CORRECTION = CFrame.Angles(math.rad(90), 0, 0)

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

function PreviewBrainrotController:Init()
    -- Écouter les respawns pour recréer le preview si besoin
    self._characterConn = player.CharacterAdded:Connect(function(character)
        -- Petit délai pour que le personnage soit chargé
        task.wait(0.5)
        -- Recréer le preview avec les dernières pièces connues
        if #self._lastPieces > 0 then
            self:UpdatePreview(self._lastPieces)
        end
    end)

    print("[PreviewBrainrotController] Initialisé!")
end

-- ═══════════════════════════════════════════════════════
-- MISE À JOUR DU PREVIEW
-- ═══════════════════════════════════════════════════════

--[[
    Met à jour le modèle preview selon les pièces en main.
    Appelé depuis ClientMain quand SyncInventory arrive.
    @param pieces: table - Liste des pièces {SetName, PieceType, Price, DisplayName}
]]
function PreviewBrainrotController:UpdatePreview(pieces)
    -- Sauvegarder les pièces
    self._lastPieces = pieces or {}

    -- Toujours détruire l'ancien preview
    self:_DestroyPreview()

    -- Si pas de pièces, rien à faire
    if #self._lastPieces == 0 then
        return
    end

    -- Vérifier que le personnage existe
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- Assembler le modèle partiel
    local model = self:_AssemblePreview(self._lastPieces)
    if not model then
        warn("[PreviewBrainrotController] Échec assemblage preview")
        return
    end

    -- Configurer le modèle (CanCollide = false, transparent pour montrer que c'est un preview)
    -- Le PrimaryPart reste Anchored (stabilisé par _AssemblePreview), les autres parts suivent via welds
    model.Name = "BrainrotPreview"
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            if part ~= model.PrimaryPart then
                part.Anchored = false
            end
            -- Légèrement transparent pour bien montrer que c'est un preview
            part.Transparency = math.max(part.Transparency, 0.25)
        end
    end

    -- Supprimer les BillboardGui (pas besoin sur le preview)
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            desc:Destroy()
        end
    end

    -- Positionner initialement (même logique que le suivi)
    if model.PrimaryPart then
        local look = rootPart.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        if flatLook.Magnitude < 0.001 then flatLook = Vector3.new(0, 0, -1) else flatLook = flatLook.Unit end
        local uprightFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook, Vector3.new(0, 1, 0))
        local pos = (uprightFrame * OFFSET).Position
        model:PivotTo(CFrame.new(pos) * ORIENTATION_CORRECTION)
    end

    -- Parent au workspace (client-side uniquement)
    model.Parent = workspace

    self._currentModel = model

    if DEBUG_PREVIEW then
        local totalParts = 0
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("BasePart") then totalParts = totalParts + 1 end
        end
        print(string.format("[PreviewBrainrotController] Preview créé avec %d part(s)", totalParts))
    end

    -- Démarrer le suivi
    self:_StartFollowing()
end

-- ═══════════════════════════════════════════════════════
-- ASSEMBLAGE DU MODÈLE PARTIEL
-- ═══════════════════════════════════════════════════════

--[[
    Déplace tous les BaseParts d'un template vers le modèle cible.
    Utilise GetDescendants() pour récupérer TOUTES les parts (pas seulement les enfants directs).
    @param templateModel: Model
    @param targetModel: Model
    @return BasePart | nil - La PrimaryPart du template (pour les attachments)
]]
local function _MoveTemplateToModel(templateModel, targetModel)
    if not templateModel or not targetModel then return nil end

    local primaryPart = templateModel.PrimaryPart
    local partsMoved = 0

    -- Récupérer TOUS les BaseParts (y compris dans des sous-models)
    for _, desc in ipairs(templateModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            -- Supprimer BillboardGui avant de déplacer
            local billboard = desc:FindFirstChildOfClass("BillboardGui")
            if billboard then billboard:Destroy() end
            desc.Parent = targetModel
            partsMoved = partsMoved + 1
        end
    end

    if DEBUG_PREVIEW then
        print(string.format("[PreviewBrainrotController] Template '%s' : %d part(s) déplacée(s)", templateModel.Name, partsMoved))
    end

    templateModel:Destroy()
    return primaryPart
end

--[[
    Assemble un modèle 3D de preview à partir des pièces disponibles.
    Reprend la logique de BrainrotModelSystem:AssembleBrainrot mais côté client
    et gère les assemblages partiels (1 ou 2 pièces).
    IMPORTANT: Utilise GetDescendants pour récupérer TOUTES les parts de chaque template.
    @param pieces: table
    @return Model | nil
]]
function PreviewBrainrotController:_AssemblePreview(pieces)
    -- 1. Trouver les dossiers de templates
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        warn("[PreviewBrainrotController] Assets folder introuvable")
        return nil
    end

    local templatesFolder = assetsFolder:FindFirstChild("BodyPartTemplates")
    if not templatesFolder then
        warn("[PreviewBrainrotController] BodyPartTemplates folder introuvable")
        return nil
    end

    local headTemplateFolder = templatesFolder:FindFirstChild("HeadTemplate")
    local bodyTemplateFolder = templatesFolder:FindFirstChild("BodyTemplate")
    local legsTemplateFolder = templatesFolder:FindFirstChild("LegsTemplate")

    -- 2. Trier les pièces par type
    local headPiece, bodyPiece, legsPiece = nil, nil, nil
    for _, piece in ipairs(pieces) do
        if piece.PieceType == "Head" then headPiece = piece end
        if piece.PieceType == "Body" then bodyPiece = piece end
        if piece.PieceType == "Legs" then legsPiece = piece end
    end

    -- 3. Cloner les templates (on clone le Model entier pour garder toute la hiérarchie)
    local headTemplate, bodyTemplate, legsTemplate = nil, nil, nil
    if headPiece and headTemplateFolder then
        local setData = BrainrotData.Sets[headPiece.SetName]
        if setData and setData.Head and setData.Head.TemplateName ~= "" then
            headTemplate = headTemplateFolder:FindFirstChild(setData.Head.TemplateName)
            if headTemplate then headTemplate = headTemplate:Clone() end
        end
    end
    if bodyPiece and bodyTemplateFolder then
        local setData = BrainrotData.Sets[bodyPiece.SetName]
        if setData and setData.Body and setData.Body.TemplateName ~= "" then
            bodyTemplate = bodyTemplateFolder:FindFirstChild(setData.Body.TemplateName)
            if bodyTemplate then bodyTemplate = bodyTemplate:Clone() end
        end
    end
    if legsPiece and legsTemplateFolder then
        local setData = BrainrotData.Sets[legsPiece.SetName]
        if setData and setData.Legs and setData.Legs.TemplateName ~= "" then
            legsTemplate = legsTemplateFolder:FindFirstChild(setData.Legs.TemplateName)
            if legsTemplate then legsTemplate = legsTemplate:Clone() end
        end
    end

    if not headTemplate and not bodyTemplate and not legsTemplate then
        warn("[PreviewBrainrotController] Aucun template trouvé pour les pièces")
        if DEBUG_PREVIEW then
            print("[PreviewBrainrotController] DEBUG pieces:", pieces and #pieces or 0)
            for i, p in ipairs(pieces or {}) do
                print("  ", i, p.SetName, p.PieceType)
            end
        end
        return nil
    end

    -- 4. Créer le conteneur
    local model = Instance.new("Model")
    model.Name = "BrainrotPreview"

    -- 5. Déplacer TOUTES les parts de chaque template (GetDescendants inclut les sous-models)
    local headPart, bodyPart, legsPart = nil, nil, nil
    if headTemplate then headPart = _MoveTemplateToModel(headTemplate, model) end
    if bodyTemplate then bodyPart = _MoveTemplateToModel(bodyTemplate, model) end
    if legsTemplate then legsPart = _MoveTemplateToModel(legsTemplate, model) end

    -- 6. Réduire la taille de toutes les parts ET scaler les Attachments (sinon les points de connexion sont décalés)
    local partCount = 0
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Size = part.Size * PREVIEW_SCALE
            part.Anchored = false
            part.CanCollide = false
            -- Scaler les Attachments pour que les points de connexion restent aux bons endroits
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("Attachment") then
                    child.Position = child.Position * PREVIEW_SCALE
                end
            end
            partCount = partCount + 1
        end
    end
    if DEBUG_PREVIEW then
        print(string.format("[PreviewBrainrotController] Total parts dans le modèle: %d (scale %.0f%%)", partCount, PREVIEW_SCALE * 100))
    end

    -- 7. Positionner et connecter (ordre: Legs en bas → Body au milieu → Head en haut)
    -- Orientation strictement verticale pour éviter toute inclinaison (pitch/roll).
    local uprightCFrame = CFrame.new()

    -- Le PrimaryPart sera ancré en section 8b ; les autres parts suivent via WeldConstraint + PivotTo
    if legsPart then
        legsPart.CFrame = CFrame.new(0, legsPart.Size.Y / 2, 0) * uprightCFrame

        if bodyPart then
            local bodyBottomAtt = bodyPart:FindFirstChild("BottomAttachment")
            local legsTopAtt = legsPart:FindFirstChild("TopAttachment")
            if bodyBottomAtt and legsTopAtt then
                bodyPart.CFrame = legsPart.CFrame * legsTopAtt.CFrame * bodyBottomAtt.CFrame:Inverse()
                local legsWeld = Instance.new("WeldConstraint")
                legsWeld.Part0 = bodyPart
                legsWeld.Part1 = legsPart
                legsWeld.Parent = legsPart
                if DEBUG_PREVIEW then print("[PreviewBrainrotController] Weld Body-Legs créé") end
            else
                bodyPart.CFrame = legsPart.CFrame * CFrame.new(0, legsPart.Size.Y / 2 + bodyPart.Size.Y / 2, 0)
                local legsWeld = Instance.new("WeldConstraint")
                legsWeld.Part0 = bodyPart
                legsWeld.Part1 = legsPart
                legsWeld.Parent = legsPart
            end
        end
    elseif bodyPart then
        bodyPart.CFrame = CFrame.new(0, bodyPart.Size.Y / 2, 0) * uprightCFrame
    end

    -- HEAD
    if headPart then
        if bodyPart then
            local headBottomAtt = headPart:FindFirstChild("BottomAttachment")
            local bodyTopAtt = bodyPart:FindFirstChild("TopAttachment")
            if headBottomAtt and bodyTopAtt then
                headPart.CFrame = bodyPart.CFrame * bodyTopAtt.CFrame * headBottomAtt.CFrame:Inverse()
                local headWeld = Instance.new("WeldConstraint")
                headWeld.Part0 = bodyPart
                headWeld.Part1 = headPart
                headWeld.Parent = headPart
                if DEBUG_PREVIEW then print("[PreviewBrainrotController] Weld Head-Body créé") end
            else
                local headOffset = bodyPart.Size.Y / 2 + headPart.Size.Y / 2
                headPart.CFrame = bodyPart.CFrame * CFrame.new(0, headOffset, 0)
                local headWeld = Instance.new("WeldConstraint")
                headWeld.Part0 = bodyPart
                headWeld.Part1 = headPart
                headWeld.Parent = headPart
            end
        elseif legsPart then
            -- Même logique que Head-Body : utiliser les Attachments pour imbriquer correctement
            -- Head.BottomAttachment → Legs.TopAttachment (où le body se serait connecté)
            local headBottomAtt = headPart:FindFirstChild("BottomAttachment")
            local legsTopAtt = legsPart:FindFirstChild("TopAttachment")
            if headBottomAtt and legsTopAtt then
                headPart.CFrame = legsPart.CFrame * legsTopAtt.CFrame * headBottomAtt.CFrame:Inverse()
            else
                headPart.CFrame = legsPart.CFrame * CFrame.new(0, legsPart.Size.Y / 2 + 0.5 + headPart.Size.Y / 2, 0)
            end
            local headWeld = Instance.new("WeldConstraint")
            headWeld.Part0 = legsPart
            headWeld.Part1 = headPart
            headWeld.Parent = headPart
        else
            headPart.CFrame = CFrame.new(0, headPart.Size.Y / 2, 0) * uprightCFrame
        end
    end

    -- 8. Définir le PrimaryPart (body au centre, sinon legs, sinon head)
    model.PrimaryPart = bodyPart or legsPart or headPart

    if not model.PrimaryPart then
        warn("[PreviewBrainrotController] Aucun PrimaryPart disponible")
        model:Destroy()
        return nil
    end

    -- 8b. Ancrer le PrimaryPart pour stabiliser l'assemblage (PivotTo fonctionne avec Anchored)
    model.PrimaryPart.Anchored = true

    -- 9. Centrer la rotation du modèle sur son centre de masse via WorldPivot
    -- IMPORTANT: On NE déplace PAS les parts individuellement car CFrame * CFrame.new(offset)
    -- applique le décalage en espace LOCAL de chaque part. Si les parts ont des rotations
    -- différentes (via Attachments), elles seraient projetées dans des directions différentes,
    -- faisant "disparaître" certaines pièces (ex: la tête part en Z au lieu de Y).
    -- À la place, on définit le WorldPivot au centroïde : PivotTo tournera alors
    -- le modèle autour de son centre visuel sans casser les positions relatives.
    local centroid = Vector3.new(0, 0, 0)
    local centroidPartCount = 0
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            centroid = centroid + part.Position
            centroidPartCount = centroidPartCount + 1
        end
    end
    if centroidPartCount > 0 then
        centroid = centroid / centroidPartCount
        model.WorldPivot = CFrame.new(centroid)
    end

    if DEBUG_PREVIEW then
        print(string.format("[PreviewBrainrotController] Assemblage OK - Head:%s Body:%s Legs:%s",
            tostring(headPart ~= nil), tostring(bodyPart ~= nil), tostring(legsPart ~= nil)))
    end

    return model
end

-- ═══════════════════════════════════════════════════════
-- SUIVI DU JOUEUR
-- ═══════════════════════════════════════════════════════

--[[
    Démarre le suivi en temps réel via Heartbeat
]]
function PreviewBrainrotController:_StartFollowing()
    -- Arrêter l'ancien suivi s'il existe
    self:_StopFollowing()

    local startTime = tick()

    self._heartbeatConn = RunService.Heartbeat:Connect(function()
        local model = self._currentModel
        if not model or not model.Parent then
            self:_StopFollowing()
            return
        end

        local character = player.Character
        if not character then return end

        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        local primaryPart = model.PrimaryPart
        if not primaryPart then return end

        -- Calculer le temps pour les animations
        local elapsed = tick() - startTime

        -- Oscillation verticale (flottement)
        local bobOffset = math.sin(elapsed * BOB_SPEED) * BOB_AMPLITUDE

        -- Rotation lente sur Y (toupie, sens horaire vu de dessus)
        local rotAngle = elapsed * ROTATION_SPEED
        local rotCFrame = CFrame.Angles(0, rotAngle, 0)

        -- Construire un repère TOUJOURS vertical (ignore pitch/roll éventuels du root part)
        local look = rootPart.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        if flatLook.Magnitude < 0.001 then
            flatLook = Vector3.new(0, 0, -1)
        else
            flatLook = flatLook.Unit
        end
        local uprightFollowFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook, Vector3.new(0, 1, 0))

        -- Position : à gauche et derrière le joueur + bob (INDÉPENDANTE de la rotation)
        local pivotPosition = (uprightFollowFrame * OFFSET * CFrame.new(0, bobOffset, 0)).Position

        -- Orientation : spin en espace monde (axe Y) puis correction debout, pour un mouvement toupie
        local pivotRotation = rotCFrame * ORIENTATION_CORRECTION

        -- Combiner : le modèle tourne sur lui-même autour de son pivot, pas autour d'un point extérieur
        local targetCFrame = CFrame.new(pivotPosition) * pivotRotation

        model:PivotTo(targetCFrame)
    end)
end

--[[
    Arrête le suivi Heartbeat
]]
function PreviewBrainrotController:_StopFollowing()
    if self._heartbeatConn then
        self._heartbeatConn:Disconnect()
        self._heartbeatConn = nil
    end
end

-- ═══════════════════════════════════════════════════════
-- NETTOYAGE
-- ═══════════════════════════════════════════════════════

--[[
    Détruit le modèle preview actuel et arrête le suivi
]]
function PreviewBrainrotController:_DestroyPreview()
    self:_StopFollowing()

    if self._currentModel then
        self._currentModel:Destroy()
        self._currentModel = nil
    end
end

return PreviewBrainrotController
