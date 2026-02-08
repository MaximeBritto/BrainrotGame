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
        ["brrbrrPatapim"] = {
            Rarity = "Common",
            Head = {
                Price = 50,
                DisplayName = "Brr Brr",
                ModelName = "brrbrrPatapim_Head",
                TemplateName = "brrbrr",  -- Template dans HeadTemplate folder
                SpawnWeight = 10,
            },
            Body = {
                Price = 75,
                DisplayName = "Brr Brr Body",
                ModelName = "brrbrrPatapim_Body",
                TemplateName = "",  -- Pas de template pour l'instant
                SpawnWeight = 0,  -- Pas de body pour l'instant
            },
            Legs = {
                Price = 60,
                DisplayName = "Pata Pim",
                ModelName = "brrbrrPatapim_Legs",
                TemplateName = "patapim",  -- Template dans LegsTemplate folder
                SpawnWeight = 10,
            },
        },
        
        ["TralaleroTralala"] = {
            Rarity = "Common",
            Head = {
                Price = 80,
                DisplayName = "Tra La La Head",
                ModelName = "TralaleroTralala_Head",
                TemplateName = "",  -- Pas de template pour l'instant
                SpawnWeight = 0,  -- Pas de head pour l'instant
            },
            Body = {
                Price = 100,
                DisplayName = "La Le Ro",
                ModelName = "TralaleroTralala_Body",
                TemplateName = "lalero",  -- Template dans BodyTemplate folder
                SpawnWeight = 10,
            },
            Legs = {
                Price = 90,
                DisplayName = "Tra La La Legs",
                ModelName = "TralaleroTralala_Legs",
                TemplateName = "",  -- Pas de template pour l'instant
                SpawnWeight = 0,  -- Pas de legs pour l'instant
            },
        },
        
        ["CactoHipopoTamo"] = {
            Rarity = "Common",
            Head = {
                Price = 70,
                DisplayName = "Cacto",
                ModelName = "CactoHipopoTamo_Head",
                TemplateName = "Cacto",  -- Template dans HeadTemplate folder
                SpawnWeight = 10,
            },
            Body = {
                Price = 85,
                DisplayName = "Hipopo",
                ModelName = "CactoHipopoTamo_Body",
                TemplateName = "Hipopo",  -- Template dans BodyTemplate folder
                SpawnWeight = 10,
            },
            Legs = {
                Price = 65,
                DisplayName = "Tamo",
                ModelName = "CactoHipopoTamo_Legs",
                TemplateName = "Tamo",  -- Template dans LegsTemplate folder
                SpawnWeight = 10,
            },
        },
        
        ["PiccioneMacchina"] = {
            Rarity = "Common",
            Head = {
                Price = 75,
                DisplayName = "Picci",
                ModelName = "PiccioneMacchina_Head",
                TemplateName = "Picci",  -- Template dans HeadTemplate folder
                SpawnWeight = 10,
            },
            Body = {
                Price = 90,
                DisplayName = "Onemac",
                ModelName = "PiccioneMacchina_Body",
                TemplateName = "Onemac",  -- Template dans BodyTemplate folder
                SpawnWeight = 10,
            },
            Legs = {
                Price = 70,
                DisplayName = "China",
                ModelName = "PiccioneMacchina_Legs",
                TemplateName = "China",  -- Template dans LegsTemplate folder
                SpawnWeight = 10,
            },
        },
        
		["GirafaCelestre"] = {
			Rarity = "Common",
			Head = {
				Price = 80,
				DisplayName = "Gira",
				ModelName = "Girafa_Celestre_Head",
				TemplateName = "Gira",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 95,
				DisplayName = "fafa",
				ModelName = "Girafa_Celestre_Body",
				TemplateName = "fafa",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 75,
				DisplayName = "Celestre",
				ModelName = "Girafa_Celestre_Legs",
				TemplateName = "Celestre",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},
		
		["LiriliLarila"] = {
			Rarity = "Common",
			Head = {
				Price = 85,
				DisplayName = "Liri",
				ModelName = "LiriliLarila_Head",
				TemplateName = "Liri",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 100,
				DisplayName = "li La",
				ModelName = "LiriliLarila_Body",
				TemplateName = "liLa",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 80,
				DisplayName = "rilà",
				ModelName = "LiriliLarila_Legs",
				TemplateName = "rila",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},
		
		["TripiTropiTropaTripa"] = {
			Rarity = "Common",
			Head = {
				Price = 90,
				DisplayName = "tripi",
				ModelName = "TripiTropiTropaTripa_Head",
				TemplateName = "tripi",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 105,
				DisplayName = "tropitropa",
				ModelName = "TripiTropiTropaTripa_Body",
				TemplateName = "tropitropa",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 85,
				DisplayName = "tripa",
				ModelName = "TripiTropiTropaTripa_Legs",
				TemplateName = "tripa",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},
		
		["Talpadifero"] = {
			Rarity = "Common",
			Head = {
				Price = 75,
				DisplayName = "talpa",
				ModelName = "Talpadifero_Head",
				TemplateName = "talpa",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 90,
				DisplayName = "di",
				ModelName = "Talpadifero_Body",
				TemplateName = "di",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 70,
				DisplayName = "fero",
				ModelName = "Talpadifero_Legs",
				TemplateName = "fero",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},
		
		["GraipusMedussi"] = {
			Rarity = "Common",
			Head = {
				Price = 85,
				DisplayName = "grai",
				ModelName = "GraipusMedussi_Head",
				TemplateName = "grai",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 95,
				DisplayName = "pus",
				ModelName = "GraipusMedussi_Body",
				TemplateName = "pus",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 80,
				DisplayName = "medussi",
				ModelName = "GraipusMedussi_Legs",
				TemplateName = "medussi",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},
		
		["BombardiroCrocodilo"] = {
			Rarity = "Common",
			Head = {
				Price = 90,
				DisplayName = "Crocodilo",
				ModelName = "BombardiroCrocodilo_Head",
				TemplateName = "Crocodilo",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 100,
				DisplayName = "Bombardiro",
				ModelName = "BombardiroCrocodilo_Body",
				TemplateName = "Bombardiro",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
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
