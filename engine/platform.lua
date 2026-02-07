-- maps from ingame achievements to the trophy id
local achievementMap = {}

if love.system.getOS() == 'iOS' then
    if love.platform.isPremium and love.platform.isPremium() then
        achievementMap = {
            ante_up =                "01_PREMIUM", --
            ante_upper =             "02_PREMIUM", --
            heads_up =               "03_PREMIUM", --
            low_stakes =             "04_PREMIUM", --
            mid_stakes =             "05_PREMIUM", --
            high_stakes =            "06_PREMIUM", --
            card_player =            "07_PREMIUM", --
            card_discarder =         "08_PREMIUM", --
            nest_egg =               "09_PREMIUM", --
            flushed =                "10_PREMIUM", --
            speedrunner =            "11_PREMIUM", --
            roi =                    "12_PREMIUM", --
            shattered =              "13_PREMIUM", --
            royale =                 "14_PREMIUM", --
            retrograde =             "15_PREMIUM", --
            _10k =                   "16_PREMIUM", --
            _1000k =                 "17_PREMIUM", --
            _100000k =               "18_PREMIUM", --
            tiny_hands =             "19_PREMIUM", --
            big_hands =              "20_PREMIUM", --
            you_get_what_you_get =   "21_PREMIUM", --
            rule_bender =            "22_PREMIUM", --
            rule_breaker =           "23_PREMIUM", --
            legendary =              "24_PREMIUM", --
            astronomy =              "25_PREMIUM", --
            cartomancy =             "26_PREMIUM", --
            clairvoyance =           "27_PREMIUM", --
            extreme_couponer =       "28_PREMIUM", --
            completionist =          "29_PREMIUM", --
            completionist_plus =     "30_PREMIUM", --
            completionist_plus_plus= "31_PREMIUM",
        }
    else
        achievementMap = {
            ante_up =                "01", --
            ante_upper =             "02", --
            heads_up =               "03", --
            low_stakes =             "04", --
            mid_stakes =             "05", --
            high_stakes =            "06", --
            card_player =            "07", --
            card_discarder =         "08", --
            nest_egg =               "09", --
            flushed =                "10", --
            speedrunner =            "11", --
            roi =                    "12", --
            shattered =              "13", --
            royale =                 "14", --
            retrograde =             "15", --
            _10k =                   "16", --
            _1000k =                 "17", --
            _100000k =               "18", --
            tiny_hands =             "19", --
            big_hands =              "20", --
            you_get_what_you_get =   "21", --
            rule_bender =            "22", --
            rule_breaker =           "23", --
            legendary =              "24", --
            astronomy =              "25", --
            cartomancy =             "26", --
            clairvoyance =           "27", --
            extreme_couponer =       "28", --
            completionist =          "29", --
            completionist_plus =     "30", --
            completionist_plus_plus= "31",
        }
    end
else
    achievementMap = {
        ante_up =                "CgkI95DFk5AREAIQAQ", --
        ante_upper =             "CgkI95DFk5AREAIQAg", --
        heads_up =               "CgkI95DFk5AREAIQAw", --
        low_stakes =             "CgkI95DFk5AREAIQBA", --
        mid_stakes =             "CgkI95DFk5AREAIQBg", --
        high_stakes =            "CgkI95DFk5AREAIQBw", --
        card_player =            "CgkI95DFk5AREAIQCA", --
        card_discarder =         "CgkI95DFk5AREAIQCQ", --
        nest_egg =               "CgkI95DFk5AREAIQCg", --
        flushed =                "CgkI95DFk5AREAIQCw", --
        speedrunner =            "CgkI95DFk5AREAIQDA", --
        roi =                    "CgkI95DFk5AREAIQDQ", --
        shattered =              "CgkI95DFk5AREAIQDg", --
        royale =                 "CgkI95DFk5AREAIQDw", --
        retrograde =             "CgkI95DFk5AREAIQEA", --
        _10k =                   "CgkI95DFk5AREAIQEQ", --
        _1000k =                 "CgkI95DFk5AREAIQEg", --
        _100000k =               "CgkI95DFk5AREAIQEw", --
        tiny_hands =             "CgkI95DFk5AREAIQFA", --
        big_hands =              "CgkI95DFk5AREAIQFQ", --
        you_get_what_you_get =   "CgkI95DFk5AREAIQFg", --
        rule_bender =            "CgkI95DFk5AREAIQFw", --
        rule_breaker =           "CgkI95DFk5AREAIQGA", --
        legendary =              "CgkI95DFk5AREAIQGQ", --
        astronomy =              "CgkI95DFk5AREAIQGg", --
        cartomancy =             "CgkI95DFk5AREAIQGw", --
        clairvoyance =           "CgkI95DFk5AREAIQHA", --
        extreme_couponer =       "CgkI95DFk5AREAIQHQ", --
        completionist =          "CgkI95DFk5AREAIQHg", --
        completionist_plus =     "CgkI95DFk5AREAIQHw", --
        completionist_plus_plus= "CgkI95DFk5AREAIQIA",
    }
end

local Platform = {};

function Platform:unlockAchievement(gameId)
    local achievementId = achievementMap[gameId]
    if achievementId ~= nil then
        love.platform.unlockAchievement(achievementId)
    else -- retail-remove
        print("TRIGGERING UNSUPPORTED ACHIEVEMENT "..tostring(gameId))    -- retail-remove
    end
end

return Platform;