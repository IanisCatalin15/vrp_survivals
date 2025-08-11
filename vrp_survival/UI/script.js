// Advanced Stress System HUD JavaScript
// Handles all UI interactions, data updates, and FiveM integration

class StressSystemHUD {
    constructor() {
        // Cache DOM elements for better performance
        this.domCache = new Map();
        this.vitalElements = new Map();
        
        this.vitals = {
            // Health: 0=dead, 200=full health (vRP standard)
            // Armor: 0=no armor, 100=full armor (vRP standard)
            health: { value: 100, maxValue: 100, color: '#ef4444', inverted: false },
            armor: { value: 100, maxValue: 100, color: '#3b82f6', inverted: false },
            
            // Other vitals: 0=bad, 100=good
            food: { value: 50, maxValue: 100, color: '#f59e0b', inverted: false },
            water: { value: 100, maxValue: 100, color: '#0ea5e9', inverted: false },
            shower: { value: 100, maxValue: 100, color: '#22c55e', inverted: false },
            
            // Stress, pee, poop: 0=good, 100=bad (inverted logic)
            stress: { value: 0, maxValue: 100, color: '#a855f7', inverted: true },
            pee: { value: 0, maxValue: 100, color: '#fbbf24', inverted: true },
            poop: { value: 0, maxValue: 100, color: '#78350f', inverted: true }
        };
        
        // Pre-calculate constants
        this.RADIUS = 26;
        this.CIRCUMFERENCE = 2 * Math.PI * this.RADIUS;
        this.WARNING_THRESHOLDS = { low: 20, medium: 50, high: 80 };
        
        this.isInitialized = false;
        
        this.init();
    }

    init() {
        this.setupFiveMIntegration();
        this.cacheDOMElements();
        this.updateAllVitals();
        this.isInitialized = true;
    }

    // Cache DOM elements for better performance
    cacheDOMElements() {
        const vitalNames = Object.keys(this.vitals);
        for (let i = 0; i < vitalNames.length; i++) {
            const vitalName = vitalNames[i];
            const element = document.querySelector(`[data-vital="${vitalName}"]`);
            if (element) {
                this.vitalElements.set(vitalName, {
                    element: element,
                    progressRing: element.querySelector('.progress-ring-fill'),
                    valueDisplay: element.querySelector('.vital-value'),
                    lowWarning: element.querySelector('.low-warning')
                });
            }
        }
    }

    // Vital Update System - optimized with cached elements
    updateAllVitals() {
        const vitalNames = Object.keys(this.vitals);
        for (let i = 0; i < vitalNames.length; i++) {
            this.updateVital(vitalNames[i], this.vitals[vitalNames[i]].value, this.vitals[vitalNames[i]].maxValue);
        }
    }

    updateVital(vitalName, value, maxValue) {
        const cachedElement = this.vitalElements.get(vitalName);
        if (!cachedElement) return;

        // Ensure value is integer and within bounds
        const intValue = Math.floor(Math.max(0, Math.min(maxValue, value)));
        
        // Display raw values without any scaling
        const displayValue = intValue;
        
        const percentage = (intValue / maxValue) * 100;
        
        // Update progress ring with cached element
        if (cachedElement.progressRing) {
            const offset = this.CIRCUMFERENCE - (percentage / 100) * this.CIRCUMFERENCE;
            cachedElement.progressRing.style.strokeDasharray = this.CIRCUMFERENCE;
            cachedElement.progressRing.style.strokeDashoffset = offset;
        }

        // Update value display with raw value
        if (cachedElement.valueDisplay) {
            cachedElement.valueDisplay.textContent = displayValue;
        }

        // Update warning indicator based on inverted logic
        if (cachedElement.lowWarning) {
            const vital = this.vitals[vitalName];
            const shouldWarn = vital.inverted ? 
                percentage >= this.WARNING_THRESHOLDS.high : 
                percentage <= this.WARNING_THRESHOLDS.low;
            
            if (shouldWarn) {
                cachedElement.lowWarning.style.opacity = '1';
                cachedElement.lowWarning.style.animation = 'pulse 1s infinite';
            } else {
                cachedElement.lowWarning.style.opacity = '0';
                cachedElement.lowWarning.style.animation = 'none';
            }
        }

        // Update vital color based on percentage and inverted logic
        if (cachedElement.progressRing) {
            const vital = this.vitals[vitalName];
            const color = this.getVitalColor(vital, percentage);
            cachedElement.progressRing.style.stroke = color;
        }
    }

    // Optimized color calculation
    getVitalColor(vital, percentage) {
        if (vital.inverted) {
            // For inverted vitals (stress, pee, poop): 0=good, 100=bad
            if (percentage >= this.WARNING_THRESHOLDS.high) {
                return '#ef4444'; // Red for high (bad)
            } else if (percentage >= this.WARNING_THRESHOLDS.medium) {
                return '#f59e0b'; // Orange for medium (bad)
            }
            return vital.color; // Normal color for low (good)
        } else {
            // For normal vitals: health (0=dead, 100=full), armor/water/food/shower (0=bad, 100=good)
            if (percentage <= this.WARNING_THRESHOLDS.low) {
                return '#ef4444'; // Red for low (bad)
            } else if (percentage <= this.WARNING_THRESHOLDS.medium) {
                return '#f59e0b'; // Orange for medium
            }
            return vital.color; // Normal color for high (good)
        }
    }

    // FiveM Integration - optimized with direct property access
    setupFiveMIntegration() {
        // Listen for messages from the Lua client
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            if (data.type === 'updateVital') {
                this.updateVitalFromFiveM(data.vital, data.value);
            } else if (data.type === 'updateVitals') {
                // Handle bulk vital updates from the survival system                
                // Use direct property access for better performance
                const vitalUpdates = [
                    { name: 'water', value: data.water },
                    { name: 'food', value: data.food },
                    { name: 'pee', value: data.pee },
                    { name: 'poop', value: data.poop },
                    { name: 'shower', value: data.shower },
                    { name: 'stress', value: data.stress },
                    { name: 'health', value: data.health },
                    { name: 'armor', value: data.armor }
                ];

                for (let i = 0; i < vitalUpdates.length; i++) {
                    const update = vitalUpdates[i];
                    if (update.value !== undefined) {
                        this.updateVitalFromFiveM(update.name, update.value);
                    }
                }
            }
        });
    }

    updateVitalFromFiveM(vitalName, value, maxValue = null) {
        if (this.vitals[vitalName]) {
            // Use the vital's own maxValue if not specified
            const vitalMaxValue = maxValue || this.vitals[vitalName].maxValue;
            
            // Ensure value is integer and within bounds
            const intValue = Math.floor(Math.max(0, Math.min(vitalMaxValue, value)));
            this.vitals[vitalName].value = intValue;
            this.updateVital(vitalName, this.vitals[vitalName].value, vitalMaxValue);
        } else {
            console.log(`Vital ${vitalName} not found in vitals object`);
        }
    }

    // Utility functions - optimized
    getVitalValue(vitalName) {
        const vital = this.vitals[vitalName];
        if (vital) {
            const value = Math.floor(vital.value);
            // Return raw values without any scaling
            return value;
        }
        return 0;
    }

    setVitalValue(vitalName, value) {
        const vital = this.vitals[vitalName];
        if (vital) {
            const vitalMaxValue = vital.maxValue;
            const intValue = Math.floor(Math.max(0, Math.min(vitalMaxValue, value)));
            
            // Set raw values without any scaling
            vital.value = intValue;
            this.updateVital(vitalName, vital.value, vitalMaxValue);
        }
    }

    // Export functions for FiveM
    exportForFiveM() {
        return {
            updateVital: this.updateVitalFromFiveM.bind(this),
            getVitalValue: this.getVitalValue.bind(this),
            setVitalValue: this.setVitalValue.bind(this)
        };
    }
}

// Initialize the HUD when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.stressSystemHUD = new StressSystemHUD();
});

// Export for FiveM integration
if (typeof exports !== 'undefined') {
    module.exports = StressSystemHUD;
}

// Make it available globally for testing
window.testVitalUpdate = function(vitalName, value) {
    if (window.stressSystemHUD) {
        window.stressSystemHUD.updateVitalFromFiveM(vitalName, value);
        
        // Show raw values for health/armor
        if (vitalName === 'health' || vitalName === 'armor') {
            const rawValue = window.stressSystemHUD.vitals[vitalName].value;
        }
    } else {
        console.log('HUD not initialized yet');
    }
};

