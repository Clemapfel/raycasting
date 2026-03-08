require "overworld.movable_object"

rt.settings.overworld.bubble = {
    respawn_duration = 2,

    pop_light_boost_duration = 5 / 60,
    pop_light_boost_magnitude = 3.5, -- factor

    line_width = 1,
    outline_width = 1.25, -- black outline
    max_motion_offset = 5,
    motion_velocity = 3.5, -- px / s
    motion_n_path_nodes = 10,
    outline_min_opacity = 0.5,

    bounce_impulse = 280, -- constant

    particles = {
        min_radius = 0.5, -- px
        max_radius = 3,
        min_velocity = 120, -- px / s
        max_velocity = 170,
        min_lifetime = 0.15, -- s
        max_lifetime = 2,
        angle_spread = 0.25 * math.pi,
        hue_spread = 0.075,
        opacity_envelope_attack = 0.025,
        inlay = 0.4,
        deceleration = 0.95,
        min_player_velocity_influence = 0.25,
        max_player_velocity_influence = 1
    }
}

--- @class ow.Bubble
ow.Bubble = meta.class("Bubble", ow.MovableObject)

local _shader = rt.Shader("overworld/objects/bubble.glsl")
local _n_hue_steps = 13

function ow.Bubble:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.ELLIPSE, "In ow.Bubble: object is not an ellipse")

    self._scene = scene
    self._stage = stage

    self._x, self._y = object:get_centroid()

    local radius = math.min(object.x_radius, object.y_radius)
    self._x_radius, self._y_radius = radius, radius

    self._is_destroyed = false
    self._respawn_elapsed = math.huge
    self._pop_fraction = 1
    self._pop_light_boost = 0

    self._should_move_in_place = object:get_boolean("should_move_in_place")
    if self._should_move_in_place == nil then self._should_move_in_place = true end

    -- physics

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("slippery", "no_blood", "unjumpable")
    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
        if self._is_destroyed
            or cx == nil or cy == nil -- player is sensor
            or not other_body:has_tag("player")
        then
            return
        end

        local body_x, body_y = self._body:get_position()
        local x, y = body_x, body_y

        -- use exact normal, since body is always an ellipse
        local player = self._scene:get_player()
        local px, py = player:get_position()
        local dx, dy = math.normalize(px - body_x, py - body_y)
        local restitution = player:bounce(dx, dy, rt.settings.overworld.bubble.bounce_impulse)
        -- constant impulse unrelated to player velocity, unlike ow.BouncePad

        self:_pop(self._x + dx * self._x_radius, self._y + dy * self._y_radius)
    end)

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._body:add_tag("point_light_source")
    self._body:set_user_data(self)

    self._stage:signal_connect("respawn", function()
        self:reset()
    end)

    -- graphics
    if stage.bubble_current_hue_step == nil then
        stage.bubble_current_hue_step = 1
    end

    local hue = math.fract( stage.bubble_current_hue_step / _n_hue_steps)
    stage.bubble_current_hue_step =  stage.bubble_current_hue_step + 1

    self._hue = hue
    self._color = { rt.lcha_to_rgba(0.8, 1, hue, 1) }

    self._contour = {}
    self._outline_contour = {}

    local line_width = rt.settings.overworld.bubble.line_width
    local outline_width = rt.settings.overworld.bubble.outline_width

    local mesh_x, mesh_y = 0, 0
    local data = {
        { mesh_x, mesh_y, 0, 0, 1, 1, 1, 1 }
    }

    local n_outer_vertices = 64

    for i = 1, n_outer_vertices + 1 do
        local angle = (i - 1) / n_outer_vertices * 2 * math.pi
        local x = mesh_x + math.cos(angle) * self._x_radius
        local y = mesh_y + math.sin(angle) * self._y_radius

        local u = math.cos(angle)
        local v = math.sin(angle)

        table.insert(data, {
            x, y,
            math.cos(angle),
            math.sin(angle),
            1, 1, 1, 1
        })

        table.insert(self._contour, x)
        table.insert(self._contour, y)

        local outline_x = mesh_x + math.cos(angle) * (self._x_radius + 0.5 * line_width + 0.5 * outline_width)
        local outline_y = mesh_y + math.sin(angle) * (self._y_radius + 0.5 * line_width + 0.5 * outline_width)

        table.insert(self._outline_contour, outline_x)
        table.insert(self._outline_contour, outline_y)
    end

    self._mesh = rt.Mesh(data)

    -- particles
    self._particle_data = {}
    self._n_active_particles = 0
    self._n_particles = 0

    -- random motion
    if self._should_move_in_place then
        local max_offset = rt.settings.overworld.bubble.max_motion_offset

        local points = {}
        for i = 1, rt.settings.overworld.bubble.motion_n_path_nodes do
            table.insert(points, rt.random.number(-0.5 * max_offset, 0.5 * max_offset))
            table.insert(points, rt.random.number(-max_offset, max_offset))
        end
        table.insert(points, points[1])
        table.insert(points, points[2])

        self._path = rt.Spline(points)
        self._path_elapsed = 0
        self._path_duration = self._path:get_length() / rt.settings.overworld.bubble.motion_velocity
    end
end

local _x_offset = 0
local _y_offset = 1
local _velocity_x_offset = 2
local _velocity_y_offset = 3
local _velocity_magnitude_offset = 4
local _elapsed_offset = 5
local _lifetime_offset = 6
local _r_offset = 7
local _g_offset = 8
local _b_offset = 9
local _opacity_offset = 10
local _radius_offset = 11
local _is_active_offset = 12

local IS_ACTIVE = 1
local IS_INACTIVE = 0

local _stride = _is_active_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1 -- 1-based
end

--- @brief
function ow.Bubble:_pop(pop_x, pop_y)
    if self._is_destroyed == true then return end

    self._is_destroyed = true
    self._respawn_elapsed = 0
    self._path_elapsed = 0 -- reset to 0 offset
    self._pop_light_boost = 0
    self._body:set_is_sensor(true)

    local perimeter
    do
        -- ramanujan approximation for ellipse perimeter
        local a = math.max(self._x_radius, self._y_radius)
        local b = math.min(self._x_radius, self._y_radius)
        local h = ((a - b) ^ 2) / ((a + b) ^ 2)
        perimeter = math.pi * (a + b) * (1 + (3 * h) / (10 + math.sqrt(4 - 3 * h)))
    end

    local settings = rt.settings.overworld.bubble.particles
    local max_lifetime = math.min(settings.max_lifetime, rt.settings.overworld.bubble.respawn_duration)

    local path_x, path_y
    if self._should_move_in_place then
        path_x, path_y = self._path:at(math.fract(self._path_elapsed / self._path_duration))
    else
        path_x, path_y = 0, 0
    end

    local body_x, body_y = self._body:get_position()
    local offset_x, offset_y = self._x - body_x + path_x, self._y - body_y + path_y

    local data = self._particle_data
    local long_axis = 2 * math.max(self._x_radius, self._y_radius)
    local function add_particle(x, y, dx, dy)
        local hue = self._hue + rt.random.number(-settings.hue_spread, settings.hue_spread)
        local r, g, b, _ = rt.lcha_to_rgba(rt.random.number(0.8, 0.9), 1, hue, 1)

        local player_dx, player_dy = math.normalize(math.subtract(x, y, pop_x, pop_y))
        local player_influence = 1 - math.min(1, math.distance(pop_x, pop_y, x, y) / long_axis)

        local i = #data + 1
        data[i + _x_offset] = x - offset_x
        data[i + _y_offset] = y - offset_y
        data[i + _velocity_x_offset] = math.mix(dx, player_dx, player_influence)
        data[i + _velocity_y_offset] = math.mix(dy, player_dy, player_influence)
        data[i + _velocity_magnitude_offset] = math.mix(settings.min_velocity, settings.max_velocity, 1 - player_influence)
        data[i + _elapsed_offset] = 0
        data[i + _lifetime_offset] = rt.random.number(settings.min_lifetime, settings.max_lifetime)
        data[i + _r_offset] = r
        data[i + _g_offset] = g
        data[i + _b_offset] = b
        data[i + _opacity_offset] = 0
        data[i + _radius_offset] = rt.random.number(settings.min_radius, settings.max_radius)
        data[i + _is_active_offset] = IS_ACTIVE

        self._n_particles = self._n_particles + 1
        self._n_active_particles = self._n_active_particles + 1
    end

    local n_particles = math.ceil(perimeter / settings.max_radius)
    for i = 1, n_particles do
        local angle = (i - 1) / n_particles * 2 * math.pi
        local dx, dy = math.cos(angle), math.sin(angle)
        local x = self._x + dx * (self._x_radius * (1 - rt.random.number(0, settings.inlay)))
        local y = self._y + dy * (self._y_radius * (1 - rt.random.number(0, settings.inlay)))

        add_particle(x, y, dx, dy)
    end
end

--- @brief
function ow.Bubble:_unpop()
    self:reset()
end

--- @brief
function ow.Bubble:update(delta)
    local respawn_duration = rt.settings.overworld.bubble.respawn_duration

    if self._is_destroyed then
        self._respawn_elapsed = self._respawn_elapsed + delta

        self._pop_light_boost = rt.InterpolationFunctions.ENVELOPE(
            math.min(1, self._respawn_elapsed / rt.settings.overworld.bubble.pop_light_boost_duration),
            0.05,
            0.25
        )

        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()
        local player_r = player:get_radius()

        local x, y = self._body:get_position()
        local radius = math.max(self._x_radius, self._y_radius)
        local overlap = math.distance(player_x, player_y, x, y) < player_r + radius

        if self._respawn_elapsed >= respawn_duration and not overlap then
            self:_unpop()
            return
        end
    end

    if self._n_active_particles > 0 then
        local data = self._particle_data
        local settings = rt.settings.overworld.bubble.particles

        local opacity_easing = function(t)
            local attack = settings.opacity_envelope_attack
            return rt.InterpolationFunctions.ENVELOPE(
                t,
                attack,
                1 - attack
            )
        end

        local deceleration = settings.deceleration
        for particle_i = 1, self._n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            local elapsed = data[i + _elapsed_offset]
            data[i + _elapsed_offset] = elapsed + delta

            local magnitude = data[i + _velocity_magnitude_offset]
            local x, y = data[i + _x_offset], data[i + _y_offset]

            data[i + _x_offset] = x + data[i + _velocity_x_offset] * magnitude * delta
            data[i + _y_offset] = y + data[i + _velocity_y_offset] * magnitude * delta

            data[i + _velocity_magnitude_offset] = data[i + _velocity_magnitude_offset] * deceleration

            local t = math.min(1, elapsed / data[i + _lifetime_offset])
            data[i + _opacity_offset] = opacity_easing(t)
        end
    end

    if not self._stage:get_is_body_visible(self._body) then return end

    local x = math.clamp(self._respawn_elapsed / respawn_duration, 0, 1)
    self._pop_fraction = math.pow(x, 40) -- manually chosen easing

    if not self._is_destroyed and self._should_move_in_place then
        -- freeze while respawning
        self._path_elapsed = self._path_elapsed + delta
    end
end

--- @brief
function ow.Bubble:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    local path_x, path_y
    if self._should_move_in_place then
        path_x, path_y = self._path:at(math.fract(self._path_elapsed / self._path_duration))
    else
        path_x, path_y = 0, 0
    end

    local body_x, body_y = self._body:get_position()
    love.graphics.translate(body_x + path_x, body_y + path_y)

    -- outline always visible so player knows where bubble will respawn
    local opacity = math.max(rt.settings.overworld.bubble.outline_min_opacity, self._pop_fraction)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    local r, g, b = rt.Palette.BLACK:unpack()
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.setLineWidth(rt.settings.overworld.bubble.outline_width)
    love.graphics.line(self._outline_contour)

    r, g, b = table.unpack(self._color)
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.setLineWidth(rt.settings.overworld.bubble.line_width)
    love.graphics.line(self._contour)

    -- player position in normalized uv space relative to center
    local px, py = self._scene:get_player():get_position()
    local dx, dy = (self._x - px) / self._x_radius, (self._y - py) / self._y_radius

    _shader:bind()
    _shader:send("player_position", { dx, dy })
    _shader:send("player_color", self._color)
    _shader:send("pop_fraction", self._pop_fraction)
    self._mesh:draw()
    _shader:unbind()

    love.graphics.pop()

    local data = self._particle_data
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        if data[i + _is_active_offset] == IS_ACTIVE then
            local r, g, b = data[i + _r_offset], data[i + _g_offset], data[i + _b_offset]
            love.graphics.setColor(r, g, b, data[i + _opacity_offset])
            love.graphics.circle("fill",
                data[i + _x_offset],
                data[i + _y_offset],
                data[i + _radius_offset]
            )
        end
    end
end

--- @brief
function ow.Bubble:draw_bloom()
    love.graphics.push()
    local path_x, path_y
    if self._should_move_in_place then
        path_x, path_y = self._path:at(math.fract(self._path_elapsed / self._path_duration))
    else
        path_x, path_y = 0, 0
    end

    local body_x, body_y = self._body:get_position()
    love.graphics.translate(body_x + path_x, body_y + path_y)

    local opacity = math.max(rt.settings.overworld.bubble.outline_min_opacity, self._pop_fraction)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    local r, g, b = table.unpack(self._color)
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.setLineWidth(rt.settings.overworld.bubble.line_width)
    love.graphics.line(self._contour)

    love.graphics.pop()
end

--- @brief
function ow.Bubble:get_color()
    local r, g, b = table.unpack(self._color)
    local a = math.clamp(self._respawn_elapsed / rt.settings.overworld.bubble.respawn_duration, 0, 1)
    return rt.RGBA(r, g, b, a)
end

--- @brief
function ow.Bubble:reset()
    self._is_destroyed = false
    self._respawn_elapsed = math.huge
    self._pop_fraction = 1
    self._pop_light_boost = 0

    self._body:set_is_sensor(false)

    table.clear(self._particle_data)
    self._n_particles = 0
    self._n_active_particles = 0

    if self._should_move_in_place then
        self._path_elapsed = 0
    end
end

--- @brief
function ow.Bubble:collect_point_lights(callback)
    local path_x, path_y
    if self._should_move_in_place then
        path_x, path_y = self._path:at(math.fract(self._path_elapsed / self._path_duration))
    else
        path_x, path_y = 0, 0
    end

    local body_x, body_y = self._body:get_position()
    local x, y = body_x + path_x, body_y + path_y

    local r, g, b, a = self:get_color():unpack()

    local radius = math.min(self._x_radius, self._y_radius)
    callback(x, y, radius, r, g, b, self._pop_fraction)
end