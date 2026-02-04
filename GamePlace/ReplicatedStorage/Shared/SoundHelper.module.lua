--[[
    SoundHelper.module.lua
    Joue des sons depuis ReplicatedStorage/Assets/Sounds par nom.
    Usage: SoundHelper.Play("CashCollect")
    
    Si Assets/Sounds n'existe pas ou qu'un son est absent, aucun crash : simple warn.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = ReplicatedStorage:FindFirstChild("Assets")
local SoundsFolder = Assets and Assets:FindFirstChild("Sounds")

if not SoundsFolder then
    warn("[SoundHelper] ReplicatedStorage/Assets/Sounds non trouvé - sons désactivés")
end

local SoundHelper = {}

--[[
    Joue un son par nom (ex: "CashCollect", "SlotBuy", "FloorUnlock", "NotEnoughMoney")
    Clone le Sound, le joue dans SoundService, puis le détruit à la fin.
]]
function SoundHelper.Play(soundName)
    if not SoundsFolder then return end
    
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

return SoundHelper
