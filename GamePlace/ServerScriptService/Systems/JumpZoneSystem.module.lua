--[[
    JumpZoneSystem.module.lua
    Détection VOLUMÉTRIQUE (XZ + Y) des zones NoJumpBoost taguées via
    CollectionService. Pas de raycast : l'override reste actif pendant
    toute la durée d'un saut, tant que le HRP reste dans le couloir
    vertical de la zone. Le saut boosté ne peut donc jamais "s'activer
    brièvement" quand les pieds décollent.

    Anti-glitch : si le joueur est dans le couloir vertical d'une zone
    mais trop haut au-dessus de son sol (toit voisin, super saut entrant),
    on applique une vélocité verticale massive vers le bas.

    L'override s'écrit dans runtimeData.JumpZoneOverride (géré par PlayerService).
]]

local Players            = game:GetService("Players")
local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local JumpZoneSystem = {}
JumpZoneSystem._initialized = false
JumpZoneSystem._trackedPlayers = {} -- [player] = { lastOverride, tickCount }

local TAG_NO_BOOST = "NoJumpBoost"

-- Intervalle du tick principal (boucle unique).
local TICK_INTERVAL      = 0.05   -- 20Hz
-- Fire SyncJumpZone au client tous les N ticks (heartbeat, évite les events
-- perdus au spawn avant que le client ait connecté son listener).
local SYNC_EVERY_N_TICKS = 5       -- 5 * 0.05s = 0.25s

-- Anti-glitch : si un joueur se retrouve horizontalement dans le volume
-- d'une zone NoJumpBoost mais trop haut au-dessus de son sol (super saut
-- entrant, chute depuis un toit adjacent), on le force à tomber.
-- Seuil assez bas pour attraper les sauts boostés entrants (qui dépassent
-- très vite 15 studs), mais on SKIP quand le joueur est en train de
-- grimper une échelle (state == Climbing) pour ne pas bloquer les
-- structures verticales légitimes.
local GLITCH_HEIGHT_THRESHOLD = 15     -- studs au-dessus du top de la zone
local GLITCH_CEILING          = 500    -- au-delà on ignore
local GLITCH_DOWN_VELOCITY    = -400   -- vélocité verticale forcée (studs/s)
-- Période de grâce UNIQUEMENT après un Climbing : permet la transition
-- échelle → toit (quelques frames airborne) sans slammer.
-- Les joueurs posés sur un toit ne rafraîchissent PAS ce timer — dès qu'ils
-- sautent du toit, l'anti-glitch les rattrape immédiatement (empêche de
-- hopper d'une base à une autre proche).
local CLIMB_GRACE_TIME        = 1.0    -- secondes

local PlayerService

-- Cache des parts taguées NoJumpBoost (mis à jour via CollectionService).
local noBoostParts = {}
local function refreshNoBoostParts()
    table.clear(noBoostParts)
    for _, p in ipairs(CollectionService:GetTagged(TAG_NO_BOOST)) do
        if p:IsA("BasePart") then
            table.insert(noBoostParts, p)
        end
    end
end

--[[
    Détermine si le joueur est dans le volume d'une zone NoJumpBoost via un
    check XZ + Y (pas de raycast). L'override ne se lève donc pas pendant
    les sauts : tant que le HRP reste dans le couloir vertical de la zone,
    on considère qu'il est dedans.
    @return boolean inNoBoost, number? heightAboveTop
]]
local function getNoBoostState(character)
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, nil end

    local pos = hrp.Position
    for _, part in ipairs(noBoostParts) do
        if part.Parent then
            local localPos = part.CFrame:PointToObjectSpace(pos)
            local halfSize = part.Size * 0.5
            if math.abs(localPos.X) <= halfSize.X
               and math.abs(localPos.Z) <= halfSize.Z then
                local aboveTop = localPos.Y - halfSize.Y
                -- Autorise un peu en-dessous du top (HRP peut descendre dans
                -- la collision) jusqu'au plafond anti-glitch au-dessus.
                if aboveTop > -2 and aboveTop < GLITCH_CEILING then
                    return true, aboveTop
                end
            end
        end
    end
    return false, nil
end

--[[
    Tick principal : détection de zone (raycast) + application override +
    sync client + anti-glitch. Tout dans la même boucle rapide pour
    éliminer la fenêtre où la détection serait en retard sur la position.
]]
function JumpZoneSystem:_Tick(player)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return end

    local state = self._trackedPlayers[player]
    if not state then return end

    local inNoBoost, aboveTop = getNoBoostState(character)
    local newOverride = inNoBoost and "NoJumpBoost" or nil

    -- Changement d'état : applique JumpPower côté serveur.
    if state.lastOverride ~= newOverride then
        state.lastOverride = newOverride
        if PlayerService then
            local runtime = PlayerService:GetRuntimeData(player)
            if runtime then
                runtime.JumpZoneOverride = newOverride
            end
            if PlayerService.ApplyJumpPower then
                PlayerService:ApplyJumpPower(player)
            end
        end
    end

    -- Sync client périodique (heartbeat toutes les ~0.25s pour rester léger).
    state.tickCount = (state.tickCount or 0) + 1
    if state.tickCount % SYNC_EVERY_N_TICKS == 0 then
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local syncRemote = remotes and remotes:FindFirstChild("SyncJumpZone")
        if syncRemote then
            syncRemote:FireClient(player, inNoBoost)
        end
    end

    -- Refresh le timer de grâce UNIQUEMENT quand le joueur est en Climbing
    -- (dans le couloir safezone). Grounded sur un toit ne refresh pas : on
    -- veut slammer dès qu'il saute du toit pour empêcher les saut-entre-bases.
    local climbing = humanoid:GetState() == Enum.HumanoidStateType.Climbing
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    if inNoBoost and climbing then
        state.lastClimbTime = tick()
    end

    if inNoBoost and aboveTop and aboveTop > GLITCH_HEIGHT_THRESHOLD then
        local inClimbGrace = state.lastClimbTime
            and (tick() - state.lastClimbTime) < CLIMB_GRACE_TIME
        if not grounded and not climbing and not inClimbGrace then
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, GLITCH_DOWN_VELOCITY, v.Z)
        end
    end
end

function JumpZoneSystem:_StartTracking(player)
    self._trackedPlayers[player] = {
        lastOverride = nil,
        tickCount = 0,
        lastClimbTime = 0,
    }
end

function JumpZoneSystem:_StopTracking(player)
    self._trackedPlayers[player] = nil
end

--[[
    Initialise le système.
    @param services: { PlayerService = ... }
]]
function JumpZoneSystem:Init(services)
    if self._initialized then return end
    services = services or {}
    PlayerService = services.PlayerService
    if not PlayerService then
        warn("[JumpZoneSystem] PlayerService requis")
        return
    end

    Players.PlayerAdded:Connect(function(p) self:_StartTracking(p) end)
    Players.PlayerRemoving:Connect(function(p) self:_StopTracking(p) end)
    for _, p in ipairs(Players:GetPlayers()) do
        self:_StartTracking(p)
    end

    -- Cache initial des parts NoJumpBoost + refresh sur ajout/retrait de tag.
    refreshNoBoostParts()
    CollectionService:GetInstanceAddedSignal(TAG_NO_BOOST):Connect(refreshNoBoostParts)
    CollectionService:GetInstanceRemovedSignal(TAG_NO_BOOST):Connect(refreshNoBoostParts)

    -- Boucle unifiée 20Hz : détection de zone + override + sync + anti-glitch.
    task.spawn(function()
        while true do
            task.wait(TICK_INTERVAL)
            for player, _ in pairs(self._trackedPlayers) do
                local ok, err = pcall(function()
                    self:_Tick(player)
                end)
                if not ok then
                    warn("[JumpZoneSystem] _Tick error:", err)
                end
            end
        end
    end)

    self._initialized = true
end

return JumpZoneSystem
