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
        
        -- Serveur → Client
        SyncPlayerData = "SyncPlayerData",
        SyncInventory = "SyncInventory",
        SyncCodex = "SyncCodex",
        SyncDoorState = "SyncDoorState",
        Notification = "Notification",
        
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
    -- MESSAGES D'ERREUR (pour UI)
    -- ═══════════════════════════════════════
    ErrorMessages = {
        NotEnoughMoney = "Pas assez d'argent!",
        NoSlotAvailable = "Aucun slot disponible! Achetez-en un.",
        InventoryFull = "Inventaire plein! (Max 3 pièces)",
        InvalidPiece = "Cette pièce n'existe plus!",
        MissingPieces = "Il vous faut 3 pièces différentes!",
        MaxSlotsReached = "Vous avez déjà tous les slots!",
        OnCooldown = "Veuillez patienter...",
        NotOwner = "Ce n'est pas votre base!",
    },
    
    -- ═══════════════════════════════════════
    -- MESSAGES DE SUCCÈS
    -- ═══════════════════════════════════════
    SuccessMessages = {
        PiecePickedUp = "Pièce ramassée!",
        BrainrotCrafted = "Brainrot créé!",
        SlotPurchased = "Nouveau slot acheté!",
        CashCollected = "Argent collecté du slot!",
        DoorActivated = "Porte fermée pour 30 secondes!",
        SetCompleted = "Set complété! Bonus reçu!",
    },
}

return Constants
