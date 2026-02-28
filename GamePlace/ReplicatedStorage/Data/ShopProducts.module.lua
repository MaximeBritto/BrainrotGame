--[[
    ShopProducts.module.lua
    Configuration des produits du Shop Robux

    Organisé par catégories (onglets dans le shop).
    Chaque catégorie contient une liste de produits.

    IMPORTANT: Les ProductId doivent correspondre aux Developer Products
    créés sur la page du jeu (roblox.com > Create > Your Game > Developer Products)
]]

local ShopProducts = {
    Categories = {
        {
            Id = "Money",
            DisplayName = "CASH",
            Icon = "rbxassetid://0",
            Order = 1,
            Products = {
                {
                    ProductId = 3537882222,
                    Cash = 3000,
                    Robux = 59,
                    DisplayName = "$3,000",
                },
                {
                    ProductId = 3537882916,
                    Cash = 25000,
                    Robux = 379,
                    DisplayName = "$25,000",
                },
                {
                    ProductId = 3537882920,
                    Cash = 100000,
                    Robux = 659,
                    DisplayName = "$100,000",
                },
                {
                    ProductId = 3537882919,
                    Cash = 500000,
                    Robux = 1249,
                    DisplayName = "$500,000",
                },
                {
                    ProductId = 3537884400,
                    Cash = 1000000,
                    Robux = 2499,
                    DisplayName = "$1,000,000",
                },
            },
        },

        {
            Id = "Extras",
            DisplayName = "EXTRAS",
            Icon = "rbxassetid://0",
            Order = 2,
            Products = {
                {
                    Section = "STARTER PACK",
                    ProductId = 3545593788, -- TODO: Créer le Developer Product sur Roblox et mettre l'ID ici
                    Cash = 1000,
                    LuckyBlocks = 1,
                    Spins = 1,
                    PermanentMultiplierBonus = 0.25,
                    Robux = 489,
                    DisplayName = "Starter Pack",
                    OneTimePurchaseKey = "StarterPack",
                    Description = {
                        "$1,000 Cash",
                        "1 Lucky Block",
                        "1 Spin",
                        "+0.25x Multiplier (permanent)",
                    },
                },
                {
                    Section = "BOOSTS",
                    ProductId = 3545587138,
                    MultiplierBoost = 2.0,
                    MultiplierDuration = 900,        -- 15 minutes
                    Robux = 249,
                    DisplayName = "x2 (15 min)",
                },
                {
                    Section = "LUCKY BLOCKS",
                    ProductId = 3543915022,
                    LuckyBlocks = 1,
                    Robux = 49,
                    DisplayName = "1 Lucky Block",
                },
                {
                    ProductId = 3543915185,
                    LuckyBlocks = 3,
                    Robux = 99,
                    DisplayName = "3 Lucky Blocks",
                },
                {
                    Section = "SPIN WHEEL",
                    ProductId = 3545025840,
                    Spins = 1,
                    Robux = 99,
                    DisplayName = "1 Spin",
                },
                {
                    ProductId = 3545025989,
                    Spins = 3,
                    Robux = 199,
                    DisplayName = "3 Spins",
                },
            },
        },

        --[[

        {
            Id = "GamePasses",
            DisplayName = "GAME PASSES",
            Icon = "rbxassetid://0",
            Order = 2,
            Products = {},
        },
        ]]
    },
}

return ShopProducts
