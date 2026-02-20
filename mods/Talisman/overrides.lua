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
    -- Optimized translate using to_number directly
    love.graphics.translate(to_number(self.T.w/2), to_number(self.T.h/2))
    for k, v in pairs(self.particles) do
        if v.draw then 
            love.graphics.push()
            -- Optimized color setting
            love.graphics.setColor(
                to_number(v.colour[1]), 
                to_number(v.colour[2]), 
                to_number(v.colour[3]), 
                to_number(v.colour[4])*to_number(alpha)*(1-to_number(self.fade_alpha))
            )                
            love.graphics.translate(to_number(v.offset.x), to_number(v.offset.y))
            love.graphics.rotate(to_number(v.facing))
            
            local s = to_number(v.scale)
            love.graphics.rectangle('fill', -s/2, -s/2, s, s) -- origin in the middle
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
        -- Optimized translate_container
        love.graphics.translate(to_number(self.container.T.w*G.TILESCALE*G.TILESIZE*0.5), to_number(self.container.T.h*G.TILESCALE*G.TILESIZE*0.5))
        love.graphics.rotate(to_number(self.container.T.r))
        love.graphics.translate(
            to_number(-self.container.T.w*G.TILESCALE*G.TILESIZE*0.5 + self.container.T.x*G.TILESCALE*G.TILESIZE),
            to_number(-self.container.T.h*G.TILESCALE*G.TILESIZE*0.5 + self.container.T.y*G.TILESCALE*G.TILESIZE))
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

-- Optimized update_hand_text for Talisman
-- This avoids to_big overhead when handling simple number updates for UI animations
local BIG_ZERO = to_big(0)

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
                if type(vals.chips) == 'table' or type(G.GAME.current_round.current_hand.chips) == 'table' then
                    delta = to_big(vals.chips) - to_big(G.GAME.current_round.current_hand.chips)
                else
                    delta = vals.chips - G.GAME.current_round.current_hand.chips
                end
                
                if to_big(delta) < BIG_ZERO then delta = number_format(delta); col = G.C.RED
                elseif to_big(delta) > BIG_ZERO then delta = '+'..number_format(delta)
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
            end
            -- Optimized mult update
            if vals.mult and G.GAME.current_round.current_hand.mult ~= vals.mult then
                local delta
                if type(vals.mult) == 'table' or type(G.GAME.current_round.current_hand.mult) == 'table' then
                    delta = to_big(vals.mult) - to_big(G.GAME.current_round.current_hand.mult)
                else
                    delta = vals.mult - G.GAME.current_round.current_hand.mult
                end

                if to_big(delta) < BIG_ZERO then delta = number_format(delta); col = G.C.RED
                elseif to_big(delta) > BIG_ZERO then delta = '+'..number_format(delta)
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
                    if type(vals.level) == 'number' or is_number(vals.level) then 
                        G.hand_text_area.hand_level.config.colour = G.C.HAND_LEVELS[math.floor(to_number(math.min(vals.level, 7)))]
                    else
                        G.hand_text_area.hand_level.config.colour = G.C.HAND_LEVELS[1]
                    end
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
