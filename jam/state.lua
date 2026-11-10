State_t = "State"

STATE = nil -- global singleton

local _new_fid = "new"
local _init_fid = "init"
local _make_active_fid = "make_active"
local _update_fid = "update"
local _draw_fid = "draw"
local _reformat_fid = "reformat"

local _scene_t_to_fs = {
    [LevelScene_t] = {
        [_new_fid] = level_scene_new,
        [_init_fid] = level_scene_init,
        [_make_active_fid] = level_scene_make_active,
        [_update_fid] = level_scene_update,
        [_draw_fid] = level_scene_draw,
        [_reformat_fid] = level_scene_reformat
    },

    [MainMenuScene_t] = {
        [_new_fid] = main_menu_scene_new,
        [_init_fid] = main_menu_scene_init,
        [_make_active_fid] = main_menu_scene_make_active,
        [_update_fid] = main_menu_scene_update,
        [_draw_fid] = main_menu_scene_draw,
        [_reformat_fid] = main_menu_scene_reformat
    },

    [SkinSelectScene_t] = {
        [_new_fid] = skin_select_scene_new,
        [_init_fid] = skin_select_scene_init,
        [_make_active_fid] = skin_select_scene_make_active,
        [_update_fid] = skin_select_scene_update,
        [_draw_fid] = skin_select_scene_draw,
        [_reformat_fid] = skin_select_scene_reformat
    },

    [LevelSelectScene_t] = {
        [_new_fid] = level_select_scene_new,
        [_init_fid] = level_select_scene_init,
        [_make_active_fid] = level_select_scene_make_active,
        [_update_fid] = level_select_scene_update,
        [_draw_fid] = level_select_scene_draw,
        [_reformat_fid] = level_select_scene_reformat
    },

    [SettingsScene_t] = {
        [_new_fid] = settings_scene_new,
        [_init_fid] = settings_scene_init,
        [_make_active_fid] = settings_scene_make_active,
        [_update_fid] = settings_scene_update,
        [_draw_fid] = settings_scene_draw,
        [_reformat_fid] = settings_scene_reformat
    },
}

local function _call_scene_f(scope, scene, fid, ...)
    local fs = _scene_t_to_fs[scene.type]
    if fs == nil then
        log_error("in ", scope, ": unhandled scene type `", object_typeof(scene), "`")
        return
    end

    local f = fs[fid]
    if f ~= nil then log_call(f, scene, ...) end
end

state_init = function()
    local self = STATE

    self.upscaler = upscaler_resize(upscaler_new(), graphics_get_window_size())

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
            "stages/stages_exported.lua"
        )

        love.filesystem.unmountFullPath(to_mount)
    end

    stage_list_init(stage_list, "jam/assets/stages_exported.lua")

    self.stage_list = stage_list

    self.level_entries = {}
    for _, name in ipairs(stage_list_get_names(self.stage_list)) do
        self.level_entries[name] = {
            is_completed = false
        }
    end

    -- preallocate scene
    self.scene_t_to_scene = {
        [LevelScene_t] = level_scene_new(),
        [MainMenuScene_t] = main_menu_scene_new(),
        [SkinSelectScene_t] = skin_select_scene_new()
    }

    -- current scene
    self.scene = self.scene_t_to_scene[MainMenuScene_t]
    return self
end

state_set_scene = function(scene_t, ...)
    local self = STATE
    local scene = self.scene_t_to_scene[scene_t]
    if scene == nil then
        log_error("In stage_set_scene: unhandled scene type `", scene_t, "`")
    end

    self.scene = scene

    _call_scene_f("state_set_scene", self.scene, _make_active_fid, ...)
end

state_update = function(delta)
    local self = STATE

    upscaler_update(self.upscaler, delta)

    _call_scene_f("state_update", self.scene, _update_fid, delta)
end

state_draw = function()
    local self = STATE

    upscaler_bind(self.upscaler)
    graphics_clear(1, 0, 1, 1)

    _call_scene_f("state_draw", self.scene, _draw_fid)


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
end

state_resize = function(w, h)
    local self = STATE

    log_typecheck(w, Number_t, h, Number_t)
    upscaler_resize(self.upscaler, w, h)

    _call_scene_f("state_resize", self.scene, _reformat_fid, aabb_new(0, 0, graphics_get_size()))
end

state_get_stage_list = function()
    return STATE.stage_list
end

state_get_n_levels_completed = function()
    local self = STATE
    local n = 0
    for _, entry in pairs(self.level_entries) do
        if entry.is_completed then
            n = n + 1
        end
    end
    return n
end

-- instance singleton
STATE = object_new(State_t, {})
state_init(STATE)
