-- Optimized overrides for Talisman performance
-- Based on engine/particles.lua, engine/node.lua, engine/event.lua

if not Particles then return end

function Particles:update(dt)
    if G.SETTINGS.paused and not self.created_on_pause then self.last_real_time = G.TIMERS[self.timer_type] ; return end
    local added_this_frame = 0
    -- Removed to_big calls for loop conditions
    while G.TIMERS[self.timer_type]  > self.last_real_time + self.timer and (#self.particles < self.max or self.pulsed < self.pulse_max) and added_this_frame < 20 do
        self.last_real_time = self.last_real_time + self.timer
        local new_offset = { 
            x=self.fill and (0.5-math.random())*self.T.w or 0,
            y=self.fill and (0.5-math.random())*self.T.h or 0
        }
        if self.fill and self.T.r < 0.1 and self.T.r > -0.1 then 
            local newer_offset = {
                x = math.sin(self.T.r)*new_offset.y + math.cos(self.T.r)*new_offset.x,
                y = math.sin(self.T.r)*new_offset.x + math.cos(self.T.r)*new_offset.y,
            }
            new_offset = newer_offset
        end
        table.insert(self.particles, {
            draw = false,
            dir = math.random()*2*math.pi,
            facing = math.random()*2*math.pi,
            size = math.random()*0.5+0.1,
            age = 0,
            velocity = self.speed*(self.vel_variation*math.random() + (1-self.vel_variation))*0.7,
            r_vel = 0.2*(0.5 - math.random()),
            e_prev = 0,
            e_curr = 0,
            scale = 0,
            visible_scale = 0,
            time = G.TIMERS[self.timer_type],
            colour = pseudorandom_element(self.colours),
            offset = new_offset
        })
        added_this_frame = added_this_frame + 1
        if self.pulsed <= self.pulse_max then self.pulsed = self.pulsed + 1 end
    end
end

function Particles:move(dt)
    if G.SETTINGS.paused and not self.created_on_pause then return end

    Moveable.move(self, dt)

    if self.timer_type ~= 'REAL' then dt = dt*G.SPEEDFACTOR end

    for i=#self.particles,1,-1 do
        self.particles[i].draw = true
        self.particles[i].e_vel = self.particles[i].e_vel or dt*self.scale
        self.particles[i].e_prev = self.particles[i].e_curr
        self.particles[i].age = self.particles[i].age + dt
        
        self.particles[i].e_curr = math.min(2*math.min((self.particles[i].age/self.lifespan)*self.scale, self.scale*((self.lifespan - self.particles[i].age)/self.lifespan)), self.scale)

        self.particles[i].e_vel =  (self.particles[i].e_curr - self.particles[i].e_prev)*self.scale*dt + (1-self.scale*dt)*self.particles[i].e_vel

        self.particles[i].scale = self.particles[i].scale + self.particles[i].e_vel
        self.particles[i].scale = math.min(2*math.min((self.particles[i].age/self.lifespan)*self.scale, self.scale*((self.lifespan - self.particles[i].age)/self.lifespan)), self.scale)

        -- Removed to_big calls for scale check
        if self.particles[i].scale < 0 then
            table.remove(self.particles, i)
        else
            self.particles[i].offset.x = self.particles[i].offset.x + self.particles[i].velocity*math.sin(self.particles[i].dir)*dt
            self.particles[i].offset.y = self.particles[i].offset.y + self.particles[i].velocity*math.cos(self.particles[i].dir)*dt
            self.particles[i].facing = self.particles[i].facing + self.particles[i].r_vel*dt
            self.particles[i].velocity = math.max(0, self.particles[i].velocity - self.particles[i].velocity*0.07*dt)
        end
    end
end

function Particles:draw(alpha)
    alpha = alpha or 1
    prep_draw(self, 1)
    
    local w = type(self.T.w) == 'table' and to_number(self.T.w) or self.T.w
    local h = type(self.T.h) == 'table' and to_number(self.T.h) or self.T.h
    love.graphics.translate(w/2, h/2)
    
    local fa = type(self.fade_alpha) == 'table' and to_number(self.fade_alpha) or (self.fade_alpha or 0)
    local al = type(alpha) == 'table' and to_number(alpha) or alpha
    
    for k, v in pairs(self.particles) do
        if v.draw then 
            love.graphics.push()
            
            local c = v.colour
            local r = type(c[1]) == 'table' and to_number(c[1]) or c[1]
            local g = type(c[2]) == 'table' and to_number(c[2]) or c[2]
            local b = type(c[3]) == 'table' and to_number(c[3]) or c[3]
            local a = type(c[4]) == 'table' and to_number(c[4]) or c[4]

            love.graphics.setColor(r, g, b, a * al * (1 - fa))                
            
            local ox = type(v.offset.x) == 'table' and to_number(v.offset.x) or v.offset.x
            local oy = type(v.offset.y) == 'table' and to_number(v.offset.y) or v.offset.y
            love.graphics.translate(ox, oy)
            
            local f = type(v.facing) == 'table' and to_number(v.facing) or v.facing
            love.graphics.rotate(f)
            
            local s = type(v.scale) == 'table' and to_number(v.scale) or v.scale
            love.graphics.rectangle('fill', -s/2, -s/2, s, s) 
            love.graphics.pop()
        end
    end
    love.graphics.pop()

    add_to_drawhash(self)
    self:draw_boundingrect()
end

if Node then
function Node:translate_container()
    if self.container and self.container ~= self then
        local c = self.container
        local w = type(c.T.w) == 'table' and to_number(c.T.w) or c.T.w
        local h = type(c.T.h) == 'table' and to_number(c.T.h) or c.T.h
        local x = type(c.T.x) == 'table' and to_number(c.T.x) or c.T.x
        local y = type(c.T.y) == 'table' and to_number(c.T.y) or c.T.y
        local r = type(c.T.r) == 'table' and to_number(c.T.r) or c.T.r

        love.graphics.translate(w*G.TILESCALE*G.TILESIZE*0.5, h*G.TILESCALE*G.TILESIZE*0.5)
        love.graphics.rotate(r)
        love.graphics.translate(-w*G.TILESCALE*G.TILESIZE*0.5 + x*G.TILESCALE*G.TILESIZE, -h*G.TILESCALE*G.TILESIZE*0.5 + y*G.TILESCALE*G.TILESIZE)
    end
end
end

if Event then
function Event:handle(_results)
    _results.blocking, _results.completed = self.blocking, self.complete
    if self.created_on_pause == false and G.SETTINGS.paused then _results.pause_skip = true; return end
    if not self.start_timer then self.time = G.TIMERS[self.timer]; self.start_timer = true end
    if self.trigger == 'after' then 
        if self.time + self.delay <= G.TIMERS[self.timer] then
            _results.time_done = true
            _results.completed = self.func()
        end
    end
    if self.trigger == 'ease' then 
        if not self.ease.start_time then
            self.ease.start_time = G.TIMERS[self.timer]
            self.ease.end_time = G.TIMERS[self.timer] + self.delay
            self.ease.start_val = self.ease.ref_table[self.ease.ref_value]
        end
        if not self.complete then 
            
            if self.ease.end_time >= G.TIMERS[self.timer] then
                local percent_done = ((self.ease.end_time - G.TIMERS[self.timer])/(self.ease.end_time - self.ease.start_time))

                -- Optimized easing logic
                if self.ease.type == 'lerp' then
                    local start_val = self.ease.start_val
                    local end_val = self.ease.end_val
                    if type(start_val) == 'table' or type(end_val) == 'table' then
                        start_val = to_big(start_val)
                        end_val = to_big(end_val)
                        self.ease.ref_table[self.ease.ref_value] = self.func(to_big(percent_done)*start_val + to_big(1-percent_done)*end_val)
                    else
                        self.ease.ref_table[self.ease.ref_value] = self.func(percent_done*start_val + (1-percent_done)*end_val)
                    end
                end
                if self.ease.type == 'elastic' then
                    percent_done = -math.pow(2, 10 * percent_done - 10) * math.sin((percent_done * 10 - 10.75) * 2*math.pi/3);
                    local start_val = self.ease.start_val
                    local end_val = self.ease.end_val
                    if type(start_val) == 'table' or type(end_val) == 'table' then
                        start_val = to_big(start_val)
                        end_val = to_big(end_val)
                        self.ease.ref_table[self.ease.ref_value] = self.func(to_big(percent_done)*start_val + to_big(1-percent_done)*end_val)
                    else
                        self.ease.ref_table[self.ease.ref_value] = self.func(percent_done*start_val + (1-percent_done)*end_val)
                    end
                end
                if self.ease.type == 'quad' then
                    percent_done = percent_done * percent_done;
                    local start_val = self.ease.start_val
                    local end_val = self.ease.end_val
                    if type(start_val) == 'table' or type(end_val) == 'table' then
                        start_val = to_big(start_val)
                        end_val = to_big(end_val)
                        self.ease.ref_table[self.ease.ref_value] = self.func(to_big(percent_done)*start_val + to_big(1-percent_done)*end_val)
                    else
                        self.ease.ref_table[self.ease.ref_value] = self.func(percent_done*start_val + (1-percent_done)*end_val)
                    end
                end
            else
                self.ease.ref_table[self.ease.ref_value] = self.func(self.ease.end_val)
                self.complete = true
                _results.completed = true
                _results.time_done = true
            end
        end
    end
    if self.trigger == 'condition' then 
        if not self.complete then _results.completed = self.func() end
        _results.time_done = true
    end
    if self.trigger == 'before' then 
        if not self.complete then _results.completed = self.func() end
        if self.time + self.delay <= G.TIMERS[self.timer] then
            _results.time_done = true
        end
    end
    if self.trigger == 'immediate' then
        _results.completed = self.func()
        _results.time_done = true
    end
    if _results.completed then self.complete = true end
end
end

-- Optimized Math Functions and Utilities for Talisman
-- Caching common BigNumbers to reduce object creation overhead
local BIG_ZERO = to_big(0)
local BIG_ONE = to_big(1)
local BIG_TWO = to_big(2)

-- Optimized math.max with varargs support
function math.max(x, y, ...)
    if y == nil then return x end
    if not ... then
        if type(x) == 'number' and type(y) == 'number' then
            return x > y and x or y
        end
        local bx = (type(x) == 'table') and x or (x == 0 and BIG_ZERO or (x == 1 and BIG_ONE or to_big(x)))
        local by = (type(y) == 'table') and y or (y == 0 and BIG_ZERO or (y == 1 and BIG_ONE or to_big(y)))
        return by > bx and by or bx
    end
    
    local max_val = x
    local n = select('#', y, ...)
    for i = 1, n do
        local next_y = select(i, y, ...)
        if type(max_val) == 'number' and type(next_y) == 'number' then
            if next_y > max_val then max_val = next_y end
        else
            local bx = (type(max_val) == 'table') and max_val or (max_val == 0 and BIG_ZERO or (max_val == 1 and BIG_ONE or to_big(max_val)))
            local by = (type(next_y) == 'table') and next_y or (next_y == 0 and BIG_ZERO or (next_y == 1 and BIG_ONE or to_big(next_y)))
            if by > bx then max_val = by else max_val = bx end
        end
    end
    return max_val
end

-- Optimized math.min with varargs support
function math.min(x, y, ...)
    if y == nil then return x end
    if not ... then
        if type(x) == 'number' and type(y) == 'number' then
            return x < y and x or y
        end
        local bx = (type(x) == 'table') and x or (x == 0 and BIG_ZERO or (x == 1 and BIG_ONE or to_big(x)))
        local by = (type(y) == 'table') and y or (y == 0 and BIG_ZERO or (y == 1 and BIG_ONE or to_big(y)))
        return by < bx and by or bx
    end
    
    local min_val = x
    local n = select('#', y, ...)
    for i = 1, n do
        local next_y = select(i, y, ...)
        if type(min_val) == 'number' and type(next_y) == 'number' then
            if next_y < min_val then min_val = next_y end
        else
            local bx = (type(min_val) == 'table') and min_val or (min_val == 0 and BIG_ZERO or (min_val == 1 and BIG_ONE or to_big(min_val)))
            local by = (type(next_y) == 'table') and next_y or (next_y == 0 and BIG_ZERO or (next_y == 1 and BIG_ONE or to_big(next_y)))
            if by < bx then min_val = by else min_val = bx end
        end
    end
    return min_val
end

-- Optimized math.abs
function math.abs(x)
    if type(x) == 'number' then
        return x < 0 and -x or x
    end
    if type(x) == 'table' then
        if x < BIG_ZERO then return x:neg() else return x end
    end
    return to_big(x)
end

-- Optimized text_super_juice
-- Replaces Talisman's wrapper to avoid to_big(2) creation and conversion overhead
function G.FUNCS.text_super_juice(e, amount)
    local amt_val = amount
    
    if type(amount) == 'table' then
        if amount > BIG_TWO then amt_val = 2
        else amt_val = to_number(amount) end
    elseif type(amount) == 'number' then
        if amount > 2 then amt_val = 2 end
    end
    
    local amount = amt_val or 1
    if e.config and e.config.object then
        e.config.object:juice_up(0.6*amount, 0.1*amount)
    end
    G.ROOM.jiggle = G.ROOM.jiggle + 0.7*amount
end

-- Optimized update_hand_text for Talisman
-- This avoids to_big overhead when handling simple number updates for UI animations

function update_hand_text(config, vals)
    if Talisman.config_file.disable_anims then
        if G.latest_uht then
          local chips = G.latest_uht.vals.chips
          local mult = G.latest_uht.vals.mult
          if not vals.chips then vals.chips = chips end
          if not vals.mult then vals.mult = mult end
        end
        G.latest_uht = {config = config, vals = vals}
    else 
        G.E_MANAGER:add_event(Event({--This is the Hand name text for the poker hand
        trigger = 'before',
        blockable = not config.immediate,
        delay = config.delay or 0.8,
        func = function()
            local col = G.C.GREEN
            -- Optimized chips update
            if vals.chips and G.GAME.current_round.current_hand.chips ~= vals.chips then
                local delta
                local v_chips = vals.chips
                local g_chips = G.GAME.current_round.current_hand.chips
                
                -- Ensure both operands are safe for arithmetic or to_big conversion
                if type(v_chips) == 'string' then v_chips = to_big(v_chips) end
                if type(g_chips) == 'string' then g_chips = to_big(g_chips) end

                if type(v_chips) == 'table' or type(g_chips) == 'table' then
                    delta = to_big(v_chips) - to_big(g_chips)
                else
                    delta = v_chips - g_chips
                end
                
                local is_neg, is_pos = false, false
                if type(delta) == 'table' then
                    is_neg = delta < BIG_ZERO
                    is_pos = delta > BIG_ZERO
                else
                    is_neg = delta < 0
                    is_pos = delta > 0
                end

                if is_neg then delta = number_format(delta); col = G.C.RED
                elseif is_pos then delta = '+'..number_format(delta)
                else delta = number_format(delta)
                end
                if type(vals.chips) == 'string' then delta = vals.chips end
                G.GAME.current_round.current_hand.chips = vals.chips
                if G.hand_text_area.chips.config.object then G.hand_text_area.chips:update(0) end
                if vals.StatusText then 
                    attention_text({
                        text =delta,
                        scale = 0.8, 
                        hold = 1,
                        cover = G.hand_text_area.chips.parent,
                        cover_colour = mix_colours(G.C.CHIPS, col, 0.1),
                        emboss = 0.05,
                        align = 'cm',
                        cover_align = 'cr'
                    })
                end
                if not G.TAROT_INTERRUPT then G.hand_text_area.chips:juice_up() end
            end
            -- Optimized mult update
            if vals.mult and G.GAME.current_round.current_hand.mult ~= vals.mult then
                local delta
                local v_mult = vals.mult
                local g_mult = G.GAME.current_round.current_hand.mult

                -- Ensure both operands are safe for arithmetic or to_big conversion
                if type(v_mult) == 'string' then v_mult = to_big(v_mult) end
                if type(g_mult) == 'string' then g_mult = to_big(g_mult) end

                if type(v_mult) == 'table' or type(g_mult) == 'table' then
                    delta = to_big(v_mult) - to_big(g_mult)
                else
                    delta = v_mult - g_mult
                end

                local is_neg, is_pos = false, false
                if type(delta) == 'table' then
                    is_neg = delta < BIG_ZERO
                    is_pos = delta > BIG_ZERO
                else
                    is_neg = delta < 0
                    is_pos = delta > 0
                end

                if is_neg then delta = number_format(delta); col = G.C.RED
                elseif is_pos then delta = '+'..number_format(delta)
                else delta = number_format(delta)
                end
                if type(vals.mult) == 'string' then delta = vals.mult end
                G.GAME.current_round.current_hand.mult = vals.mult
                if G.hand_text_area.mult.config.object then G.hand_text_area.mult:update(0) end
                if vals.StatusText then 
                    attention_text({
                        text =delta,
                        scale = 0.8, 
                        hold = 1,
                        cover = G.hand_text_area.mult.parent,
                        cover_colour = mix_colours(G.C.MULT, col, 0.1),
                        emboss = 0.05,
                        align = 'cm',
                        cover_align = 'cl'
                    })
                end
                if not G.TAROT_INTERRUPT then G.hand_text_area.mult:juice_up() end
            end
            if vals.handname and G.GAME.current_round.current_hand.handname ~= vals.handname then
                G.GAME.current_round.current_hand.handname = vals.handname
                if not config.nopulse then 
                    G.hand_text_area.handname.config.object:pulse(0.2)
                end
            end
            if vals.chip_total then G.GAME.current_round.current_hand.chip_total = vals.chip_total;G.hand_text_area.chip_total.config.object:pulse(0.5) end
            if vals.level and G.GAME.current_round.current_hand.hand_level ~= ' '..localize('k_lvl')..number_format(vals.level) then
                if vals.level == '' then
                    G.GAME.current_round.current_hand.hand_level = vals.level
                else
                    G.GAME.current_round.current_hand.hand_level = ' '..localize('k_lvl')..number_format(vals.level)
                    local lvl = vals.level
                    if type(lvl) == 'table' then lvl = to_number(lvl) end
                    G.hand_text_area.hand_level.config.colour = G.C.HAND_LEVELS[math.floor(math.min(lvl or 1, 7))]
                    G.hand_text_area.hand_level:juice_up()
                end
            end
            if config.sound and not config.modded then play_sound(config.sound, config.pitch or 1, config.volume or 1) end
            if config.modded then 
                G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff_1'):juice_up(0.3, 0)
                G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff_2'):juice_up(0.3, 0)
                G.GAME.blind:juice_up()
                G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.06*G.SETTINGS.GAMESPEED, blockable = false, blocking = false, func = function()
                    play_sound('tarot2', 0.76, 0.4);return true end}))
                play_sound('tarot2', 1, 0.4)
            end
            return true
        end}))
    end
end
