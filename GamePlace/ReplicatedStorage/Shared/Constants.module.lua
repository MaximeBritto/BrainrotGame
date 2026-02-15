--[[
    Constants.lua
    Enums et constantes partagées entre client et serveur
    
    Utiliser ces valeurs au lieu de strings magiques dans le code
]]

local Constants = {
    -- ═══════════════════════════════════════
    -- ÉTATS DE LA PORTE
    -- ═══════════════════════════════════════
    DoorState = {
        Open = "Open",
        Closed = "Closed",
    },
    
    -- ═══════════════════════════════════════
    -- TYPES DE PIÈCES
    -- ═══════════════════════════════════════
    PieceType = {
        Head = "Head",
        Body = "Body",
        Legs = "Legs",
    },
    
    -- ═══════════════════════════════════════
    -- RÉSULTATS D'ACTIONS
    -- ═══════════════════════════════════════
    ActionResult = {
        Success = "Success",
        NotEnoughMoney = "NotEnoughMoney",
        NoSlotAvailable = "NoSlotAvailable",
        InventoryFull = "InventoryFull",
        InvalidPiece = "InvalidPiece",
        MissingPieces = "MissingPieces",
        AlreadyOwned = "AlreadyOwned",
        MaxSlotsReached = "MaxSlotsReached",
        OnCooldown = "OnCooldown",
        NotOwner = "NotOwner",
        AlreadyCarrying = "AlreadyCarrying",
        NotCarrying = "NotCarrying",
    },
    
    -- ═══════════════════════════════════════
    -- COLLISION GROUPS
    -- ═══════════════════════════════════════
    CollisionGroup = {
        Default = "Default",
        Players = "Players",
        DoorBars = "DoorBars",
        Pieces = "Pieces",
    },
    
    -- ═══════════════════════════════════════
    -- NOMS DES REMOTES
    -- ═══════════════════════════════════════
    RemoteNames = {
        -- Client → Serveur
        PickupPiece = "PickupPiece",
        DropPieces = "DropPieces",
        Craft = "Craft",
        BuySlot = "BuySlot",
        CollectSlotCash = "CollectSlotCash",  -- slotIndex en paramètre
        ActivateDoor = "ActivateDoor",
        StealBrainrot = "StealBrainrot",            -- Phase 8: Vol de Brainrot (simplifié)
        PlaceStolenBrainrot = "PlaceStolenBrainrot", -- Phase 8: Placer brainrot volé sur un slot
        BatHit = "BatHit",                          -- Phase 8: Coup de batte
        RequestShopPurchase = "RequestShopPurchase",   -- Phase 9: Achat shop Robux

        -- Serveur → Client
        SyncPlayerData = "SyncPlayerData",
        SyncInventory = "SyncInventory",
        SyncCodex = "SyncCodex",
        SyncDoorState = "SyncDoorState",
        Notification = "Notification",
        SyncPlacedBrainrots = "SyncPlacedBrainrots",  -- Phase 8: Sync Brainrots placés
        SyncCarriedBrainrot = "SyncCarriedBrainrot", -- Phase 8: Sync état brainrot porté
        SyncStunState = "SyncStunState",            -- Phase 8: État d'assommage

        -- RemoteFunctions
        GetFullPlayerData = "GetFullPlayerData",
    },
    
    -- ═══════════════════════════════════════
    -- NOMS WORKSPACE
    -- ═══════════════════════════════════════
    WorkspaceNames = {
        BasesFolder = "Bases",
        ArenaFolder = "Arena",
        PiecesFolder = "ActivePieces",
        
        -- Dans une Base
        SpawnPoint = "SpawnPoint",
        SlotsFolder = "Slots",
        DoorFolder = "Door",
        DoorBars = "Bars",
        DoorPad = "ActivationPad",
        SlotShop = "SlotShop",
        SlotShopSign = "Sign",        -- Le panneau avec ProximityPrompt
        SlotShopDisplay = "Display",  -- L'écran avec le prix
        FloorsFolder = "Floors",
        
        -- Dans un Slot
        SlotPlatform = "Platform",
        SlotCollectPad = "CollectPad",
        
        -- Dans l'Arène
        Canon = "Canon",
        Spinner = "Spinner",
        SpawnZone = "SpawnZone",
    },
    
    -- ═══════════════════════════════════════
    -- ERROR MESSAGES (for UI)
    -- ═══════════════════════════════════════
    ErrorMessages = {
        NotEnoughMoney = "Not enough money!",
        NoSlotAvailable = "No slot available! Buy one.",
        InventoryFull = "Inventory full! (Max 3 pieces)",
        InvalidPiece = "This piece no longer exists!",
        MissingPieces = "You need 3 different pieces!",
        MaxSlotsReached = "You already have all slots!",
        OnCooldown = "Please wait...",
        NotOwner = "This is not your base!",
        AlreadyCarrying = "You are already carrying a Brainrot!",
        NotCarrying = "You are not carrying a stolen Brainrot.",
    },
    
    -- ═══════════════════════════════════════
    -- SUCCESS MESSAGES
    -- ═══════════════════════════════════════
    SuccessMessages = {
        PiecePickedUp = "Piece picked up!",
        BrainrotCrafted = "Brainrot created!",
        SlotPurchased = "New slot purchased!",
        CashCollected = "Cash collected from slot!",
        DoorActivated = "Door closed for 30 seconds!",
        SetCompleted = "Set completed! Bonus received!",
    },
}

return Constants
