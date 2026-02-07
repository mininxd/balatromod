local _tvos = nil
if love.system.getPlatform and love.system.getPlatform() == 'tvos' then 
    _tvos = true
end

love.mod_filesystem = love.mod_filesystem or {
    getDirectoryItems = love.filesystem.getDirectoryItems,
    getInfo = _tvos and (love.platform.localGetInfo ) or love.filesystem.getInfo,
    read = _tvos and (love.platform.localRead) or love.filesystem.read,
    remove = _tvos and (love.platform.localRemove) or love.filesystem.remove,
    getSourceBaseDirectory = love.filesystem.getSourceBaseDirectory,
    createDirectory = love.filesystem.createDirectory,
    write = _tvos and (love.platform.localWrite) or love.filesystem.write
}

--[[
MIT License
Copyright (c) 2017 Robert Herlihy
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

--I modified this A LOT. Needed to make it quicker if it is being saved to file every few seconds during a game

function STR_PACK(data, recursive)
	local ret_str = (recursive and "" or "return ").."{"
	
      for i, v in pairs(data) do
		local type_i, type_v = type(i), type(v)
        assert((type_i ~= "table"), "Data table cannot have an table as a key reference")
        if type_i == "string" then
			i = '['..string.format("%q",i)..']'
        else
          	i = "["..i.."]"
        end
        if type_v == "table" then
			if v.is and v:is(Object) then
				v = [["]].."MANUAL_REPLACE"..[["]]
			else
				v = STR_PACK(v, true)
			end
        else
          if type_v == "string" then v = string.format("%q", v) end
		  if type_v == "boolean" then v = v and "true" or "false" end
        end
		ret_str = ret_str..i.."="..v..","
      end

	  return ret_str.."}"
end

function STR_UNPACK(str)
  return assert(loadstring(str))()
end


function load_local_file(_file)
    if string.find(_file, 'unlock_notify') then
        return
    end

    local file_data = love.mod_filesystem.getInfo(_file)
    if file_data ~= nil then
        local file_string = love.mod_filesystem.read(_file)
        return get_table_from_string(file_string)
    end
end

function get_table_from_string(file_string)
    if file_string ~= '' and file_string then
        local success = nil
        if string.sub(file_string, 1, 6) ~= 'return' then 
            success, file_string = pcall(love.data.decompress, 'string', 'deflate', file_string)
        else
            success = true
        end
        
        if success then 
            return STR_UNPACK(file_string)
        end
    end
end

function compress_table_to_string(_table)
    local save_string = type(_table) == 'table' and STR_PACK(_table) or _table
    if NO_COMPRESS then return save_string end
    return love.data.compress('string', 'deflate', save_string, 1)
end

function get_compressed(_file)
    local file_data = love.mod_filesystem.getInfo(_file)
    if file_data ~= nil then
        local file_string = love.mod_filesystem.read(_file)
        if file_string ~= '' then
            if string.sub(file_string, 1, 6) ~= 'return' then 
                local success = nil
                success, file_string = pcall(love.data.decompress, 'string', 'deflate', file_string)
                if not success then return nil end
            end
            return file_string
        end
    end
end

function compress_and_save(_file, _data)
    love.mod_filesystem.write(_file,compress_table_to_string(_data))
end

function copy_table(O)
    local O_type = type(O)
    local copy
    if O_type == 'table' then
        copy = {}
        for k, v in next, O, nil do
            copy[copy_table(k)] = copy_table(v)
        end
        setmetatable(copy, copy_table(getmetatable(O)))
    else
        copy = O
    end
    return copy
end

function reconcile_save(_local, _remote, _type, _inital_load)
    _local = _local or {}
    _remote = _remote or {}
   
    if _local and _remote and _local.ver and _remote.ver then
        if _local.deleted and _remote.deleted then
            _local.ver = math.max(_local.ver or 0, _remote.ver or 0)
            return copy_table(_local)
        end

        if _local.deleted and not _remote.deleted then
            if _local.ver > _remote.ver then 
                return copy_table(_local)
            else
                return copy_table(_remote)
            end
        end

        if not _local.deleted and _remote.deleted then
            --if the player is playing on a deleted profile and this is NOT the first load, we don't want to kick them out
            if _inital_load then
                if _remote.ver > _local.ver then 
                    return copy_table(_remote), true
                else
                    return copy_table(_local)
                end 
            end
            return copy_table(_local)
        end

        --if we hit here, neither profile is deleted
        if _local.ver > _remote.ver then
            return copy_table(_local)
        elseif _local.ver < _remote.ver then
            --if this happens, we need to delete the local files for this profile because they might be messed up too
            return copy_table(_remote), true
        end
    end

    local _reconciled = copy_table(_local)

    if _type == 'profile' then 
        --Reconcile name
        if _remote.name then _reconciled.name = _remote.name end

        --Reconcile flags
        _reconciled.flags = _reconciled.flags or {}
        if _local and _local.flags then 
            for k, v in pairs(_local.flags) do
                _reconciled.flags[k] = v
            end
        end
        if _remote and _remote.flags then 
            for k, v in pairs(_remote.flags) do
                _reconciled.flags[k] = v
            end
        end

        --Reconcile high scores on this profile
        local function _rec_high_score(_hs_type, _local, _remote)
            if _local and _local.high_scores and _local.high_scores[_hs_type] and _local.high_scores[_hs_type].amt then
                if _remote and _remote.high_scores and _remote.high_scores[_hs_type] and _remote.high_scores[_hs_type].amt then
                    return _remote.high_scores[_hs_type].amt > _local.high_scores[_hs_type].amt and _remote.high_scores[_hs_type].amt or _local.high_scores[_hs_type].amt
                end
                return _local.high_scores[_hs_type].amt
            end
            return 0
        end
        for k, v in pairs(_reconciled.high_scores or {}) do
            _reconciled.high_scores[k].amt = _rec_high_score(k, _reconciled, _remote)
        end

        --Reconcile career stats
        local function _rec_career_stat(_cs_type, _local, _remote)
            if _local and _local.career_stats and _local.career_stats[_cs_type] then
                if _remote and _remote.career_stats and _remote.career_stats[_cs_type] then
                    return _remote.career_stats[_cs_type] > _local.career_stats[_cs_type] and _remote.career_stats[_cs_type] or _local.career_stats[_cs_type]
                end
                return _local.career_stats[_cs_type]
            end
            return 0
        end
        for k, v in pairs(_reconciled.career_stats or {}) do
            _reconciled.career_stats[k] = _rec_career_stat(k, _reconciled, _remote)
        end

        --Reconcile usage
        --decks
        local function _rec_deck_usage(_deck, _local, _remote)
            _local.deck_usage[_deck] = _local.deck_usage[_deck] or _remote.deck_usage[_deck] or nil

            if _local.deck_usage and _local.deck_usage[_deck] then
                if _remote.deck_usage and _remote.deck_usage[_deck] then
                    _local.deck_usage[_deck].count = math.max(_local.deck_usage[_deck].count, _remote.deck_usage[_deck].count)
                    _local.deck_usage[_deck].order = _local.deck_usage[_deck].order or _remote.deck_usage[_deck].order
                    _local.deck_usage[_deck].wins = _local.deck_usage[_deck].wins or {}
                    _local.deck_usage[_deck].losses = _local.deck_usage[_deck].losses or {}
                    for i = 1, 20 do
                        if _local.deck_usage[_deck].wins[i] or _remote.deck_usage[_deck].wins[i] then
                            _local.deck_usage[_deck].wins[i] = math.max(_local.deck_usage[_deck].wins[i] or 0, _remote.deck_usage[_deck].wins[i] or 0)
                        end
                        if _local.deck_usage[_deck].losses[i] or _remote.deck_usage[_deck].losses[i] then
                            _local.deck_usage[_deck].losses[i] = math.max(_local.deck_usage[_deck].losses[i] or 0, _remote.deck_usage[_deck].losses[i] or 0)
                        end
                    end
                end
            end
        end
        for k, v in pairs(_reconciled.deck_usage or {}) do
            _rec_deck_usage(k, _reconciled, _remote)
        end
        for k, v in pairs(_remote.deck_usage or {}) do
            _rec_deck_usage(k, _reconciled, _remote)
        end
        --jokers
        local function _rec_joker_usage(_joker, _local, _remote)
            _local.joker_usage[_joker] = _local.joker_usage[_joker] or _remote.joker_usage[_joker] or nil

            if _local.joker_usage and _local.joker_usage[_joker] then
                if _remote.joker_usage and _remote.joker_usage[_joker] then
                    _local.joker_usage[_joker].count = math.max(_local.joker_usage[_joker].count, _remote.joker_usage[_joker].count)
                    _local.joker_usage[_joker].order = _local.joker_usage[_joker].order or _remote.joker_usage[_joker].order
                    _local.joker_usage[_joker].wins = _local.joker_usage[_joker].wins or {}
                    _local.joker_usage[_joker].losses = _local.joker_usage[_joker].losses or {}
                    for i = 1, 20 do
                        if _local.joker_usage[_joker].wins[i] or (_remote.joker_usage[_joker].wins and _remote.joker_usage[_joker].wins[i]) then
                            _local.joker_usage[_joker].wins[i] = math.max(_local.joker_usage[_joker].wins[i] or 0, _remote.joker_usage[_joker].wins[i] or 0)
                        end
                        if _local.joker_usage[_joker].losses[i] or (_remote.joker_usage[_joker].losses and _remote.joker_usage[_joker].losses[i]) then
                            _local.joker_usage[_joker].losses[i] = math.max(_local.joker_usage[_joker].losses[i] or 0, _remote.joker_usage[_joker].losses[i] or 0)
                        end
                    end
                end
            end
        end
        for k, v in pairs(_reconciled.joker_usage or {}) do
            _rec_joker_usage(k, _reconciled, _remote)
        end
        for k, v in pairs(_remote.joker_usage or {}) do
            _rec_joker_usage(k, _reconciled, _remote)
        end
        --consumables
        local function _rec_consumable_usage(_consumable, _local, _remote)
            _local.consumeable_usage[_consumable] = _local.consumeable_usage[_consumable] or _remote.consumeable_usage[_consumable] or nil
            if _local.consumeable_usage and _local.consumeable_usage[_consumable] then
                if _remote.consumeable_usage and _remote.consumeable_usage[_consumable] then
                    _local.consumeable_usage[_consumable].count = math.max(_local.consumeable_usage[_consumable].count, _remote.consumeable_usage[_consumable].count)
                    _local.consumeable_usage[_consumable].order = _local.consumeable_usage[_consumable].order or _remote.consumeable_usage[_consumable].order 
                end
            end
        end
        for k, v in pairs(_reconciled.consumeable_usage or {}) do
            _rec_consumable_usage(k, _reconciled, _remote)
        end
        for k, v in pairs(_remote.consumeable_usage or {}) do
            _rec_consumable_usage(k, _reconciled, _remote)
        end
        --vouchers
        local function _rec_voucher_usage(_voucher, _local, _remote)
            _local.voucher_usage[_voucher] = _local.voucher_usage[_voucher] or _remote.voucher_usage[_voucher] or nil
            if _local.voucher_usage and _local.voucher_usage[_voucher] then
                if _remote.voucher_usage and _remote.voucher_usage[_voucher] then
                    _local.voucher_usage[_voucher].count = math.max(_local.voucher_usage[_voucher].count, _remote.voucher_usage[_voucher].count)
                    _local.voucher_usage[_voucher].order = _local.voucher_usage[_voucher].order or _remote.voucher_usage[_voucher].order 
                end
            end
        end
        for k, v in pairs(_reconciled.voucher_usage or {}) do
            _rec_voucher_usage(k, _reconciled, _remote)
        end
        for k, v in pairs(_remote.voucher_usage or {}) do
            _rec_voucher_usage(k, _reconciled, _remote)
        end
        --hands
        local function _rec_hand_usage(_hand, _local, _remote)
            _local.hand_usage[_hand] = _local.hand_usage[_hand] or _remote.hand_usage[_hand] or nil
            if _local.hand_usage and _local.hand_usage[_hand] then
                if _remote.hand_usage and _remote.hand_usage[_hand] then
                    _local.hand_usage[_hand].count = math.max(_local.hand_usage[_hand].count, _remote.hand_usage[_hand].count)
                    _local.hand_usage[_hand].order = _local.hand_usage[_hand].order or _remote.hand_usage[_hand].order 
                end
            end
        end
        for k, v in pairs(_reconciled.hand_usage or {}) do
            _rec_hand_usage(k, _reconciled, _remote)
        end
        for k, v in pairs(_remote.hand_usage or {}) do
            _rec_hand_usage(k, _reconciled, _remote)
        end
        --challenge unlocks
        _reconciled.challenges_unlocked = (_reconciled.challenges_unlocked or _remote.challenges_unlocked) and (math.max(_reconciled.challenges_unlocked or 0, _remote.challenges_unlocked or 0)) or nil
        --challenges
        local function _rec_challenges(_local, _remote)
            if _remote.challenge_progress then 
                for k, v in pairs(_remote.challenge_progress.completed) do
                    _local.challenge_progress.completed[k] = true
                end
                for k, v in pairs(_remote.challenge_progress.unlocked) do
                    _local.challenge_progress.unlocked[k] = true
                end
            end
        end
        _rec_challenges(_reconciled, _remote)
        --all unlocks
        _reconciled.all_unlocked = _reconciled.all_unlocked or _remote.all_unlocked or nil
        --Reconcile progress

        return _reconciled
    end

    if _type == 'meta' then
        if _remote.unlocked then
            --unlocks
            for k, v in pairs(_remote.unlocked) do
                _reconciled.unlocked[k] = true
            end
        end

        if _remote.discovered then
            --discoveries
            for k, v in pairs(_remote.discovered) do
                _reconciled.discovered[k] = true
            end
        end

        if _remote.alerted then
            --alerts
            for k, v in pairs(_remote.alerted) do
                _reconciled.alerted[k] = true
            end
        end

        return _reconciled
    end
end
