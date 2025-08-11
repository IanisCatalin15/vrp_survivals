-- ========================================
-- VRP SURVIVAL SYSTEM CONFIGURATION
-- ========================================
-- This file controls all aspects of the survival system
-- Modify values below to customize gameplay experience
-- 
-- IMPORTANT: Health values use vRP's 100-200 range system
-- Server-side calculations use 100-200 range, client displays 0-100% range
-- ========================================

local cfg = {
    -- ========================================
    -- DEFAULT VITAL VALUES (Starting Values)
    -- ========================================
    -- These are the initial values when a player spawns
    -- Range: 0-100 for all vitals, 100-200 for health (vRP standard)
    -- Note: For pee/poop: 0=good, 100=bad (inverted logic)
    
    defaults = {
        health = 200,     -- Starting health level (200 = full health, 100 = dead) - vRP standard
        armor = 0,        -- Starting armor level (100 = full armor, 0 = no armor)
        water = 100,      -- Starting water level (100 = full, 0 = empty)
        food = 50,        -- Starting food level (100 = full, 0 = empty)
        pee = 0,          -- Starting pee level (0 = empty, 100 = full bladder)
        poop = 10,        -- Starting poop level (0 = empty, 100 = full bowels)
        shower = 100,     -- Starting hygiene level (100 = clean, 0 = dirty)
        stress = 0,       -- Starting stress level (0 = calm, 100 = extremely stressed)
    },

    -- ========================================
    -- VITAL DECAY RATES (Per Minute)
    -- ========================================
    -- How much each vital changes every minute
    -- Positive values = increase, Negative values = decrease
    
    decay_rates = {
        water = -1,       -- Water decreases by 1 per minute (thirst)
        food = -1,        -- Food decreases by 1 per minute (hunger)
        shower = -5,      -- Hygiene decreases by 5 per minute (gets dirty)
        pee = 2,          -- Pee increases by 2 per minute (bladder fills)
        poop = 1,         -- Poop increases by 1 per minute (bowels fill)
    },

    -- ========================================
    -- STRESS SYSTEM CONFIGURATION
    -- ========================================
    -- Controls when and how much stress increases
    
    stress = {
        -- Thresholds for low vitals causing stress
        low_threshold = 20,           -- Vitals below this cause stress
        very_low_threshold = 10,      -- Vitals below this cause high stress
        
        -- Pee/Poop stress thresholds (inverted logic - high values = bad)
        pee_poop_threshold = 75,      -- Pee/poop above this causes stress
        pee_poop_critical = 90,       -- Pee/poop above this causes high stress
        
        -- Money stress threshold
        low_money_threshold = 5000,   -- Money below this causes stress
        
        -- Stress increase amounts per minute
        increase_low = 5,             -- Stress increase when vitals are low
        increase_very_low = 10,       -- Stress increase when vitals are very low
    },

    -- ========================================
    -- HEALTH DAMAGE SYSTEM
    -- ========================================
    -- Controls how stress and low vitals damage health
    
    health_damage = {
        -- Health damage from low vitals (water/food/pee/poop)
        from_low_vitals = {
            medium = 5,               -- Damage when vitals are low
            high = 10,                -- Damage when vitals are very low
        },
        
        -- Health damage from high stress
        from_stress = {
            low = 1,                  -- Damage when stress > 50
            medium = 5,               -- Damage when stress > 75
            high = 10,                -- Damage when stress > 90
        },
        
        -- Stress thresholds for health damage
        stress_thresholds = {
            low = 50,                 -- Stress level for low damage
            medium = 75,              -- Stress level for medium damage
            high = 90,                -- Stress level for high damage
        },
    },

    -- ========================================
    -- OVERFLOW DAMAGE SYSTEM
    -- ========================================
    -- Controls damage when vitals go below 0 or above 100
    
    overflow = {
        damage_factor = 2,            -- Multiplier for vital overflow damage
    },

    -- ========================================
    -- UPDATE FREQUENCY
    -- ========================================
    -- How often the system updates (in milliseconds)
    
    update_interval = 60000,         -- 60 seconds (1 minute)
}
  
return cfg