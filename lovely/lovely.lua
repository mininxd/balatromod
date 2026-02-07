-- This file contains template values filled during JIT. You can access these values
-- within your code with `local lovely = require("lovely")`.

return {
    repo = "https://github.com/ethangreen-dev/lovely-injector",
    version = "1.0.0-",
    -- mod_dir = love.filesystem.getSourceBaseDirectory().. "/Mods",
    mod_dir = love.filesystem.getSaveDirectory().. "/Mods",
}
