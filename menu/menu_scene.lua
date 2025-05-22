require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.translation"
require "common.control_indicator"
require "common.timed_animation"

rt.settings.menu_scene = {
    player_max_falling_velocity = 1500,
    player_falling_x_damping = 0.98,
    title_screen_player_velocity = 200, -- when reflecting
    falling_fraction_threshold = 2000, -- how long it takes to transition to level select
    title_font_path = "assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf",
}

--- @class mn.MenuScene
mn.MenuScene = meta.class("MenuScene", rt.Scene)

mn.MenuSceneState = meta.enum("MenuSceneState", {
    TITLE_SCREEN = "TITLE_SCREEN",
    FALLING = "FALLING",
    LEVEL_SELECT = "LEVEL_SELECT",
    CREDITS = "CREDITS"
})

local _title_shader_sdf, _title_shader_no_sdf, _background_shader = nil, nil, nil

-- @brief
function mn.MenuScene:instantiate(state)
    if _background_shader == nil then
        _background_shader = rt.Shader("menu/title_screen_scene_background.glsl")
    end

    if _title_shader_no_sdf == nil then
        _title_shader_no_sdf = rt.Shader("menu/title_screen_scene_label.glsl", { MODE = 0 })
    end

    if _title_shader_sdf == nil then
        _title_shader_sdf = rt.Shader("menu/title_screen_scene_label.glsl", { MODE = 1 })
    end

    self._world = b2.World()
    self._world:set_use_fixed_timestep(false)

    self._player = state:get_player()
    self._player_velocity_x, self._player_velocity_y = -1, -1

    self._camera = rt.Camera()

    self._shader_camera_offset = { 0, 0 }
    self._shader_elapsed = 0
    self._shader_fraction = 0

    do -- title screen
        local translation = rt.Translation.menu_scene.title_screen
        local title_screen = {}
        self._title_screen = title_screen

        title_screen.control_indicator = rt.ControlIndicator({
                [rt.ControlIndicatorButton.JUMP] = translation.control_indicator_select,
                [rt.ControlIndicatorButton.UP_DOWN] = translation.control_indicator_move
            })
        title_screen.control_indicator:set_use_frame(false)

        local font, font_mono = rt.settings.font.default_large, rt.settings.font.default_mono_large
        title_screen.menu_items = {}
        title_screen.n_menu_items = 0
        title_screen.selected_item_i = 1

        for text in range(
            translation.level_select,
            translation.settings,
            translation.credits,
            translation.quit
        ) do
            local item = {
                unselected_label = rt.Label("<o>" .. text .. "</o>", font, rt.FontSize.LARGE),
                selected_label = rt.Label("<o><b><color=SELECTION>" .. text .. "</color></b></o>", font, rt.FontSize.LARGE),
            }

            table.insert(title_screen.menu_items, item)
            title_screen.n_menu_items =  title_screen.n_menu_items + 1
        end

        -- menu item: level select
        local level_select_item = title_screen.menu_items[1]
        level_select_item.activate = function()
            self:_set_state(mn.MenuSceneState.FALLING)
        end

        -- menu item: settings
        local settings_item = title_screen.menu_items[2]
        settings_item.activate = function()
            rt.error("TODO")
            rt.SceneManager:set_scene(mn.SettingsScene)
        end

        -- menu item: credits
        local credits_item = title_screen.menu_items[3]
        credits_item.activate = function()
            rt.error("TODO: credits")
            self:_set_state(mn.MenuSceneState.CREDITS)
        end

        -- menu item: quit
        local quit_item = title_screen.menu_items[4]
        quit_item.activate = function()
            exit(0)
        end

        title_screen.input = rt.InputSubscriber()
        title_screen.input:signal_connect("pressed", function(_, which)
            if which == rt.InputButton.JUMP then
                local item = title_screen.menu_items[title_screen.selected_item_i]
                item.activate()
            elseif which == rt.InputButton.UP then
                if title_screen.selected_item_i > 1 then
                    title_screen.selected_item_i = title_screen.selected_item_i - 1
                end
            elseif which == rt.InputButton.DOWN then
                if title_screen.selected_item_i < title_screen.n_menu_items then
                    title_screen.selected_item_i = title_screen.selected_item_i + 1
                end
            end
        end)

        title_screen.title_label_no_sdf = nil
        title_screen.title_label_sdf = nil
        title_screen.title_x, title_screen.title_y = 0, 0
        title_screen.boundaries = {}
    end
end

--- @brief
function mn.MenuScene:realize()
    self._title_screen.control_indicator:realize()
    for item in values(self._title_screen.menu_items) do
        item.unselected_label:realize()
        item.selected_label:realize()
    end
end

--- @brief
function mn.MenuScene:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 3 * m

    do -- title screen
        local title_screen = self._title_screen
        local font_size = rt.FontSize.GIGANTIC
        local title = rt.Translation.menu_scene.title_screen.title
        local font = rt.Font(rt.settings.menu_scene.title_font_path)
        title_screen.title_label_no_sdf = love.graphics.newTextBatch(font:get_native(font_size, rt.FontStyle.REGULAR, false), title)
        title_screen.title_label_sdf = love.graphics.newTextBatch(font:get_native(font_size, rt.FontStyle.REGULAR, true), title)

        local font_native = font:get_native(font_size)
        local title_w, title_h = font_native:getWidth(title), font_native:getHeight()

        title_screen.title_x = math.floor(0 - 0.5 * title_w)
        title_screen.title_y = math.floor(0 - title_h - outer_margin)

        local boundaries = title_screen.boundaries
        for boundary in values(boundaries) do
            boundary:destroy()
        end

        do -- physics walls
            local scale = self._camera:get_scale_delta()
            local w, h = width / scale, height / scale
            local cx, cw = 0 - 0.5 * w, 0 - 0.5 * h
            title_screen.boundaries = {
                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx, cw, cx + w, cw
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx + w, cw, cx + w, cw + h
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx + w, cw + h, cx, cw + h
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx, cw + h, cx, cw
                )),
            }

            -- reflect player along normal
            for body in values(title_screen.boundaries) do
                body:set_collides_with(rt.settings.player.bounce_collision_group)
                body:set_collision_group(rt.settings.player.bounce_collision_group)
                body:set_use_continuous_collision(true)
                body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y)
                    local current_vx, current_vy = self._player_velocity_x, self._player_velocity_y
                    local dot_product = current_vx * normal_x + current_vy * normal_y
                    self._player_velocity_x = current_vx - 2 * dot_product * normal_x
                    self._player_velocity_y = current_vy - 2 * dot_product * normal_y
                end)
            end
        end

        -- menu items
        local current_y = 2 * m
        local menu_center_x = 0
        for item in values(title_screen.menu_items) do
            local selected_w, selected_h = item.selected_label:measure()
            local unselected_w, unselected_h = item.unselected_label:measure()

            item.selected_label:reformat(menu_center_x - 0.5 * selected_w, current_y, math.huge)
            item.unselected_label:reformat(menu_center_x - 0.5 * unselected_w, current_y, math.huge)
            current_y = current_y + math.max(selected_h, unselected_h)
        end

        -- control indicator
        local control_w, control_h = title_screen.control_indicator:measure()
        title_screen.control_indicator:reformat(
            0 - 0.5 * width + width - m - control_w,
            0 - 0.5 * height + height - m - control_h,
            control_w, control_h
        )
    end
end
--- @brief
function mn.MenuScene:enter()
    if self._player:get_world() ~= self._world then
        self._player:move_to_world(self._world)
    end

    self._player:disable()

    if self._state == nil then
        self:_set_state(mn.MenuSceneState.TITLE_SCREEN)
    end
end

--- @brief
function mn.MenuScene:exit()
    self._title_screen.input:deactivate()
    self._player:enable()
end

--- @brief
function mn.MenuScene:_set_state(next)
    if next == mn.MenuSceneState.TITLE_SCREEN then
        self._title_screen.input:activate()
        self._player:teleport_to(0, 0)
        self._player:set_velocity(0, 0)
        self._player:set_gravity(0)
        self._player:set_is_bubble(true)
        self._player:set_flow(0)

        for boundary in values(self._title_screen.boundaries) do
            boundary:set_is_sensor(false)
        end
    elseif next == mn.MenuSceneState.FALLING then
        self._title_screen.input:activate()
        self._player:set_gravity(1)
        self._player:set_is_bubble(false)

        for boundary in values(self._title_screen.boundaries) do
            boundary:set_is_sensor(true)
        end
    end

    self._state = next
end

--- @brief
function mn.MenuScene:update(delta)
    self._world:update(delta)
    self._camera:update(delta)
    self._player:update(delta)

    self._shader_elapsed = self._shader_elapsed + delta
    self._shader_camera_offset = { self._camera:get_offset() }
    self._shader_camera_scale = self._camera:get_scale()
    self._shader_fraction = 0

    if self._state == mn.MenuSceneState.TITLE_SCREEN then
        -- stay centered, reflect player around walls
        self._camera:set_position(0, 0)
        local magnitude = rt.settings.menu_scene.title_screen_player_velocity
        self._player:set_velocity(
            self._player_velocity_x * magnitude,
            self._player_velocity_y * magnitude
        )
    elseif self._state == mn.MenuSceneState.FALLING then
        local px, py = self._player:get_predicted_position()
        self._shader_fraction = math.clamp(py / rt.settings.menu_scene.falling_fraction_threshold, 0, 1)
        self._player:set_flow(self._shader_fraction)

        -- clamp velocity
        local vx, vy = self._player:get_velocity()
        local max_velocity = rt.settings.menu_scene.player_max_falling_velocity
        vx = math.min(vx * rt.settings.menu_scene.player_falling_x_damping, max_velocity)
        vy = math.min(vy, max_velocity)
        self._player:set_velocity(vx, vy)

        -- transition player to left side of screen
        local x_offset = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(self._shader_fraction) * 1 / 3 * love.graphics.getWidth()
        self._camera:move_to(px + x_offset, py)
    end

end

local _black = { rt.Palette.BLACK:unpack() }

--- @brief
function mn.MenuScene:draw()
    -- draw background
    love.graphics.push()
    love.graphics.origin()
    _background_shader:bind()
    _background_shader:send("black", _black)
    _background_shader:send("elapsed", self._shader_elapsed)
    _background_shader:send("camera_offset", self._shader_camera_offset)
    _background_shader:send("camera_scale", self._shader_camera_scale)
    _background_shader:send("fraction", self._shader_fraction)
    _background_shader:send("hue", self._player:get_hue())

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    _background_shader:unbind()
    love.graphics.pop()

    -- title screen
    if self._state == mn.MenuSceneState.TITLE_SCREEN or self._state == mn.MenuSceneState.FALLING then
        local title_screen = self._title_screen

        -- draw title
        love.graphics.push()
        love.graphics.translate(self._camera:get_offset())
        _title_shader_sdf:bind()
        _title_shader_sdf:send("elapsed", self._shader_elapsed)
        _title_shader_sdf:send("black", _black)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(title_screen.title_label_sdf, title_screen.title_x, title_screen.title_y)
        _title_shader_sdf:unbind()

        _title_shader_no_sdf:bind()
        _title_shader_no_sdf:send("elapsed", self._shader_elapsed)
        _title_shader_no_sdf:send("hue", self._player:get_hue())
        _title_shader_no_sdf:send("black", _black)
        _title_shader_no_sdf:send("camera_offset", self._shader_camera_offset)
        _title_shader_no_sdf:send("camera_scale", self._shader_camera_scale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(title_screen.title_label_no_sdf, title_screen.title_x, title_screen.title_y)
        _title_shader_no_sdf:unbind()

        -- draw menu
        for i, item in ipairs(title_screen.menu_items) do
            if i == title_screen.selected_item_i then
                item.selected_label:draw()
            else
                item.unselected_label:draw()
            end
        end

        title_screen.control_indicator:draw()
        love.graphics.pop()
    end

    self._camera:bind()
    self._player:draw()
    self._camera:unbind()
end

--- @brief
function mn.MenuScene:get_camera()
    return self._camera
end