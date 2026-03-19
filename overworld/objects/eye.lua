require "common.random"
require "common.smoothed_motion_2d"

rt.settings.overworld.eye = {
    detection_radius = 400,
    pupil_radius_factor = 0.3,
    iris_radius_factor = 0.6
}

--- @class ow.Eye
ow.Eye = meta.class("OverworldEye")

local _new_transform = function()
    return {
        scale_x = 1,
        scale_y = 1,
        shear_x = 0,
        shear_y = 0
    }
end

local _iris_shader = rt.Shader("overworld/objects/eye_iris.glsl")
local _lighting_shader = rt.Shader("overworld/objects/eye_sclera.glsl")

local _noise_texture = rt.NoiseTexture(32, 32, 8,
    rt.NoiseType.GRADIENT, 8
)

local _lch_texture = rt.LCHTexture(1, 1, 256)

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "k" then
        _iris_shader:recompile()
        _lighting_shader:recompile()
    end
end)

function ow.Eye:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.ELLIPSE, "In ow.Eye.instantiate: object is not a circle")

    self._camera_body = object:create_physics_body(stage:get_physics_world())
    self._camera_body:set_collides_with(0x0)
    self._camera_body:set_collision_group(0x0)

    self._stage = stage
    self._scene = scene
    self._x = object.x
    self._y = object.y

    local radius = math.min(object.x_radius, object.y_radius)
    self._radius = radius

    local n_outer_vertices = rt.Mesh.radius_to_n_vertices(radius, radius)

    local new_lining = function(radius)
        local out = {}
        for i = 1, n_outer_vertices + 1 do
            local angle = (i - 1) / n_outer_vertices * 2 * math.pi
            table.insert(out, 0 + math.cos(angle) * radius)
            table.insert(out, 0 + math.sin(angle) * radius)
        end
        return out
    end

    local settings = rt.settings.overworld.eye

    self._pupil_x, self._pupil_y = 0, 0
    self._pupil_radius = settings.pupil_radius_factor * radius
    self._pupil_lining = new_lining(self._pupil_radius)
    self._pupil_transform = _new_transform()

    self._iris_x, self._iris_y = 0, 0
    self._iris_radius = settings.iris_radius_factor * radius
    self._iris_transform = _new_transform()
    self._iris_lining = new_lining(self._iris_radius)

    self._sclera_x, self._sclera_y = 0, 0
    self._sclera_radius = radius
    self._sclera_lining = new_lining(self._sclera_radius)

    self._motion = rt.SmoothedMotion2D(0, 0, 400 * rt.random.number(0.8, 1))
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, rt.random.number(0, 1), 1))

    self._sclera_color = rt.Palette.BLACK
    self._sclera_lining_color = self._color

    self._pupil_color = rt.Palette.BLACK
    self._pupil_lining_color = self._color

    self._iris_color = self._color
    self._iris_lining_color = self._color

    self._iris_mesh = nil
    do
        local data = {}
        local vertex_indices = {}

        for i = 1, n_outer_vertices do
            local angle = (i - 1) / n_outer_vertices * 2 * math.pi
            local cos_a, sin_a = math.cos(angle), math.sin(angle)
            local u = (i - 1) / n_outer_vertices

            table.insert(data, {
                cos_a * self._iris_radius, sin_a * self._iris_radius,
                u, 1,
                0, 0, 0, 1
            })

            table.insert(data, {
                cos_a * self._pupil_radius, sin_a * self._pupil_radius,
                u, 0,
                1, 1, 1, 1
            })
        end

        -- manual closing vertices, to prevent interpolation between first and last tri u coord
        table.insert(data, {
            self._iris_radius, 0,
            1, 1,
            0, 0, 0, 1
        })
        table.insert(data, {
            self._pupil_radius, 0,
            1, 0,
            1, 1, 1, 1
        })

        for i = 0, n_outer_vertices - 2 do
            local outer_current = 2 * i + 1
            local inner_current = 2 * i + 2
            local outer_next    = 2 * (i + 1) + 1
            local inner_next    = 2 * (i + 1) + 2

            table.insert(vertex_indices, outer_current)
            table.insert(vertex_indices, outer_next)
            table.insert(vertex_indices, inner_current)
            table.insert(vertex_indices, inner_current)
            table.insert(vertex_indices, outer_next)
            table.insert(vertex_indices, inner_next)
        end

        local outer_last = 2 * (n_outer_vertices - 1) + 1
        local inner_last = 2 * (n_outer_vertices - 1) + 2
        local outer_closing = 2 * n_outer_vertices + 1
        local inner_closing = 2 * n_outer_vertices + 2

        table.insert(vertex_indices, outer_last)
        table.insert(vertex_indices, outer_closing)
        table.insert(vertex_indices, inner_last)
        table.insert(vertex_indices, inner_last)
        table.insert(vertex_indices, outer_closing)
        table.insert(vertex_indices, inner_closing)

        self._iris_mesh = rt.Mesh(data, rt.MeshDrawMode.TRIANGLES)
        self._iris_mesh:set_vertex_map(vertex_indices)
    end

    do
        local mesh_x, mesh_y = 0, 0
        local iris_highlight_data = {
            { mesh_x, mesh_y, 0, 0, 1, 1, 1, 1 }
        }

        local sclera_highlight_data = {
            { mesh_x, mesh_y, 0, 0, 1, 1, 1, 1 }
        }

        for i = 1, n_outer_vertices + 1 do
            local angle = (i - 1) / n_outer_vertices * 2 * math.pi
            local cos_a, sin_a = math.cos(angle), math.sin(angle)

            table.insert(iris_highlight_data, {
                mesh_x + cos_a * self._iris_radius,
                mesh_y + sin_a * self._iris_radius,
                cos_a,
                sin_a,
                1, 1, 1, 1
            })

            table.insert(sclera_highlight_data, {
                mesh_x + cos_a * self._sclera_radius,
                mesh_y + sin_a * self._sclera_radius,
                cos_a,
                sin_a,
                1, 1, 1, 1
            })
        end

        self._iris_highlight_mesh = rt.Mesh(iris_highlight_data)
        self._sclera_highlight_mesh = rt.Mesh(sclera_highlight_data)
    end
end

function ow.Eye:update(delta)
    if not self._stage:get_is_body_visible(self._camera_body) then return end

    local settings = rt.settings.overworld.eye
    local player_x, player_y = self._scene:get_player():get_position()
    local dx, dy = player_x - self._x, player_y - self._y
    local distance_to_player = math.magnitude(dx, dy)

    dx, dy = math.normalize(dx, dy)
    local offset = math.min(distance_to_player / settings.detection_radius, 1.0)
    self._motion:set_target_position(
        dx * self._radius * offset,
        dy * self._radius * offset
    )
    self._motion:update(delta)

    local offset_x, offset_y = self._motion:get_position()

    -- clamp to avoid deformed iris moving the sclera
    local offset_magnitude = math.magnitude(offset_x, offset_y)
    local nx, ny = 1, 0
    if offset_magnitude > 0 then
        nx, ny = offset_x / offset_magnitude, offset_y / offset_magnitude
    end

    local depth = math.sqrt(math.max(self._radius * self._radius - offset_magnitude * offset_magnitude, 0))
    local scale_along_gaze = depth / self._radius

    local r, rs, ri = self._radius, self._sclera_radius, self._iris_radius
    local a = r * r + ri * ri
    local b = -2 * r * r * rs
    local c = r * r * (rs * rs - ri * ri)
    local clamped_magnitude = math.min(offset_magnitude, (-b - math.sqrt(b * b - 4 * a * c)) / (2 * a))
    -- don't ask

    offset_x, offset_y = nx * clamped_magnitude, ny * clamped_magnitude

    self._iris_x, self._iris_y = offset_x, offset_y
    self._pupil_x, self._pupil_y = offset_x, offset_y

    local squared_offset = math.min(math.magnitude(offset_x, offset_y), self._radius) ^ 2
    local depth_clamped = math.sqrt(self._radius * self._radius - squared_offset)
    local sx = depth_clamped / self._radius

    local cos2 = nx * nx
    local sin2 = ny * ny
    local sincos = nx * ny

    local new_scale_x = sx * cos2 + sin2
    local new_scale_y = sx * sin2 + cos2
    local shear_factor = sincos * (sx - 1)

    self._iris_transform.scale_x = new_scale_x
    self._iris_transform.scale_y = new_scale_y
    self._iris_transform.shear_x = shear_factor / new_scale_y
    self._iris_transform.shear_y = shear_factor / new_scale_x

    self._pupil_transform.scale_x = new_scale_x
    self._pupil_transform.scale_y = new_scale_y
    self._pupil_transform.shear_x = shear_factor / new_scale_y
    self._pupil_transform.shear_y = shear_factor / new_scale_x
end

function ow.Eye:draw()
    if not self._stage:get_is_body_visible(self._camera_body) then return end

    love.graphics.push("all")
    love.graphics.setLineStyle("smooth")
    love.graphics.translate(self._x, self._y)

    local bind_transform = function(x, y, transform)
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.shear(transform.shear_x, transform.shear_y)
        love.graphics.scale(transform.scale_x, transform.scale_y)
    end

    local unbind_transform = function()
        love.graphics.pop()
    end

    self._sclera_color:bind()
    love.graphics.circle("fill", self._sclera_x, self._sclera_y, self._sclera_radius)

    local white_r, white_g, white_b = rt.Palette.WHITE:unpack()

    _lighting_shader:bind()
    _lighting_shader:send("highlight_color", { 0, 0, 0, 0 })

    local r, g, b = self._color:unpack()
    _lighting_shader:send("shading_color", { r, g, b, 0.25  })
    --self._sclera_highlight_mesh:draw()
    _lighting_shader:unbind()

    local line_width = 2

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(line_width + 2)
    love.graphics.line(self._sclera_lining)

    love.graphics.setLineWidth(line_width)
    self._sclera_lining_color:bind()
    love.graphics.line(self._sclera_lining)

    bind_transform(self._iris_x, self._iris_y, self._iris_transform)

    _iris_shader:bind()
    _iris_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _iris_shader:send("noise_texture", _noise_texture)
    _iris_shader:send("lch_texture", _lch_texture)
    self._iris_color:bind()
    self._iris_mesh:draw()
    _iris_shader:unbind()

    self._iris_lining_color:bind()
    love.graphics.line(self._iris_lining)

    unbind_transform()

    bind_transform(self._pupil_x, self._pupil_y, self._pupil_transform)

    self._pupil_color:bind()
    love.graphics.circle("fill", 0, 0, self._pupil_radius)

    self._pupil_lining_color:bind()
    love.graphics.line(self._pupil_lining)

    _lighting_shader:bind()
    _lighting_shader:send("highlight_color", { 1, 1, 1, 0.5 })
    _lighting_shader:send("shading_color", { 0, 0, 0, 0 })
    self._iris_highlight_mesh:draw()
    _lighting_shader:unbind()

    unbind_transform()

    love.graphics.pop()
end

--- @brief
function ow.Eye:draw_bloom()
    self._sclera_lining_color:bind()
    love.graphics.line(self._sclera_lining)

    self._iris_lining_color:bind()
    love.graphics.line(self._iris_lining)
end