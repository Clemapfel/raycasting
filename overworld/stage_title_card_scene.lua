require "common.translation"
require "common.game_state"
require "overworld.stage_config"
require "common.camera"
require "common.control_indicator"
require "physics.physics"

rt.settings.overworld.stage_title_card_scene = {
    font_path = "assets/fonts/DejaVuSans/DejaVuSansCondensed-Bold.ttf",
    stage_id = "stage_title_cards", -- tile map used for text geometry
    layer_i = 2, -- layer i in that tile map

    control_indicator_reveal_duration = 0.25,
    control_indicator_reveal_delay = 3.5, -- seconds
}

--- @class ow.StageTitleCardScene
ow.StageTitleCardScene = meta.class("StageTitleCardScene", rt.Scene)

local _canvas = nil
local _post_fx_shader = nil

--- @brief
function ow.StageTitleCardScene:instantiate(state)
    if _post_fx_shader == nil then
        _post_fx_shader = rt.Shader("overworld/stage_title_card_scene_post_fx.glsl")
    end

    self._state = state
    self._player = state:get_player()
    self._camera = rt.Camera()
    self._camera_position_x, self._camera_position_y = 0, 0
    self._elapsed = 0
    self._initialized = false

    local translation = rt.Translation.stage_title_card_scene
    local prefix = "<o>"
    local postfix = "</o>"
    self._control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.ALL_DIRECTIONS, translation.control_indicator_move,
        rt.ControlIndicatorButton.JUMP, translation.control_indicator_jump
    )

    self._control_indicator_reveal_animation = rt.TimedAnimation(
        rt.settings.overworld.stage_title_card_scene.control_indicator_reveal_duration,
        0, 1, rt.InterpolationFunctions.LINEAR
    )
    self._control_indicator_reveal_active = false
    self._control_indicator_delay_elapsed = 0

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.JUMP then
            self._player:set_is_bubble(false)
        end
    end)

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "^" then
            self:_initialize()
        elseif which == "k" then

        end
    end)
end

local _config

--- @brief
function ow.StageTitleCardScene:_initialize()
    -- use tiled map to get layer geometry
    local settings = rt.settings.overworld.stage_title_card_scene
    --if _config == nil then
        _config = ow.StageConfig(settings.stage_id)
    --end

    self._objects = {}
    for object in values(_config:get_layer_object_wrappers(settings.layer_i)) do
        if object.class == self._stage_id then
            table.insert(self._objects, object)
        end
    end

    self._world = b2.World()
    self._bodies = {}
    local tris = {}
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for object in values(self._objects) do
        local body = object:create_physics_body(self._world, b2.BodyType.STATIC)
        body:add_tag("stencil")
        local aabb = body:compute_aabb()
        min_x = math.min(min_x, aabb.x)
        min_y = math.min(min_y, aabb.y)
        max_x = math.max(max_x, aabb.x + aabb.width)
        max_y = math.max(max_y, aabb.y + aabb.height)
        table.insert(self._bodies, body)

        local object_tris = object:triangulate()
        for tri in values(object_tris) do
            table.insert(tris, tri)
        end
    end

    local mesh_data = {}
    local _push_vertex = function(x, y)
        meta.assert(x, "Number", y, "Number")
        table.insert(mesh_data, {
            x, y, 0, 0, 1, 1, 1, 1
        })
    end

    for tri in values(tris) do
        _push_vertex(tri[1], tri[2])
        _push_vertex(tri[3], tri[4])
        _push_vertex(tri[5], tri[6])
    end

    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._tris = tris

    self._camera_bounds = rt.AABB(min_x, min_y, max_x - min_x, max_y - min_y)
    self._camera_anchor_x, self._camera_anchor_y = math.mix2(min_x, min_y, max_x, max_y, 0.5)
    self._camera:set_position(self._camera_anchor_x, self._camera_anchor_y)

    local screen_w, screen_h = love.graphics.getDimensions()
    local outer_margin = 10 * rt.settings.margin_unit
    self._camera:set_scale(math.min(
        screen_w / (self._camera_bounds.width + 2 * outer_margin),
        screen_h / (self._camera_bounds.height + 2 * outer_margin)
    )) -- scale such that camera_bounds fits into

    -- screen bounds
    do
        local x, y, w, h = self._camera:get_world_bounds()
        local padding = 0
        local top_left_x, top_left_y = x - padding, y - padding
        local top_right_x, top_right_y = x + w + 2 * padding, y - padding
        local bottom_right_x, bottom_right_y = x + w + 2 * padding, y + h + 2 * padding
        local bottom_left_x, bottom_left_y = x - padding, y + h + 2 * padding

        local top_segment_body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0,
            b2.Segment(top_left_x, top_left_y, top_right_x, top_right_y)
        )

        local offset = 4 * rt.settings.player.radius

        local side_segment_body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0,
            b2.Segment(top_right_x, top_right_y, bottom_right_x, bottom_right_y + offset),
            b2.Segment(top_left_x, top_left_y, bottom_left_x, bottom_left_y + offset)
        )

        local bottom_segment_body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0,
            b2.Segment(bottom_left_x, bottom_left_y + offset, bottom_right_x, bottom_right_y + offset)
        )

        self._top_segment_body = top_segment_body
        self._bottom_segment_body = bottom_segment_body
        table.insert(self._bodies, side_segment_body)

        -- top waits for player to pass, then locks in
        self._top_segment_body:set_is_sensor(true) -- enabled once player is on screen in update
        self._top_segment_body_threshold_y = top_left_y + offset

        -- bottom is trigger to exit scene
        self._bottom_segment_body:signal_connect("collision_end", function(_)
            self:_move_to_stage()
        end)
    end

    self._player:move_to_world(self._world)
    self._player:set_is_bubble(true)
    self._player:set_opacity(1)
    self._player:enable()

    self._player:teleport_to(
        self._camera_anchor_x,
        self._camera_anchor_y - 0.5 * select(4, self._camera:get_world_bounds()) - 2 * self._player:get_radius()
    )
    self._player:set_velocity(0, 100)
    self._initialized = false
end

--- @brief
function ow.StageTitleCardScene:realize()
    if self:already_realized() then return end

    self._control_indicator:set_has_frame(false)
    self._control_indicator:set_opacity(0)
    self._control_indicator:realize()
end

--- @brief
function ow.StageTitleCardScene:size_allocate(x, y, width, height)
    if _canvas == nil or _canvas:get_width() ~= width or _canvas:get_height() ~= height then
        _canvas = rt.RenderTexture(width, height, 4)
        _canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    self._bounds:reformat(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_m = 2 * m

    local control_w, control_h = self._control_indicator:measure()
    self._control_indicator:reformat(x + width - control_w, y + height - control_h, control_w, control_h)

    if self._is_initialized then
        self:_initialize()
    end
end

--- @brief
function ow.StageTitleCardScene:update(delta)
    self._elapsed = self._elapsed + delta
    self._fraction = (math.sin(self._elapsed) + 1) / 2

    if self._control_indicator_delay_elapsed > rt.settings.overworld.stage_title_card_scene.control_indicator_reveal_delay then
        self._control_indicator_reveal_active = true
    end

    if self._control_indicator_reveal_active then
        self._control_indicator_reveal_animation:update(delta)
        self._control_indicator:set_opacity(self._control_indicator_reveal_animation:get_value())
    else
        self._control_indicator_delay_elapsed = self._control_indicator_delay_elapsed + delta
    end

    self._world:update(delta)
    self._player:update(delta)
    self._camera:update(delta)

    local px, py = self._player:get_position()
    if py > self._top_segment_body_threshold_y then
        self._top_segment_body:set_is_sensor(false)
    end
end

--- @brief
function ow.StageTitleCardScene:draw()
    local w, h = _canvas:get_size()

    love.graphics.push()
    love.graphics.origin()
    rt.Palette.TRUE_MAGENTA:bind()
    love.graphics.rectangle("fill", self._bounds:unpack())

    _canvas:bind()
    love.graphics.clear(0, 0, 0, 0)
    local offset_x, offset_y = self._camera_anchor_x + 0.5 * w, self._camera_anchor_x + 0.5 * h
    self._camera:bind()
    self._mesh:draw()
    _canvas:unbind()

    rt.Palette.BLACK:bind()
    love.graphics.draw(self._mesh:get_native())
    self._camera:unbind()

    _post_fx_shader:bind()
    _post_fx_shader:send("elapsed", self._elapsed)
    _post_fx_shader:send("camera_scale", self._camera:get_final_scale())
    love.graphics.origin()
    love.graphics.setBlendMode("alpha", "premultiplied")
    _canvas:draw()
    love.graphics.setBlendMode("alpha")
    _post_fx_shader:unbind()

    self._camera:bind()
    self._player:draw()
    self._camera:unbind()

    self._control_indicator:draw()

    love.graphics.pop()
end

--- @brief
function ow.StageTitleCardScene:enter(stage_id)
    meta.assert(stage_id, "String")
    self._stage_id = stage_id
    self._stage_index = rt.GameState:get_stage_index(stage_id)
    self._input:activate()
    rt.SceneManager:set_use_fixed_timestep(true)
    self:_initialize()

    self._control_indicator:set_opacity(0)
    self._control_indicator_reveal_animation:set_elapsed(0)
    self._control_indicator_reveal_active = false
    self._control_indicator_delay_elapsed = 0
end

--- @brief
function ow.StageTitleCardScene:exit()
    self._input:deactivate()
end

--- @brief
function ow.StageTitleCardScene:_move_to_stage()
    require "overworld.overworld_scene"
    rt.SceneManager:push(ow.OverworldScene, self._stage_id)
end