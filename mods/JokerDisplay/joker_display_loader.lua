-- Native JokerDisplay Loader (No SMODS)
require "mods/JokerDisplay/joker_display_core"

-- Load source files
JokerDisplay.load_file("src/utils.lua")()
JokerDisplay.load_file("src/ui.lua")()
JokerDisplay.load_file("src/display_functions.lua")()
JokerDisplay.load_file("src/api_helper_functions.lua")()
JokerDisplay.load_file("src/controller.lua")()
JokerDisplay.load_file("src/config_tab.lua")()

-- Initialize definitions immediately
JokerDisplay.init_definitions()

-- Hook Game:main_menu for definitions loading
local jokerdisplay_game_main_menu_ref = Game.main_menu
function Game:main_menu(...)
    JokerDisplay.init_definitions()
    return jokerdisplay_game_main_menu_ref(self, ...)
end

-- Hook localization (stripped of SMODS)
local jokerdisplay_init_localization_ref = init_localization
function init_localization(...)
    local en_loc = JokerDisplay.load_file("localization/en-us.lua")()
    
    local function table_merge(target, source)
        for k, v in pairs(source) do
            if type(v) == "table" then
                target[k] = target[k] or {}
                table_merge(target[k], v)
            else
                target[k] = v
            end
        end
        return target
    end
    
    if G.localization then
        table_merge(G.localization, en_loc)
        if G.SETTINGS.language ~= "en-us" then
            local success, current_loc = pcall(function()
                return JokerDisplay.load_file("localization/" .. G.SETTINGS.language .. ".lua")()
            end)
            if success and current_loc and type(current_loc) == 'table' then
                table_merge(G.localization, current_loc)
            end
        end
    end

    return jokerdisplay_init_localization_ref(...)
end
