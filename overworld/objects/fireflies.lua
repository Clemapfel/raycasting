require "common.path1d"

rt.settings.overworld.fireflies = {
    radius = 30, -- px
    texture_radius = 60, -- px
    path_n_nodes = 256,

    max_glow_offset = 0.75,
    glow_cycle_duration = 2,

    max_hover_offset = 20, -- px
    hover_cycle_duration = 4
}

--- @class ow.Fireflies
ow.Fireflies = meta.class("Fireflies")

local _texture -- rt.RenderTexture
local _glow_noise_path -- Path1D
local _stationary_offset_path -- Path2D

local _MODE_STATIONARY = 1
local _MODE_FOLLOW_PLAYER = 2

--- @brief
function ow.Fireflies:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.POINT, "In ow.Fireflies: object `", object:get_id(), "` is not a point")

    self._stage = stage
    self._scene = scene
    self._world = stage:get_physics_world()

    self._body = b2.Body(
        self._world,
        b2.BodyType.DYNAMIC,
        object.x, object.y,
        b2.Circle(0, 0, rt.settings.player.radius * 0.5)
    )
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)

    self._mode = _MODE_STATIONARY
    self._body:signal_connect("collision_start")
    self._follow_motion = rt.SmoothedMotion2D(object.x, object.y)

    -- individual flies
    local n_flies = rt.random.number(1, 4)
    local glow_cycle_duration = rt.settings.overworld.fireflies.glow_cycle_duration
    local hover_cycle_duration = rt.settings.overworld.fireflies.hover_cycle_duration
    local radius = rt.settings.overworld.fireflies.radius

    self._fly_entries = {}
    for i = 1, n_flies do
        table.insert(self._fly_entries, {
            glow_offset_t = rt.random.number(0, 1),
            glow_cycle_duration = rt.random.number(0.75 * glow_cycle_duration, 1.25 * glow_cycle_duration),
            glow_elapsed = 0,

            hover_offset_t = rt.random.number(0, 1),
            hover_cycle_duration = rt.random.number(0.75 * hover_cycle_duration, 1.25 * hover_cycle_duration),
            hover_elapsed = 0,

            x_offset = rt.random.number(-2 * radius, 2 * radius),
            y_offset = rt.random.number(-2 * radius, 2 * radius),
            scale = rt.random.number(0.75, 1.25)
        })
    end

    -- init shared globals

    if _texture == nil then
        local r = rt.settings.overworld.fireflies.texture_radius
        local padding = 2
        local texture_w = 2 * (r + padding)
        _texture = rt.RenderTexture(texture_w, texture_w)

        local x, y = 0.5 * texture_w, 0.5 * texture_w

        local inner_inner_r, inner_outer_r = 0.05, 0.25
        local outer_inner_r, outer_outer_r = 0.1, 1
        local inner_color = rt.RGBA(1, 1, 1, 1)
        local outer_color = rt.RGBA(1, 1, 1, 0)

        local inner_glow = rt.MeshRing(
            x, y,
            inner_inner_r * r, inner_outer_r * r,
            true, -- fill center
            nil,  -- n_outer_vertices
            inner_color, outer_color
        )

        local outer_glow = rt.MeshRing(
            x, y,
            outer_inner_r * r, outer_outer_r * r,
            true,
            nil,
            inner_color, outer_color
        )

        _texture:bind()
        inner_glow:draw()
        outer_glow:draw()
        _texture:unbind()
    end

    local n_path_nodes = rt.settings.overworld.fireflies.path_n_nodes
    if _glow_noise_path == nil then
        local values = {}
        for i = 1, n_path_nodes do
            table.insert(values, rt.random.number(0.25, 1))
        end
        _glow_noise_path = rt.Path1D(values)
    end

    if _stationary_offset_path == nil then
        local points = {}
        local max_offset = rt.settings.overworld.fireflies.max_hover_offset
        for i = 1, n_path_nodes do
            table.insert(points, rt.random.number(-max_offset, max_offset))
            table.insert(points, rt.random.number(-max_offset, max_offset))
        end
        _stationary_offset_path = rt.Path2D(points)
    end
end

--- @brief
function ow.Fireflies:update(delta)
    if self._mode == _MODE_STATIONARY then
        if not self._stage:get_is_body_visible(self._body) then return end
        for entry in values(self._fly_entries) do

        end

    elseif self._mode == _MODE_FOLLOW_PLAYER then
        local target_x, target_y = self._scene:get_player():get_position()
        self._follow_motion:set_target_position(target_x, target_y)
        self._follow_motion:update(delta)
    end
end

--- @brief
function ow.Fireflies:draw()
    love.graphics.push()
    love.graphics.origin()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(1,1, 1, 1)
    _texture:draw()
    love.graphics.pop()
end