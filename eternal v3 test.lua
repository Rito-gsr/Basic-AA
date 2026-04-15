--[[
    ETERNAL GOD v6 - NEVERLOSE STYLE KEYBINDS
    Standalone | Draggable Indicators | Safe Head Logic
]]

-- [ 1. CACHE API ]
local ui_get, ui_set, ui_ref, ui_is_menu_open, ui_mouse_pos = 
      ui.get, ui.set, ui.reference, ui.is_menu_open, ui.mouse_position
local ui_new_cb, ui_new_lbl, ui_new_combo, ui_new_slider, ui_new_hotkey, ui_new_multiselect = 
      ui.new_checkbox, ui.new_label, ui.new_combobox, ui.new_slider, ui.new_hotkey, ui.new_multiselect
local client_set_event, client_delay_call, client_userid_to_entindex, client_key_state = 
      client.set_event_callback, client.delay_call, client.userid_to_entindex, client.key_state
local globals_tick, globals_curtime = globals.tickcount, globals.curtime
local entity_get_local, entity_get_prop, entity_get_classname = 
      entity.get_local_player, entity.get_prop, entity.get_classname
local math_random, math_floor, math_sin = math.random, math.floor, math.sin
local renderer_rect, renderer_text, renderer_gradient = 
      renderer.rectangle, renderer.text, renderer.gradient

-- [ 2. REFERÊNCIAS NATIVAS ]
-- AA
local ref_pitch = ui_ref("AA", "Anti-aimbot angles", "Pitch")
local ref_yawbase = ui_ref("AA", "Anti-aimbot angles", "Yaw base")
local ref_yaw, ref_yawadd = ui_ref("AA", "Anti-aimbot angles", "Yaw")
local ref_jitter, ref_jitteradd = ui_ref("AA", "Anti-aimbot angles", "Yaw jitter")
local ref_body, ref_bodyval = ui_ref("AA", "Anti-aimbot angles", "Body yaw")

-- RAGE & OTHERS (Para os Indicators)
local ref_dt = {ui_ref("RAGE", "Aimbot", "Double tap")}
local ref_hs = {ui_ref("AA", "Other", "On shot anti-aim")}
local ref_mindmg = {ui_ref("RAGE", "Aimbot", "Minimum damage override")}
local ref_fd = ui_ref("RAGE", "Other", "Duck peek assist")

-- [ 3. INTERFACE NA ABA LUA ]
local tab = "LUA"
local sub = "A"

ui_new_lbl(tab, sub, "--- ETERNAL GOD v6 ---")

-- >> CATEGORIA: ANTI-AIM
ui_new_lbl(tab, sub, " ")
ui_new_lbl(tab, sub, ">>> ANTI-AIM SETTINGS <<<")
local master_aa = ui_new_cb(tab, sub, "Enable Custom Anti-Aim")

-- Jitter Settings
local aa_type = ui_new_combo(tab, sub, "Jitter Mode", {"Off", "Offset", "Center", "Random", "Skitter", "3-Way", "5-Way", "Sway"})
local aa_range = ui_new_slider(tab, sub, "Jitter Range", -180, 180, 45)
local aa_speed = ui_new_slider(tab, sub, "Jitter Delay (Ticks)", 0, 15, 1)

-- Body Yaw Settings
local body_mode = ui_new_combo(tab, sub, "Body Yaw Mode", {"Static", "Jitter", "Opposite", "Void Flip"})
local body_val = ui_new_slider(tab, sub, "Body Yaw Angle", -180, 180, 60)

-- Freestand
local fs_key = ui_new_hotkey(tab, sub, "Static Freestand Key", true)

-- Advanced Features
ui_new_lbl(tab, sub, ">>> ADVANCED FEATURES <<<")
local anim_breakers = ui_new_multiselect(tab, sub, "Animation Breakers", {"Pitch 0 on Land", "Static Legs in Air", "Body Lean"})
local safe_head_opt = ui_new_cb(tab, sub, "Safe Head (Knife/Zeus + Air)")

-- >> CATEGORIA: MISC
ui_new_lbl(tab, sub, " ")
ui_new_lbl(tab, sub, ">>> MISC SETTINGS <<<")

-- Clantag
local clantag_mode = ui_new_combo(tab, sub, "Clantag Changer", {"Off", "Eternal.lua", "Toxic Trash", "Gamesense"})

-- Trashtalk
local tt_kill = ui_new_cb(tab, sub, "Trashtalk on Kill")
local tt_death = ui_new_cb(tab, sub, "Trashtalk on Death")

-- [ 4. LOGIC: KEYBINDS WINDOW (NEVERLOSE STYLE) ]
local kb_x, kb_y = 200, 200 -- Posição inicial
local dragging = false
local drag_x, drag_y = 0, 0

local function is_in_bounds(mouse_x, mouse_y, x, y, w, h)
    return mouse_x >= x and mouse_x <= x + w and mouse_y >= y and mouse_y <= y + h
end

local function draw_keybinds()
    if not ui_get(master_aa) then return end

    -- Coletar Estado dos Binds
    local active_binds = {}

    -- 1. Double Tap
    if ui_get(ref_dt[1]) and ui_get(ref_dt[2]) then table.insert(active_binds, {name = "Double Tap", mode = "[Toggled]"}) end
    -- 2. Hide Shots
    if ui_get(ref_hs[1]) and ui_get(ref_hs[2]) then table.insert(active_binds, {name = "Hide Shots", mode = "[On Shot]"}) end
    -- 3. Min Damage
    if ui_get(ref_mindmg[1]) and ui_get(ref_mindmg[2]) then table.insert(active_binds, {name = "Min Damage", mode = "[Override]"}) end
    -- 4. Fake Duck
    if ui_get(ref_fd) then table.insert(active_binds, {name = "Duck Peek", mode = "[Holding]"}) end
    -- 5. Freestand (Nosso script)
    if ui_get(fs_key) then table.insert(active_binds, {name = "Freestand", mode = "[Static]"}) end
    
    -- 6. Safe Head (Lógica Interna)
    local me = entity_get_local()
    if ui_get(safe_head_opt) and me and entity.is_alive(me) then
        local weapon = entity.get_player_weapon(me)
        local cls = weapon and entity_get_classname(weapon) or ""
        local flags = entity_get_prop(me, "m_fFlags") or 0
        local in_air = not (bit.band(flags, 1) == 1)
        local is_ducking = (bit.band(flags, 4) == 4)
        if (cls == "CKnife" or cls == "CWeaponTaser") and in_air and is_ducking then
            table.insert(active_binds, {name = "Safe Head", mode = "[Safety]"})
        end
    end

    -- Se não houver nada ativo e menu fechado, não desenha nada (comportamento NL)
    -- Se menu estiver aberto, desenha vazio para poder arrastar
    local menu_open = ui_is_menu_open()
    if #active_binds == 0 and not menu_open then return end

    -- Dimensões
    local w = 180
    local h_header = 22
    local h_item = 18
    local total_h = h_header + (#active_binds * h_item) + 4

    -- Lógica de Arrastar (Só funciona com Menu Aberto)
    if menu_open then
        local mx, my = ui_mouse_pos()
        local left_click = client_key_state(0x01)

        if dragging then
            kb_x = mx - drag_x
            kb_y = my - drag_y
            if not left_click then dragging = false end
        else
            if left_click and is_in_bounds(mx, my, kb_x, kb_y, w, h_header) then
                dragging = true
                drag_x = mx - kb_x
                drag_y = my - kb_y
            end
        end
    end

    -- Renderização (Estilo NL)
    -- Fundo
    renderer_rect(kb_x, kb_y, w, total_h, 12, 12, 12, 240) -- Fundo escuro
    -- Linha de Acento (Topo) - Roxo Eternal
    renderer_rect(kb_x, kb_y, w, 2, 150, 100, 255, 255)
    
    -- Texto Header
    renderer_text(kb_x + w/2, kb_y + 11, 255, 255, 255, 255, "c-", 0, "keybinds")

    -- Itens
    local y_offset = kb_y + h_header + 2
    for i, bind in ipairs(active_binds) do
        -- Nome (Esquerda)
        renderer_text(kb_x + 6, y_offset, 255, 255, 255, 200, "-", 0, bind.name)
        -- Estado (Direita)
        renderer_text(kb_x + w - 6, y_offset, 255, 255, 255, 150, "r", 0, bind.mode)
        y_offset = y_offset + h_item
    end
end


-- [ 5. FUNÇÃO DE CLANTAG ]
local last_tag_time = 0
local function handle_clantag()
    local mode = ui_get(clantag_mode)
    if mode == "Off" then return end
    if globals_curtime() - last_tag_time < 0.5 then return end

    local tag_str = ""
    local time_factor = math_floor(globals_curtime() * 2.5)

    if mode == "Eternal.lua" then
        local text = " eternal.lua "
        local idx = time_factor % #text
        tag_str = text:sub(idx + 1) .. text:sub(1, idx)
    elseif mode == "Toxic Trash" then
        local frames = {"?", "owned", "1", "sit", "EZ", "trash", "eternal"}
        tag_str = frames[(time_factor % #frames) + 1]
    elseif mode == "Gamesense" then
        local text = " gamesense "
        local idx = time_factor % #text
        tag_str = text:sub(idx + 1) .. text:sub(1, idx)
    end

    if tag_str ~= "" then client.set_clan_tag(tag_str) end
    last_tag_time = globals_curtime()
end

-- [ 6. KILLSAY FIXO ]
local kill_msgs = {
    "ETERNAL GOD > voce.", "1", "Senta pro pai.", "Config de padaria a sua?", 
    "UID 001.", "Desync resolveu seu cerebro?", "tchau.", "volte para o lobby.", "?"
}
local death_msgs = {
    "meu time é peso.", "nice config, passa?", "lag compensation me trollou.", 
    "sorte.", "baim user kkkk"
}

local function on_player_death(e)
    if tt_kill == nil or tt_death == nil then return end
    if not ui.get(tt_kill) and not ui.get(tt_death) then return end

    local me = entity_get_local()
    local attacker_userid = e.attacker
    local victim_userid = e.userid

    if attacker_userid == nil or victim_userid == nil then return end

    local attacker_ent = client.userid_to_entindex(attacker_userid)
    local victim_ent = client.userid_to_entindex(victim_userid)
    
    if ui.get(tt_kill) and attacker_ent == me and victim_ent ~= me then
        local msg = kill_msgs[math.random(#kill_msgs)]
        client.delay_call(0.1, client.exec, "say " .. msg)
    end

    if ui.get(tt_death) and victim_ent == me then
        local msg = death_msgs[math.random(#death_msgs)]
        client.delay_call(0.2, client.exec, "say " .. msg)
    end
end

-- [ 7. FUNÇÃO HELPERS ]
local function contains(table, val)
    for i=1, #table do if table[i] == val then return true end end
    return false
end

-- [ 8. LÓGICA DE ANIMATION BREAKERS ]
local function handle_anim_breakers()
    if not ui_get(master_aa) then return end
    
    local me = entity_get_local()
    if not me or not entity.is_alive(me) then return end

    local breakers = ui_get(anim_breakers)
    if #breakers == 0 then return end

    local flags = entity_get_prop(me, "m_fFlags")
    local in_air = not (bit.band(flags, 1) == 1)
    
    if contains(breakers, "Pitch 0 on Land") and not in_air then
        entity.set_prop(me, "m_flPoseParameter", 0.5, 12) 
    end
    if contains(breakers, "Static Legs in Air") and in_air then
        entity.set_prop(me, "m_flPoseParameter", 1, 6) 
    end
    if contains(breakers, "Body Lean") then
        entity.set_prop(me, "m_flPoseParameter", 1, 7)
    end
end

-- [ 9. LÓGICA DE ANTI-AIM PRINCIPAL ]
local function on_setup_command(cmd)
    if not ui_get(master_aa) then return end

    local me = entity_get_local()
    if not me or not entity.is_alive(me) then return end

    -- Override Nativos
    ui_set(ref_pitch, "Down")
    ui_set(ref_yaw, "180")
    ui_set(ref_jitter, "Off")
    ui_set(ref_body, "Static")

    -- SAFE HEAD LOGIC
    if ui_get(safe_head_opt) then
        local weapon = entity.get_player_weapon(me)
        local weapon_class = "nil"
        if weapon then weapon_class = entity_get_classname(weapon) end
        
        local is_safe_weapon = (weapon_class == "CKnife" or weapon_class == "CWeaponTaser")
        local flags = entity_get_prop(me, "m_fFlags")
        local in_air = not (bit.band(flags, 1) == 1)
        local is_ducking = (bit.band(flags, 4) == 4)

        if is_safe_weapon and in_air and is_ducking then
            ui_set(ref_yawbase, "At targets")
            ui_set(ref_yawadd, 0)
            ui_set(ref_bodyval, 60)
            return 
        end
    end

    -- FREESTAND ESTÁTICO
    if ui_get(fs_key) then
        ui_set(ref_yawbase, "At targets")
        ui_set(ref_yawadd, 0)
        local side = (globals_tick() % 120 < 60) and 60 or -60
        ui_set(ref_bodyval, side)
        return
    end

    -- JITTER LOGIC (0-15 Ticks)
    ui_set(ref_yawbase, "At targets")
    local mode = ui_get(aa_type)
    local range = ui_get(aa_range)
    local speed = ui_get(aa_speed)
    local tick = globals_tick()
    local yaw_final = 0

    local time_cond = (tick % (speed + 1) == 0)
    local tick_scaled = math_floor(tick / (speed + 1))

    if mode == "Offset" then yaw_final = (tick_scaled % 2 == 0) and range or -range
    elseif mode == "Center" then yaw_final = (tick_scaled % 2 == 0) and range or 0
    elseif mode == "Random" then if time_cond then yaw_final = math_random(-range, range) end
    elseif mode == "Skitter" then if time_cond then yaw_final = math_random(-range/2, range/2) end
    elseif mode == "3-Way" then
        local s = tick_scaled % 3
        yaw_final = (s == 0 and -range or (s == 1 and 0 or range))
    elseif mode == "5-Way" then
        local s = tick_scaled % 5
        yaw_final = -range + (s * (range * 0.5))
    elseif mode == "Sway" then yaw_final = math_sin(globals_curtime() * (16 - speed)) * range
    end
    ui_set(ref_yawadd, math_floor(yaw_final))

    -- BODY YAW LOGIC
    local b_mode = ui_get(body_mode)
    local b_angle = ui_get(body_val)
    
    if mode == "Skitter" then ui_set(ref_bodyval, (tick_scaled % 3 == 0) and 60 or -60)
    else
        if b_mode == "Static" then ui_set(ref_bodyval, b_angle)
        elseif b_mode == "Jitter" then ui_set(ref_bodyval, (tick_scaled % 2 == 0) and b_angle or -b_angle)
        elseif b_mode == "Opposite" then ui_set(ref_bodyval, (tick % 64 < 32) and 60 or -60)
        elseif b_mode == "Void Flip" then ui_set(ref_bodyval, math_random(-b_angle, b_angle))
        end
    end
end

-- [ 10. VISUAIS E CALLBACKS ]
client_set_event("paint", function()
    draw_keybinds() -- Nova função Keybinds
    handle_clantag()
end)

client_set_event("setup_command", on_setup_command)
client_set_event("player_death", on_player_death)
client_set_event("pre_render", handle_anim_breakers)