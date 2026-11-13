
State_t = "State"

local _new_fid = "new"
local _init_fid = "init"
local _enter_fid = "enter"
local _exit_fid = "exit"
local _update_fid = "update"
local _draw_fid = "draw"
local _reformat_fid = "reformat"
local _get_control_indicator_fid = "control_indicator"

local _scene_t_to_fs = {
    [StageScene_t] = {
        [_new_fid] = stage_scene_new,
        [_init_fid] = stage_scene_init,
        [_enter_fid] = stage_scene_enter,
        [_exit_fid] = stage_scene_exit,
        [_update_fid] = stage_scene_update,
        [_draw_fid] = stage_scene_draw,
        [_reformat_fid] = stage_scene_reformat,
        [_get_control_indicator_fid] = stage_scene_get_control_indicator
    },

    [MainMenuScene_t] = {
        [_new_fid] = main_menu_scene_new,
        [_init_fid] = main_menu_scene_init,
        [_enter_fid] = main_menu_scene_enter,
        [_exit_fid] = main_menu_scene_exit,
        [_update_fid] = main_menu_scene_update,
        [_draw_fid] = main_menu_scene_draw,
        [_reformat_fid] = main_menu_scene_reformat,
        [_get_control_indicator_fid] = main_menu_scene_get_control_indicator
    },

    [SkinSelectScene_t] = {
        [_new_fid] = skin_select_scene_new,
        [_init_fid] = skin_select_scene_init,
        [_enter_fid] = skin_select_scene_enter,
        [_exit_fid] = skin_select_scene_exit,
        [_update_fid] = main_menu_scene_update,
        [_draw_fid] = main_menu_scene_draw,
        [_reformat_fid] = main_menu_scene_reformat,
        [_get_control_indicator_fid] = skin_select_scene_get_control_indicator
    },

    [StageSelectScene_t] = {
        [_new_fid] = stage_select_scene_new,
        [_init_fid] = stage_select_scene_init,
        [_enter_fid] = stage_select_scene_enter,
        [_exit_fid] = stage_select_scene_exit,
        [_update_fid] = stage_select_scene_update,
        [_draw_fid] = stage_select_scene_draw,
        [_reformat_fid] = stage_select_scene_reformat,
        [_get_control_indicator_fid] = stage_select_scene_get_control_indicator
    },

    [SettingsScene_t] = {
        [_new_fid] = settings_scene_new,
        [_init_fid] = settings_scene_init,
        [_enter_fid] = settings_scene_enter,
        [_exit_fid] = settings_scene_exit,
        [_update_fid] = settings_scene_update,
        [_draw_fid] = settings_scene_draw,
        [_reformat_fid] = settings_scene_reformat,
        [_get_control_indicator_fid] = settings_scene_get_control_indicator
    },
}

local function _call_scene_f(scope, scene, fid, ...)
    if scene == nil then return end

    local fs = _scene_t_to_fs[scene.type]
    if fs == nil then
        log_error("in ", scope, ": unhandled scene type `", object_typeof(scene), "`")
        return
    end

    local f = fs[fid]
    if f ~= nil then
        return log_call(f, scene, ...)
    end
end

local _lag_full = 1.0
local _lag_empty = 0.0

local function _get_current(self)
    return self.scene_stack[table_sizeof(self.scene_stack)]
end

local function _flush_fade(self)
    if self.fade_motion_routine ~= nil then
        log_call(self.fade_motion_routine, self)
        self.fade_motion_routine = nil
        lag_set_value(self.fade_motion, _lag_empty)
        self.fade_motion_active = false
    end
end

local function _reformat_control_indicator(self)
    local window_width = graphics_get_window_width()
    local window_height = graphics_get_window_height()
    local graphics_width, graphics_height = graphics_get_size()
    local letterbox = (window_width - graphics_width) / 2
    local top = (window_height - graphics_height) / 2

    local min_x, min_y = math_positive_inf, math_positive_inf
    local max_x, max_y = math_negative_inf, math_negative_inf

    for _, scene in pairs(self.scene_t_to_scene) do
        local indicator = _call_scene_f("_reformat_control_indicator", scene, _get_control_indicator_fid)
        if object_isa(indicator, ControlIndicator_t) then
            control_indicator_reformat(indicator,
                _global_outer_margin, _global_outer_margin,
                letterbox, window_height
            )
            local b = control_indicator_get_bounds(indicator)
            min_x = math.min(min_x, b.x)
            min_y = math.min(min_y, b.y)
            max_x = math.max(max_x, b.x + b.width)
            max_y = math.max(max_y, b.y + b.height)
        end
    end

    local bounds = aabb_new(0, 0, 0, 0)
    if min_x ~= math_positive_inf then
        bounds = aabb_new(min_x, min_y, (max_x - min_x) + _global_outer_margin, max_y - min_y)
    end
    self.control_indicator_bounds = bounds

    local offset = 0
    local overlaps_y = bounds.y < top + graphics_height and bounds.y + bounds.height > top
    if overlaps_y then
        local wanted = (bounds.x + bounds.width) - letterbox
        offset = math_clamp(wanted, 0, math_max(letterbox, 0))
    end

    upscaler_resize(self.upscaler, window_width + 2 * offset, window_height)
end

state_new = function()
    return state_init(object_new(State_t, {}))
end

state_init = function(self)
    log_typecheck(self, State_t)
    self.upscaler = upscaler_resize(upscaler_new(), graphics_get_window_size())

    self.sound_effect_volume = 1.0
    self.music_volume = 1.0
    self.shaders_enabled = true

    self.fade_motion = lag_new(_lag_full, 4)
    self.fade_motion_routine = nil -- Function
    self.fade_motion_active = false

    local w, h = graphics_get_size()
    local stage_list = stage_list_new()
    if DEBUG then
        -- in dev env, export to file
        -- this is necessary because triangulation is unavailable in release mode
        local to_mount = love.filesystem.getSource() .. "/jam/assets"
        local mount_point = "stages"
        if not love.filesystem.mountFullPath(
            to_mount,
            mount_point,
            "readwrite",
            false
        ) then
            log_error("unable to mount path `", to_mount, "` to mount point `", mount_point, "`")
        end

        stage_list_export(
            stage_list,
            "jam/assets/stages.lua",
            mount_point .. "/stages_exported.lua"
        )

        love.filesystem.unmountFullPath(to_mount)
    end

    self.control_indicator_bounds = aabb_new(0, 0, 1, 1)

    -- allocate stages
    stage_list_init(stage_list, (DEBUG and "jam/" or "") .. "assets/stages_exported.lua")
    self.stage_list = stage_list
    self.stage_entries = {}
    for _, stage_id in ipairs(stage_list_get_ids(stage_list)) do
        self.stage_entries[stage_id] = {
            stage = stage_new(stage_list, stage_id), -- persistent instance
            is_completed = false
        }
    end

    -- skin
    self.player_skin = nil

    -- preallocate scenes
    self.scene_t_to_scene = {}

    -- current scene
    self.scene_stack = {}
    return self
end

local _create_fade_routine = function(clear_stack, scene_t, ...)
    local varargs = { ... }
    return function(self)
        local next = {
            scene = self.scene_t_to_scene[scene_t],
            args = varargs
        }

        if next.scene == nil then
            log_error("In state_push_scene: no scene allocated for scene type `", scene_t, "`")
            return
        end

        if clear_stack then
            self.scene_stack = { next }
        else
            table_push(self.scene_stack, next)
        end

        _call_scene_f("_create_fade_routine", next.scene, _reformat_fid, aabb_new(0, 0, graphics_get_size()))
        _call_scene_f("_create_fade_routine", next.scene, _enter_fid, table_unpack(next.args))
        _reformat_control_indicator(self, next.scene)

        input_set_is_active(true)
    end
end

state_push_scene = function(self, scene_t, ...)
    log_typecheck(self, State_t, scene_t, String_t)

    _flush_fade(self)

    input_set_is_active(false)
    self.fade_motion_routine = _create_fade_routine(false, scene_t, ...)
    lag_set_target_value(self.fade_motion, _lag_full)
    self.fade_motion_active = true
end

state_set_scene = function(self, scene_t, ...)
    log_typecheck(self, State_t, scene_t, String_t)

    _flush_fade(self)

    input_set_is_active(false)
    self.fade_motion_routine = _create_fade_routine(true, scene_t, ...)
    lag_set_target_value(self.fade_motion, _lag_full)
    self.fade_motion_active = true
end

state_pop_scene = function(self)
    log_typecheck(self, State_t)
    _flush_fade(self)

    input_set_is_active(false)
    self.fade_motion_routine = function(self)
        local n = table_sizeof(self.scene_stack)
        table_remove(self.scene_stack, n)

        local current = self.scene_stack[table_sizeof(self.scene_stack)]
        if current ~= nil then
            _call_scene_f("state_pop_scene", current.scene, _exit_fid)
        end

        local next = self.scene_stack[n - 1]
        if next ~= nil then
            _call_scene_f("state_pop_scene", next.scene, _enter_fid, table_unpack(next.args))
        end

        _reformat_control_indicator(self, next.scene)
        input_set_is_active(true)
    end

    lag_set_target_value(self.fade_motion, _lag_full)
    self.fade_motion_active = true
end

state_update = function(self, delta)
    log_typecheck(self, State_t)
    local fade = self.fade_motion

    local current = _get_current(self)
    if current ~= nil then
        _call_scene_f("state_update", current.scene, _update_fid, delta)
    end

    lag_update(fade, delta)
    local fade_value = lag_get_value(fade)

    local control_indicator = _call_scene_f("state_update", current.scene, _get_control_indicator_fid)
    if control_indicator ~= nil then
        control_indicator_update(control_indicator, delta)
    end

    if self.fade_motion_active then
        if math_greater_than_or_equal(fade_value, _lag_full, 0.001) then
            log_call(self.fade_motion_routine, self)
            lag_set_value(self.fade_motion, _lag_full)

            self.fade_motion_active = false
            self.fade_motion_routine = nil
            lag_set_target_value(self.fade_motion, 0)
        end
    end
end

state_get_current_scene = function(self)
    log_typecheck(self, State_t)
    local current = _get_current(self)
    if current == nil then
        return nil
    end

    return current.scene
end

state_get_scene_is_active = function(self, scene)
    log_typecheck(self, State_t, scene, Table_t)
    local current = _get_current(self)
    return current ~= nil and current.scene == scene
end

state_draw = function(self)
    log_typecheck(self, State_t)
    upscaler_bind(self.upscaler)
    graphics_clear(1, 0, 1, 1)

    local current = _get_current(self)
    if current ~= nil then
        _call_scene_f("state_draw", current.scene, _draw_fid)
    end

    graphics_set_color(1, 1, 1, 0.75)
    graphics_set_line_state(1)
    local w, h = graphics_get_size()
    graphics_draw_line(
        0.5 * w, 0,
        0.5 * w, h
    )

    graphics_draw_line(
        0, 0.5 * h,
        w, 0.5 * h
    )

    upscaler_unbind(self.upscaler)
    upscaler_draw(self.upscaler)

    graphics_push_state()
    graphics_reset_state()
    graphics_set_scale(1 / graphics_get_dpi_scale())
    graphics_set_color(0, 0, 0, lag_get_value(self.fade_motion))
    graphics_draw_rectangle(0, 0, graphics_get_window_size())
    graphics_pop_state()

    if current ~= nil then
        control_indicator_draw(_call_scene_f("state_draw", current.scene, _get_control_indicator_fid))
    end
end

state_resize = function(self, w, h)
    log_typecheck(self, State_t, w, Number_t, h, Number_t)

    local indicator_bounds = aabb_new(0, 0, 0, 0)
    local current = _get_current(self)
    if current ~= nil then
        _call_scene_f("state_resize", current.scene, _reformat_fid, aabb_new(0, 0, graphics_get_size()))
        local indicators = { _call_scene_f("state_resize", current.scene, _get_control_indicator_fid) }

        local min_x, min_y = math_positive_inf, math_positive_inf
        local max_x, max_y = math_negative_inf, math_negative_inf

        for indicator in iter_values(indicators) do
            local other = control_indicator_get_bounds(indicator)
            min_x = math.min(min_x, other.x)
            min_y = math.min(min_y, other.y)
            max_x = math.max(max_x, other.x + other.width)
            max_y = math.max(max_y, other.y + other.height)
        end

        if min_x ~= math_positive_inf then
            indicator_bounds = aabb_init(indicator_bounds, min_x, min_y, max_x - min_x, max_y - min_y)
        end
    end

    self.control_indicator_bounds = indicator_bounds
    _reformat_control_indicator(self, current ~= nil and current.scene or nil, w, h)
end

state_get_stage_list = function(self)
    log_typecheck(self, State_t)
    return self.stage_list
end

state_get_level_ids = function(self)
    log_typecheck(self, State_t)
    return stage_list_get_ids(self.stage_list)
end

state_get_stage = function(self, id)
    log_typecheck(self, State_t)
    local result = self.stage_entries[id]
    if result == nil then
        log_error("In stage_get_stage: no stage with id `", id, "`")
        return nil
    end
    return result.stage
end

state_get_n_stages = function(self)
    log_typecheck(self, State_t)
    return table_count(self.stage_entries)
end

state_get_n_stages_completed = function(self)
    log_typecheck(self, State_t)
    local n = 0
    for _, entry in pairs(self.stage_entries) do
        if entry.is_completed then
            n = n + 1
        end
    end
    return n
end

state_set_stage_is_completed = function(self, id, b)
    log_typecheck(self, State_t, id, String_t)
    local entry = self.stage_entries[id]
    if entry == nil then
        log_error("In state_set_stage_is_completed: no stage with id `", id, "`")
        return false
    else
        entry.is_completed = b
    end
end

state_get_stage_is_completed = function(self, id)
    log_typecheck(self, State_t, id, String_t)
    local entry = self.stage_entries[id]
    if entry == nil then
        log_error("In state_set_stage_is_completed: no stage with id `", id, "`")
        return false
    else
        return not entry.is_completed
    end
end

state_set_player_skin = function(self, texture)
    log_typecheck(self, State_t, texture, Texture_t)
    self.player_skin = texture
end

state_get_player_skin = function(self)
    log_typecheck(self, State_t)
    return self.player_skin
end

state_allocate_scenes = function(self)
    log_typecheck(self, State_t)

    self.scene_stack = {}
    for t, scene in pairs(self.scene_t_to_scene) do
        _call_scene_f("state_allocate_scenes", scene, _exit_fid)
    end

    self.scene_t_to_scene = {
        [StageScene_t] = stage_scene_new(),
        [MainMenuScene_t] = main_menu_scene_new(),
        [SkinSelectScene_t] = skin_select_scene_new(),
        [StageSelectScene_t] = stage_select_scene_new(self.stage_list),
        [SettingsScene_t] = settings_scene_new()
    }

    state_set_player_skin(self, skin_select_scene_get_selected_skin(self.scene_t_to_scene[SkinSelectScene_t]))
end

state_get_sound_effect_volume = function(self)
    log_typecheck(self, State_t)
    return self.sound_effect_volume
end

state_set_sound_effect_volume = function(self, volume)
    log_typecheck(self, State_t, volume, Number_t)
    self.sound_effect_volume = math_clamp(volume, 0, 1)
end

state_get_music_volume = function(self)
    log_typecheck(self, State_t)
    return self.music_volume
end

state_set_music_volume = function(self, volume)
    log_typecheck(self, State_t, volume, Number_t)
    self.music_volume = math_clamp(volume, 0, 1)
end

state_get_shaders_enabled = function(self)
    log_typecheck(self, State_t)
    return self.shaders_enabled
end

state_set_shaders_enabled = function(self, b)
    log_typecheck(self, State_t, b, Boolean_t)
    self.shaders_enabled = b
end
