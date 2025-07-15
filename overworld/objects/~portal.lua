rt.settings.overworld.portal = {
    shader_area_w = 100, -- px
    pulse_duration = 1, -- s
    particles = {
        min_speed = 10,
        max_speed = 50,
        min_lifetime = 0.3,
        max_lifetime = 0.7,
        max_hue_offset = 0.05,
        min_scale = 0.5,
        max_scale = 1.5,
    }
}

--- @class ow.Portal
ow.Portal = meta.class("Portal")

--- @class ow.PortalNode
ow.PortalNode = meta.class("PortalNode") -- dummy

local _assert_point = function(object)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Portal: object `" .. object:get_id() .. " is not a point")
end

local _current_hue = 0
local _get_hue = function()
    local out = _current_hue
    _current_hue = math.fract(_current_hue + 1 / 8)
    return _current_hue
end

local _shader

local _LEFT = false
local _RIGHT = not _LEFT

local _get_side = function(vx, vy, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local cross = abx * vy - aby * vx
    return cross > 0
end

local first = true -- TODO

local _particle_texture

--- @brief
function ow.Portal:instantiate(object, stage, scene)
    if _shader == nil then _shader = rt.Shader("overworld/objects/portal.glsl") end

    if _particle_texture == nil then
        local radius = 30
        local padding = 3
        _particle_texture = rt.RenderTexture(2 * (radius + padding), 2 * (radius + padding))

        local mesh = rt.MeshCircle(0, 0, radius)
        local value = 0.4 -- for additive blending
        mesh:set_vertex_color(1, 1, 1, 1)
        for i = 2, mesh:get_n_vertices() do
            mesh:set_vertex_color(i, 1, 1, 1, 0)
        end

        love.graphics.push()
        love.graphics.origin()
        _particle_texture:bind()
        love.graphics.translate(0.5 * _particle_texture:get_width(), 0.5 * _particle_texture:get_width())
        mesh:draw()
        _particle_texture:unbind()
        love.graphics.pop()
    end

    if first then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "k" then
                _shader:recompile()
            end
        end)
        first = false
    end

    self._stage = stage
    self._scene = scene
    self._world = self._stage:get_physics_world()

    self._pulse_elapsed = math.huge
    self._pulse_value = 0
    self._elapsed_offset = rt.random.number(0, 10000)

    self._hue = 0
    self._hue_set = false

    -- whether the portal can be entered from the left, right, or both
    self._left_active = object:get_boolean("left", false)
    self._right_active = object:get_boolean("right", false)

    if self._left_active == nil then self._left_active = true end
    if self._right_active == nil then self._right_active = true end

    if self._left_active == false and self._right_active == false then
        rt.warning("In ow.Portal: object `" .. object:get_id() .. "` of stage `" .. stage:get_id() .. "` has both `left` and `right` set to false")
    end

    stage:signal_connect("initialized", function()
        -- get portal pairs as ordered points
        self._a = object
        _assert_point(self._a)
        self._ax, self._ay = object.x, object.y

        self._b = object:get_object("other", true)
        _assert_point(self._b)
        self._bx, self._by = self._b.x, self._b.y

        self._target = stage:get_object_instance(object:get_object("target", true))
        assert(self._target ~= nil and meta.isa(self._target, ow.Portal), "In ow.Portal: `target` of object `" .. object:get_id() .. "` is not another portal")

        -- synch hue
        if self._hue_set == false and self._target._hue_set == true then
            self._hue = self._target_hue
        elseif self._hue_set == true and self._target._hue_set == false then
            self._target._hue = self._hue
        elseif self._hue_set == false and self._target._hue_set == false then
            self._hue = _get_hue()
            self._target._hue = self._hue
        end

        self._hue_set = true
        self._target._hue_set = true

        -- sensors
        local center_x, center_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)

        self._segment_sensor = b2.Body(
            self._world,
            b2.BodyType.STATIC,
            center_x, center_y,
            b2.Segment(self._ax - center_x, self._ay - center_y, self._bx - center_x, self._by - center_y)
        )

        self._segment_sensor:set_use_continuous_collision(true)

        --self._segment_sensor:set_is_sensor(true)
        self._segment_sensor:set_collides_with(rt.settings.player.player_collision_group)
        self._segment_sensor:signal_connect("collision_start", function(self_body, other_body, nx, ny, contact_x, contact_y)
            if not self._is_disabled and self._disabled_cooldown <= 0 then

                -- check if allowed to enter from that side
                local vx, vy = self._scene:get_player():get_velocity()
                local side = _get_side(vx, vy, self._ax, self._ay, self._bx, self._by)
                if (side == _LEFT and self._left_active) or (side == _RIGHT and self._right_active) then
                    self:_teleport(nx, ny, contact_x, contact_y)
                end
            end
        end)

        -- rectangle sensor
        local sensor_w = rt.settings.player.radius
        local dx, dy = self._ax - self._bx, self._ay - self._by
        local left_x, left_y = math.normalize(math.turn_left(dx, dy))
        local right_x, right_y = math.normalize(math.turn_right(dx, dy))

        local sensor_shape = b2.Polygon(
            self._ax +  left_x * sensor_w - center_x, self._ay +  left_y * sensor_w - center_y,
            self._ax + right_x * sensor_w - center_x, self._ay + right_y * sensor_w - center_y,
            self._bx + right_x * sensor_w - center_x, self._by + right_y * sensor_w - center_y,
            self._bx +  left_x * sensor_w - center_x, self._by +  left_y * sensor_w - center_y
        )

        self._area_sensor = b2.Body(self._world, b2.BodyType.STATIC, center_x, center_y, sensor_shape)
        self._area_sensor:set_is_sensor(true)
        self._area_sensor:signal_connect("collision_end", function()
            self._is_disabled = false
        end)

        for sensor in range(self._segment_sensor, self._area_sensor) do
            sensor:set_collides_with(rt.settings.player.player_collision_group)
        end

        self._sidedness = math.cross(self._ax, self._ay, self._bx, self._by) > 0
        self._is_disabled = false
        self._disabled_cooldown = 0

        -- graphics
        local outer = function() return 0, 0, 0, 0 end -- rgba
        local inner = function() return 1, 1, 1, 1 end

        local w = rt.settings.overworld.portal.shader_area_w

        local padding = 0 --0.25 * math.distance(self._ax, self._ay, self._bx, self._by)
        local dx, dy = math.normalize(self._bx - self._ax, self._by - self._ay)
        local ax, ay = self._ax - dx * padding, self._ay - dy * padding
        local bx, by = self._bx + dx * padding, self._by + dy * padding

        local left_mesh_data = {
            { ax +  left_x * w, ay +  left_y * w, 0, 1, outer() },
            { ax, ay, 0, 0, inner() },
            { bx, by, 1, 0, inner() },
            { bx +  left_x * w, by +  left_y * w, 1, 1, outer() }
        }

        local right_mesh_data = {
            { ax, ay, 1, 0, inner() },
            { ax + right_x * w, ay + right_y * w, 1, 1, outer() },
            { bx + right_x * w, by + right_y * w, 0, 1, outer() },
            { bx, by, 0, 0, inner() }
        }

        self._left_mesh = rt.Mesh(left_mesh_data)
        self._right_mesh = rt.Mesh(right_mesh_data)

        self._particles = {}
        self._particle_left_direction_x, self._particle_left_direction_y = left_x, left_y
        self._particle_right_direction_x, self._particle_right_direction_y = right_x, right_y
    end)
end

function ow.Portal:_spawn(n_particles)
    local player_vx, player_vy = self._scene:get_player():get_velocity()
    local side = _get_side(player_vx, player_vy, self._ax, self._ay, self._bx, self._by)
    local vx, vy
    if side == _LEFT then
        vx, vy = self._particle_left_direction_x, self._particle_left_direction_y
    else
        vx, vy = self._particle_right_direction_x, self._particle_right_direction_y
    end

    local settings = rt.settings.overworld.portal.particles
    for i = 1, n_particles do
        local t = rt.random.number(0, 1)
        local x, y = math.mix2(self._ax, self._ay, self._bx, self._by, t)
        local hue = rt.random.number(-settings.max_hue_offset, settings.max_hue_offset)
        local speed = rt.random.number(settings.min_speed, settings.max_speed)
        local r, g, b, a = rt.lcha_to_rgba(0.8, 1, hue, 1)
        local particle = {
            x = x,
            y = y,
            vx = vx,
            vy = vy,
            speed = speed,
            scale = rt.random.number(settings.min_scale, settings.max_scale),
            r = r,
            g = g,
            b = b,
            a = a,
            elapsed = 0,
            lifetime = rt.random.number(settings.min_lifetime, settings.max_lifetime)
        }

        table.insert(self._particles, particle)
    end
end

--- @brief
function ow.Portal:update(delta)
    if self._scene:get_is_body_visible(self._area_sensor) == false then return end

    self._pulse_elapsed = self._pulse_elapsed + delta
    local pulse_duration = rt.settings.overworld.portal.pulse_duration
    self._pulse_value = rt.InterpolationFunctions.ENVELOPE(
        math.min(self._pulse_elapsed / pulse_duration),
        pulse_duration * 0.05
    )

    local to_remove = {}
    for i, particle in ipairs(self._particles) do
        particle.x = particle.x + particle.speed * particle.vx * delta
        particle.y = particle.y + particle.speed * particle.vy * delta

        if particle.elapsed > particle.lifetime then
            table.insert(to_remove, i)
        end
        particle.elapsed = particle.elapsed + delta
    end

    table.sort(to_remove, function(a, b) return a > b end)
    for i in values(to_remove) do
        table.remove(self._particles, i)
    end
end

function ow.Portal:_disable()
    self._is_disabled = true
    self._disable_cooldown = 2
end

local _get_ratio = function(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local apx, apy = px - ax, py - ay

    local ab_length_squared = math.dot(abx, aby, abx, aby)
    local t = math.dot(apx, apy, abx, aby) / ab_length_squared
    return 1 - math.max(0, math.min(1, t))
end

local _get_sidedness = function(ax, ay, bx, by)
    return math.cross(ax, ay, bx, by) > 0
end

local function teleport_player(
    from_ax, from_ay, from_bx, from_by,
    to_ax, to_ay, to_bx, to_by,
    vx, vy, contact_x, contact_y
)
    -- new position
    local ratio = _get_ratio(contact_x, contact_y, from_ax, from_ay, from_bx, from_by)
    local from_sidedness = _get_sidedness(from_ax, from_ay, from_bx, from_by)
    local to_sidedness = _get_sidedness(to_ax, to_ay, to_bx, to_by)
    if from_sidedness == to_sidedness then
        ratio = 1 - ratio
    end

    local new_x, new_y = math.mix2(to_ax, to_ay, to_bx, to_by, ratio)

    -- new velocity
    local from_dx = from_bx - from_ax
    local from_dy = from_by - from_ay
    local to_dx = to_bx - to_ax
    local to_dy = to_by - to_ay

    local from_angle = math.angle(from_dx, from_dy)
    local to_angle = math.angle(to_dx, to_dy)
    local angle_diff = to_angle - from_angle

    local speed = math.magnitude(vx, vy)
    local velocity_angle = math.angle(vx, vy)
    local new_velocity_angle = velocity_angle + angle_diff

    local new_vx = speed * math.cos(new_velocity_angle)
    local new_vy = speed * math.sin(new_velocity_angle)

    local from_normal_angle = from_angle + math.pi / 2  -- perpendicular to portal
    local to_normal_angle = to_angle + math.pi / 2

    local from_normal_x, from_normal_y = math.cos(from_normal_angle), math.sin(from_normal_angle)
    local to_normal_x, to_normal_y = math.cos(to_normal_angle), math.sin(to_normal_angle)

    local from_dot = vx * from_normal_x + vy * from_normal_y
    local new_to_dot = new_vx * to_normal_x + new_vy * to_normal_y

    if not ((from_dot > 0 and new_to_dot < 0) or (from_dot < 0 and new_to_dot > 0)) then
        new_vx = -new_vx
        new_vy = -new_vy
    end

    -- override actual position with center of exit
    new_x, new_y = math.mix2(to_ax, to_ay, to_bx, to_by, 0.5)

    return new_x, new_y, new_vx, new_vy
end

function ow.Portal:_teleport(normal_x, normal_y, contact_x, contact_y)
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local target = self._target

    -- disable to prevent loops
    target:_disable()
    self:_disable()

    self._pulse_elapsed = 0
    target._pulse_elapsed = 0

    local vx, vy = player:get_velocity()
    local new_x, new_y, new_vx, new_vy = teleport_player(
        self._ax, self._ay,  self._bx, self._by,
        target._ax, target._ay, target._bx, target._by,
        vx, vy,
        contact_x, contact_y
    )

    local radius = player:get_radius()
    local nvx, nvy = math.normalize(new_vx, new_vy)
    player:teleport_to(new_x + radius * nvx, new_y + radius * nvy)
    player:set_velocity(new_vx, new_vy)

    new_vx, new_vy = math.normalize(new_vx, new_vy)
    vx, vy = math.normalize(vx, vy)

    self:_spawn(rt.random.integer(4, 12))
    target:_spawn(rt.random.integer(4, 12))

    _dbg = {
        {
            new_x, new_y,
            new_x + new_vx * 10,
            new_y + new_vy * 10
        }, {
            contact_x, contact_y,
            contact_x + new_vx * 10,
            contact_y + new_vy * 10
        }
    }

    target._is_active = true
end

--- @brief
function ow.Portal:draw()
    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, self._hue, 1)

    love.graphics.setColor(r, g, b, a)

    local value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
    ow.Hitbox:draw_mask(true, false) -- sticky, not slippery
    rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed() + self._hue * 1000)
    _shader:send("color", { r, g, b, a })
    _shader:send("pulse", self._pulse_value == math.huge and 0 or self._pulse_value)

    if self._left_active then
        love.graphics.draw(self._left_mesh:get_native())
    end

    if self._right_active then
        love.graphics.draw(self._right_mesh:get_native())
    end

    _shader:unbind()
    rt.graphics.set_stencil_mode(nil)

    local texture = _particle_texture:get_native()
    local texture_w, texture_h = _particle_texture:get_size()
    for particle in values(self._particles) do
        love.graphics.setColor(particle.r, particle.g, particle.b, particle.a)
        love.graphics.draw(
            texture,
            particle.x,
            particle.y,
            0,
            particle.scale,
            particle.scale,
            0.5 * texture_w,
            0.5 * texture_h
        )
    end

    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(4)
    love.graphics.line(self._ax, self._ay, self._bx, self._by)

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.draw(_particle_texture:get_native(), 50, 50)
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
    if _dbg ~= nil then
        for l in values(_dbg) do love.graphics.line(l) end
    end
end

--- @brief
function ow.Portal:draw_bloom()
    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, self._hue, 1)

    local dampening = self._pulse_value * 0.5
    love.graphics.setColor(dampening * r, dampening * g, dampening * b, dampening * a)

    local value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
    ow.Hitbox:draw_mask(true, false) -- sticky, not slippery
    rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

    _shader:bind()
    if self._left_active then
        love.graphics.draw(self._left_mesh:get_native())
    end

    if self._right_active then
        love.graphics.draw(self._right_mesh:get_native())
    end
    _shader:unbind()

    rt.graphics.set_stencil_mode(nil)
end

--- @brief
function ow.Portal:get_render_priority()
    return 1
end