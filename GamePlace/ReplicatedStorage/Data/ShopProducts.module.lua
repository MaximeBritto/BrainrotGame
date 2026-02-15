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
