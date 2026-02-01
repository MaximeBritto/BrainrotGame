--[[
    BrainrotData.lua
    Registry de tous les sets de Brainrots et leurs pièces
    
    Pour ajouter un nouveau set, copier un bloc existant et modifier les valeurs
]]

local BrainrotData = {
    -- ═══════════════════════════════════════
    -- SETS DE BRAINROTS
    -- ═══════════════════════════════════════
    Sets = {
        ["Skibidi"] = {
            Rarity = "Common",
            Head = {
                Price = 50,
                DisplayName = "Skibidi",
                ModelName = "Skibidi_Head",     -- Nom dans ReplicatedStorage/Assets/Pieces
                SpawnWeight = 10,               -- Probabilité relative de spawn
            },
            Body = {
                Price = 75,
                DisplayName = "Skibidi",
                ModelName = "Skibidi_Body",
                SpawnWeight = 10,
            },
            Legs = {
                Price = 60,
                DisplayName = "Skibidi",
                ModelName = "Skibidi_Legs",
                SpawnWeight = 10,
            },
        },
        
        ["Rizz"] = {
            Rarity = "Common",
            Head = {
                Price = 80,
                DisplayName = "Rizz",
                ModelName = "Rizz_Head",
                SpawnWeight = 10,
            },
            Body = {
                Price = 100,
                DisplayName = "Rizz",
                ModelName = "Rizz_Body",
                SpawnWeight = 10,
            },
            Legs = {
                Price = 90,
                DisplayName = "Rizz",
                ModelName = "Rizz_Legs",
                SpawnWeight = 10,
            },
        },
        
        ["Fanum"] = {
            Rarity = "Rare",
            Head = {
                Price = 150,
                DisplayName = "Fanum",
                ModelName = "Fanum_Head",
                SpawnWeight = 5,                -- Plus rare
            },
            Body = {
                Price = 200,
                DisplayName = "Fanum",
                ModelName = "Fanum_Body",
                SpawnWeight = 5,
            },
            Legs = {
                Price = 175,
                DisplayName = "Fanum",
                ModelName = "Fanum_Legs",
                SpawnWeight = 5,
            },
        },
        
        ["Gyatt"] = {
            Rarity = "Epic",
            Head = {
                Price = 400,
                DisplayName = "Gyatt",
                ModelName = "Gyatt_Head",
                SpawnWeight = 2,
            },
            Body = {
                Price = 500,
                DisplayName = "Gyatt",
                ModelName = "Gyatt_Body",
                SpawnWeight = 2,
            },
            Legs = {
                Price = 450,
                DisplayName = "Gyatt",
                ModelName = "Gyatt_Legs",
                SpawnWeight = 2,
            },
        },
    },
    
    -- ═══════════════════════════════════════
    -- RARETÉS
    -- ═══════════════════════════════════════
    Rarities = {
        Common = {
            Color = Color3.fromRGB(255, 255, 255),  -- Blanc
            BonusMultiplier = 1,
            DisplayOrder = 1,
        },
        Rare = {
            Color = Color3.fromRGB(0, 112, 221),    -- Bleu
            BonusMultiplier = 2,
            DisplayOrder = 2,
        },
        Epic = {
            Color = Color3.fromRGB(163, 53, 238),   -- Violet
            BonusMultiplier = 5,
            DisplayOrder = 3,
        },
        Legendary = {
            Color = Color3.fromRGB(255, 185, 0),    -- Or
            BonusMultiplier = 10,
            DisplayOrder = 4,
        },
    },
    
    -- ═══════════════════════════════════════
    -- TYPES DE PIÈCES
    -- ═══════════════════════════════════════
    PieceTypes = {"Head", "Body", "Legs"},
}

return BrainrotData
