-- ================================
-- File: Scripts/DynamicBandages/dynamicbandages_init.lua
-- ================================

-- Ensure global table exists
DynamicBandages = DynamicBandages or {}

-- Bootstrap main logic
Script.ReloadScript("Scripts/DynamicBandages/DynamicBandages.lua")

-- Register a simple lifecycle entry to kick things off
function DynamicBandages.OnGameplayStarted()
    if DynamicBandages and DynamicBandages.Initialize then
        DynamicBandages.Initialize(true)
    end
end

UIAction.RegisterEventSystemListener(DynamicBandages, "System", "OnGameplayStarted", "OnGameplayStarted")
System.LogAlways("[DynamicBandages] Init loaded — System.OnGameplayStarted listener registered")
