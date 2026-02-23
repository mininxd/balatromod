JokerDisplay = {}
JokerDisplay.path = "mods/JokerDisplay/"
JokerDisplay.current_hand = {}
JokerDisplay.current_hand_info = {
    text = "Unknown",
    poker_hands = {},
    scoring_hand = {}
}

function JokerDisplay.load_file(path, target)
    local full_path = JokerDisplay.path .. path
    local file, error = love.filesystem.read(full_path)
    if not file then
        print("Failed to read " .. full_path .. ": " .. tostring(error))
        return function() return {} end
    end
    return load(file, ('=[JokerDisplay "%s"]'):format(target or path))
end

-- Load default config
JokerDisplay.config = {
	default_rows = {
		reminder = true,
		extra = true,
		modifiers = true,
	},
	hide_by_default = false,
	hide_empty = true,
	shift_to_hide = false,
	joker_count = true,
	disable_collapse = false,
	disable_perishable = false,
	disable_rental = false,
	small_rows = {
		reminder = false,
		extra = false,
		modifiers = true,
	},
	enabled = true,
}

function JokerDisplay.save_config()
    local function serialize(t, indent)
        local function serialize_string(s)
            return string.format("%q", s)
        end
        indent = indent or ''
        local str = '{\n'
        for k, v in ipairs(t) do
            str = str .. indent .. '\t'
            if type(v) == 'number' then
                str = str .. v
            elseif type(v) == 'boolean' then
                str = str .. (v and 'true' or 'false')
            elseif type(v) == 'string' then
                str = str .. serialize_string(v)
            elseif type(v) == 'table' then
                str = str .. serialize(v, indent .. '\t')
            else
                str = str .. 'nil'
            end
            str = str .. ',\n'
        end
        for k, v in pairs(t) do
            if type(k) == 'string' then
                str = str .. indent .. '\t' .. '[' .. serialize_string(k) .. '] = '
                if type(v) == 'number' then
                    str = str .. v
                elseif type(v) == 'boolean' then
                    str = str .. (v and 'true' or 'false')
                elseif type(v) == 'string' then
                    str = str .. serialize_string(v)
                elseif type(v) == 'table' then
                    str = str .. serialize(v, indent .. '\t')
                else
                    str = str .. 'nil'
                end
                str = str .. ',\n'
            end
        end
        str = str .. indent .. '}'
        return str
    end

    local serialized = 'return ' .. serialize(JokerDisplay.config)
    love.filesystem.write('JokerDisplay_config.jkr', serialized)
end

-- Load saved config if exists
local saved_config_file = love.filesystem.read('JokerDisplay_config.jkr')
if saved_config_file then
    local ok, saved_config_fn = pcall(load, saved_config_file)
    if ok then
        local ok2, saved_config = pcall(saved_config_fn)
        if ok2 and type(saved_config) == 'table' then
            local function merge(target, source)
                for k, v in pairs(source) do
                    if type(v) == 'table' and type(target[k]) == 'table' then
                        merge(target[k], v)
                    else
                        target[k] = v
                    end
                end
            end
            merge(JokerDisplay.config, saved_config)
        end
    end
end

-- Initialize definitions
function JokerDisplay.init_definitions()
    if not JokerDisplay.Global_Definitions then
        JokerDisplay.Global_Definitions = JokerDisplay.load_file("definitions/global_definitions.lua")() or {}
        JokerDisplay.Definitions = JokerDisplay.load_file("definitions/display_definitions.lua")() or {}
        JokerDisplay.Blind_Definitions = JokerDisplay.load_file("definitions/blind_definitions.lua")() or {}
        JokerDisplay.Edition_Definitions = JokerDisplay.load_file("definitions/edition_definitions.lua")() or {}
    end
end

-- Helper functions
function JokerDisplay.strsplit(str, sep)
    if sep == nil then sep = "%s" end
    local t = {}
    for substr in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, substr)
    end
    return t
end

function JokerDisplay.deepcopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[JokerDisplay.deepcopy(orig_key)] = JokerDisplay.deepcopy(orig_value)
        end
        setmetatable(copy, JokerDisplay.deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function JokerDisplay.number_format(num, e_switch_point, places)
    if not num then return num or '' end
    if type(num) == "function" then num = num() end
    if (type(num) ~= 'number' and type(num) ~= 'table') then return num or '' end
    if type(num) == 'table' then
        local big_num = _G["to_big"] and to_big(num) or num
        if big_num >= (to_big and to_big(e_switch_point or 1000000) or (e_switch_point or 1000000)) then
            return Notations.Balatro:format(big_num, places or 2)
        end
        num = num.to_number and num:to_number() or num
    end
    local sign = (num >= 0 and "") or "-"
    num = math.abs(num)
    if num >= (e_switch_point or 1000000) then
        local x = string.format("%.4g", num)
        local fac = math.floor(math.log(tonumber(x), 10))
        if num == math.huge then return sign .. "naneinf" end
        local mantissa = round_number(x / (10 ^ fac), 3)
        if mantissa >= 10 then mantissa = mantissa / 10; fac = fac + 1 end
        return sign .. (string.format(fac >= 100 and "%.1fe%i" or fac >= 10 and "%.2fe%i" or "%." .. (places or 2) .. "fe%i", mantissa, fac))
    end
    local formatted
    if num ~= math.floor(num) and num < 100 then
        formatted = string.format(num >= 10 and "%.1f" or "%.2f", num)
        if formatted:sub(-1) == "0" then formatted = formatted:gsub("%.?0+$", "") end
        if num < 0.01 then return tostring(num) end
    else
        formatted = string.format("%.0f", num)
    end
    return sign .. (formatted:reverse():gsub("(%d%d%d)", "%1,"):gsub(",$", ""):reverse())
end

function JokerDisplay.get_display_areas()
    return { G.jokers }
end

function JokerDisplay.in_scoring(card, scoring_hand)
    for _, _card in pairs(scoring_hand) do
        if card == _card then return true end
    end
end
