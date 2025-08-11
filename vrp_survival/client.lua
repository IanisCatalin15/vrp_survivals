--########## VRP Main ##########--
Tunnel = module("vrp", "lib/Tunnel")
Proxy = module("vrp", "lib/Proxy")

local cvRP = module("vrp", "client/vRP")
vRP = cvRP()

local Survival = class("Survival", vRP.Extension)

function Survival:__construct()
  vRP.Extension.__construct(self)
  
  -- Initialize injured state
  self.isInjured = false
  
  -- Check initial health for injured walking animation
  Citizen.CreateThread(function()
    Citizen.Wait(2000) -- Wait for ped to fully spawn
    local ped = PlayerPedId()
    local currentHealth = GetEntityHealth(ped)
    
    Survival:handleInjuredWalking(ped, currentHealth)
  end)
end

-- Store vitals locally
local vitals = {
  water = 100,
  food = 50,
  pee = 0,
  poop = 10,
  shower = 100,
  stress = 0,
  health = 100,
  armor = 100
}

-- Helper function to convert vRP health (100-200) to UI health (0-100)
local function convertHealthToUI(healthValue)
  if healthValue <= 100 then return 0 end
  return math.min(100, math.floor(((healthValue - 100) / 100) * 100))
end

-- Helper function to convert vRP armor (0-200) to UI armor (0-100)
local function convertArmorToUI(armorValue)
  if armorValue <= 0 then return 0 end
  return math.min(100, math.floor((armorValue / 200) * 100))
end

-- Helper function to update UI with vitals
local function updateUI()
  local uiHealth = convertHealthToUI(vitals.health)
  local uiArmor = convertArmorToUI(vitals.armor)
  
  SendNUIMessage({
    type = "updateVitals",
    water = vitals.water,
    food = vitals.food,
    pee = vitals.pee,
    poop = vitals.poop,
    shower = vitals.shower,
    stress = vitals.stress,
    health = uiHealth,
    armor = uiArmor
  })
end

-- Helper function to handle injured walking animation
function Survival:handleInjuredWalking(ped, currentHealth)
  if currentHealth <= 125 then -- 25% of 100-200 range (125 = 25% of 100-200)
    print("[SURVIVAL] Health check - Current:", currentHealth, "Threshold: 125 (25%)")
    RequestAnimSet("move_m@injured")
    while not HasAnimSetLoaded("move_m@injured") do
      Citizen.Wait(0)
    end
    SetPedMovementClipset(ped, "move_m@injured", 1.0)
    
    -- Disable sprinting and jumping when injured
    SetPedCanPlayAmbientAnims(ped, false)
    SetPedCanPlayAmbientBaseAnims(ped, false)
    
    -- Additional injured state effects
    SetPedCanRagdoll(ped, true)
    SetPedCanBeKnockedOffVehicle(ped, true)
    
    -- Store injured state
    self.isInjured = true
  else
    -- Reset to normal walking when health is above 25%
    ResetPedMovementClipset(ped, 0.0)
    
    -- Re-enable sprinting and jumping when recovered
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanPlayAmbientBaseAnims(ped, true)
    
    -- Reset additional injured state effects
    SetPedCanRagdoll(ped, false)
    SetPedCanBeKnockedOffVehicle(ped, false)
    
    -- Clear injured state
    self.isInjured = false
  end
end

Survival.tunnel = {}

-- Function server calls every minute to update vitals
function Survival.tunnel:updateVitals(data)
  vitals.water = math.floor(data.water or 100)
  vitals.food = math.floor(data.food or 50)
  vitals.pee = math.floor(data.pee or 0)
  vitals.poop = math.floor(data.poop or 10)
  vitals.shower = math.floor(data.shower or 100)
  vitals.stress = math.floor(data.stress or 0)
  -- Don't update health from server - keep actual ped health
  vitals.armor = math.floor(data.armor or 200)
  
  updateUI()
end

-- Function to vary health (called by server)
function Survival.tunnel:varyHealth(variation)
  local ped = GetPlayerPed(-1)
  local newHealth = math.floor(GetEntityHealth(ped) + variation)
  
  SetEntityHealth(ped, newHealth)
  vitals.health = newHealth
  
  -- Update injured walking animation immediately
  Survival:handleInjuredWalking(ped, newHealth)
  
  updateUI()
end

-- Function to get current ped health for server sync
function Survival.tunnel:getPedHealth()
  return GetEntityHealth(GetPlayerPed(-1))
end

-- Function to set health directly (called by server)
function Survival.tunnel:setHealth(healthValue)
  local ped = PlayerPedId()
  if ped then
    healthValue = math.max(100, math.min(200, healthValue))
    SetEntityHealth(ped, healthValue)
    -- Don't set vitals.health here - let the monitoring thread handle it
    updateUI()
  end
end

-- Main monitoring thread (consolidated health and armor monitoring)
Citizen.CreateThread(function()
  local lastHealth = GetEntityHealth(PlayerPedId())
  local lastArmor = GetPedArmour(PlayerPedId())
  
  while true do
    Citizen.Wait(50) -- Run more frequently to maintain priority over server updates
    local ped = PlayerPedId()
    local currentHealth = GetEntityHealth(ped)
    local currentArmor = GetPedArmour(ped)
    local needsUpdate = false
    
    -- Check health changes (this takes priority over server updates)
    if currentHealth ~= lastHealth then
      vitals.health = currentHealth
      lastHealth = currentHealth
      needsUpdate = true
      
      -- Handle injured walking animation based on health
      Survival:handleInjuredWalking(ped, currentHealth)
      
      -- Notify server of significant health changes
      if math.abs(currentHealth - vitals.health) > 5 and vRP.EXT.Survival and vRP.EXT.Survival.remote then
        vRP.EXT.Survival.remote._syncHealth()
      end
    end
    
    -- Check armor changes
    if currentArmor ~= lastArmor then
      vitals.armor = currentArmor
      lastArmor = currentArmor
      needsUpdate = true
    end
    
    -- Update UI only when needed
    if needsUpdate then
      updateUI()
    end
  end
end)

-- Prevent health regeneration (conflicts with survival system)
Citizen.CreateThread(function() 
  while true do
    Citizen.Wait(1000)
    SetPlayerHealthRechargeMultiplier(PlayerId(), 0)
  end
end)

-- Injured movement restrictions thread
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0) -- Run every frame to catch all movement inputs
    local ped = PlayerPedId()
    
    if Survival.isInjured then
      DisableControlAction(0, 21, true) -- Disable sprint (Shift key)
      DisableControlAction(0, 22, true) -- Disable jump (Space bar)
      
      -- Disable other movement abilities when injured
      DisableControlAction(0, 24, true) -- Disable attack
      DisableControlAction(0, 25, true) -- Disable aim
      DisableControlAction(0, 47, true) -- Disable weapon wheel
      DisableControlAction(0, 58, true) -- Disable weapon wheel
      
      -- Force walking speed
      SetPedMoveRateOverride(ped, 0.8) -- Reduce movement speed to 50%
    else
      -- Re-enable all controls when not injured
      EnableControlAction(0, 21, true) -- Enable sprint
      EnableControlAction(0, 22, true) -- Enable jump
      EnableControlAction(0, 24, true) -- Enable attack
      EnableControlAction(0, 25, true) -- Enable aim
      EnableControlAction(0, 47, true) -- Enable weapon wheel
      EnableControlAction(0, 58, true) -- Enable weapon wheel
      
      -- Reset movement speed
      SetPedMoveRateOverride(ped, 1.0) -- Normal movement speed
    end
  end
end)

-- Pee function with animations and particles
function Pee(ped, sex)
    local Player = ped
    local PlayerPed = GetPlayerPed(GetPlayerFromServerId(ped))

    local particleDictionary = "core"
    local particleName = "ent_amb_peeing"
    local animDictionary = 'misscarsteal2peeing'
    local animName = 'peeing_loop'

    RequestNamedPtfxAsset(particleDictionary)
    while not HasNamedPtfxAssetLoaded(particleDictionary) do
        Citizen.Wait(0)
    end

    RequestAnimDict(animDictionary)
    while not HasAnimDictLoaded(animDictionary) do
        Citizen.Wait(0)
    end

    RequestAnimDict('missfbi3ig_0')
    while not HasAnimDictLoaded('missfbi3ig_0') do
        Citizen.Wait(1)
    end

    if sex == 'male' then
        SetPtfxAssetNextCall(particleDictionary)
        local bone = GetPedBoneIndex(PlayerPed, 11816)
        TaskPlayAnim(PlayerPed, animDictionary, animName, 8.0, -8.0, -1, 0, 0, false, false, false)
        local effect = StartParticleFxLoopedOnPedBone(particleName, PlayerPed, 0.0, 0.2, 0.0, -140.0, 0.0, 0.0, bone, 2.5, false, false, false)
        Wait(6500)
        StopParticleFxLooped(effect, 0)
        ClearPedTasks(PlayerPed)
    else
        SetPtfxAssetNextCall(particleDictionary)
        local bone = GetPedBoneIndex(PlayerPed, 11816)
        TaskPlayAnim(PlayerPed, 'missfbi3ig_0', 'shit_loop_trev', 8.0, -8.0, -1, 0, 0, false, false, false)
        local effect = StartParticleFxLoopedOnPedBone(particleName, PlayerPed, 0.0, 0.0, -0.55, 0.0, 0.0, 20.0, bone, 2.0, false, false, false)
        Wait(6500)
        Citizen.Wait(100)
        StopParticleFxLooped(effect, 0)
        ClearPedTasks(PlayerPed)
    end
end

-- Poop function with animations and particles
function Poop(ped)
    local Player = ped
    local PlayerPed = GetPlayerPed(GetPlayerFromServerId(ped))

    local particleDictionary = "scr_amb_chop"
    local particleName = "ent_anim_dog_poo"
    local animDictionary = 'missfbi3ig_0'
    local animName = 'shit_loop_trev'

    RequestNamedPtfxAsset(particleDictionary)
    while not HasNamedPtfxAssetLoaded(particleDictionary) do
        Citizen.Wait(0)
    end

    RequestAnimDict(animDictionary)
    while not HasAnimDictLoaded(animDictionary) do
        Citizen.Wait(0)
    end

    SetPtfxAssetNextCall(particleDictionary)
    local bone = GetPedBoneIndex(PlayerPed, 11816)
    TaskPlayAnim(PlayerPed, animDictionary, animName, 8.0, -8.0, -1, 0, 0, false, false, false)

    local effect = StartParticleFxLoopedOnPedBone(particleName, PlayerPed, 0.0, 0.0, -0.6, 0.0, 0.0, 20.0, bone, 2.0, false, false, false)
    Wait(5000)
    local effect2 = StartParticleFxLoopedOnPedBone(particleName, PlayerPed, 0.0, 0.0, -0.6, 0.0, 0.0, 20.0, bone, 2.0, false, false, false)
    Wait(1000)

    StopParticleFxLooped(effect, 0)
    Wait(10)
    StopParticleFxLooped(effect2, 0)
end

-- Shower function with animations and particles
function Shower(ped)
    local Player = ped
    local PlayerPed = GetPlayerPed(GetPlayerFromServerId(ped))
    
    local isFemale = GetEntityModel(PlayerPed) == -1667301416
    
    if isFemale then
        LoadDict("mp_safehouseshower@female@")
        LoadDict("anim@mp_yacht@shower@female@")
    else
        LoadDict("amb@world_human_bum_wash@male@high@idle_a")
        LoadDict("amb@world_human_bum_wash@male@high@base")
        LoadDict("amb@world_human_bum_wash@male@low@base")
        LoadDict("amb@world_human_bum_wash@male@low@idle_a")
        LoadDict("switch@michael@wash_face")
        LoadDict("anim@mp_yacht@shower@male@")
    end
  
    
    if isFemale then
        TaskPlayAnim(PlayerPed, "mp_safehouseshower@female@", "shower_enter_into_idle", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
        Citizen.Wait(5000)
        TaskPlayAnim(PlayerPed, "anim@mp_yacht@shower@female@", "shower_idle_a", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
        Citizen.Wait(5000)
        TaskPlayAnim(PlayerPed, "anim@mp_yacht@shower@female@", "shower_idle_b", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
        Citizen.Wait(5000)
        TaskPlayAnim(PlayerPed, "mp_safehouseshower@female@", "shower_idle_a", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
        Citizen.Wait(5000)
    else
        TaskPlayAnim(PlayerPed, "anim@mp_yacht@shower@male@", "male_shower_idle_d", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
        Citizen.Wait(5000)
        TaskPlayAnim(PlayerPed, "anim@mp_yacht@shower@male@", "male_shower_idle_a", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
        Citizen.Wait(5000)
        TaskPlayAnim(PlayerPed, "anim@mp_yacht@shower@male@", "male_shower_idle_c", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
        Citizen.Wait(5000)
    end
    
    ClearPedTasks(PlayerPed)
end

-- Helper function to load animation dictionaries
function LoadDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(0)
    end
end

-- Shower zones where players can take showers
local showerZones = {
    vector3(-1234.5, -1500.2, 4.3),
    vector3(345.1, -999.9, 29.2),
}

-- Function to check if player can take a shower
function CanPlayerShower()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    if GetWaterHeight(playerCoords.x, playerCoords.y, playerCoords.z, 0.0) then
        return true
    end

    for _, pos in pairs(showerZones) do
        if #(playerCoords - pos) < 2.0 then
            return true
        end
    end

    return false
end

-- Pee command
RegisterCommand("pee", function(source, args, rawCommand)
    if vitals.pee < 75 then
        return
    end
    
    local playerId = GetPlayerServerId(PlayerId())
    local sex = args[1] or 'male'
    
    if sex ~= 'male' and sex ~= 'female' then
        sex = 'male' 
    end
    
    Pee(playerId, sex)
    
    Citizen.CreateThread(function()
        Citizen.Wait(1500)
        if vRP.EXT.Survival and vRP.EXT.Survival.remote then
            vRP.EXT.Survival.remote._resetPee()
        end
    end)
end, false)

-- Poop command
RegisterCommand("poop", function(source, args, rawCommand)
    if vitals.poop < 75 then
        return
    end
    
    local playerId = GetPlayerServerId(PlayerId())
    Poop(playerId)
    
    Citizen.CreateThread(function()
        Citizen.Wait(2000)
        if vRP.EXT.Survival and vRP.EXT.Survival.remote then
            vRP.EXT.Survival.remote._resetPoop()
        end
    end)
end, false)

-- Shower command
RegisterCommand("shower", function(source, args, rawCommand)
    if vitals.shower >= 25 then
        return
    end
    
    if not CanPlayerShower() then
        return
    end
    
    local playerId = GetPlayerServerId(PlayerId())
    Shower(playerId)
    
    Citizen.CreateThread(function()
        Citizen.Wait(15000)
        if vRP.EXT.Survival and vRP.EXT.Survival.remote then
            vRP.EXT.Survival.remote._resetShower()
        end
    end)
end, false)

vRP:registerExtension(Survival)
