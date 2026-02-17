--[[
    ArenaSystem.module.lua
    Gestion du spawn des pièces dans l'arène
    
    Responsabilités:
    - Spawn aléatoire de pièces selon les SpawnWeight
    - Gestion du lifetime des pièces (despawn auto)
    - Référence et suppression des pièces
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = nil
local BrainrotData = nil
local Constants = nil

local ArenaSystem = {}
ArenaSystem._initialized = false
ArenaSystem._pieces = {}  -- [pieceId] = {Model = piece, SpawnedAt = tick()}
ArenaSystem._spawnLoopRunning = false
ArenaSystem._cleanupLoopRunning = false
ArenaSystem._spawnZone = nil
ArenaSystem._piecesFolder = nil
ArenaSystem._headTemplates = nil
ArenaSystem._bodyTemplates = nil
ArenaSystem._legsTemplates = nil
ArenaSystem._nextPieceId = 1
ArenaSystem._cannons = {}  -- Liste des canons {Position, Direction, BarrelPart, FirePoint, Model}

--[[
    Initialise le système Arena
    @param services: table (optionnel)
]]
function ArenaSystem:Init(services)
    if self._initialized then
        warn("[ArenaSystem] Déjà initialisé!")
        return
    end
    
    -- print("[ArenaSystem] Initialisation...")
    
    -- Charger les modules de config
    local Config = ReplicatedStorage:WaitForChild("Config")
    local Data = ReplicatedStorage:WaitForChild("Data")
    local Shared = ReplicatedStorage:WaitForChild("Shared")
    
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
    Constants = require(Shared:WaitForChild("Constants.module"))
    
    -- Récupérer les références Workspace
    local arena = Workspace:FindFirstChild(Constants.WorkspaceNames.ArenaFolder)
    if not arena then
        warn("[ArenaSystem] Arena folder manquant dans Workspace!")
        return
    end
    
    self._spawnZone = arena:FindFirstChild(Constants.WorkspaceNames.SpawnZone)
    if not self._spawnZone then
        warn("[ArenaSystem] SpawnZone manquante dans Arena!")
        return
    end
    
    -- Créer ou récupérer le folder ActivePieces
    self._piecesFolder = Workspace:FindFirstChild(Constants.WorkspaceNames.PiecesFolder)
    if not self._piecesFolder then
        self._piecesFolder = Instance.new("Folder")
        self._piecesFolder.Name = Constants.WorkspaceNames.PiecesFolder
        self._piecesFolder.Parent = Workspace
        -- print("[ArenaSystem] Folder ActivePieces créé")
    end
    
    -- Récupérer les templates
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if not assets then
        warn("[ArenaSystem] Assets folder manquant!")
        return
    end
    
    local bodyPartTemplates = assets:FindFirstChild("BodyPartTemplates")
    if not bodyPartTemplates then
        warn("[ArenaSystem] BodyPartTemplates folder manquant!")
        return
    end
    
    self._headTemplates = bodyPartTemplates:FindFirstChild("HeadTemplate")
    self._bodyTemplates = bodyPartTemplates:FindFirstChild("BodyTemplate")
    self._legsTemplates = bodyPartTemplates:FindFirstChild("LegsTemplate")
    
    if not self._headTemplates or not self._bodyTemplates or not self._legsTemplates then
        warn("[ArenaSystem] Templates manquants (HeadTemplate, BodyTemplate, LegsTemplate)!")
        return
    end
    
    -- Initialiser les canons
    self:_InitializeCannons(arena)
    
    -- Lancer les boucles
    self:_StartSpawnLoop()
    self:_StartCleanupLoop()
    
    self._initialized = true
    print("[ArenaSystem] Initialisé - Spawn actif avec " .. #self._cannons .. " canons")
end

--[[
    Ajoute un Highlight coloré à une pièce selon son type
    @param piece: Model
    @param pieceType: string
]]
function ArenaSystem:_AddHighlightToPiece(piece, pieceType)
    local primaryPart = piece.PrimaryPart
    if not primaryPart then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "PieceHighlight"
    
    local textLabel = ""
    local textColor = Color3.new(1, 1, 1)
    
    -- Couleurs selon le type de pièce
    if pieceType == Constants.PieceType.Head then
        -- Rouge pour Head
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 100, 100)
        textLabel = "HEAD"
        textColor = Color3.fromRGB(255, 0, 0)
    elseif pieceType == Constants.PieceType.Body then
        -- Vert pour Body
        highlight.FillColor = Color3.fromRGB(0, 255, 0)
        highlight.OutlineColor = Color3.fromRGB(100, 255, 100)
        textLabel = "BODY"
        textColor = Color3.fromRGB(0, 255, 0)
    elseif pieceType == Constants.PieceType.Legs then
        -- Bleu-Violet pour Legs
        highlight.FillColor = Color3.fromRGB(138, 43, 226)
        highlight.OutlineColor = Color3.fromRGB(180, 100, 255)
        textLabel = "LEGS"
        textColor = Color3.fromRGB(138, 43, 226)
    end
    
    -- Seulement le contour, pas de remplissage
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.Enabled = false -- Désactivé par défaut, activé par le client selon la distance
    highlight.Adornee = piece
    highlight.Parent = piece
    
    -- Trouver le BillboardGui existant avec le nom/prix et ajouter le TypeLabel dedans
    local existingBillboard = primaryPart:FindFirstChildOfClass("BillboardGui")
    
    if existingBillboard then
        -- Augmenter la taille du BillboardGui pour faire de la place pour le TypeLabel
        local originalSize = existingBillboard.Size
        existingBillboard.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 
                                           originalSize.Y.Scale, originalSize.Y.Offset + 40)
        
        -- Décaler le StudsOffset pour compenser l'agrandissement
        local originalOffset = existingBillboard.StudsOffset
        existingBillboard.StudsOffset = Vector3.new(originalOffset.X, originalOffset.Y + 0.5, originalOffset.Z)
        
        -- Ajouter le TypeLabel en haut du BillboardGui
        local typeLabel = Instance.new("TextLabel")
        typeLabel.Name = "TypeLabel"
        typeLabel.Size = UDim2.new(1, 0, 0, 35) -- 35 pixels de hauteur
        typeLabel.Position = UDim2.new(0, 0, 0, 0) -- Tout en haut
        typeLabel.BackgroundTransparency = 1
        typeLabel.Text = textLabel
        typeLabel.TextColor3 = textColor
        typeLabel.TextScaled = true
        typeLabel.Font = Enum.Font.Bangers
        typeLabel.TextStrokeTransparency = 0.5
        typeLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        typeLabel.Visible = false -- Désactivé par défaut
        typeLabel.Parent = existingBillboard
        
        -- Décaler les autres labels vers le bas
        local nameLabel = existingBillboard:FindFirstChild("NameLabel")
        if nameLabel and nameLabel:IsA("TextLabel") then
            nameLabel.Position = UDim2.new(0, 0, 0, 35)
        end
        
        local priceLabel = existingBillboard:FindFirstChild("PriceLabel")
        if priceLabel and priceLabel:IsA("TextLabel") then
            priceLabel.Position = UDim2.new(0, 0, 0.5, 35)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SYSTÈME DE CANONS
-- ═══════════════════════════════════════════════════════════════

--[[
    Initialise les canons en scannant le dossier Arena
    Cherche tous les modèles Canon1..Canon10 avec Barrel > FirePoint
    @param arena: Folder (Workspace.Arena)
]]
function ArenaSystem:_InitializeCannons(arena)
    self._cannons = {}
    
    for _, child in ipairs(arena:GetChildren()) do
        -- Chercher les modèles dont le nom commence par "Canon"
        if (child:IsA("Model") or child:IsA("Folder")) and string.sub(child.Name, 1, 5) == "Canon" then
            local barrel = child:FindFirstChild("Barrel")
            if barrel then
                -- Chercher le FirePoint (Attachment) dans le Barrel (récursivement)
                local firePoint = barrel:FindFirstChild("FirePoint", true)
                
                -- Trouver la BasePart principale du barrel
                local barrelPart
                if barrel:IsA("BasePart") then
                    barrelPart = barrel
                elseif barrel:IsA("Model") then
                    barrelPart = barrel.PrimaryPart or barrel:FindFirstChildWhichIsA("BasePart")
                end
                
                -- Déterminer la position de tir
                local firePosition
                if firePoint and firePoint:IsA("Attachment") then
                    -- L'Attachment est forcément sur une BasePart
                    local attachParent = firePoint.Parent
                    if attachParent and attachParent:IsA("BasePart") then
                        firePosition = attachParent.CFrame:PointToWorldSpace(firePoint.Position)
                    elseif barrelPart then
                        firePosition = barrelPart.Position
                    end
                elseif barrelPart then
                    firePosition = barrelPart.Position
                end
                
                if firePosition then
                    -- Calculer la direction vers le centre de la SpawnZone
                    local direction = Vector3.new(0, 0, 0)
                    if self._spawnZone then
                        direction = (self._spawnZone.Position - firePosition).Unit
                    end
                    
                    local cannonData = {
                        Model = child,
                        Barrel = barrel,
                        FirePoint = firePoint,
                        Position = firePosition,
                        Direction = direction,
                    }
                    
                    table.insert(self._cannons, cannonData)
                    print("[ArenaSystem] Canon trouvé: " .. child.Name .. " à " .. tostring(firePosition))
                else
                    warn("[ArenaSystem] Canon " .. child.Name .. " - impossible de déterminer la position de tir")
                end
            else
                warn("[ArenaSystem] Canon " .. child.Name .. " - Barrel manquant!")
            end
        end
    end
    
    if #self._cannons == 0 then
        warn("[ArenaSystem] Aucun canon trouvé! Les pièces spawneront directement dans la zone.")
    end
end

--[[
    Sélectionne un canon aléatoire
    @return cannonData: table | nil
]]
function ArenaSystem:_SelectRandomCannon()
    if #self._cannons == 0 then return nil end
    return self._cannons[math.random(1, #self._cannons)]
end

--[[
    Récupère la position de tir d'un canon (recalculée en temps réel)
    Utile si le canon peut tourner ou bouger
    @param cannon: table (cannonData)
    @return Vector3
]]
function ArenaSystem:_GetCannonFirePosition(cannon)
    local barrel = cannon.Barrel
    local firePoint = cannon.FirePoint
    
    if firePoint and firePoint:IsA("Attachment") then
        -- Recalculer la position monde de l'attachment
        local parentPart = firePoint.Parent
        if parentPart and parentPart:IsA("BasePart") then
            return parentPart.CFrame:PointToWorldSpace(firePoint.Position)
        end
    end
    
    -- Fallback : utiliser la position du barrel
    if barrel:IsA("BasePart") then
        return barrel.Position
    elseif barrel:IsA("Model") then
        local mainPart = barrel.PrimaryPart or barrel:FindFirstChildWhichIsA("BasePart")
        if mainPart then
            return mainPart.Position
        end
    end
    
    return cannon.Position
end

--[[
    Calcule une position aléatoire dans la SpawnZone
    @return Vector3
]]
function ArenaSystem:_GetRandomSpawnZonePosition()
    local zoneCFrame = self._spawnZone.CFrame
    local zoneSize = self._spawnZone.Size
    
    -- La SpawnZone est un Cylindre plat (disque)
    -- Axe du cylindre = local X (Size.X = épaisseur = 3.189)
    -- Section circulaire = local Y et Z (diamètres ~344 et ~357)
    local radiusY = zoneSize.Y / 2
    local radiusZ = zoneSize.Z / 2
    
    -- Point aléatoire dans le disque (distribution uniforme avec sqrt)
    local angle = math.random() * 2 * math.pi
    local dist = math.sqrt(math.random()) * 0.8 -- 80% du rayon pour éviter les bords
    
    local localY = math.cos(angle) * radiusY * dist
    local localZ = math.sin(angle) * radiusZ * dist
    
    -- Transformer le point du disque en coordonnées monde (localX = 0 = centre du cylindre)
    local worldPos = zoneCFrame:PointToWorldSpace(Vector3.new(0, localY, localZ))
    
    -- Forcer la hauteur Y : utiliser la position monde du centre du cylindre + offset
    -- Les pièces spawn au-dessus et tombent naturellement sur le Floor
    worldPos = Vector3.new(worldPos.X, zoneCFrame.Position.Y + 10, worldPos.Z)
    
    return worldPos
end

--[[
    Calcule la trajectoire balistique pour atteindre une position cible
    @param startPos: Vector3 (position du canon)
    @param targetPos: Vector3 (position d'atterrissage)
    @param launchAngle: number (angle en degrés)
    @return velocity: Vector3, timeToTarget: number
]]
function ArenaSystem:_CalculateBallisticTrajectory(startPos, targetPos, launchAngle)
    local gravity = 196.2 -- Gravité Roblox par défaut
    local angleRad = math.rad(launchAngle)
    
    -- Distance horizontale
    local dx = targetPos.X - startPos.X
    local dz = targetPos.Z - startPos.Z
    local horizontalDistance = math.sqrt(dx * dx + dz * dz)
    
    -- Différence de hauteur
    local dy = targetPos.Y - startPos.Y
    
    -- Formule balistique pour calculer la vitesse nécessaire
    local sin2a = math.sin(2 * angleRad)
    local cosa = math.cos(angleRad)
    local sina = math.sin(angleRad)
    
    -- Éviter division par zéro
    if horizontalDistance < 1 then
        horizontalDistance = 1
    end
    
    local denominator = sin2a - (2 * cosa * cosa * dy / horizontalDistance)
    
    if denominator <= 0 or denominator ~= denominator then
        denominator = 0.5
    end
    
    local velocity = math.sqrt(math.abs(gravity * horizontalDistance / denominator))
    velocity = math.clamp(velocity, GameConfig.Cannon.VelocityMin, GameConfig.Cannon.VelocityMax)
    
    -- Composantes de la vitesse
    local horizontalVelocity = velocity * cosa
    local verticalVelocity = velocity * sina
    
    -- Direction horizontale normalisée
    local horizontalDir = Vector3.new(dx, 0, dz)
    if horizontalDir.Magnitude > 0 then
        horizontalDir = horizontalDir.Unit
    else
        horizontalDir = Vector3.new(1, 0, 0)
    end
    
    -- Vecteur vitesse final
    local velocityVector = horizontalDir * horizontalVelocity + Vector3.new(0, verticalVelocity, 0)
    
    -- Temps estimé pour atteindre la cible
    local timeToTarget = horizontalDistance / (horizontalVelocity + 0.001)
    
    return velocityVector, timeToTarget
end

--[[
    Crée l'effet visuel de tir au canon (flash + fumée)
    @param cannon: table (cannonData)
    @param firePosition: Vector3
]]
function ArenaSystem:_CreateFireEffect(cannon, firePosition)
    local direction = cannon.Direction
    
    -- Flash lumineux au bout du canon
    local flash = Instance.new("Part")
    flash.Name = "MuzzleFlash"
    flash.Shape = Enum.PartType.Ball
    flash.Size = Vector3.new(4, 4, 4)
    flash.Position = firePosition + direction * 2
    flash.BrickColor = BrickColor.new("Deep orange")
    flash.Material = Enum.Material.Neon
    flash.Anchored = true
    flash.CanCollide = false
    flash.Transparency = 0
    flash.Parent = Workspace
    
    -- Animation de fondu du flash
    task.spawn(function()
        for i = 0, 1, 0.1 do
            if flash and flash.Parent then
                flash.Transparency = i
                flash.Size = flash.Size * 1.15
            end
            task.wait(0.05)
        end
        if flash and flash.Parent then
            flash:Destroy()
        end
    end)
    
    -- Nuage de fumée
    local smoke = Instance.new("Part")
    smoke.Name = "CannonSmoke"
    smoke.Shape = Enum.PartType.Ball
    smoke.Size = Vector3.new(3, 3, 3)
    smoke.Position = firePosition + direction * 1.5
    smoke.BrickColor = BrickColor.new("Medium stone grey")
    smoke.Material = Enum.Material.SmoothPlastic
    smoke.Anchored = true
    smoke.CanCollide = false
    smoke.Transparency = 0.3
    smoke.Parent = Workspace
    
    -- Animation de la fumée (monte et se dissipe)
    task.spawn(function()
        for i = 0, 1, 0.05 do
            if smoke and smoke.Parent then
                smoke.Transparency = 0.3 + (i * 0.7)
                smoke.Size = smoke.Size * 1.1
                smoke.Position = smoke.Position + Vector3.new(0, 0.3, 0)
            end
            task.wait(0.05)
        end
        if smoke and smoke.Parent then
            smoke:Destroy()
        end
    end)
end

--[[
    Crée un projectile visuel (Anchored, animé manuellement)
    @param firePosition: Vector3
    @return Part (le projectile)
]]
function ArenaSystem:_CreateProjectile(firePosition)
    local size = GameConfig.Cannon.ProjectileSize
    
    local projectile = Instance.new("Part")
    projectile.Name = "CannonProjectile"
    projectile.Shape = Enum.PartType.Ball
    projectile.Size = Vector3.new(size, size, size)
    projectile.Position = firePosition
    projectile.BrickColor = BrickColor.new("Really red")
    projectile.Material = Enum.Material.Neon
    projectile.Anchored = true
    projectile.CanCollide = false
    projectile.Transparency = 0.2
    projectile.Parent = Workspace
    
    -- Émetteur de particules pour trainée de fumée
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
    particles.Rate = 40
    particles.Lifetime = NumberRange.new(0.5, 1.5)
    particles.Speed = NumberRange.new(2, 4)
    particles.SpreadAngle = Vector2.new(20, 20)
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50), Color3.fromRGB(100, 100, 100))
    particles.Transparency = NumberSequence.new(0.3, 1)
    particles.Size = NumberSequence.new(1.5, 3)
    particles.Parent = projectile
    
    -- Light pour rendre le projectile lumineux
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 100, 0)
    light.Brightness = 2
    light.Range = 12
    light.Parent = projectile
    
    return projectile
end

--[[
    Crée l'effet d'impact à l'atterrissage
    @param position: Vector3
]]
function ArenaSystem:_CreateLandingEffect(position)
    -- Cercle d'impact lumineux
    local impact = Instance.new("Part")
    impact.Name = "LandingImpact"
    impact.Shape = Enum.PartType.Cylinder
    impact.Size = Vector3.new(0.5, 5, 5)
    impact.Position = position
    impact.Orientation = Vector3.new(0, 0, 90)
    impact.BrickColor = BrickColor.new("Bright yellow")
    impact.Material = Enum.Material.Neon
    impact.Anchored = true
    impact.CanCollide = false
    impact.Transparency = 0.2
    impact.Parent = Workspace
    
    -- Animation d'expansion et fondu
    task.spawn(function()
        for i = 0, 1, 0.08 do
            if impact and impact.Parent then
                impact.Transparency = 0.2 + (i * 0.8)
                impact.Size = impact.Size * 1.2
            end
            task.wait(0.04)
        end
        if impact and impact.Parent then
            impact:Destroy()
        end
    end)
end

--[[
    Lance une pièce depuis un canon avec une trajectoire parabolique animée
    @param cannon: table (cannonData)
    @param piece: Model (la pièce Brainrot clonée, déjà configurée)
    @param targetPosition: Vector3
]]
function ArenaSystem:_LaunchPieceFromCannon(cannon, piece, targetPosition)
    -- Récupérer la position de tir actuelle du canon
    local firePosition = self:_GetCannonFirePosition(cannon)
    
    -- Effet de tir au canon
    self:_CreateFireEffect(cannon, firePosition)
    
    -- Créer le projectile visuel (Anchored, on le déplace manuellement)
    local projectile = self:_CreateProjectile(firePosition)
    
    -- Sauvegarder les propriétés originales de la pièce puis la cacher
    local savedTransparencies = {}
    local savedCanCollide = {}
    local savedAnchored = {}
    for _, child in ipairs(piece:GetDescendants()) do
        if child:IsA("BasePart") then
            savedTransparencies[child] = child.Transparency
            savedCanCollide[child] = child.CanCollide
            savedAnchored[child] = child.Anchored
            child.Transparency = 1
            child.CanCollide = false
            child.Anchored = true -- Ancrer pour éviter de tomber dans le vide pendant le vol
        end
    end
    
    -- Cacher le BillboardGui et le Highlight
    local primaryPart = piece.PrimaryPart
    if primaryPart then
        local billboard = primaryPart:FindFirstChildOfClass("BillboardGui")
        if billboard then
            billboard.Enabled = false
        end
    end
    local highlight = piece:FindFirstChild("PieceHighlight")
    if highlight then
        highlight.Enabled = false
    end
    
    -- Placer la pièce au canon (invisible, ancrée) et l'ajouter au dossier
    piece:PivotTo(CFrame.new(firePosition))
    piece.Parent = self._piecesFolder
    
    -- Paramètres de la trajectoire parabolique
    local startPos = firePosition
    local endPos = targetPosition
    -- Hauteur de l'arc : plus la distance est grande, plus l'arc est haut
    local horizontalDist = (Vector3.new(endPos.X, 0, endPos.Z) - Vector3.new(startPos.X, 0, startPos.Z)).Magnitude
    local arcHeight = math.clamp(horizontalDist * 0.4, 15, 80)
    -- Durée du vol proportionnelle à la distance
    local flightDuration = math.clamp(horizontalDist / 80, 1.0, 3.0)
    
    -- Animer la trajectoire parabolique
    task.spawn(function()
        local elapsed = 0
        local stepInterval = 0.03 -- ~30 FPS d'animation serveur
        
        while elapsed < flightDuration do
            elapsed = elapsed + stepInterval
            local t = math.min(elapsed / flightDuration, 1)
            
            -- Interpolation linéaire X et Z
            local posX = startPos.X + (endPos.X - startPos.X) * t
            local posZ = startPos.Z + (endPos.Z - startPos.Z) * t
            -- Interpolation Y linéaire + arc parabolique (4*h*t*(1-t) donne un pic à t=0.5)
            local posY = startPos.Y + (endPos.Y - startPos.Y) * t + arcHeight * 4 * t * (1 - t)
            
            if projectile and projectile.Parent then
                projectile.Position = Vector3.new(posX, posY, posZ)
            else
                break
            end
            
            task.wait(stepInterval)
        end
        
        -- Le projectile a atteint la cible
        if projectile and projectile.Parent then
            projectile:Destroy()
        end
        
        -- Effet d'impact
        self:_CreateLandingEffect(endPos)
        
        -- Révéler la pièce à la position d'atterrissage
        self:_RevealPieceAtPosition(piece, endPos, savedTransparencies, savedCanCollide, savedAnchored)
    end)
end

--[[
    Révèle une pièce à une position après l'atterrissage du projectile
    Restaure les propriétés originales sauvegardées
    @param piece: Model
    @param position: Vector3
    @param savedTransparencies: table {BasePart -> number}
    @param savedCanCollide: table {BasePart -> boolean}
    @param savedAnchored: table {BasePart -> boolean}
]]
function ArenaSystem:_RevealPieceAtPosition(piece, position, savedTransparencies, savedCanCollide, savedAnchored)
    if not piece or not piece.Parent then
        warn("[ArenaSystem] Pièce détruite avant l'atterrissage!")
        return
    end
    
    -- Positionner la pièce avec PivotTo (plus fiable que SetPrimaryPartCFrame)
    piece:PivotTo(CFrame.new(position))
    
    -- Restaurer toutes les propriétés originales
    for _, child in ipairs(piece:GetDescendants()) do
        if child:IsA("BasePart") then
            if savedTransparencies and savedTransparencies[child] ~= nil then
                child.Transparency = savedTransparencies[child]
            end
            if savedCanCollide and savedCanCollide[child] ~= nil then
                child.CanCollide = savedCanCollide[child]
            end
            if savedAnchored and savedAnchored[child] ~= nil then
                child.Anchored = savedAnchored[child]
            end
        end
    end
    
    -- Réactiver le BillboardGui
    local primaryPart = piece.PrimaryPart
    if primaryPart then
        local billboard = primaryPart:FindFirstChildOfClass("BillboardGui")
        if billboard then
            billboard.Enabled = true
        end
    end
    
    -- Le Highlight reste disabled par défaut, le client l'active selon la distance
    local highlight = piece:FindFirstChild("PieceHighlight")
    if highlight then
        highlight.Enabled = false
    end
end

-- ═══════════════════════════════════════════════════════════════
-- LOGIQUE DE SPAWN
-- ═══════════════════════════════════════════════════════════════

--[[
    Choisit un set et un type de pièce selon les SpawnWeight
    @return setName: string, pieceType: string, pieceInfo: table
]]
function ArenaSystem:_ChooseRandomPiece()
    -- 1. Calculer le poids total
    local totalWeight = 0
    local weightedSets = {}
    
    for setName, setData in pairs(BrainrotData.Sets) do
        for _, pieceType in ipairs(BrainrotData.PieceTypes) do
            local pieceInfo = setData[pieceType]
            if pieceInfo and pieceInfo.SpawnWeight then
                table.insert(weightedSets, {
                    SetName = setName,
                    PieceType = pieceType,
                    Weight = pieceInfo.SpawnWeight,
                    Info = pieceInfo,
                })
                totalWeight = totalWeight + pieceInfo.SpawnWeight
            end
        end
    end
    
    if totalWeight == 0 then
        warn("[ArenaSystem] Aucune pièce avec SpawnWeight > 0!")
        return nil, nil, nil
    end
    
    -- 2. Sélection pondérée
    local roll = math.random() * totalWeight
    local cumulative = 0
    
    for _, entry in ipairs(weightedSets) do
        cumulative = cumulative + entry.Weight
        if roll <= cumulative then
            return entry.SetName, entry.PieceType, entry.Info
        end
    end
    
    -- Fallback (ne devrait jamais arriver)
    local last = weightedSets[#weightedSets]
    return last.SetName, last.PieceType, last.Info
end

--[[
    Spawn une pièce aléatoire dans l'arène
    @return Model | nil
]]
function ArenaSystem:SpawnRandomPiece()
    if not self._initialized then return nil end
    
    -- Vérifier la limite
    local currentCount = 0
    for _ in pairs(self._pieces) do
        currentCount = currentCount + 1
    end
    
    if currentCount >= GameConfig.Arena.MaxPiecesInArena then
        return nil
    end
    
    -- Choisir une pièce
    local setName, pieceType, pieceInfo = self:_ChooseRandomPiece()
    if not setName then return nil end
    
    -- Récupérer le nom du template depuis pieceInfo
    local templateName = pieceInfo.TemplateName
    if not templateName or templateName == "" then
        warn("[ArenaSystem] TemplateName manquant ou vide pour: " .. setName .. " " .. pieceType)
        return nil
    end
    
    -- Choisir le bon template folder selon le type
    local templateFolder
    if pieceType == Constants.PieceType.Head then
        templateFolder = self._headTemplates
    elseif pieceType == Constants.PieceType.Body then
        templateFolder = self._bodyTemplates
    elseif pieceType == Constants.PieceType.Legs then
        templateFolder = self._legsTemplates
    else
        warn("[ArenaSystem] Type de pièce inconnu: " .. tostring(pieceType))
        return nil
    end
    
    -- Récupérer le template spécifique (ex: brrbrr, lalero, patapim)
    local template = templateFolder:FindFirstChild(templateName)
    if not template then
        warn("[ArenaSystem] Template introuvable: " .. templateName .. " dans " .. templateFolder.Name)
        return nil
    end
    
    -- Cloner le template
    local piece = template:Clone()
    
    -- Générer un ID unique
    local pieceId = "Piece_" .. self._nextPieceId
    self._nextPieceId = self._nextPieceId + 1
    
    -- Définir les attributs
    piece:SetAttribute("PieceId", pieceId)
    piece:SetAttribute("SetName", setName)
    piece:SetAttribute("PieceType", pieceType)
    piece:SetAttribute("Price", pieceInfo.Price)
    piece:SetAttribute("DisplayName", pieceInfo.DisplayName)
    piece:SetAttribute("SpawnedAt", tick())
    
    -- Nom du modèle
    piece.Name = pieceId
    
    -- Mettre à jour le BillboardGui dans PrimaryPart
    local primaryPart = piece.PrimaryPart
    if primaryPart then
        local billboard = primaryPart:FindFirstChildOfClass("BillboardGui")
        if billboard then
            -- Chercher NameLabel pour afficher le nom du template
            local nameLabel = billboard:FindFirstChild("NameLabel")
            if nameLabel and nameLabel:IsA("TextLabel") then
                nameLabel.Text = templateName -- Affiche "brrbrr", "lalero", etc.
            end
            
            -- Chercher PriceLabel pour afficher le prix
            local priceLabel = billboard:FindFirstChild("PriceLabel")
            if priceLabel and priceLabel:IsA("TextLabel") then
                priceLabel.Text = "$" .. pieceInfo.Price
            end
        end
    end
    
    -- Supprimer l'ancien PickupZone s'il existe (pour éviter les problèmes de réplication)
    local oldPickupZone = primaryPart:FindFirstChild("PickupZone")
    if oldPickupZone then
        oldPickupZone:Destroy()
    end
    
    -- Créer un nouveau PickupZone
    local pickupZone = Instance.new("Part")
    pickupZone.Name = "PickupZone"
    pickupZone.Size = primaryPart.Size * 1.5 -- Un peu plus grand que la pièce
    pickupZone.CFrame = primaryPart.CFrame
    pickupZone.Transparency = 1
    pickupZone.CanCollide = false
    pickupZone.Anchored = false
    pickupZone.Massless = true
    
    -- Souder au PrimaryPart
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = primaryPart
    weld.Part1 = pickupZone
    weld.Parent = pickupZone
    
    pickupZone.Parent = primaryPart
    
    -- Créer le ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Pickup"
    prompt.ObjectText = templateName
    prompt.MaxActivationDistance = 15
    prompt.RequiresLineOfSight = false
    prompt.HoldDuration = 0
    prompt.Enabled = true
    prompt.Parent = pickupZone
    
    -- Ajouter le Highlight coloré selon le type de pièce
    self:_AddHighlightToPiece(piece, pieceType)
    
    -- Stocker la pièce dans le tracker
    self._pieces[pieceId] = {
        Model = piece,
        SpawnedAt = tick(),
    }
    
    -- === TIR DEPUIS UN CANON ===
    local cannon = self:_SelectRandomCannon()
    
    if cannon then
        -- Position cible aléatoire dans la SpawnZone
        local targetPosition = self:_GetRandomSpawnZonePosition()
        
        -- Lancer la pièce depuis le canon (gère le parent, la visibilité, et l'atterrissage)
        self:_LaunchPieceFromCannon(cannon, piece, targetPosition)
    else
        -- Fallback sans canon : spawn direct (ancien comportement)
        local zonePos = self._spawnZone.Position
        local zoneSize = self._spawnZone.Size
        
        local randomX = zonePos.X + (math.random() - 0.5) * zoneSize.X
        local randomY = zonePos.Y + zoneSize.Y / 2 + 10
        local randomZ = zonePos.Z + (math.random() - 0.5) * zoneSize.Z
        
        piece:SetPrimaryPartCFrame(CFrame.new(randomX, randomY, randomZ))
        piece.Parent = self._piecesFolder
    end
    
    return piece
end

--[[
    Spawn une pièce spécifique à une position donnée (pour le cheat menu)
    @param setName string
    @param pieceType string
    @param pieceInfo table
    @param templateName string
    @param template Model
    @param position Vector3
    @return Model | nil
]]
function ArenaSystem:_SpawnSpecificPiece(setName, pieceType, pieceInfo, templateName, template, position)
    if not self._initialized then return nil end
    
    -- Cloner le template
    local piece = template:Clone()
    
    -- Générer un ID unique
    local pieceId = "Piece_" .. self._nextPieceId
    self._nextPieceId = self._nextPieceId + 1
    
    -- Définir les attributs
    piece:SetAttribute("PieceId", pieceId)
    piece:SetAttribute("SetName", setName)
    piece:SetAttribute("PieceType", pieceType)
    piece:SetAttribute("Price", pieceInfo.Price)
    piece:SetAttribute("DisplayName", pieceInfo.DisplayName)
    piece:SetAttribute("SpawnedAt", tick())
    
    -- Nom du modèle
    piece.Name = pieceId
    
    -- Mettre à jour le BillboardGui dans PrimaryPart
    local primaryPart = piece.PrimaryPart
    if primaryPart then
        local billboard = primaryPart:FindFirstChildOfClass("BillboardGui")
        if billboard then
            -- Chercher NameLabel pour afficher le nom du template
            local nameLabel = billboard:FindFirstChild("NameLabel")
            if nameLabel and nameLabel:IsA("TextLabel") then
                nameLabel.Text = templateName
            end
            
            -- Chercher PriceLabel pour afficher le prix
            local priceLabel = billboard:FindFirstChild("PriceLabel")
            if priceLabel and priceLabel:IsA("TextLabel") then
                priceLabel.Text = "$" .. pieceInfo.Price
            end
        end
    end
    
    -- Position personnalisée
    piece:SetPrimaryPartCFrame(CFrame.new(position))
    
    -- Supprimer l'ancien PickupZone s'il existe
    local oldPickupZone = primaryPart:FindFirstChild("PickupZone")
    if oldPickupZone then
        oldPickupZone:Destroy()
    end
    
    -- Créer un nouveau PickupZone
    local pickupZone = Instance.new("Part")
    pickupZone.Name = "PickupZone"
    pickupZone.Size = primaryPart.Size * 1.5
    pickupZone.CFrame = primaryPart.CFrame
    pickupZone.Transparency = 1
    pickupZone.CanCollide = false
    pickupZone.Anchored = false
    pickupZone.Massless = true
    
    -- Souder au PrimaryPart
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = primaryPart
    weld.Part1 = pickupZone
    weld.Parent = pickupZone
    
    pickupZone.Parent = primaryPart
    
    -- Créer le ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Pickup"
    prompt.ObjectText = templateName
    prompt.MaxActivationDistance = 15
    prompt.RequiresLineOfSight = false
    prompt.HoldDuration = 0
    prompt.Enabled = true
    prompt.Parent = pickupZone
    
    -- print("[ArenaSystem] PickupZone et ProximityPrompt créés pour:", pieceId)
    
    -- Ajouter le Highlight coloré selon le type de pièce
    self:_AddHighlightToPiece(piece, pieceType)
    
    -- Parent et stockage
    piece.Parent = self._piecesFolder
    self._pieces[pieceId] = {
        Model = piece,
        SpawnedAt = tick(),
    }
    
    -- print("[ArenaSystem] Pièce cheat spawnée: " .. pieceId .. " (" .. templateName .. " " .. pieceType .. " - Set: " .. setName .. ")")
    
    return piece
end

--[[
    Boucle de spawn des pièces
]]
function ArenaSystem:_StartSpawnLoop()
    if self._spawnLoopRunning then return end
    self._spawnLoopRunning = true
    
    task.spawn(function()
        -- print("[ArenaSystem] Boucle de spawn démarrée")
        
        while self._spawnLoopRunning do
            task.wait(GameConfig.Arena.SpawnInterval)
            
            -- Compter les pièces actuelles
            local count = 0
            for _ in pairs(self._pieces) do
                count = count + 1
            end
            
            -- Spawn si sous la limite
            if count < GameConfig.Arena.MaxPiecesInArena then
                local piece = self:SpawnRandomPiece()
                if piece then
                    -- print("[ArenaSystem] Pièce spawnée: " .. piece.Name)
                end
            end
        end
    end)
end

--[[
    Boucle de nettoyage des pièces expirées
]]
function ArenaSystem:_StartCleanupLoop()
    if self._cleanupLoopRunning then return end
    self._cleanupLoopRunning = true
    
    task.spawn(function()
        -- print("[ArenaSystem] Boucle de nettoyage démarrée")
        
        while self._cleanupLoopRunning do
            task.wait(10) -- Vérifier toutes les 10 secondes
            
            local now = tick()
            local toRemove = {}
            
            -- Trouver les pièces expirées
            for pieceId, data in pairs(self._pieces) do
                if (now - data.SpawnedAt) > GameConfig.Arena.PieceLifetime then
                    table.insert(toRemove, pieceId)
                end
            end
            
            -- Supprimer les pièces expirées
            for _, pieceId in ipairs(toRemove) do
                local data = self._pieces[pieceId]
                if data and data.Model then
                    data.Model:Destroy()
                    -- print("[ArenaSystem] Pièce expirée supprimée: " .. pieceId)
                end
                self._pieces[pieceId] = nil
            end
        end
    end)
end

--[[
    Récupère une pièce par son ID
    @param pieceId: string
    @return Model | nil
]]
function ArenaSystem:GetPieceById(pieceId)
    local data = self._pieces[pieceId]
    return data and data.Model or nil
end

--[[
    Supprime une pièce de l'arène
    @param piece: Model
]]
function ArenaSystem:RemovePiece(piece)
    if not piece then return end
    
    local pieceId = piece:GetAttribute("PieceId")
    if pieceId then
        self._pieces[pieceId] = nil
    end
    
    piece:Destroy()
    -- print("[ArenaSystem] Pièce supprimée: " .. (pieceId or "unknown"))
end

--[[
    Spawn une pièce dans l'arène à partir de pieceData (utilisé quand un joueur remplace une pièce).
    La pièce apparaît légèrement au-dessus de la position donnée et tombe naturellement.
    @param pieceData: table - {SetName, PieceType, Price, DisplayName}
    @param position: Vector3 - Position où faire tomber la pièce
    @return Model | nil
]]
function ArenaSystem:SpawnPieceFromData(pieceData, position)
    if not self._initialized then return nil end

    local setName = pieceData.SetName
    local pieceType = pieceData.PieceType

    -- Récupérer les infos du set depuis BrainrotData
    local setData = BrainrotData.Sets[setName]
    if not setData or not setData[pieceType] then
        warn("[ArenaSystem] Set ou PieceType introuvable: " .. tostring(setName) .. " " .. tostring(pieceType))
        return nil
    end

    local pieceInfo = setData[pieceType]
    local templateName = pieceInfo.TemplateName
    if not templateName or templateName == "" then
        warn("[ArenaSystem] TemplateName vide pour: " .. setName .. " " .. pieceType)
        return nil
    end

    -- Choisir le bon template folder
    local templateFolder
    if pieceType == Constants.PieceType.Head then
        templateFolder = self._headTemplates
    elseif pieceType == Constants.PieceType.Body then
        templateFolder = self._bodyTemplates
    elseif pieceType == Constants.PieceType.Legs then
        templateFolder = self._legsTemplates
    end

    if not templateFolder then return nil end

    local template = templateFolder:FindFirstChild(templateName)
    if not template then
        warn("[ArenaSystem] Template introuvable pour drop: " .. templateName)
        return nil
    end

    -- Spawn légèrement au-dessus pour que la pièce tombe
    local dropPosition = position + Vector3.new(0, 5, 0)

    local piece = self:_SpawnSpecificPiece(setName, pieceType, pieceInfo, templateName, template, dropPosition)
    if piece then
        print("[ArenaSystem] Pièce droppée: " .. setName .. " " .. pieceType .. " à " .. tostring(position))
    end

    return piece
end

return ArenaSystem
