require "common.smoothed_motion_1d"
require "common.polyline"
require "common.softbody"
require "common.lch_texture"
require "common.player_body_core_type"

rt.settings.player_body = {
    outline_darkening = 0.5,
    texture_scale = 4,
    msaa = 2,

    squish_speed = 2, -- fraction
    squish_magnitude = 0.2, -- fraction

    core_config = {
        distance_compliance = 1e-7,
        bending_compliance = 5e-6,
        anchor_compliance = 0
    },

    bubble_config = {
        distance_compliance = 0,
        bending_compliance = 0
    }
}

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

rt.PlayerBodyState = meta.enum("PlayerBodyState", {
    BUBBLE = true,
    NON_BUBBLE = false
})

local _core_type_to_shader = {
    [rt.PlayerBodyCoreType.DEFAULT] = rt.Shader("common/player_body_core_default.glsl"),
    [rt.PlayerBodyCoreType.SOLID] = rt.Shader("common/player_body_core_solid.glsl")
}
for x in values(meta.instances(rt.PlayerBodyCoreType)) do
    if _core_type_to_shader[x] == nil then
        rt.error("In rt.PlayerBody: not shader is associated with `PlayerBodyCoreType` `", x, "`")
        _core_type_to_shader[x] = _core_type_to_shader[rt.PlayerBodyCoreType.DEFAULT]
    end
end

local _lch_texture = rt.LCHTexture(256, 64, 256)
local _squished = 1
local _not_squished = 0

--- @brief
function rt.PlayerBody:instantiate(position_x, position_y)
    meta.typecheck(position_x, mt.Number, position_y, mt.Number)

    -- appearance
    self._core_color = rt.Palette.WHITE
    self._bubble_body_color = rt.Palette.BLACK
    self._hue = select(3, rt.rgba_to_lcha(self._core_color:unpack()))
    self._opacity = 1
    self._saturation = 1
    self._contraction = 0

    self._position_x = position_x
    self._position_y = position_y
    self._relative_velocity_x = 0
    self._relative_velocity_y = 0
    self._gravity_x = 0
    self._gravity_y = 200

    self._bubble_body = nil -- rt.SoftBody
    self._core = nil -- rt.SoftBody

    local squish_speed = rt.settings.player_body.squish_speed

    self._down_squish = false
    self._down_squish_normal_x = nil
    self._down_squish_normal_y = nil
    self._down_squish_origin_x = nil
    self._down_squish_origin_y = nil
    self._down_squish_motion = rt.SmoothedMotion1D(_not_squished, squish_speed)

    self._left_squish = false
    self._left_squish_normal_x = nil
    self._left_squish_normal_y = nil
    self._left_squish_origin_x = nil
    self._left_squish_origin_y = nil
    self._left_squish_motion = rt.SmoothedMotion1D(_not_squished, squish_speed)

    self._right_squish = false
    self._right_squish_normal_x = nil
    self._right_squish_normal_y = nil
    self._right_squish_origin_x = nil
    self._right_squish_origin_y = nil
    self._right_squish_motion = rt.SmoothedMotion1D(_not_squished, squish_speed)

    self._up_squish = false
    self._up_squish_normal_x = nil
    self._up_squish_normal_y = nil
    self._up_squish_origin_x = nil
    self._up_squish_origin_y = nil
    self._up_squish_motion = rt.SmoothedMotion1D(_not_squished, squish_speed)

    self._bubble_body_stencil_bodies = {}
    self._core_stencil_bodies = {}

    self._state = rt.PlayerBodyState.NON_BUBBLE
    self:_initialize()
end

local box_r = 200

--- @brief
function rt.PlayerBody:_initialize()
    local center_x, center_y = self._position_x, self._position_y
    local core_radius = rt.settings.player.radius
    local bubble_radius_factor = rt.settings.player.bubble_radius_factor
    local n_vertices = rt.settings.player.n_outer_bodies

    self._core = rt.SoftBody(rt.PolylineCircle(center_x, center_y, core_radius, n_vertices))
    self._core:set_anchor(center_x, center_y)
    self._core:set_config(rt.settings.player_body.core_config)
    self._core_mesh = nil
    self._core_mesh_data = nil

    self._bubble_body = rt.SoftBody(rt.PolylineCircle(center_x, center_y, bubble_radius_factor * core_radius, math.ceil(bubble_radius_factor * n_vertices)))
    self._bubble_body:set_anchor(center_x, center_y)
    self._bubble_body:set_config(rt.settings.player_body.bubble_config)
    self._bubble_body_mesh = nil
    self._bubble_body_mesh_data = nil

    self._bubble_body_anchor_x_offset, self._bubble_body_anchor_y_offset = 0, 0
end

--- @brief
function rt.PlayerBody:relax()
    if self._bubble_body ~= nil then
        self._bubble_body:relax()
    end

    if self._core ~= nil then
        self._core:relax()
    end
end

function rt.PlayerBody:update(delta)
    if self._core ~= nil then
        self._core:clear_forces()
        self._core:add_linear_force(-self._relative_velocity_x, -self._relative_velocity_y)
        self._core:set_gravity(self._gravity_x, self._gravity_y)
        self._core:update(delta)
    end

    if self._bubble_body ~= nil and self._state == rt.PlayerBodyState.BUBBLE then
        self._bubble_body:add_linear_force(-self._relative_velocity_x, -self._relative_velocity_y)
        self._bubble_body:set_gravity(self._gravity_x, self._gravity_y)
        self._bubble_body:update(delta)
    end

    for motion in range(
        self._down_squish_motion,
        self._right_squish_motion,
        self._up_squish_motion,
        self._left_squish_motion
    ) do
        motion:update(delta)
    end
end

--- @brief
function rt.PlayerBody:set_stencil_bodies(t)

    self._bubble_body_stencil_bodies = t
    local contours = {}
    for body in values(t) do
        for contour in values(body:get_contours()) do
            table.insert(contours, rt.Polyline(contour))
        end
    end

    self._bubble_body:set_collision_contours(contours)
    self._core:set_collision_contours(contours)
end

--- @brief
function rt.PlayerBody:set_core_stencil_bodies(t)
    self._core_stencil_bodies = t
end

--- @brief
function rt.PlayerBody:_apply_transform()
    local magnitude = rt.settings.player_body.squish_magnitude
    local radius = rt.settings.player.radius

    local function apply(motion, normal_x, normal_y, origin_x, origin_y)
        local amount = motion:get_value()
        if amount <= 0.01 then return end
        normal_x, normal_y = math.normalize(normal_x, normal_y)

        local angle = math.angle(normal_x, normal_y)
        local scale_x = 1 - magnitude * amount

        love.graphics.translate(origin_x, origin_y)
        love.graphics.rotate(angle)
        love.graphics.scale(scale_x, 1)
        love.graphics.rotate(-angle)
        love.graphics.translate(-origin_x, -origin_y)
    end

    apply(self._down_squish_motion,
        self._down_squish_normal_x, self._down_squish_normal_y,
        self._down_squish_origin_x, self._down_squish_origin_y
    )

    apply(self._up_squish_motion,
        self._up_squish_normal_x, self._up_squish_normal_y,
        self._up_squish_origin_x, self._up_squish_origin_y
    )

    apply(self._left_squish_motion,
        self._left_squish_normal_x, self._left_squish_normal_y,
        self._left_squish_origin_x, self._left_squish_origin_y
    )

    apply(self._right_squish_motion,
        self._right_squish_normal_x, self._right_squish_normal_y,
        self._right_squish_origin_x, self._right_squish_origin_y
    )

    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(3)
end

--- @brief
function rt.PlayerBody:draw_body()
    love.graphics.push("all")
    self:_apply_transform()
    local contour = self._bubble_body:get_draw_contour()
    contour:draw()
    love.graphics.pop()
end

local _triangulate = function(mesh, mesh_data, contour)
    if mesh_data == nil then mesh_data = {} end

    local aabb = contour:get_aabb()
    local data = contour:get_vertices()
    local tris = contour:triangulate()
    local vertex_i = 1
    for _, tri in ipairs(tris) do
        for i = 1, #tri, 2 do
            local x, y = tri[i + 0], tri[i + 1]
            local u = (x - aabb.x) / aabb.width
            local v = (y - aabb.y) / aabb.height
            local entry = mesh_data[vertex_i]
            if entry == nil then
                entry = { x, y, u, v, 1, 1, 1, 1 }
                mesh_data[vertex_i] = entry
            else
                entry[1], entry[2], entry[3], entry[4] = x, y, u, v
            end

            vertex_i = vertex_i + 1
        end
    end

    if mesh == nil or mesh:get_n_vertices() ~= vertex_i - 1 then
        mesh = rt.Mesh(mesh_data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBuffer.STREAM
        )
    else
        mesh:replace_data(mesh_data)
    end

    return mesh, mesh_data
end

--- @brief
function rt.PlayerBody:draw_core()
    love.graphics.push("all")

    self:_apply_transform()

    local contour = self._core:get_draw_contour()
    self._core_mesh, self._core_mesh_data = _triangulate(
        self._core_mesh,
        self._core_mesh_data,
        contour
    )

    local core_shader = _core_type_to_shader[rt.GameState:get_player_body_core_type()]
    core_shader:bind()
    core_shader:send("hue", self._hue)
    core_shader:send("elapsed", rt.SceneManager:get_elapsed())
    core_shader:send("saturation",  self._saturation)
    core_shader:send("lch_texture", _lch_texture)
    love.graphics.setColor(1, 1, 1, self._opacity)
    self._core_mesh:draw()
    core_shader:unbind()

    love.graphics.setLineWidth(2)
    love.graphics.setLineJoin("bevel")
    self._core_color:clone():lighten(0.2):bind()
    love.graphics.line(contour:get_vertices())

    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:set_position(x, y)
    meta.typecheck(x, mt.Number, y, mt.Number)
    self._position_x = x
    self._position_y = y
    self._core:set_anchor(x, y)
    self._bubble_body:set_anchor(x + self._bubble_body_anchor_x_offset, y + self._bubble_body_anchor_y_offset)
end

--- @brief
function rt.PlayerBody:set_color(color)
    meta.typecheck(color, rt.RGBA)
    self._core_color = color
    self._hue = select(3, rt.rgba_to_lcha(self._core_color:unpack()))
end

--- @brief
function rt.PlayerBody:set_body_color(color)
    meta.typecheck(color, rt.RGBA)
    self._bubble_body_color = color
end

--- @brief
function rt.PlayerBody:set_core_color(color)
    self._core_color = color
end

--- @brief
function rt.PlayerBody:set_opacity(opacity)
    self._opacity = opacity
end

--- @brief
function rt.PlayerBody:set_state(state)
    local before = self._state
    self._state = state

    if before ~= rt.PlayerBodyState.BUBBLE and state == rt.PlayerBodyState.BUBBLE then
        local contour = self._bubble_body:get_contour()
        local center_x, center_y = contour:get_centroid()

        local data = contour:get_vertices()
        local radius = rt.settings.player.radius
        for i = 1, #data, 2 do
            local current_x, current_y = data[i + 0], data[i + 1]
            local dx, dy = math.normalize(current_x - center_x, current_y - center_y)
            data[i + 0] = center_x + dx * radius
            data[i + 1] = center_y + dy * radius
        end

        self._bubble_body:set_shape(rt.Polyline(data))
    end
end

--- @brief
function rt.PlayerBody:draw_bloom()
    love.graphics.push("all")
    self:_apply_transform()
    self._core_color:bind()
    love.graphics.setLineWidth(1)
    self._core:get_draw_contour():draw()
    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:set_relative_velocity(vx, vy)
    self._relative_velocity_x = vx
    self._relative_velocity_y = vy
end

--- @brief
function rt.PlayerBody:set_down_squish(b, nx, ny, contact_x, contact_y)
    self._down_squish = b
    self._down_squish_normal_x = nx or self._down_squish_normal_x
    self._down_squish_normal_y = ny or self._down_squish_normal_y
    self._down_squish_origin_x = contact_x or self._down_squish_origin_x
    self._down_squish_origin_y = contact_y or self._down_squish_origin_y

    if b == true then
        self._down_squish_motion:set_target_value(_squished)
    else
        self._down_squish_motion:set_target_value(_not_squished)
    end
end

--- @brief
function rt.PlayerBody:set_left_squish(b, nx, ny, contact_x, contact_y)
    self._left_squish = b
    self._left_squish_normal_x = nx or self._left_squish_normal_x
    self._left_squish_normal_y = ny or self._left_squish_normal_y
    self._left_squish_origin_x = contact_x or self._left_squish_origin_x
    self._left_squish_origin_y = contact_y or self._left_squish_origin_y

    if b == true then
        self._left_squish_motion:set_target_value(_squished)
    else
        self._left_squish_motion:set_target_value(_not_squished)
    end
end

--- @brief
function rt.PlayerBody:set_right_squish(b, nx, ny, contact_x, contact_y)
    self._right_squish = b
    self._right_squish_normal_x = nx or self._right_squish_normal_x
    self._right_squish_normal_y = ny or self._right_squish_normal_y
    self._right_squish_origin_x = contact_x or self._right_squish_origin_x
    self._right_squish_origin_y = contact_y or self._right_squish_origin_y

    if b == true then
        self._right_squish_motion:set_target_value(_squished)
    else
        self._right_squish_motion:set_target_value(_not_squished)
    end
end

--- @brief
function rt.PlayerBody:set_up_squish(b, nx, ny, contact_x, contact_y)
    self._up_squish = b
    self._up_squish_normal_x = nx or self._up_squish_normal_x
    self._up_squish_normal_y = ny or self._up_squish_normal_y
    self._up_squish_origin_x = contact_x or self._up_squish_origin_x
    self._up_squish_origin_y = contact_y or self._up_squish_origin_y

    if b == true then
        self._up_squish_motion:set_target_value(_squished)
    else
        self._up_squish_motion:set_target_value(_not_squished)
    end
end

--- @brief
function rt.PlayerBody:set_gravity(gravity_x, gravity_y)
    if self._core ~= nil then
        self._core:set_gravity(gravity_x, gravity_y)
    end

    if self._bubble_body ~= nil then
        self._core:set_gravity(gravity_x, gravity_y)
    end
end

--- @brief
function rt.PlayerBody:set_saturation(t)
    self._saturation = t
end

--- @brief
function rt.PlayerBody:get_saturation()
    return self._saturation
end

--- @brief
function rt.PlayerBody:set_contraction(t)
    self._contraction = t
end

do
    local once = false
    --- @brief
    function rt.PlayerBody:set_player_velocity()
        if once ~= true then
            rt.critical("Im rt.PlayerBody: set_player_velocity TODO")
            once = true
        end
    end
end