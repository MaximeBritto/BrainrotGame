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
                GainPerSec = 5,
                DisplayName = "Brr Brr",
                ModelName = "brrbrrPatapim_Head",
                TemplateName = "brrbrr",  -- Template dans HeadTemplate folder
                SpawnWeight = 10,
            },
            Body = {
                Price = 75,
                GainPerSec = 0,
                DisplayName = "Brr Brr Body",
                ModelName = "brrbrrPatapim_Body",
                TemplateName = "",  -- Pas de template pour l'instant
                SpawnWeight = 0,  -- Pas de body pour l'instant
            },
            Legs = {
                Price = 60,
                GainPerSec = 6,
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
                GainPerSec = 0,
                DisplayName = "Tra La La Head",
                ModelName = "TralaleroTralala_Head",
                TemplateName = "",  -- Pas de template pour l'instant
                SpawnWeight = 0,  -- Pas de head pour l'instant
            },
            Body = {
                Price = 100,
                GainPerSec = 10,
                DisplayName = "La Le Ro",
                ModelName = "TralaleroTralala_Body",
                TemplateName = "lalero",  -- Template dans BodyTemplate folder
                SpawnWeight = 10,
            },
            Legs = {
                Price = 90,
                GainPerSec = 0,
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
                GainPerSec = 7,
                DisplayName = "Cacto",
                ModelName = "CactoHipopoTamo_Head",
                TemplateName = "Cacto",  -- Template dans HeadTemplate folder
                SpawnWeight = 10,
            },
            Body = {
                Price = 85,
                GainPerSec = 8,
                DisplayName = "Hipopo",
                ModelName = "CactoHipopoTamo_Body",
                TemplateName = "Hipopo",  -- Template dans BodyTemplate folder
                SpawnWeight = 10,
            },
            Legs = {
                Price = 65,
                GainPerSec = 6,
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
                GainPerSec = 7,
                DisplayName = "Picci",
                ModelName = "PiccioneMacchina_Head",
                TemplateName = "Picci",  -- Template dans HeadTemplate folder
                SpawnWeight = 10,
            },
            Body = {
                Price = 90,
                GainPerSec = 9,
                DisplayName = "Onemac",
                ModelName = "PiccioneMacchina_Body",
                TemplateName = "Onemac",  -- Template dans BodyTemplate folder
                SpawnWeight = 10,
            },
            Legs = {
                Price = 70,
                GainPerSec = 7,
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
				GainPerSec = 8,
				DisplayName = "Gira",
				ModelName = "Girafa_Celestre_Head",
				TemplateName = "Gira",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 95,
				GainPerSec = 9,
				DisplayName = "fafa",
				ModelName = "Girafa_Celestre_Body",
				TemplateName = "fafa",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 75,
				GainPerSec = 7,
				DisplayName = "Celestre",
				ModelName = "Girafa_Celestre_Legs",
				TemplateName = "Celestre",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["LiriliLarila"] = {
			Rarity = "Rare",
			Head = {
				Price = 85,
				GainPerSec = 17,
				DisplayName = "Liri",
				ModelName = "LiriliLarila_Head",
				TemplateName = "Liri",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 100,
				GainPerSec = 20,
				DisplayName = "li La",
				ModelName = "LiriliLarila_Body",
				TemplateName = "liLa",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 80,
				GainPerSec = 16,
				DisplayName = "rilà",
				ModelName = "LiriliLarila_Legs",
				TemplateName = "rila",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["TripiTropiTropaTripa"] = {
			Rarity = "Rare",
			Head = {
				Price = 90,
				GainPerSec = 18,
				DisplayName = "tripi",
				ModelName = "TripiTropiTropaTripa_Head",
				TemplateName = "tripi",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 105,
				GainPerSec = 21,
				DisplayName = "tropitropa",
				ModelName = "TripiTropiTropaTripa_Body",
				TemplateName = "tropitropa",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 85,
				GainPerSec = 17,
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
				GainPerSec = 7,
				DisplayName = "talpa",
				ModelName = "Talpadifero_Head",
				TemplateName = "talpa",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 90,
				GainPerSec = 9,
				DisplayName = "di",
				ModelName = "Talpadifero_Body",
				TemplateName = "di",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 70,
				GainPerSec = 7,
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
				GainPerSec = 8,
				DisplayName = "grai",
				ModelName = "GraipusMedussi_Head",
				TemplateName = "grai",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 95,
				GainPerSec = 9,
				DisplayName = "pus",
				ModelName = "GraipusMedussi_Body",
				TemplateName = "pus",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 80,
				GainPerSec = 8,
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
				GainPerSec = 9,
				DisplayName = "Crocodilo",
				ModelName = "BombardiroCrocodilo_Head",
				TemplateName = "Crocodilo",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 100,
				GainPerSec = 10,
				DisplayName = "Bombardiro",
				ModelName = "BombardiroCrocodilo_Body",
				TemplateName = "Bombardiro",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 0,
				GainPerSec = 0,
				DisplayName = "",
				ModelName = "",
				TemplateName = "",  -- Pas de legs
				SpawnWeight = 0,
			},
		},

		["SpioniroGolubiro"] = {
			Rarity = "Common",
			Head = {
				Price = 95,
				GainPerSec = 9,
				DisplayName = "spio",
				ModelName = "SpioniroGolubiro_Head",
				TemplateName = "spio",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 110,
				GainPerSec = 11,
				DisplayName = "nirogolu",
				ModelName = "SpioniroGolubiro_Body",
				TemplateName = "nirogolu",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 90,
				GainPerSec = 9,
				DisplayName = "biro",
				ModelName = "SpioniroGolubiro_Legs",
				TemplateName = "biro",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["ZibraZubraZibralini"] = {
			Rarity = "Common",
			Head = {
				Price = 100,
				GainPerSec = 10,
				DisplayName = "zibra",
				ModelName = "ZibraZubraZibralini_Head",
				TemplateName = "zibra",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 115,
				GainPerSec = 11,
				DisplayName = "zubra",
				ModelName = "ZibraZubraZibralini_Body",
				TemplateName = "zubra",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 95,
				GainPerSec = 9,
				DisplayName = "zibralini",
				ModelName = "ZibraZubraZibralini_Legs",
				TemplateName = "zibralini",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["TorrtuginniDragonfrutini"] = {
			Rarity = "Common",
			Head = {
				Price = 105,
				GainPerSec = 10,
				DisplayName = "Torrtuginni",
				ModelName = "TorrtuginniDragonfrutini_Head",
				TemplateName = "Torrtuginni",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 120,
				GainPerSec = 12,
				DisplayName = "Dragon",
				ModelName = "TorrtuginniDragonfrutini_Body",
				TemplateName = "Dragon",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 100,
				GainPerSec = 10,
				DisplayName = "frutini",
				ModelName = "TorrtuginniDragonfrutini_Legs",
				TemplateName = "frutini",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["BananitaDolphinita"] = {
			Rarity = "Common",
			Head = {
				Price = 110,
				GainPerSec = 11,
				DisplayName = "Bananita",
				ModelName = "BananitaDolphinita_Head",
				TemplateName = "Bananita",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 0,
				GainPerSec = 0,
				DisplayName = "",
				ModelName = "",
				TemplateName = "",  -- Pas de body
				SpawnWeight = 0,
			},
			Legs = {
				Price = 105,
				GainPerSec = 10,
				DisplayName = "Dolphinita",
				ModelName = "BananitaDolphinita_Legs",
				TemplateName = "Dolphinita",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["ChimpanziniSpiderini"] = {
			Rarity = "Common",
			Head = {
				Price = 115,
				GainPerSec = 11,
				DisplayName = "Chimpan",
				ModelName = "ChimpanziniSpiderini_Head",
				TemplateName = "Chimpan",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 125,
				GainPerSec = 12,
				DisplayName = "zini",
				ModelName = "ChimpanziniSpiderini_Body",
				TemplateName = "zini",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 110,
				GainPerSec = 11,
				DisplayName = "Spiderini",
				ModelName = "ChimpanziniSpiderini_Legs",
				TemplateName = "Spiderini",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["DragonCannelloni"] = {
			Rarity = "Legendary",
			Head = {
				Price = 120,
				GainPerSec = 30,
				DisplayName = "dragon",
				ModelName = "DragonCannelloni_Head",
				TemplateName = "dragon",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 130,
				GainPerSec = 32,
				DisplayName = "cannel",
				ModelName = "DragonCannelloni_Body",
				TemplateName = "cannel",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 115,
				GainPerSec = 28,
				DisplayName = "loni",
				ModelName = "DragonCannelloni_Legs",
				TemplateName = "loni",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["FrigoFrigoCamelo"] = {
			Rarity = "Common",
			Head = {
				Price = 125,
				GainPerSec = 12,
				DisplayName = "Frigo",
				ModelName = "FrigoFrigoCamelo_Head",
				TemplateName = "Frigo",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 135,
				GainPerSec = 13,
				DisplayName = "Frigo",
				ModelName = "FrigoFrigoCamelo_Body",
				TemplateName = "Frigo",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 120,
				GainPerSec = 12,
				DisplayName = "Camelo",
				ModelName = "FrigoFrigoCamelo_Legs",
				TemplateName = "Camelo",  -- Template dans LegsTemplate folder (Frigo2 pour différencier)
				SpawnWeight = 10,
			},
		},

		["GattatinoNyanino"] = {
			Rarity = "Epic",
			Head = {
				Price = 130,
				GainPerSec = 26,
				DisplayName = "Gattatino",
				ModelName = "GattatinoNyanino_Head",
				TemplateName = "Gattatino",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 140,
				GainPerSec = 28,
				DisplayName = "Nya",
				ModelName = "GattatinoNyanino_Body",
				TemplateName = "Nya",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 125,
				GainPerSec = 25,
				DisplayName = "nino",
				ModelName = "GattatinoNyanino_Legs",
				TemplateName = "nino",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["TrenostruzzoTurbo3000"] = {
			Rarity = "Common",
			Head = {
				Price = 135,
				GainPerSec = 13,
				DisplayName = "Trenostruzzo",
				ModelName = "TrenostruzzoTurbo3000_Head",
				TemplateName = "Trenostruzzo",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 145,
				GainPerSec = 14,
				DisplayName = "Turbo",
				ModelName = "TrenostruzzoTurbo3000_Body",
				TemplateName = "Turbo",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 130,
				GainPerSec = 13,
				DisplayName = "3000",
				ModelName = "TrenostruzzoTurbo3000_Legs",
				TemplateName = "3000",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["CocoCocosiniMama"] = {
			Rarity = "Common",
			Head = {
				Price = 140,
				GainPerSec = 14,
				DisplayName = "Coco",
				ModelName = "CocoCocosiniMama_Head",
				TemplateName = "Coco",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 150,
				GainPerSec = 15,
				DisplayName = "Cocosini",
				ModelName = "CocoCocosiniMama_Body",
				TemplateName = "Cocosini",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 135,
				GainPerSec = 13,
				DisplayName = "Mama",
				ModelName = "CocoCocosiniMama_Legs",
				TemplateName = "Mama",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["BlueberrinniOctopusini"] = {
			Rarity = "Common",
			Head = {
				Price = 145,
				GainPerSec = 14,
				DisplayName = "Blueberrinni",
				ModelName = "BlueberrinniOctopusini_Head",
				TemplateName = "Blueberrinni",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 0,
				GainPerSec = 0,
				DisplayName = "",
				ModelName = "",
				TemplateName = "",  -- Pas de body
				SpawnWeight = 0,
			},
			Legs = {
				Price = 140,
				GainPerSec = 14,
				DisplayName = "Octopusini",
				ModelName = "BlueberrinniOctopusini_Legs",
				TemplateName = "Octopusini",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["LaVaccaSaturnoSaturnita"] = {
			Rarity = "Common",
			Head = {
				Price = 150,
				GainPerSec = 15,
				DisplayName = "LaVacca",
				ModelName = "LaVaccaSaturnoSaturnita_Head",
				TemplateName = "LaVacca",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 160,
				GainPerSec = 16,
				DisplayName = "Saturno",
				ModelName = "LaVaccaSaturnoSaturnita_Body",
				TemplateName = "Saturno",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 145,
				GainPerSec = 14,
				DisplayName = "Saturnita",
				ModelName = "LaVaccaSaturnoSaturnita_Legs",
				TemplateName = "Saturnita",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["StrawberrelliFlamingelli"] = {
			Rarity = "Common",
			Head = {
				Price = 155,
				GainPerSec = 15,
				DisplayName = "Strawberrelli",
				ModelName = "StrawberrelliFlamingelli_Head",
				TemplateName = "Strawberrelli",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 165,
				GainPerSec = 16,
				DisplayName = "Flamin",
				ModelName = "StrawberrelliFlamingelli_Body",
				TemplateName = "Flamin",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 150,
				GainPerSec = 15,
				DisplayName = "gelli",
				ModelName = "StrawberrelliFlamingelli_Legs",
				TemplateName = "gelli",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["SalamiSalaminoPenguino"] = {
			Rarity = "Common",
			Head = {
				Price = 160,
				GainPerSec = 16,
				DisplayName = "Salami",
				ModelName = "SalamiSalaminoPenguino_Head",
				TemplateName = "Salami",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 170,
				GainPerSec = 17,
				DisplayName = "Salamino",
				ModelName = "SalamiSalaminoPenguino_Body",
				TemplateName = "Salamino",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 155,
				GainPerSec = 15,
				DisplayName = "Penguino",
				ModelName = "SalamiSalaminoPenguino_Legs",
				TemplateName = "Penguino",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["TigreTigroligreFrutonni"] = {
			Rarity = "Common",
			Head = {
				Price = 165,
				GainPerSec = 16,
				DisplayName = "Tigré",
				ModelName = "TigreTigroligreFrutonni_Head",
				TemplateName = "Tigré",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 175,
				GainPerSec = 17,
				DisplayName = "Tigroligre",
				ModelName = "TigreTigroligreFrutonni_Body",
				TemplateName = "Tigroligre",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 160,
				GainPerSec = 16,
				DisplayName = "Frutonni",
				ModelName = "TigreTigroligreFrutonni_Legs",
				TemplateName = "Frutonni",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["ElcrococrocoDilito"] = {
			Rarity = "Common",
			Head = {
				Price = 170,
				GainPerSec = 17,
				DisplayName = "Elcroco",
				ModelName = "ElcrococrocoDilito_Head",
				TemplateName = "Elcroco",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 180,
				GainPerSec = 18,
				DisplayName = "croco",
				ModelName = "ElcrococrocoDilito_Body",
				TemplateName = "croco",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 165,
				GainPerSec = 16,
				DisplayName = "Dilito",
				ModelName = "ElcrococrocoDilito_Legs",
				TemplateName = "Dilito",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["DinossauroNuclearo"] = {
			Rarity = "Common",
			Head = {
				Price = 175,
				GainPerSec = 17,
				DisplayName = "Dinossauro",
				ModelName = "DinossauroNuclearo_Head",
				TemplateName = "Dinossauro",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 185,
				GainPerSec = 18,
				DisplayName = "sauro",
				ModelName = "DinossauroNuclearo_Body",
				TemplateName = "sauro",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 170,
				GainPerSec = 17,
				DisplayName = "Nuclearo",
				ModelName = "DinossauroNuclearo_Legs",
				TemplateName = "Nuclearo",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["ChefCrabracadabra"] = {
			Rarity = "Common",
			Head = {
				Price = 180,
				GainPerSec = 18,
				DisplayName = "Chef",
				ModelName = "ChefCrabracadabra_Head",
				TemplateName = "Chef",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 190,
				GainPerSec = 19,
				DisplayName = "Crabra",
				ModelName = "ChefCrabracadabra_Body",
				TemplateName = "Crabra",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 175,
				GainPerSec = 17,
				DisplayName = "cadabra",
				ModelName = "ChefCrabracadabra_Legs",
				TemplateName = "cadabra",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["AvocadoGorille"] = {
			Rarity = "Common",
			Head = {
				Price = 185,
				GainPerSec = 18,
				DisplayName = "avo",
				ModelName = "AvocadoGorille_Head",
				TemplateName = "avo",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 195,
				GainPerSec = 19,
				DisplayName = "cado",
				ModelName = "AvocadoGorille_Body",
				TemplateName = "cado",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 180,
				GainPerSec = 18,
				DisplayName = "Gorilla",
				ModelName = "AvocadoGorille_Legs",
				TemplateName = "Gorilla",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["PapePaperoBetonino"] = {
			Rarity = "Common",
			Head = {
				Price = 190,
				GainPerSec = 19,
				DisplayName = "Pape",
				ModelName = "PapePaperoBetonino_Head",
				TemplateName = "Pape",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 200,
				GainPerSec = 20,
				DisplayName = "Papero",
				ModelName = "PapePaperoBetonino_Body",
				TemplateName = "Papero",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 185,
				GainPerSec = 18,
				DisplayName = "Betonino",
				ModelName = "PapePaperoBetonino_Legs",
				TemplateName = "Betonino",  -- Template dans LegsTemplate folder
				SpawnWeight = 10,
			},
		},

		["KoalaTostinoGrillini"] = {
			Rarity = "Common",
			Head = {
				Price = 195,
				GainPerSec = 19,
				DisplayName = "Koala",
				ModelName = "KoalaTostinoGrillini_Head",
				TemplateName = "Koala",  -- Template dans HeadTemplate folder
				SpawnWeight = 10,
			},
			Body = {
				Price = 205,
				GainPerSec = 20,
				DisplayName = "Tostino",
				ModelName = "KoalaTostinoGrillini_Body",
				TemplateName = "Tostino",  -- Template dans BodyTemplate folder
				SpawnWeight = 10,
			},
			Legs = {
				Price = 190,
				GainPerSec = 19,
				DisplayName = "Grillini",
				ModelName = "KoalaTostinoGrillini_Legs",
				TemplateName = "Grillini",  -- Template dans LegsTemplate folder
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
