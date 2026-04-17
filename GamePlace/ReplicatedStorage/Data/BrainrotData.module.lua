--[[
    BrainrotData.lua
    Registry de tous les sets de Brainrots et leurs pièces

    Équilibrage (aligné Steal a Brainrot) :
    1 brainrot crafté ici (H+B+L sommés) = 1 brainrot SaB

    Totaux craft par rareté (somme H+B+L) :
    - Common    : 30$-1700$   | 2-14 GPS   | ROI ~110-130s
    - Rare      : 2000-9700$  | 15-75 GPS  | ROI ~130s
    - Epic      : 10000-47500$| 75-325 GPS | ROI ~140s
    - Legendary : 35000-347000$| 200-1900 GPS | ROI ~175-185s

    Les SpawnWeight varient par tier au sein d'une rareté :
    plus le tier est élevé, plus le set est rare à looter.

    Pour ajouter un nouveau set, copier un bloc existant et modifier les valeurs.
]]

local BrainrotData = {
    -- ═══════════════════════════════════════
    -- SETS DE BRAINROTS
    -- ═══════════════════════════════════════
    Sets = {
        -- ────────── COMMON tier 1 ──────────
        ["brrbrrPatapim"] = {
            Rarity = "Common",
            Head = {
                Price = 15,
                GainPerSec = 1,
                DisplayName = "Brr Brr",
                ModelName = "brrbrrPatapim_Head",
                TemplateName = "brrbrr",
                SpawnWeight = 25,
            },
            Body = {
                Price = 0,
                GainPerSec = 0,
                DisplayName = "Brr Brr Body",
                ModelName = "brrbrrPatapim_Body",
                TemplateName = "",
                SpawnWeight = 0,
            },
            Legs = {
                Price = 15,
                GainPerSec = 1,
                DisplayName = "Pata Pim",
                ModelName = "brrbrrPatapim_Legs",
                TemplateName = "patapim",
                SpawnWeight = 25,
            },
        },

        -- ────────── COMMON tier 2 ──────────
        ["TralaleroTralala"] = {
            Rarity = "Common",
            Head = {
                Price = 0,
                GainPerSec = 0,
                DisplayName = "Tra La La Head",
                ModelName = "TralaleroTralala_Head",
                TemplateName = "",
                SpawnWeight = 0,
            },
            Body = {
                Price = 60,
                GainPerSec = 3,
                DisplayName = "La Le Ro",
                ModelName = "TralaleroTralala_Body",
                TemplateName = "lalero",
                SpawnWeight = 22,
            },
            Legs = {
                Price = 0,
                GainPerSec = 0,
                DisplayName = "Tra La La Legs",
                ModelName = "TralaleroTralala_Legs",
                TemplateName = "",
                SpawnWeight = 0,
            },
        },

        -- ────────── COMMON tier 3 ──────────
        ["CactoHipopoTamo"] = {
            Rarity = "Common",
            Head = {
                Price = 40,
                GainPerSec = 1,
                DisplayName = "Cacto",
                ModelName = "CactoHipopoTamo_Head",
                TemplateName = "Cacto",
                SpawnWeight = 20,
            },
            Body = {
                Price = 45,
                GainPerSec = 2,
                DisplayName = "Hipopo",
                ModelName = "CactoHipopoTamo_Body",
                TemplateName = "Hipopo",
                SpawnWeight = 20,
            },
            Legs = {
                Price = 35,
                GainPerSec = 1,
                DisplayName = "Tamo",
                ModelName = "CactoHipopoTamo_Legs",
                TemplateName = "Tamo",
                SpawnWeight = 20,
            },
        },

        -- ────────── EPIC tier 1 ──────────
        ["PiccioneMacchina"] = {
            Rarity = "Epic",
            Head = {
                Price = 3500,
                GainPerSec = 26,
                DisplayName = "Picci",
                ModelName = "PiccioneMacchina_Head",
                TemplateName = "Picci",
                SpawnWeight = 22,
            },
            Body = {
                Price = 3700,
                GainPerSec = 27,
                DisplayName = "Onemac",
                ModelName = "PiccioneMacchina_Body",
                TemplateName = "Onemac",
                SpawnWeight = 22,
            },
            Legs = {
                Price = 2800,
                GainPerSec = 22,
                DisplayName = "China",
                ModelName = "PiccioneMacchina_Legs",
                TemplateName = "China",
                SpawnWeight = 22,
            },
        },

        -- ────────── COMMON tier 4 ──────────
        ["GirafaCelestre"] = {
            Rarity = "Common",
            Head = {
                Price = 75,
                GainPerSec = 2,
                DisplayName = "Gira",
                ModelName = "Girafa_Celestre_Head",
                TemplateName = "Gira",
                SpawnWeight = 18,
            },
            Body = {
                Price = 75,
                GainPerSec = 2,
                DisplayName = "fafa",
                ModelName = "Girafa_Celestre_Body",
                TemplateName = "fafa",
                SpawnWeight = 18,
            },
            Legs = {
                Price = 60,
                GainPerSec = 1,
                DisplayName = "Celestre",
                ModelName = "Girafa_Celestre_Legs",
                TemplateName = "Celestre",
                SpawnWeight = 18,
            },
        },

        -- ────────── RARE tier 1 ──────────
        ["LiriliLarila"] = {
            Rarity = "Rare",
            Head = {
                Price = 700,
                GainPerSec = 5,
                DisplayName = "Liri",
                ModelName = "LiriliLarila_Head",
                TemplateName = "Liri",
                SpawnWeight = 25,
            },
            Body = {
                Price = 720,
                GainPerSec = 5,
                DisplayName = "li La",
                ModelName = "LiriliLarila_Body",
                TemplateName = "liLa",
                SpawnWeight = 25,
            },
            Legs = {
                Price = 580,
                GainPerSec = 5,
                DisplayName = "rilà",
                ModelName = "LiriliLarila_Legs",
                TemplateName = "rila",
                SpawnWeight = 25,
            },
        },

        -- ────────── RARE tier 2 ──────────
        ["TripiTropiTropaTripa"] = {
            Rarity = "Rare",
            Head = {
                Price = 1100,
                GainPerSec = 8,
                DisplayName = "tripi",
                ModelName = "TripiTropiTropaTripa_Head",
                TemplateName = "tripi",
                SpawnWeight = 20,
            },
            Body = {
                Price = 1150,
                GainPerSec = 8,
                DisplayName = "tropitropa",
                ModelName = "TripiTropiTropaTripa_Body",
                TemplateName = "tropitropa",
                SpawnWeight = 20,
            },
            Legs = {
                Price = 950,
                GainPerSec = 7,
                DisplayName = "tripa",
                ModelName = "TripiTropiTropaTripa_Legs",
                TemplateName = "tripa",
                SpawnWeight = 20,
            },
        },

        -- ────────── COMMON tier 5 ──────────
        ["Talpadifero"] = {
            Rarity = "Common",
            Head = {
                Price = 115,
                GainPerSec = 2,
                DisplayName = "talpa",
                ModelName = "Talpadifero_Head",
                TemplateName = "talpa",
                SpawnWeight = 15,
            },
            Body = {
                Price = 120,
                GainPerSec = 2,
                DisplayName = "di",
                ModelName = "Talpadifero_Body",
                TemplateName = "di",
                SpawnWeight = 15,
            },
            Legs = {
                Price = 95,
                GainPerSec = 2,
                DisplayName = "fero",
                ModelName = "Talpadifero_Legs",
                TemplateName = "fero",
                SpawnWeight = 15,
            },
        },

        -- ────────── LEGENDARY tier 1 ──────────
        ["GraipusMedussi"] = {
            Rarity = "Legendary",
            Head = {
                Price = 12300,
                GainPerSec = 70,
                DisplayName = "grai",
                ModelName = "GraipusMedussi_Head",
                TemplateName = "grai",
                SpawnWeight = 25,
            },
            Body = {
                Price = 12500,
                GainPerSec = 72,
                DisplayName = "pus",
                ModelName = "GraipusMedussi_Body",
                TemplateName = "pus",
                SpawnWeight = 25,
            },
            Legs = {
                Price = 10200,
                GainPerSec = 58,
                DisplayName = "medussi",
                ModelName = "GraipusMedussi_Legs",
                TemplateName = "medussi",
                SpawnWeight = 25,
            },
        },

        -- ────────── EPIC tier 2 ──────────
        ["BombardiroCrocodilo"] = {
            Rarity = "Epic",
            Head = {
                Price = 6500,
                GainPerSec = 48,
                DisplayName = "Crocodilo",
                ModelName = "BombardiroCrocodilo_Head",
                TemplateName = "Crocodilo",
                SpawnWeight = 20,
            },
            Body = {
                Price = 6600,
                GainPerSec = 48,
                DisplayName = "Bombardiro",
                ModelName = "BombardiroCrocodilo_Body",
                TemplateName = "Bombardiro",
                SpawnWeight = 20,
            },
            Legs = {
                Price = 0,
                GainPerSec = 0,
                DisplayName = "",
                ModelName = "",
                TemplateName = "",
                SpawnWeight = 0,
            },
        },

        -- ────────── EPIC tier 3 ──────────
        ["SpioniroGolubiro"] = {
            Rarity = "Epic",
            Head = {
                Price = 5700,
                GainPerSec = 41,
                DisplayName = "spio",
                ModelName = "SpioniroGolubiro_Head",
                TemplateName = "spio",
                SpawnWeight = 18,
            },
            Body = {
                Price = 5900,
                GainPerSec = 42,
                DisplayName = "nirogolu",
                ModelName = "SpioniroGolubiro_Body",
                TemplateName = "nirogolu",
                SpawnWeight = 18,
            },
            Legs = {
                Price = 4700,
                GainPerSec = 34,
                DisplayName = "biro",
                ModelName = "SpioniroGolubiro_Legs",
                TemplateName = "biro",
                SpawnWeight = 18,
            },
        },

        -- ────────── COMMON tier 6 ──────────
        ["ZibraZubraZibralini"] = {
            Rarity = "Common",
            Head = {
                Price = 170,
                GainPerSec = 3,
                DisplayName = "zibra",
                ModelName = "ZibraZubraZibralini_Head",
                TemplateName = "zibra",
                SpawnWeight = 13,
            },
            Body = {
                Price = 170,
                GainPerSec = 2,
                DisplayName = "zubra",
                ModelName = "ZibraZubraZibralini_Body",
                TemplateName = "zubra",
                SpawnWeight = 13,
            },
            Legs = {
                Price = 140,
                GainPerSec = 2,
                DisplayName = "zibralini",
                ModelName = "ZibraZubraZibralini_Legs",
                TemplateName = "zibralini",
                SpawnWeight = 13,
            },
        },

        -- ────────── EPIC tier 4 ──────────
        ["TorrtuginniDragonfrutini"] = {
            Rarity = "Epic",
            Head = {
                Price = 6800,
                GainPerSec = 48,
                DisplayName = "Torrtuginni",
                ModelName = "TorrtuginniDragonfrutini_Head",
                TemplateName = "Torrtuginni",
                SpawnWeight = 15,
            },
            Body = {
                Price = 7000,
                GainPerSec = 50,
                DisplayName = "Dragon",
                ModelName = "TorrtuginniDragonfrutini_Body",
                TemplateName = "Dragon",
                SpawnWeight = 15,
            },
            Legs = {
                Price = 5600,
                GainPerSec = 40,
                DisplayName = "frutini",
                ModelName = "TorrtuginniDragonfrutini_Legs",
                TemplateName = "frutini",
                SpawnWeight = 15,
            },
        },

        -- ────────── COMMON tier 7 ──────────
        ["BananitaDolphinita"] = {
            Rarity = "Common",
            Head = {
                Price = 310,
                GainPerSec = 4,
                DisplayName = "Bananita",
                ModelName = "BananitaDolphinita_Head",
                TemplateName = "Bananita",
                SpawnWeight = 11,
            },
            Body = {
                Price = 0,
                GainPerSec = 0,
                DisplayName = "",
                ModelName = "",
                TemplateName = "",
                SpawnWeight = 0,
            },
            Legs = {
                Price = 310,
                GainPerSec = 4,
                DisplayName = "Dolphinita",
                ModelName = "BananitaDolphinita_Legs",
                TemplateName = "Dolphinita",
                SpawnWeight = 11,
            },
        },

        -- ────────── RARE tier 3 ──────────
        ["ChimpanziniSpiderini"] = {
            Rarity = "Rare",
            Head = {
                Price = 1550,
                GainPerSec = 11,
                DisplayName = "Chimpan",
                ModelName = "ChimpanziniSpiderini_Head",
                TemplateName = "Chimpan",
                SpawnWeight = 15,
            },
            Body = {
                Price = 1600,
                GainPerSec = 11,
                DisplayName = "zini",
                ModelName = "ChimpanziniSpiderini_Body",
                TemplateName = "zini",
                SpawnWeight = 15,
            },
            Legs = {
                Price = 1350,
                GainPerSec = 10,
                DisplayName = "Spiderini",
                ModelName = "ChimpanziniSpiderini_Legs",
                TemplateName = "Spiderini",
                SpawnWeight = 15,
            },
        },

        -- ────────── LEGENDARY tier 2 ──────────
        ["DragonCannelloni"] = {
            Rarity = "Legendary",
            Head = {
                Price = 16800,
                GainPerSec = 93,
                DisplayName = "dragon",
                ModelName = "DragonCannelloni_Head",
                TemplateName = "dragon",
                SpawnWeight = 20,
            },
            Body = {
                Price = 17100,
                GainPerSec = 95,
                DisplayName = "cannel",
                ModelName = "DragonCannelloni_Body",
                TemplateName = "cannel",
                SpawnWeight = 20,
            },
            Legs = {
                Price = 14100,
                GainPerSec = 77,
                DisplayName = "loni",
                ModelName = "DragonCannelloni_Legs",
                TemplateName = "loni",
                SpawnWeight = 20,
            },
        },

        -- ────────── COMMON tier 8 ──────────
        ["FrigoFrigoCamelo"] = {
            Rarity = "Common",
            Head = {
                Price = 270,
                GainPerSec = 3,
                DisplayName = "Frigo",
                ModelName = "FrigoFrigoCamelo_Head",
                TemplateName = "Frigo",
                SpawnWeight = 9,
            },
            Body = {
                Price = 280,
                GainPerSec = 3,
                DisplayName = "Frigo",
                ModelName = "FrigoFrigoCamelo_Body",
                TemplateName = "Frigo",
                SpawnWeight = 9,
            },
            Legs = {
                Price = 230,
                GainPerSec = 3,
                DisplayName = "Camelo",
                ModelName = "FrigoFrigoCamelo_Legs",
                TemplateName = "Camelo",
                SpawnWeight = 9,
            },
        },

        -- ────────── EPIC tier 5 ──────────
        ["GattatinoNyanino"] = {
            Rarity = "Epic",
            Head = {
                Price = 7900,
                GainPerSec = 56,
                DisplayName = "Gattatino",
                ModelName = "GattatinoNyanino_Head",
                TemplateName = "Gattatino",
                SpawnWeight = 13,
            },
            Body = {
                Price = 8100,
                GainPerSec = 58,
                DisplayName = "Nya",
                ModelName = "GattatinoNyanino_Body",
                TemplateName = "Nya",
                SpawnWeight = 13,
            },
            Legs = {
                Price = 6500,
                GainPerSec = 45,
                DisplayName = "nino",
                ModelName = "GattatinoNyanino_Legs",
                TemplateName = "nino",
                SpawnWeight = 13,
            },
        },

        -- ────────── LEGENDARY tier 3 ──────────
        ["TrenostruzzoTurbo3000"] = {
            Rarity = "Legendary",
            Head = {
                Price = 21700,
                GainPerSec = 119,
                DisplayName = "Trenostruzzo",
                ModelName = "TrenostruzzoTurbo3000_Head",
                TemplateName = "Trenostruzzo",
                SpawnWeight = 16,
            },
            Body = {
                Price = 22100,
                GainPerSec = 122,
                DisplayName = "Turbo",
                ModelName = "TrenostruzzoTurbo3000_Body",
                TemplateName = "Turbo",
                SpawnWeight = 16,
            },
            Legs = {
                Price = 18200,
                GainPerSec = 99,
                DisplayName = "3000",
                ModelName = "TrenostruzzoTurbo3000_Legs",
                TemplateName = "3000",
                SpawnWeight = 16,
            },
        },

        -- ────────── COMMON tier 9 ──────────
        ["CocoCocosiniMama"] = {
            Rarity = "Common",
            Head = {
                Price = 350,
                GainPerSec = 4,
                DisplayName = "Coco",
                ModelName = "CocoCocosiniMama_Head",
                TemplateName = "Coco",
                SpawnWeight = 7,
            },
            Body = {
                Price = 370,
                GainPerSec = 4,
                DisplayName = "Cocosini",
                ModelName = "CocoCocosiniMama_Body",
                TemplateName = "Cocosini",
                SpawnWeight = 7,
            },
            Legs = {
                Price = 280,
                GainPerSec = 3,
                DisplayName = "Mama",
                ModelName = "CocoCocosiniMama_Legs",
                TemplateName = "Mama",
                SpawnWeight = 7,
            },
        },

        -- ────────── EPIC tier 6 ──────────
        ["BlueberrinniOctopusini"] = {
            Rarity = "Epic",
            Head = {
                Price = 13000,
                GainPerSec = 91,
                DisplayName = "Blueberrinni",
                ModelName = "BlueberrinniOctopusini_Head",
                TemplateName = "Blueberrinni",
                SpawnWeight = 11,
            },
            Body = {
                Price = 0,
                GainPerSec = 0,
                DisplayName = "",
                ModelName = "",
                TemplateName = "",
                SpawnWeight = 0,
            },
            Legs = {
                Price = 12600,
                GainPerSec = 89,
                DisplayName = "Octopusini",
                ModelName = "BlueberrinniOctopusini_Legs",
                TemplateName = "Octopusini",
                SpawnWeight = 11,
            },
        },

        -- ────────── EPIC tier 7 ──────────
        ["LaVaccaSaturnoSaturnita"] = {
            Rarity = "Epic",
            Head = {
                Price = 10100,
                GainPerSec = 71,
                DisplayName = "LaVacca",
                ModelName = "LaVaccaSaturnoSaturnita_Head",
                TemplateName = "LaVacca",
                SpawnWeight = 9,
            },
            Body = {
                Price = 10300,
                GainPerSec = 73,
                DisplayName = "Saturno",
                ModelName = "LaVaccaSaturnoSaturnita_Body",
                TemplateName = "Saturno",
                SpawnWeight = 9,
            },
            Legs = {
                Price = 8400,
                GainPerSec = 57,
                DisplayName = "Saturnita",
                ModelName = "LaVaccaSaturnoSaturnita_Legs",
                TemplateName = "Saturnita",
                SpawnWeight = 9,
            },
        },

        -- ────────── COMMON tier 10 ──────────
        ["StrawberrelliFlamingelli"] = {
            Rarity = "Common",
            Head = {
                Price = 470,
                GainPerSec = 4,
                DisplayName = "Strawberrelli",
                ModelName = "StrawberrelliFlamingelli_Head",
                TemplateName = "Strawberrelli",
                SpawnWeight = 5,
            },
            Body = {
                Price = 490,
                GainPerSec = 4,
                DisplayName = "Flamin",
                ModelName = "StrawberrelliFlamingelli_Body",
                TemplateName = "Flamin",
                SpawnWeight = 5,
            },
            Legs = {
                Price = 390,
                GainPerSec = 4,
                DisplayName = "gelli",
                ModelName = "StrawberrelliFlamingelli_Legs",
                TemplateName = "gelli",
                SpawnWeight = 5,
            },
        },

        -- ────────── COMMON tier 11 ──────────
        ["SalamiSalaminoPenguino"] = {
            Rarity = "Common",
            Head = {
                Price = 600,
                GainPerSec = 5,
                DisplayName = "Salami",
                ModelName = "SalamiSalaminoPenguino_Head",
                TemplateName = "Salami",
                SpawnWeight = 3,
            },
            Body = {
                Price = 620,
                GainPerSec = 5,
                DisplayName = "Salamino",
                ModelName = "SalamiSalaminoPenguino_Body",
                TemplateName = "Salamino",
                SpawnWeight = 3,
            },
            Legs = {
                Price = 480,
                GainPerSec = 4,
                DisplayName = "Penguino",
                ModelName = "SalamiSalaminoPenguino_Legs",
                TemplateName = "Penguino",
                SpawnWeight = 3,
            },
        },

        -- ────────── EPIC tier 8 ──────────
        ["TigreTigroligreFrutonni"] = {
            Rarity = "Epic",
            Head = {
                Price = 11200,
                GainPerSec = 78,
                DisplayName = "Tigré",
                ModelName = "TigreTigroligreFrutonni_Head",
                TemplateName = "Tigré",
                SpawnWeight = 8,
            },
            Body = {
                Price = 11400,
                GainPerSec = 80,
                DisplayName = "Tigroligre",
                ModelName = "TigreTigroligreFrutonni_Body",
                TemplateName = "Tigroligre",
                SpawnWeight = 8,
            },
            Legs = {
                Price = 9300,
                GainPerSec = 64,
                DisplayName = "Frutonni",
                ModelName = "TigreTigroligreFrutonni_Legs",
                TemplateName = "Frutonni",
                SpawnWeight = 8,
            },
        },

        -- ────────── LEGENDARY tier 4 ──────────
        ["ElcrococrocoDilito"] = {
            Rarity = "Legendary",
            Head = {
                Price = 28000,
                GainPerSec = 152,
                DisplayName = "Elcroco",
                ModelName = "ElcrococrocoDilito_Head",
                TemplateName = "Elcroco",
                SpawnWeight = 12,
            },
            Body = {
                Price = 28500,
                GainPerSec = 155,
                DisplayName = "croco",
                ModelName = "ElcrococrocoDilito_Body",
                TemplateName = "croco",
                SpawnWeight = 12,
            },
            Legs = {
                Price = 23500,
                GainPerSec = 128,
                DisplayName = "Dilito",
                ModelName = "ElcrococrocoDilito_Legs",
                TemplateName = "Dilito",
                SpawnWeight = 12,
            },
        },

        -- ────────── LEGENDARY tier 5 ──────────
        ["DinossauroNuclearo"] = {
            Rarity = "Legendary",
            Head = {
                Price = 36400,
                GainPerSec = 193,
                DisplayName = "Dinossauro",
                ModelName = "DinossauroNuclearo_Head",
                TemplateName = "Dinossauro",
                SpawnWeight = 9,
            },
            Body = {
                Price = 37100,
                GainPerSec = 196,
                DisplayName = "sauro",
                ModelName = "DinossauroNuclearo_Body",
                TemplateName = "sauro",
                SpawnWeight = 9,
            },
            Legs = {
                Price = 30500,
                GainPerSec = 161,
                DisplayName = "Nuclearo",
                ModelName = "DinossauroNuclearo_Legs",
                TemplateName = "Nuclearo",
                SpawnWeight = 9,
            },
        },

        -- ────────── RARE tier 4 ──────────
        ["ChefCrabracadabra"] = {
            Rarity = "Rare",
            Head = {
                Price = 2050,
                GainPerSec = 14,
                DisplayName = "Chef",
                ModelName = "ChefCrabracadabra_Head",
                TemplateName = "Chef",
                SpawnWeight = 12,
            },
            Body = {
                Price = 2100,
                GainPerSec = 15,
                DisplayName = "Crabra",
                ModelName = "ChefCrabracadabra_Body",
                TemplateName = "Crabra",
                SpawnWeight = 12,
            },
            Legs = {
                Price = 1750,
                GainPerSec = 13,
                DisplayName = "cadabra",
                ModelName = "ChefCrabracadabra_Legs",
                TemplateName = "cadabra",
                SpawnWeight = 12,
            },
        },

        -- ────────── EPIC tier 9 ──────────
        ["AvocadoGorille"] = {
            Rarity = "Epic",
            Head = {
                Price = 12300,
                GainPerSec = 86,
                DisplayName = "avo",
                ModelName = "AvocadoGorille_Head",
                TemplateName = "avo",
                SpawnWeight = 7,
            },
            Body = {
                Price = 12500,
                GainPerSec = 87,
                DisplayName = "cado",
                ModelName = "AvocadoGorille_Body",
                TemplateName = "cado",
                SpawnWeight = 7,
            },
            Legs = {
                Price = 10200,
                GainPerSec = 70,
                DisplayName = "Gorilla",
                ModelName = "AvocadoGorille_Legs",
                TemplateName = "Gorilla",
                SpawnWeight = 7,
            },
        },

        -- ────────── RARE tier 5 ──────────
        ["PapePaperoBetonino"] = {
            Rarity = "Rare",
            Head = {
                Price = 2600,
                GainPerSec = 19,
                DisplayName = "Pape",
                ModelName = "PapePaperoBetonino_Head",
                TemplateName = "Pape",
                SpawnWeight = 8,
            },
            Body = {
                Price = 2700,
                GainPerSec = 19,
                DisplayName = "Papero",
                ModelName = "PapePaperoBetonino_Body",
                TemplateName = "Papero",
                SpawnWeight = 8,
            },
            Legs = {
                Price = 2200,
                GainPerSec = 17,
                DisplayName = "Betonino",
                ModelName = "PapePaperoBetonino_Legs",
                TemplateName = "Betonino",
                SpawnWeight = 8,
            },
        },

        -- ────────── RARE tier 6 ──────────
        ["KoalaTostinoGrillini"] = {
            Rarity = "Rare",
            Head = {
                Price = 3400,
                GainPerSec = 26,
                DisplayName = "Koala",
                ModelName = "KoalaTostinoGrillini_Head",
                TemplateName = "Koala",
                SpawnWeight = 5,
            },
            Body = {
                Price = 3500,
                GainPerSec = 26,
                DisplayName = "Tostino",
                ModelName = "KoalaTostinoGrillini_Body",
                TemplateName = "Tostino",
                SpawnWeight = 5,
            },
            Legs = {
                Price = 2800,
                GainPerSec = 23,
                DisplayName = "Grillini",
                ModelName = "KoalaTostinoGrillini_Legs",
                TemplateName = "Grillini",
                SpawnWeight = 5,
            },
        },

        -- ────────── LEGENDARY tier 6 ──────────
        ["LucertoloDisconnessoDisconessa"] = {
            Rarity = "Legendary",
            Head = {
                Price = 46200,
                GainPerSec = 245,
                DisplayName = "Lucertolo",
                ModelName = "LucertoloDisconnessoDisconessa_Head",
                TemplateName = "Lucertolo",
                SpawnWeight = 7,
            },
            Body = {
                Price = 47100,
                GainPerSec = 249,
                DisplayName = "Disconnesso",
                ModelName = "LucertoloDisconnessoDisconessa_Body",
                TemplateName = "Disconnesso",
                SpawnWeight = 7,
            },
            Legs = {
                Price = 38700,
                GainPerSec = 206,
                DisplayName = "Disconessa",
                ModelName = "LucertoloDisconnessoDisconessa_Legs",
                TemplateName = "Disconessa",
                SpawnWeight = 7,
            },
        },

        -- ────────── LEGENDARY tier 7 ──────────
        ["DonCaprinoSigaro"] = {
            Rarity = "Legendary",
            Head = {
                Price = 58800,
                GainPerSec = 308,
                DisplayName = "Don",
                ModelName = "DonCaprinoSigaro_Head",
                TemplateName = "Don",
                SpawnWeight = 5,
            },
            Body = {
                Price = 60000,
                GainPerSec = 314,
                DisplayName = "Caprino",
                ModelName = "DonCaprinoSigaro_Body",
                TemplateName = "Caprino",
                SpawnWeight = 5,
            },
            Legs = {
                Price = 49200,
                GainPerSec = 258,
                DisplayName = "Sigaro",
                ModelName = "DonCaprinoSigaro_Legs",
                TemplateName = "Sigaro",
                SpawnWeight = 5,
            },
        },

        -- ────────── LEGENDARY tier 8 ──────────
        ["AstroGorilloBananito"] = {
            Rarity = "Legendary",
            Head = {
                Price = 75300,
                GainPerSec = 385,
                DisplayName = "Astro",
                ModelName = "AstroGorilloBananito_Head",
                TemplateName = "Astro",
                SpawnWeight = 4,
            },
            Body = {
                Price = 76800,
                GainPerSec = 392,
                DisplayName = "Gorillo",
                ModelName = "AstroGorilloBananito_Body",
                TemplateName = "Gorillo",
                SpawnWeight = 4,
            },
            Legs = {
                Price = 62900,
                GainPerSec = 323,
                DisplayName = "Bananito",
                ModelName = "AstroGorilloBananito_Legs",
                TemplateName = "Bananito",
                SpawnWeight = 4,
            },
        },

        -- ────────── LEGENDARY tier 9 ──────────
        ["PupazzoVuotoOrbitalino"] = {
            Rarity = "Legendary",
            Head = {
                Price = 96300,
                GainPerSec = 490,
                DisplayName = "Pupazzo",
                ModelName = "PupazzoVuotoOrbitalino_Head",
                TemplateName = "Pupazzo",
                SpawnWeight = 3,
            },
            Body = {
                Price = 98200,
                GainPerSec = 499,
                DisplayName = "Vuoto",
                ModelName = "PupazzoVuotoOrbitalino_Body",
                TemplateName = "Vuoto",
                SpawnWeight = 3,
            },
            Legs = {
                Price = 80500,
                GainPerSec = 411,
                DisplayName = "orbitalino",
                ModelName = "PupazzoVuotoOrbitalino_Legs",
                TemplateName = "orbitalino",
                SpawnWeight = 3,
            },
        },

        -- ────────── EPIC tier 10 ──────────
        ["ToilettoPinzePinze"] = {
            Rarity = "Epic",
            Head = {
                Price = 13400,
                GainPerSec = 93,
                DisplayName = "Toiletto",
                ModelName = "ToilettoPinzePinze_Head",
                TemplateName = "Toiletto",
                SpawnWeight = 6,
            },
            Body = {
                Price = 13600,
                GainPerSec = 94,
                DisplayName = "Pinze",
                ModelName = "ToilettoPinzePinze_Body",
                TemplateName = "Pinze",
                SpawnWeight = 6,
            },
            Legs = {
                Price = 11100,
                GainPerSec = 77,
                DisplayName = "pinze",
                ModelName = "ToilettoPinzePinze_Legs",
                TemplateName = "pinze",
                SpawnWeight = 6,
            },
        },

        -- ────────── EPIC tier 11 ──────────
        -- Visuellement 2 pièces (Head + Legs). Le jeu exige 3 templates pour craft + assemblage :
        -- crée un petit corps "connecteur" (part invisible + Top/BottomAttachment) dans BodyTemplate
        -- sous le nom PakrahmatmamatBody.
        ["Pakrahmatmamat"] = {
            Rarity = "Epic",
            Head = {
                Price = 20800,
                GainPerSec = 143,
                DisplayName = "Pakrahmat",
                ModelName = "Pakrahmatmamat_Head",
                TemplateName = "Pakrahmat",
                SpawnWeight = 5,
            },

            Legs = {
                Price = 20500,
                GainPerSec = 142,
                DisplayName = "mamat",
                ModelName = "Pakrahmatmamat_Legs",
                TemplateName = "mamat",
                SpawnWeight = 5,
            },
        },

        -- ────────── LEGENDARY tier 10 ──────────
        ["MariachiCoraCorazoni"] = {
            Rarity = "Legendary",
            Head = {
                Price = 121400,
                GainPerSec = 665,
                DisplayName = "Mariachi",
                ModelName = "MariachiCoraCorazoni_Head",
                TemplateName = "Mariachi",
                SpawnWeight = 2,
            },
            Body = {
                Price = 123900,
                GainPerSec = 678,
                DisplayName = "Cora",
                ModelName = "MariachiCoraCorazoni_Body",
                TemplateName = "Cora",
                SpawnWeight = 2,
            },
            Legs = {
                Price = 101700,
                GainPerSec = 557,
                DisplayName = "Corazoni",
                ModelName = "MariachiCoraCorazoni_Legs",
                TemplateName = "Corazoni",
                SpawnWeight = 2,
            },
        },

        -- ────────── EPIC tier 12 ──────────
        ["LaCucarachaScara"] = {
            Rarity = "Epic",
            Head = {
                Price = 15600,
                GainPerSec = 107,
                DisplayName = "LaCuca",
                ModelName = "LaCucarachaScara_Head",
                TemplateName = "LaCuca",
                SpawnWeight = 4,
            },
            Body = {
                Price = 15800,
                GainPerSec = 108,
                DisplayName = "Racha",
                ModelName = "LaCucarachaScara_Body",
                TemplateName = "Racha",
                SpawnWeight = 4,
            },
            Legs = {
                Price = 13000,
                GainPerSec = 91,
                DisplayName = "Scara",
                ModelName = "LaCucarachaScara_Legs",
                TemplateName = "Scara",
                SpawnWeight = 4,
            },
        },

        -- ────────── EPIC tier 13 ──────────
        ["Alessio"] = {
            Rarity = "Epic",
            Head = {
                Price = 23800,
                GainPerSec = 163,
                DisplayName = "Ales",
                ModelName = "Alessio_Head",
                TemplateName = "Ales",
                SpawnWeight = 3,
            },

            Legs = {
                Price = 23700,
                GainPerSec = 162,
                DisplayName = "sio",
                ModelName = "Alessio_Legs",
                TemplateName = "sio",
                SpawnWeight = 3,
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
