# VRP Survival System

A comprehensive survival system for vRP (FiveM) that adds realistic health, vitals, and movement mechanics to your server.

## 🌟 Features

### **Core Survival Mechanics**
- **Health System**: Realistic health management with 100-200 vRP range
- **Vital Management**: Water, food, pee, poop, shower, stress, and armor
- **Vital Decay**: Gradual decrease of vitals over time
- **Health Damage**: Damage from low vitals and high stress levels

### **Movement & Animation System**
- **Injured Walking**: Automatic injured gait when health ≤25%
- **Movement Restrictions**: No sprint/jump when injured
- **Speed Reduction**: 50% movement speed when severely hurt
- **Animation Integration**: Seamless walking animation transitions

### **Interactive Commands**
- **`/pee`**: Pee animation with particles (requires pee vital >75)
- **`/poop`**: Poop animation with particles (requires poop vital >75)
- **`/shower`**: Shower animation with gender-specific animations (requires shower vital <25)

### **Smart Notifications**
- **Low Vital Warnings**: Notifications for dehydration, starvation, etc.
- **Stress Alerts**: Warnings for high stress levels
- **Damage Notifications**: Specific reasons for health damage
- **Bathroom Reminders**: Notifications for bathroom needs

### **Advanced Features**
- **Water Detection**: Shower in natural water or predefined zones
- **Gender-Specific Animations**: Different animations for male/female characters
- **Particle Effects**: Realistic pee and poop particles
- **Health Synchronization**: Perfect sync between client and server

## 📋 Requirements

- **FiveM Server** with vRP framework
- **vRP Extensions**: Base, Inventory, Audio modules
- **Lua 5.1+** support

## 🚀 Installation

### **1. Download & Extract**
```bash
# Download the resource
git clone https://github.com/yourusername/vrp_survival.git

# Move to your resources folder
mv vrp_survival /path/to/your/server/resources/
```

### **2. Framework Integration**
⚠️ **IMPORTANT**: You need to replace/modify your existing vRP framework files:

#### **Replace in `vrp/modules/edible.lua`:**
```lua
-- Add this effect definition
-- Add cigarette and joint types
self:defineType("cigarette", "Smoke cigarette", function(user, edible)
  vRP.EXT.Base.remote._playAnim(user.source, true, cigarette_seq, false)
  vRP.EXT.Audio.remote._playAudioSource(-1, self.cfg.smoke_sound, 1, 0, 0, 0, 30, user.source)
  vRP.EXT.Base.remote._notify(user.source, "You smoked a cigarette")
end)

self:defineType("joint", "Smoke joint", function(user, edible)
  vRP.EXT.Base.remote._playAnim(user.source, true, joint_seq, false)
  vRP.EXT.Audio.remote._playAudioSource(-1, self.cfg.smoke_sound, 1, 0, 0, 0, 30, user.source)
  vRP.EXT.Base.remote._notify(user.source, "You smoked a joint")
end)
```

#### **Replace in `vrp/cfg/edibles.lua`:**
```lua
-- Add these items to your edibles configuration
cigarette = {"cigarette", {stress = -15}, "Cigarette", "A cigarette to reduce stress", 0.1},
joint = {"joint", {stress = -30, food = -5}, "Joint", "A joint to relax and reduce stress", 0.1},
```

### **3. Server Configuration**
```lua
-- Add to your server.cfg
ensure vrp_survival
```

### **4. Database Setup**
The system automatically creates necessary database tables for vital storage.

## ⚙️ Configuration

### **Main Configuration (`cfg.lua`)**
```lua
-- Vital decay rates (per update interval)
decay_rates = {
  water = 1,    -- Water decreases by 1 per interval
  food = 5,   -- Food decreases by 0.5 per interval
  shower = 3, -- Hygiene decreases by 0.3 per interval
  pee = 2,      -- Pee increases by 2 when over threshold
  poop = 1.5    -- Poop increases by 1.5 when over threshold
}

-- Stress thresholds
stress = {
  low_threshold = 30,           -- Low vital threshold
  very_low_threshold = 15,      -- Very low vital threshold
  pee_poop_threshold = 70,      -- Bathroom need threshold
  pee_poop_critical = 90,       -- Critical bathroom need
  increase_low = 1,             -- Stress increase for low vitals
  increase_very_low = 2         -- Stress increase for very low vitals
}

-- Health damage configuration
health_damage = {
  from_low_vitals = {
    medium = 2,  -- Medium damage from low vitals
    high = 5     -- High damage from very low vitals
  },
  from_stress = {
    low = 1,     -- Low stress damage
    medium = 2,  -- Medium stress damage
    high = 3     -- High stress damage
  },
  stress_thresholds = {
    low = 50,    -- Low stress threshold
    medium = 70, -- Medium stress threshold
    high = 85    -- High stress threshold
  }
}
```

### **Shower Zones**
Add custom shower locations in `client.lua`:
```lua
local showerZones = {
    vector3(0, 0, 0), -- Example location 1
    -- Add more locations as needed
}
```

## 🎮 Usage

### **Player Commands**
- **`/pee [male/female]`**: Use bathroom (pee vital must be >75)
- **`/poop`**: Use bathroom (poop vital must be >75)
- **`/shower`**: Take a shower (shower vital must be <25)

### **Vital Management**
- **Water**: Decreases over time, causes damage when low
- **Food**: Decreases over time, causes damage when low
- **Pee**: Increases over time, causes stress and damage when high
- **Poop**: Increases over time, causes stress and damage when high
- **Shower**: Decreases over time, causes stress when low
- **Stress**: Increases from low vitals, causes health damage when high
- **Armor**: Can be increased with armor items

### **Health System**
- **Range**: 100 (dead) to 200 (full health)
- **UI Display**: Converts to 0-100% for display
- **Injured State**: Activates at ≤25% health (≤125 vRP health)
- **Movement Restrictions**: No sprint/jump when injured

## 🔧 Technical Details

### **Architecture**
- **Client-Side**: Health monitoring, UI updates, movement restrictions
- **Server-Side**: Vital logic, damage calculation, data persistence
- **Database**: vRP cdata system for vital storage
- **Communication**: Tunnel system for client-server sync

### **Performance Optimizations**
- **Efficient Threading**: Health monitoring every 50ms
- **Smart Updates**: UI updates only when needed
- **Optimized Loops**: Consolidated vital processing
- **Memory Management**: Minimal resource usage

### **Health Synchronization**
- **Client Priority**: Health vital always reflects actual ped health
- **Server Read-Only**: Server never overrides health vital
- **Real-Time Sync**: Immediate health updates
- **Validation**: Prevents invalid health values

## 📁 File Structure
```
vrp_survival/
├── client.lua          # Client-side logic and UI
├── server.lua          # Server-side vital management
├── cfg.lua             # Configuration file
├── __resource.lua      # FiveM resource manifest
├── vrp_s.lua           # vRP integration
├── UI/                 # User interface files
│   ├── index.html      # Main UI structure
│   ├── style.css       # UI styling
│   └── script.js       # UI functionality
└── README.md           # This file
```

## 🐛 Troubleshooting

### **Common Issues**

#### **Health Not Syncing**
- Check if `vRP.EXT.Survival` is properly loaded
- Verify tunnel functions are working
- Check console for error messages

#### **Movement Restrictions Not Working**
- Ensure health is actually ≤125 (25%)
- Check if `Survival.isInjured` is being set
- Verify the movement restrictions thread is running

#### **Vitals Not Updating**
- Check server update interval in config
- Verify vital decay rates are set correctly
- Check if server is processing users

### **Debug Mode**
Enable debug logging by uncommenting print statements in the code.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **vRP Framework**: Base framework for FiveM
- **FiveM Community**: Support and testing
- **Flaticon**: Icons used in the UI

## 📞 Support

- **GitHub Issues**: Report bugs and request features
- **Discord**: Join our community server
- **Documentation**: Check the wiki for detailed guides

## 🔄 Updates

### **Version 1.0.0**
- Initial release with core survival mechanics
- Health and vital management system
- Movement restrictions and injured walking
- Interactive bathroom commands
- Comprehensive notification system

---

**Made with for the vRP2 FiveM community**
