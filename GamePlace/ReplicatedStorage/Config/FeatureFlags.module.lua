--[[
    FeatureFlags.lua
    Activer/désactiver des features du jeu
    
    Utile pour:
    - Développement progressif
    - A/B testing
    - Désactiver temporairement une feature buggée
]]

local FeatureFlags = {
    -- ═══════════════════════════════════════
    -- FEATURES ACTIVES
    -- ═══════════════════════════════════════
    DOOR_SYSTEM = true,              -- Système de porte sécurisée
    CODEX_SYSTEM = true,             -- Collection de pièces
    REVENUE_SYSTEM = true,           -- Revenus passifs des Brainrots
    DEATH_ON_SPINNER = true,         -- Mort au contact du spinner
    ROBUX_SHOP = true,               -- Phase 9: Shop Robux

    -- ═══════════════════════════════════════
    -- FEATURES DÉSACTIVÉES (FUTURES)
    -- ═══════════════════════════════════════
    TRADING_SYSTEM = false,          -- Échange entre joueurs
    DAILY_REWARDS = false,           -- Récompenses journalières
    LEADERBOARD = false,             -- Classement
    EVENTS_SYSTEM = false,           -- Événements temporaires
    PETS_SYSTEM = false,             -- Animaux de compagnie
    GAMEPASSES = false,              -- Achats in-game
    
    -- ═══════════════════════════════════════
    -- DEBUG
    -- ═══════════════════════════════════════
    DEBUG_MODE = true,               -- Afficher les logs de debug
    DEBUG_UI = false,                -- UI de debug visible
    SKIP_DATASTORE = false,          -- Ignorer DataStore (pour tests)
    INSTANT_SPAWN = false,           -- Spawn pièces instantané (pour tests)
    FREE_PURCHASES = false,          -- Achats gratuits (pour tests)
}

return FeatureFlags
