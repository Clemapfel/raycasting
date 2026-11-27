require "common.smoothed_motion_1d"
require "common.polyline"
require "common.softbody"
require "common.hairbody"
require "common.lch_texture"
require "common.player_body_core_type"

rt.settings.player_body = {
    outline_darkening = 0.5,
    texture_scale = 4,
    msaa = 2,

    squish_speed = 2, -- fraction
    squish_magnitude = 0.2, -- fraction

    core_radius_offset = -2,
    hair_body_radius_offset = 3,

    core_non_bubble_config = {
        static_friction = 0.0,
        kinetic_friction = 0.0,

        n_constraint_iterations = 4,
        damping = 0.96,
        distance_compliance = 1e-7,
        bending_compliance = 1e-7,
        volume_compliance = 1e-7,
        anchor_compliance = 0,
        angular_momentum_compliance = 0
    },

    core_bubble_config = {
        static_friction = 0.0,
        kinetic_friction = 0.0,

        distance_compliance = 8e-7,
        bending_compliance = 1e-7,
        volume_compliance = 10e-6,

        -- turn off everything except anchor
        enforce_distance = false,
        enforce_volume = false,
        enforce_contour_collision = false,
        enforce_bending = false,
        enforce_linear_momentum = false,
        enforce_pinch = false,

        enforce_anchor = true,
        enforce_angular_momentum = true
    },

    bubble_config = {
        static_friction = 1.2,
        kinetic_friction = 0.9,
        damping = 0.98,

        bending_compliance = 0,
        distance_compliance = 0,
        volume_compliance = 0
    },

    hair_bubble_config = {
        enforce_distance = true,
        distance_compliance = 0, -- for contraction

        enforce_contour_collision = false,
        enforce_bending = false,
        enforce_anchor = true,
        enforce_angular_momentum = false
    },

    hair_non_bubble_config = {
        -- defaults
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
local _bubble_eps = 0.01

--- @brief
function rt.PlayerBody:instantiate(position_x, position_y)
    meta.typecheck(position_x, mt.Number, position_y, mt.Number)

    -- appearance
    self._color = rt.Palette.WHITE
    self._bubble_body_color = rt.Palette.BLACK
    self._hue = select(3, rt.rgba_to_lcha(self._color:unpack()))
    self._opacity = 1
    self._saturation = 1
    self._contraction = 0

    self._position_x = position_x
    self._position_y = position_y
    self._relative_velocity_x = 0
    self._relative_velocity_y = 0
    self._gravity_x = 0
    self._gravity_y = 200

    self._is_disabled = false
    self._triangulate_needed = true

    self._bubble_body = nil -- rt.SoftBody
    self._core_body = nil -- rt.SoftBody
    self._hair_body = nil -- rt.HairBody

    self._bubble_contraction_motion = rt.SmoothedMotion1D(0)
    self._hair_contraction_motion = rt.SmoothedMotion1D(0)

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
    self._core_body_stencil_bodies = {}
    self:_initialize()

    self._state = rt.PlayerBodyState.BUBBLE
    self:set_state(rt.PlayerBodyState.NON_BUBBLE) -- force update
end

local box_r = 200

--- @brief
function rt.PlayerBody:_initialize()
    local center_x, center_y = self._position_x, self._position_y
    local core_radius = rt.settings.player.radius
    local bubble_radius_factor = rt.settings.player.bubble_radius_factor

    local core_body_radius = core_radius + rt.settings.player_body.core_radius_offset
    self._core_body = rt.SoftBody(rt.PolylineCircle(
        center_x, center_y, core_body_radius,
        18
    ))
    self._core_body:set_anchor(center_x, center_y)
    self._core_body:set_config(rt.settings.player_body.core_non_bubble_config)
    self._core_body_mesh = nil
    self._core_body_mesh_data = nil
    self._core_body_contour = nil

    self._bubble_body = rt.SoftBody(rt.PolylineCircle(
        center_x, center_y, bubble_radius_factor * core_body_radius,
        26
    ))
    self._bubble_body:set_anchor(center_x, center_y)
    self._bubble_body:set_config(rt.settings.player_body.bubble_config)
    self._bubble_body:set_contraction(self._bubble_contraction_motion:get_value())
    self._bubble_body_mesh = nil
    self._bubble_body_mesh_data = nil
    self._bubble_body_contour = nil

    self._hair_body = rt.HairBody(
        0, 0,
        rt.settings.player.radius + rt.settings.player_body.hair_body_radius_offset,
        12
    )

    self._hair_body:set_anchor(center_x, center_y)
    self._hair_body:set_contraction(self._hair_contraction_motion:get_value())
    self._hair_body:set_config(rt.settings.player_body.hair_non_bubble_config)
    self._hair_body_mesh = nil
    self._hair_body_mesh_data = nil
    self._hair_body_contour = nil

    self._bubble_body_anchor_x_offset, self._bubble_body_anchor_y_offset = 0, 0
end

--- @brief
function rt.PlayerBody:relax()
    self._bubble_body:relax()
    self._core_body:relax()
    self._hair_body:relax()
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
                entry[8] = 1
            end

            vertex_i = vertex_i + 1
        end
    end

    -- hide overflow tris
    for i = vertex_i, #mesh_data do
        mesh_data[i][8] = 0
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

    return mesh, mesh_data, contour
end

function rt.PlayerBody:update(delta)
    self._bubble_contraction_motion:update(delta)
    self._hair_contraction_motion:update(delta)

    local gravity_x, gravity_y
    if self._state == rt.PlayerBodyState.BUBBLE then
        gravity_x, gravity_y = 0, 0
    else
        gravity_x, gravity_y = self._gravity_x, self._gravity_y
    end

    for body in range(self._core_body, self._hair_body, self._bubble_body) do
        body:set_gravity(gravity_x, gravity_y)
        body:update(delta)
    end

    self._triangulate_needed = true

    do
        local contraction = self._bubble_contraction_motion:get_value()
        self._bubble_body:set_contraction(contraction)
    end

    do
        local contraction = self._hair_contraction_motion:get_value()
        self._hair_body:set_contraction(contraction)
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
function rt.PlayerBody:set_body_stencil_bodies(t)
    self._body_stencil_bodies = t
end

--- @brief
function rt.PlayerBody:set_core_stencil_bodies(t)
    self._core_stencil_bodies = t
end

--- @brief
function rt.PlayerBody:set_colliding_bodies(t)
    local contours = {}
    for body in values(t) do
        local object = body:get_user_data()
        if object ~= nil and meta.is_function(object.get_contour) then
            local contour = object:get_contour()
            if contour ~= nil then
                if DEBUG then
                    if not meta.isa(contour, rt.Polyline) then
                        rt.error("In rt.PlayerBody.set_colliding_bodies: object `", meta.typeof(object), "` has a `get_contour` function, but it does not return a `rt.Polyline`")
                    end
                end
                table.insert(contours, contour)
            end
        end
    end

    self._collision_contours = contours
    self._bubble_body:set_collision_contours(contours)
    self._core_body:set_collision_contours(contours)
    self._hair_body:set_collision_contours(contours)
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
end

--- @brief
function rt.PlayerBody:_triangulate()
    local hair_body_contour = self._hair_body:get_draw_contour()
    self._hair_body_mesh, self._hair_body_mesh_datas, self._hair_body_contour = _triangulate(
        self._hair_body_mesh,
        self._hair_body_mesh_data,
        hair_body_contour
    )

    local bubble_body_contour = self._bubble_body:get_draw_contour()
    self._bubble_body_mesh, self._bubble_body_mesh_data, self._bubble_body_contour = _triangulate(
        self._bubble_body_mesh,
        self._bubble_body_mesh_data,
        bubble_body_contour
    )

    local contour = self._core_body:get_draw_contour()
    self._core_body_mesh, self._core_body_mesh_data, self._core_body_contour = _triangulate(
        self._core_body_mesh,
        self._core_body_mesh_data,
        contour
    )
end

--- @brief
function rt.PlayerBody:draw_body()
    if self._triangulate_needed then
        self:_triangulate()
        self._triangulate_needed = false
    end

    love.graphics.push("all")

    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    for body in values(self._body_stencil_bodies) do
        body:draw(true) -- mask only
    end
    
    self:_apply_transform()

    -- bodies
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)
        
    rt.Palette.BLACK:bind()
    self._hair_body_mesh:draw()
    self._bubble_body_mesh:draw()

    rt.graphics.set_stencil_mode(nil)

    love.graphics.pop()
end

local _draw_contour = function(contour)
    local data = contour:get_vertices()
    love.graphics.line(data)

    local fill_r = love.graphics.getLineWidth() / 2
    for i = 1, #data, 2 do
        local x, y = data[i + 0], data[i + 1]
        love.graphics.circle("fill", x, y, fill_r, 9)
    end
end

--- @brief
function rt.PlayerBody:draw_core()
    if self._triangulate_needed then
        self:_triangulate()
        self._triangulate_needed = false
    end

    love.graphics.push("all")

    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    for body in values(self._core_stencil_bodies) do
        body:draw(true) -- mask only
    end

    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

    self:_apply_transform()

    love.graphics.setLineWidth(2)
    love.graphics.setLineJoin("none")

    -- contours drawn here as they need to check against core stencil, not body stencil
    local r, g, b = self._color:unpack()

    local bubble_t = math.clamp(self._bubble_contraction_motion:get_value(), 0, 1)

    local angle = bubble_t * (math.pi / 2)
    local hair_alpha = math.cos(angle)
    local bubble_alpha = math.sin(angle)

    love.graphics.setColor(r, g, b, hair_alpha)
    _draw_contour(self._hair_body_contour)

    love.graphics.setColor(r, g, b, bubble_alpha)
    _draw_contour(self._bubble_body_contour)

    local core_shader = _core_type_to_shader[rt.GameState:get_player_body_core_type()]
    core_shader:bind()
    core_shader:send("hue", self._hue)
    core_shader:send("elapsed", rt.SceneManager:get_elapsed())
    core_shader:send("saturation",  self._saturation)
    core_shader:send("lch_texture", _lch_texture)
    love.graphics.setColor(1, 1, 1, self._opacity)
    self._core_body_mesh:draw()
    core_shader:unbind()

    love.graphics.setLineJoin("none")
    self._color:clone():lighten(0.2):bind()

    _draw_contour(self._core_body_contour)

    rt.graphics.set_stencil_mode(nil)

    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:set_position(x, y)
    meta.typecheck(x, mt.Number, y, mt.Number)
    self._position_x = x
    self._position_y = y
    self._core_body:set_anchor(x, y)
    self._bubble_body:set_anchor(x + self._bubble_body_anchor_x_offset, y + self._bubble_body_anchor_y_offset)
    self._hair_body:set_anchor(x, y)
end

--- @brief
function rt.PlayerBody:set_color(color)
    meta.typecheck(color, rt.RGBA)
    self._color = color
    self._hue = select(3, rt.rgba_to_lcha(self._color:unpack()))
end

--- @brief
function rt.PlayerBody:set_body_color(color)
    meta.typecheck(color, rt.RGBA)
    self._bubble_body_color = color
end

--- @brief
function rt.PlayerBody:set_core_color(color)
    self._color = color
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
        self._bubble_contraction_motion:set_value(0)
        self._bubble_contraction_motion:set_target_value(1)
        self._hair_contraction_motion:set_target_value(0)
        self._core_body:set_config(rt.settings.player_body.core_bubble_config)
        self._hair_body:set_config(rt.settings.player_body.hair_bubble_config)
        self._core_body:relax()
    elseif before == rt.PlayerBodyState.BUBBLE and state ~= rt.PlayerBodyState.BUBBLE then
        self._bubble_contraction_motion:set_target_value(0)
        self._hair_contraction_motion:set_value(0)
        self._hair_contraction_motion:set_target_value(1)
        self._core_body:set_config(rt.settings.player_body.core_non_bubble_config)
        self._hair_body:set_config(rt.settings.player_body.hair_non_bubble_config)
        self._core_body:relax()
    end
end

--- @brief
function rt.PlayerBody:draw_bloom()
    love.graphics.push("all")
    self:_apply_transform()
    self._color:bind()
    love.graphics.setLineWidth(1)
    self._core_body:get_draw_contour():draw()
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
    for body in range(self._core_body, self._bubble_body, self._hair_body) do
        body:set_gravity(gravity_x, gravity_y)
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

--- @brief
function rt.PlayerBody:set_is_disabled(b)
    self._is_disabled = b
end

--- @brief
function rt.PlayerBody:get_is_disabled()
    return self._is_disabled
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