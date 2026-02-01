--[[
    NetworkSetup.lua
    Crée tous les RemoteEvents et RemoteFunctions au démarrage du serveur
    
    Ce script doit être exécuté EN PREMIER avant tout autre script serveur
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Charger les constantes
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local NetworkSetup = {}

function NetworkSetup:Init()
    print("[NetworkSetup] Création des Remotes...")
    
    -- Créer le dossier Remotes s'il n'existe pas
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end
    
    -- Créer les RemoteEvents et RemoteFunctions
    for name, _ in pairs(Constants.RemoteNames) do
        -- Vérifier si c'est une RemoteFunction (commence par "Get")
        local isFunction = string.sub(name, 1, 3) == "Get"
        
        -- Vérifier si le Remote existe déjà
        if not remotesFolder:FindFirstChild(name) then
            if isFunction then
                local remote = Instance.new("RemoteFunction")
                remote.Name = name
                remote.Parent = remotesFolder
                print("[NetworkSetup] RemoteFunction créée: " .. name)
            else
                local remote = Instance.new("RemoteEvent")
                remote.Name = name
                remote.Parent = remotesFolder
                print("[NetworkSetup] RemoteEvent créé: " .. name)
            end
        end
    end
    
    print("[NetworkSetup] Tous les Remotes sont prêts!")
    return remotesFolder
end

--[[
    Récupère un Remote par son nom
    @param name: string - Nom du Remote (depuis Constants.RemoteNames)
    @return RemoteEvent | RemoteFunction
]]
function NetworkSetup:GetRemote(name)
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    return remotesFolder:WaitForChild(name)
end

--[[
    Récupère tous les Remotes dans une table
    @return table - {[name] = Remote}
]]
function NetworkSetup:GetAllRemotes()
    local remotes = {}
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    
    for _, remote in ipairs(remotesFolder:GetChildren()) do
        remotes[remote.Name] = remote
    end
    
    return remotes
end

return NetworkSetup
