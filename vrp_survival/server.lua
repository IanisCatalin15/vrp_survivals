local Survival = class("Survival", vRP.Extension)

Survival.User = class("User")

function Survival.User:getVital(name)
  return self.cdata.vitals[name]
end

function Survival.User:setVital(name, value)
  if vRP.EXT.Survival.vitals[name] then
    local overflow

    if value < 0 then
      overflow = value
      value = 0
    elseif value > 200 then
      overflow = value - 1
      value = 200
    end

    local pvalue = self.cdata.vitals[name]
    self.cdata.vitals[name] = value

    if pvalue ~= value then
      vRP:triggerEvent("playerVitalChange", self, name)
      
      if self.source then
        vRP.EXT.Survival.remote._updateVitals(self.source, {
          water = self:getVital("water"),
          food = self:getVital("food"),
          pee = self:getVital("pee"),
          poop = self:getVital("poop"),
          shower = self:getVital("shower"),
          stress = self:getVital("stress"),
          health = self:getVital("health"),
          armor = self:getVital("armor")
        })
      end
    end

    if overflow then
      vRP:triggerEvent("playerVitalOverflow", self, name, overflow)
    end
  end
end

function Survival.User:varyVital(name, value)
  local current = self:getVital(name)
  self:setVital(name, current + value)
end

function Survival:__construct()
  vRP.Extension.__construct(self)

  self.cfg = module("vrp_survival", "cfg")
  self.vitals = {}

  self:registerVital("health", self.cfg.defaults.health)
  self:registerVital("armor", self.cfg.defaults.armor)
  self:registerVital("water", self.cfg.defaults.water)
  self:registerVital("food", self.cfg.defaults.food)
  self:registerVital("pee", self.cfg.defaults.pee)
  self:registerVital("poop", self.cfg.defaults.poop)
  self:registerVital("shower", self.cfg.defaults.shower)
  self:registerVital("stress", self.cfg.defaults.stress)

  local function task_update()
    SetTimeout(self.cfg.update_interval, task_update)

    for id, user in pairs(vRP.users) do
      if user:isReady() then
        -- Apply vital decay
        user:varyVital("water", -self.cfg.decay_rates.water)
        user:varyVital("food", -self.cfg.decay_rates.food)
        user:varyVital("shower", -self.cfg.decay_rates.shower)

        local water = user:getVital("water")
        local food = user:getVital("food")
        local pee = user:getVital("pee")
        local poop = user:getVital("poop")
        local shower = user:getVital("shower")

        -- Calculate health damage from low vitals
        local healthDamage = 0
        local damageReasons = {}
        
        -- Water damage
        if water < self.cfg.stress.very_low_threshold then
          healthDamage = healthDamage - self.cfg.health_damage.from_low_vitals.high
          table.insert(damageReasons, "severe dehydration")
        elseif water < self.cfg.stress.low_threshold then
          healthDamage = healthDamage - self.cfg.health_damage.from_low_vitals.medium
          table.insert(damageReasons, "dehydration")
        end
        
        -- Food damage
        if food < self.cfg.stress.very_low_threshold then
          healthDamage = healthDamage - self.cfg.health_damage.from_low_vitals.high
          table.insert(damageReasons, "severe starvation")
        elseif food < self.cfg.stress.low_threshold then
          healthDamage = healthDamage - self.cfg.health_damage.from_low_vitals.medium
          table.insert(damageReasons, "starvation")
        end
        
        -- Pee damage
        if pee > self.cfg.stress.pee_poop_critical then
          healthDamage = healthDamage - self.cfg.health_damage.from_low_vitals.high
          table.insert(damageReasons, "bladder infection")
        elseif pee > self.cfg.stress.pee_poop_threshold then
          healthDamage = healthDamage - self.cfg.health_damage.from_low_vitals.medium
          table.insert(damageReasons, "bladder pressure")
        end
        
        -- Poop damage
        if poop > self.cfg.stress.pee_poop_critical then
          healthDamage = healthDamage - self.cfg.health_damage.from_low_vitals.high
          table.insert(damageReasons, "bowel infection")
        elseif poop > self.cfg.stress.pee_poop_threshold then
          healthDamage = healthDamage - self.cfg.health_damage.from_low_vitals.medium
          table.insert(damageReasons, "bowel pressure")
        end
        
        -- Apply health damage if any
        if healthDamage < 0 then
          self.remote._varyHealth(user.source, healthDamage)
          
          -- Create damage message
          local damageMessage = "You took " .. math.abs(healthDamage) .. " damage from "
          if #damageReasons == 1 then
            damageMessage = damageMessage .. damageReasons[1] .. "!"
          else
            damageMessage = damageMessage .. table.concat(damageReasons, ", ") .. "!"
          end
          
          vRP.EXT.Base.remote._notify(user.source, damageMessage)
        end

        -- Update pee/poop levels
        if pee > self.cfg.stress.pee_poop_threshold then 
          user:varyVital("pee", self.cfg.decay_rates.pee) 
        end
        if poop > self.cfg.stress.pee_poop_threshold then
          user:varyVital("poop", self.cfg.decay_rates.poop) 
        end

        -- Stress from low hygiene
        if shower < self.cfg.stress.low_threshold then
          user:varyVital("stress", self.cfg.stress.increase_low)
          vRP.EXT.Base.remote._notify(user.source, "You need to take a shower!")
        elseif shower < self.cfg.stress.very_low_threshold then
          user:varyVital("stress", self.cfg.stress.increase_very_low)
          vRP.EXT.Base.remote._notify(user.source, "You really need to take a shower!")
        end

        -- Stress from bathroom needs
        if pee > self.cfg.stress.pee_poop_threshold or poop > self.cfg.stress.pee_poop_threshold then
          user:varyVital("stress", self.cfg.stress.increase_low)
          
          if pee > self.cfg.stress.pee_poop_threshold then
            vRP.EXT.Base.remote._notify(user.source, "You need to use the bathroom!")
          end
          if poop > self.cfg.stress.pee_poop_threshold then
            vRP.EXT.Base.remote._notify(user.source, "You need to use the bathroom!")
          end
        elseif pee > self.cfg.stress.pee_poop_critical or poop > self.cfg.stress.pee_poop_critical then
          user:varyVital("stress", self.cfg.stress.increase_very_low)
          
          if pee > self.cfg.stress.pee_poop_critical then
            vRP.EXT.Base.remote._notify(user.source, "You really need to use the bathroom!")
          end
          if poop > self.cfg.stress.pee_poop_critical then
            vRP.EXT.Base.remote._notify(user.source, "You really need to use the bathroom!")
          end
        end

        -- Stress from low vitals
        if water < self.cfg.stress.low_threshold or food < self.cfg.stress.low_threshold then
          user:varyVital("stress", self.cfg.stress.increase_low)
          
          if water < self.cfg.stress.low_threshold then
            vRP.EXT.Base.remote._notify(user.source, "You are getting thirsty!")
          end
          if food < self.cfg.stress.low_threshold then
            vRP.EXT.Base.remote._notify(user.source, "You are getting hungry!")
          end
        elseif water < self.cfg.stress.very_low_threshold or food < self.cfg.stress.very_low_threshold then
          user:varyVital("stress", self.cfg.stress.increase_very_low)
          
          if water < self.cfg.stress.very_low_threshold then
            vRP.EXT.Base.remote._notify(user.source, "You are very thirsty! Find water soon!")
          end
          if food < self.cfg.stress.very_low_threshold then
            vRP.EXT.Base.remote._notify(user.source, "You are very hungry! Find food soon!")
          end
        end
        
        -- High stress notifications
        local currentStress = user:getVital("stress")
        if currentStress > 80 then
          vRP.EXT.Base.remote._notify(user.source, "You are extremely stressed! Try to relax!")
        elseif currentStress > 60 then
          vRP.EXT.Base.remote._notify(user.source, "You are feeling stressed!")
        end

        -- Health damage from high stress
        local stress = user:getVital("stress")
        local stressDamage = 0
        local stressReason = ""
        
        if stress > self.cfg.health_damage.stress_thresholds.high then
          stressDamage = -self.cfg.health_damage.from_stress.high
          stressReason = "extreme stress"
        elseif stress > self.cfg.health_damage.stress_thresholds.medium then
          stressDamage = -self.cfg.health_damage.from_stress.medium * 2
          stressReason = "high stress"
        elseif stress > self.cfg.health_damage.stress_thresholds.low then
          stressDamage = -self.cfg.health_damage.from_stress.low
          stressReason = "moderate stress"
        end
        
        -- Apply stress damage if any
        if stressDamage < 0 then
          self.remote._varyHealth(user.source, stressDamage)
          vRP.EXT.Base.remote._notify(user.source, string.format("You took %d damage from %s!", math.abs(stressDamage), stressReason))
        end

        -- Get current ped health from client (read-only)
        local currentHealth = user:getVital("health")
        local pedHealth = self.remote._getPedHealth(user.source) or currentHealth
        
        -- Health vital is read-only from server - only client can set it
        -- We just read it here for display purposes
        
        -- Update client vitals
        self.remote._updateVitals(user.source, {
          water  = user:getVital("water"),
          food   = user:getVital("food"),
          pee    = user:getVital("pee"),
          poop   = user:getVital("poop"),
          shower = user:getVital("shower"),
          stress = user:getVital("stress"),
          health = user:getVital("health"),
          armor  = user:getVital("armor"),
        })
      end
    end
  end

  task_update()
end

function Survival:registerVital(name, default_value)
  self.vitals[name] = { default_value or 0 }
end

-- Helper function to update client vitals
function Survival:updateClientVitals(user)
  if user.source then
    self.remote._updateVitals(user.source, {
      water = user:getVital("water"),
      food = user:getVital("food"),
      pee = user:getVital("pee"),
      poop = user:getVital("poop"),
      shower = user:getVital("shower"),
      stress = user:getVital("stress"),
      health = user:getVital("health"),
      armor = user:getVital("armor")
    })
  end
end

Survival.event = {}

function Survival.event:characterLoad(user)
  if not user.cdata.vitals then
    user.cdata.vitals = {}
  end

  for name, vital in pairs(self.vitals) do
    if not user.cdata.vitals[name] then
      user.cdata.vitals[name] = vital[1]
    end
  end

  self:updateClientVitals(user)
end

function Survival.event:playerDeath(user)
  -- Reset vitals (except health - health will be synced after respawn)
  for name, vital in pairs(self.vitals) do
    if name ~= "health" then -- Don't reset health vital
      user:setVital(name, vital[1])
    end
  end
end

function Survival.event:playerSpawn(user)
  if user.source then
    -- Wait for ped to fully spawn, then let health sync naturally
    SetTimeout(2000, function()
      if user.source and user:isReady() then
        local pedHealth = self.remote._getPedHealth(user.source)
        if pedHealth and pedHealth >= 100 then
          -- Don't set health vital - let it sync naturally from client
          self:updateClientVitals(user)
        end
      end
    end)
  end
end

Survival.tunnel = {}

function Survival.tunnel:consume(water, food)
  local user = vRP.users_by_source[source]
  if user and user:isReady() then
    if water then
      user:varyVital("water", -water)
      vRP.EXT.Base.remote._notify(user.source, string.format("You drank water! (+%d water)", water))
    end
    if food then
      user:varyVital("food", -food)
      vRP.EXT.Base.remote._notify(user.source, string.format("You ate food! (+%d food)", food))
    end
  end
end

-- Function to reset pee after animation
function Survival.tunnel:resetPee()
  local user = vRP.users_by_source[source]
  if user and user:isReady() then
    user:setVital("pee", 0)
    self:updateClientVitals(user)
    vRP.EXT.Base.remote._notify(user.source, "You feel relieved!")
  end
end

-- Function to reset poop after animation
function Survival.tunnel:resetPoop()
  local user = vRP.users_by_source[source]
  if user and user:isReady() then
    user:setVital("poop", 0)
    self:updateClientVitals(user)
    vRP.EXT.Base.remote._notify(user.source, "You feel much better now!")
  end
end

-- Function to reset shower after animation
function Survival.tunnel:resetShower()
  local user = vRP.users_by_source[source]
  if user and user:isReady() then
    user:setVital("shower", 100)
    self:updateClientVitals(user)
    vRP.EXT.Base.remote._notify(user.source, "You feel clean and refreshed!")
  end
end

-- Function to manually sync health
function Survival.tunnel:syncHealth()
  local user = vRP.users_by_source[source]
  if user and user:isReady() then
    local pedHealth = self.remote._getPedHealth(user.source)
    if pedHealth then
      local oldHealth = user:getVital("health")
      -- Don't set health vital - let it sync naturally from client
      self:updateClientVitals(user)
      
      vRP.EXT.Base.remote._notify(user.source, string.format("Health sync requested! Ped: %d, Current Vital: %d", 
        pedHealth, oldHealth))
    end
  end
end

vRP:registerExtension(Survival)