State_t = "State"

STATE = nil -- global singleton

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
        [_update_fid] = skin_select_scene_update,
        [_draw_fid] = skin_select_scene_draw,
        [_reformat_fid] = skin_select_scene_reformat,
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
    if f ~= nil then log_call(f, scene, ...) end
end

local _lag_full = 1.0
local _lag_empty = 0.0

state_init = function()
    local self = STATE

    self.upscaler = upscaler_resize(upscaler_new(), graphics_get_window_size())

    self.fade_motion = lag_new(_lag_full, 4)
    self.fade_motion_routine = nil -- Function
    self.fade_motion_active = false

    local w, h = graphics_get_size()
    local stage_list = stage_list_new()
    if love.getVersion() >= 12 then
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

    -- allocate stages
    stage_list_init(stage_list, "jam/assets/stages_exported.lua")
    self.stage_list = stage_list
    self.stage_entries = {}
    for _, stage_id in ipairs(stage_list_get_ids(stage_list)) do
        self.stage_entries[stage_id] = {
            stage = stage_new(stage_list, stage_id), -- persistent instance
            is_completed = false
        }
    end

    -- skin
    self.active_skin = nil -- Texture_t

    -- preallocate scenes
    self.scene_t_to_scene = {
        [StageScene_t] = stage_scene_new(),
        [MainMenuScene_t] = main_menu_scene_new(),
        [SkinSelectScene_t] = skin_select_scene_new(),
        [StageSelectScene_t] = stage_select_scene_new(self.stage_list)
    }

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

        _call_scene_f("state_resize", next.scene, _reformat_fid, aabb_new(0, 0, graphics_get_size()))
        _call_scene_f("state_push_scene", next.scene, _enter_fid, table_unpack(next.args))

        input_set_is_active(true)
    end
end


state_push_scene = function(scene_t, ...)
    log_typecheck(scene_t, String_t)
    local self = STATE

    if self.fade_motion_routine ~= nil then
        log_call(self.fade_motion_routine, STATE)
        self.fade_motion_routine = nil
        lag_set_value(self.fade_motion, _lag_empty)
        self.fade_motion_active = false
    end

    input_set_is_active(false)
    self.fade_motion_routine = _create_fade_routine(false, scene_t, ...)
    lag_set_target_value(self.fade_motion, _lag_full)
    self.fade_motion_active = true
end

state_set_scene = function(scene_t, ...)
    log_typecheck(scene_t, String_t)
    local self = STATE

    if self.fade_motion_routine ~= nil then
        log_call(self.fade_motion_routine, STATE)
        self.fade_motion_routine = nil
        lag_set_value(self.fade_motion, _lag_empty)
        self.fade_motion_active = false
    end

    input_set_is_active(false)
    self.fade_motion_routine = _create_fade_routine(true, scene_t, ...)
    lag_set_target_value(self.fade_motion, _lag_full)
    self.fade_motion_active = true
end

state_pop_scene = function(_)
    log_typecheck(_, Nil_t)
    local self = STATE

    if self.fade_motion_routine ~= nil then
        log_call(self.fade_motion_routine, STATE)
        self.fade_motion_routine = nil
        lag_set_value(self.fade_motion, _lag_empty)
        self.fade_motion_active = false
    end

    input_set_is_active(false)
    self.fade_motion_routine = function(self)
        local n = table_sizeof(self.scene_stack)
        table_remove(self.scene_stack, n)

        local current = self.scene_stack[table_sizeof(self.scene_stack)]
        if current ~= nil then
            _call_scene_f("state_push_scene", current.scene, _exit_fid)
        end

        local next = self.scene_stack[n - 1]
        if next ~= nil then
            _call_scene_f("state_pop_scene", next.scene, _enter_fid, table_unpack(next.args))
        end
        input_set_is_active(true)
    end

    lag_set_target_value(self.fade_motion, _lag_full)
    self.fade_motion_active = true
end

state_update = function(delta)
    local self = STATE
    local fade = self.fade_motion

    local current = self.scene_stack[table_sizeof(self.scene_stack)]
    if current ~= nil then
        _call_scene_f("state_update", current.scene, _update_fid, delta)
    end

    lag_update(fade, delta)
    local fade_value = lag_get_value(fade)

    -- once fully opaque, switch scenes
    if self.fade_motion_active then
        if math.greater_than_or_equal(fade_value, _lag_full, 0.001) then
            log_call(self.fade_motion_routine, STATE)
            lag_set_value(self.fade_motion, _lag_full)

            self.fade_motion_active = false
            self.fade_motion_routine = nil
            lag_set_target_value(self.fade_motion, 0)
        end
    end
end

state_get_current_scene = function(_)
    log_typecheck(_, Nil_t)

    local self = STATE
    local current = self.scene_stack[table_sizeof(self.scene_stack)]
    if current == nil then
        return nil
    end

    return current.scene
end

state_get_scene_is_active = function(scene)
    log_typecheck(scene, Table_t)
    local self = STATE
    local current = self.scene_stack[table_sizeof(self.scene_stack)]
    return current ~= nil and current.scene == scene
end

state_draw = function()
    local self = STATE

    upscaler_bind(self.upscaler)
    graphics_clear(1, 0, 1, 1)

    local current = self.scene_stack[table_sizeof(self.scene_stack)]
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
end

state_resize = function(w, h)
    local self = STATE

    log_typecheck(w, Number_t, h, Number_t)
    upscaler_resize(self.upscaler, w, h)

    local current = self.scene_stack[table_sizeof(self.scene_stack)]
    if current ~= nil then
        _call_scene_f("state_resize", current.scene, _reformat_fid, aabb_new(0, 0, graphics_get_size()))
    end
end

state_get_stage_list = function()
    return STATE.stage_list
end

state_get_level_ids = function()
    return stage_list_get_ids(STATE.stage_list)
end

state_get_stage = function(id)
    local result = STATE.stage_entries[id]
    if result == nil then
        log_error("In stage_get_stage: no stage with id `", id, "`")
        return nil
    end
    return result.stage
end

state_get_n_stages = function()
    return table_count(STATE.stage_entries)
end

state_get_n_stages_completed = function()
    local n = 0
    for _, entry in pairs(STATE.stage_entries) do
        if entry.is_completed then
            n = n + 1
        end
    end
    return n
end

state_set_stage_is_completed = function(id, b)
    log_typecheck(id, String_t)
    local entry = STATE.stage_entries[id]
    if entry == nil then
        log_error("In state_set_stage_is_completed: no stage with id `", id, "`")
        return false
    else
        entry.is_completed = b
    end
end

state_get_stage_is_completed = function(id)
    log_typecheck(id, String_t)
    local entry = STATE.stage_entries[id]
    if entry == nil then
        log_error("In state_set_stage_is_completed: no stage with id `", id, "`")
        return false
    else
        return not entry.is_completed
    end
end

state_set_active_skin = function(texture)
    log_typecheck(texture, Texture_t)
    STATE.active_skin = texture
end

state_get_active_skin = function(texture)
    log_typecheck(texture, Texture_t)
    return STATE.active_skin
end

-- instance singleton
STATE = object_new(State_t, {})
state_init(STATE)
