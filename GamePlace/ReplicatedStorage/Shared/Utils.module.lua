--[[
    Utils.lua
    Fonctions utilitaires partagées entre client et serveur
]]

local Utils = {}

--[[
    Copie profonde d'une table
    @param original: table - La table à copier
    @return table - Une nouvelle table avec les mêmes valeurs
]]
function Utils.DeepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = Utils.DeepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

--[[
    Fusionne deux tables (la seconde écrase la première)
    @param base: table - Table de base
    @param override: table - Table avec les valeurs à écraser
    @return table - Table fusionnée
]]
function Utils.MergeTables(base, override)
    local result = Utils.DeepCopy(base)
    for key, value in pairs(override) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = Utils.MergeTables(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

--[[
    Génère un ID unique
    @return string - ID unique basé sur le temps et un nombre aléatoire
]]
function Utils.GenerateId()
    return tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
end

--[[
    Formate un nombre avec séparateurs de milliers
    @param number: number - Le nombre à formater
    @return string - Nombre formaté (ex: 1,234,567)
]]
function Utils.FormatNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

--[[
    Formate l'argent avec le symbole $
    @param amount: number - Montant
    @return string - Montant formaté (ex: $1,234)
]]
function Utils.FormatMoney(amount)
    return "$" .. Utils.FormatNumber(amount)
end

--[[
    Formate un temps en secondes en mm:ss
    @param seconds: number - Temps en secondes
    @return string - Temps formaté (ex: 01:30)
]]
function Utils.FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", mins, secs)
end

--[[
    Vérifie si une table contient une valeur
    @param table: table - La table à vérifier
    @param value: any - La valeur à chercher
    @return boolean - true si trouvée
]]
function Utils.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

--[[
    Compte les éléments d'une table (incluant les clés non-numériques)
    @param table: table - La table à compter
    @return number - Nombre d'éléments
]]
function Utils.TableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--[[
    Retourne une valeur aléatoire d'une table pondérée
    @param weightedTable: table - Table avec des poids {item = weight, ...}
    @return any - L'item sélectionné
]]
function Utils.WeightedRandom(weightedTable)
    local totalWeight = 0
    for _, weight in pairs(weightedTable) do
        totalWeight = totalWeight + weight
    end
    
    local random = math.random() * totalWeight
    local currentWeight = 0
    
    for item, weight in pairs(weightedTable) do
        currentWeight = currentWeight + weight
        if random <= currentWeight then
            return item
        end
    end
    
    -- Fallback (ne devrait jamais arriver)
    for item, _ in pairs(weightedTable) do
        return item
    end
end

--[[
    Crée un debounce pour une fonction
    @param cooldown: number - Temps de cooldown en secondes
    @return function - Fonction qui retourne true si pas en cooldown
]]
function Utils.CreateDebounce(cooldown)
    local lastCall = 0
    return function()
        local now = tick()
        if now - lastCall >= cooldown then
            lastCall = now
            return true
        end
        return false
    end
end

--[[
    Lerp linéaire entre deux valeurs
    @param a: number - Valeur de départ
    @param b: number - Valeur de fin
    @param t: number - Facteur (0-1)
    @return number - Valeur interpolée
]]
function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

--[[
    Clamp une valeur entre min et max
    @param value: number - Valeur à limiter
    @param min: number - Minimum
    @param max: number - Maximum
    @return number - Valeur limitée
]]
function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

return Utils
