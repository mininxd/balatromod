require "love.system" 

if (jit.arch == 'arm64' or jit.arch == 'arm') then jit.off() end

require "love.timer"
require "love.thread"
require "love.filesystem"
require "love.platform"
require "engine/object"
require "engine/string_packer"

FOS = {
    Success = 0,
    FetchError = 1,
    CloudSaveError = 2,
    Conflict = 3,
    Offline = 4,
    LoadError = 5,
    NotFound = 6
}

IN_CHANNEL = love.thread.getChannel("load_request")
OUT_CHANNEL = love.thread.getChannel('load_return')

function load_callback(_file, _return_code, _error_string, _local, _remote, _conflictId)
    if _return_code == FOS.Conflict then
        local _upgrade = nil
        if string.match(_file, "meta") then
            _local = get_table_from_string(_local)
            _remote = get_table_from_string(_remote)
            _local = reconcile_save(_local, _remote, 'meta', true)
        end

        if string.match(_file, "profile") then
            _local = get_table_from_string(_local)
            _remote = get_table_from_string(_remote)
            _local = reconcile_save(_local, _remote, 'profile', true)
        end
        
        --CLOUD SAVE AFTER CONFLICT RESOLUTION
        love.platform.resolveConflict(_file, compress_table_to_string(_local), _conflictId)

        OUT_CHANNEL:push({
            _status = 'OK',
            _filename = _file,
            _content = _local,
            _upgrade = _upgrade
        })
    elseif _local ~= nil then
        -- irrespective of return code, if we have no conflict, local will always contain what we want to load
        _local = get_table_from_string(_local)
        OUT_CHANNEL:push({
            _status = 'OK',
            _filename = _file,
            _content = _local
        })
    else
        -- if not conflict, and no local file, consider this not found
        OUT_CHANNEL:push({
            _status = 'NOT FOUND',
            _filename = _file,
            _content = nil
        })    
    end
end

function fakeload(_file, _callback)
    local _contents = get_compressed(_file)
    if _contents then
        --if string.match(_file, "meta") then 
        --    _callback(_file, FOS.Conflict, '', _contents, get_compressed('2/INM2.jkr'))
        --    return
        --end
        --if string.match(_file, "profile") then 
        --    _callback(_file, FOS.Conflict, '', _contents, get_compressed('2/INP2.jkr'))
        --    return
        --end

        _callback(_file, FOS.Success, '', _contents, nil)
        return
    end
    _callback(_file, FOS.NotFound, '', _contents, nil)
end

love.platform.setLoadGameCallback(load_callback)

local status, message = pcall(function()
    while true do
        -- Check the channel for any new requests without blocking
        local request = IN_CHANNEL:pop()  -- Non-blocking check
        
        while request do
            -- Async Load
            if request.type == 'load_request' then
                -- CLOUD SAVE
                love.platform.loadGameFile(request.file)
            end
            
            -- Check for the next message
            request = IN_CHANNEL:pop()
        end


        -- Run callbacks every frame
        love.platform.runLoadGameCallbacks()

        -- Yield to allow the game to continue running smoothly
        love.timer.sleep(0.01)  -- Small sleep to avoid CPU hogging
    end

end)

if not status then
    print("[PLATFORM] LOAD GAME THREAD ISSUE:")
    print(message)
end