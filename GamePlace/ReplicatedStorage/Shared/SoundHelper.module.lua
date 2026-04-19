--[[
    SoundHelper.module.lua
    - Par nom : ReplicatedStorage/Assets/Sounds (ex: SoundHelper.Play("CashCollect"))
    - Par ID : SoundHelper.PlayFromAssetId("rbxassetid://...", volume?)
    - Musique : SoundHelper.StartBackgroundMusic("rbxassetid://...", volume?)
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = ReplicatedStorage:FindFirstChild("Assets")
local SoundsFolder = Assets and Assets:FindFirstChild("Sounds")

local backgroundMusicInstance = nil

local function normalizeAssetId(soundId)
    if type(soundId) ~= "string" or soundId == "" then
        return nil
    end
    if string.sub(soundId, 1, 13) == "rbxassetid://" then
        return soundId
    end
    return "rbxassetid://" .. soundId
end

local function waitForSoundLoaded(sound, maxSeconds)
    local limit = typeof(maxSeconds) == "number" and maxSeconds or 6
    local t0 = os.clock()
    while not sound.IsLoaded and (os.clock() - t0) < limit do
        task.wait(0.03)
    end
end

local SoundHelper = {}

--[[
    Joue un son par nom (ex: "CashCollect", "SlotBuy", "FloorUnlock", "NotEnoughMoney")
    Clone le Sound, le joue dans SoundService, puis le détruit à la fin.
]]
function SoundHelper.Play(soundName)
    if not SoundsFolder then
        return
    end

    local template = SoundsFolder:FindFirstChild(soundName)
    if not template or not template:IsA("Sound") then
        warn("[SoundHelper] Son non trouvé: " .. tostring(soundName))
        return
    end

    local sound = template:Clone()
    sound.Parent = SoundService
    sound:Play()

    sound.Ended:Once(function()
        sound:Destroy()
    end)
end

function SoundHelper.PrecacheConfigSounds(sounds)
    if not sounds then
        return
    end
    local list = {}
    for _, key in ipairs({ "BackgroundMusic", "DoorClose" }) do
        local id = normalizeAssetId(sounds[key])
        if id then
            local s = Instance.new("Sound")
            s.SoundId = id
            table.insert(list, s)
        end
    end
    if #list == 0 then
        return
    end
    pcall(function()
        ContentProvider:PreloadAsync(list)
    end)
    for _, s in ipairs(list) do
        s:Destroy()
    end
end

function SoundHelper.PlayFromAssetId(soundId, volume)
    local id = normalizeAssetId(soundId)
    if not id then
        return
    end

    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Volume = typeof(volume) == "number" and volume or 0.5
    sound.Parent = SoundService
    waitForSoundLoaded(sound)
    sound:Play()

    sound.Ended:Once(function()
        sound:Destroy()
    end)
end

function SoundHelper.StartBackgroundMusic(soundId, volume)
    local id = normalizeAssetId(soundId)
    if not id then
        return
    end

    if backgroundMusicInstance then
        backgroundMusicInstance:Destroy()
        backgroundMusicInstance = nil
    end

    local sound = Instance.new("Sound")
    sound.Name = "GameBackgroundMusic"
    sound.SoundId = id
    sound.Looped = true
    sound.Volume = typeof(volume) == "number" and volume or 0.35
    sound.Parent = SoundService
    waitForSoundLoaded(sound)
    sound:Play()
    backgroundMusicInstance = sound
end

return SoundHelper
