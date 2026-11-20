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
}

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

local _lch_texture = rt.LCHTexture(256, 64, 256)

local _squished = 1
local _not_squished = 0

--- @brief
--- @brief
function rt.PlayerBody:instantiate(position_x, position_y)
    meta.typecheck(position_x, mt.Number, position_y, mt.Number)

    -- appearance
    self._core_color = rt.Palette.WHITE
    self._body_color = rt.Palette.BLACK
    self._hue = select(3, rt.rgba_to_lcha(self._core_color:unpack()))
    self._opacity = 1
    self._saturation = 1
    self._contraction = 0

    self._position_x = position_x
    self._position_y = position_y
    self._relative_velocity_x = 0
    self._relative_velocity_y = 0
    self._gravity_x = 0
    self._gravity_y = 0

    self._body = nil -- rt.Softbody
    self._body_outline = nil -- rt.Polyline
    self._core = nil -- rt.Softbody
    self._core_outline = nil -- rt.Polyline

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

    self._body_stencil_bodies = {}
    self._core_stencil_bodies = {}

    self._use_contour = true
    self._contour_radius = rt.settings.player.radius * rt.settings.player.bubble_radius_factor
    self._contour_transition_motion = rt.SmoothedMotion1D(0)
    self._contour_transition_motion:set_speed(
        rt.settings.player_body.contour_inflation_speed,
        rt.settings.player_body.contour_deflation_speed
    )

    self:_initialize()
end

local box_r = 200

--- @brief
function rt.PlayerBody:_initialize()
    local settings = rt.settings.player_body

    local center_x, center_y = 0, 0
    local core_radius = rt.settings.player.radius
    do
        local contour = {}
        local n_vertices = rt.Mesh.radius_to_n_vertices(core_radius)
        for i = 1, n_vertices do
            table.insert(contour, center_x + core_radius * math.cos((i - 1) / n_vertices * math.tau))
            table.insert(contour, center_y + core_radius * math.sin((i - 1) / n_vertices * math.tau))
        end

        contour = rt.Polyline(contour)
        self._core = rt.Softbody(contour)
        self._core:set_anchor(0, 0)
        self._core:set_is_anchored(true)
    end

    local x, y, w, h = center_x - box_r, center_y - box_r, 2 * box_r, 2 * box_r
    local collision = rt.Polyline(
        x + 0, y + 0,
        x + w, y + 0,
        x + w, y + h,
        x + 0, y + h
    ):close():reverse()

    self._core:set_collision_contours({
        collision
    })

    self._dbg_contour = collision

    self:update(0) -- init draw contours
end

function rt.PlayerBody:set_colliding_lines(t)
    -- TODO
end

--- @brief
function rt.PlayerBody:set_shape(vertices)
    self._core_outline = rt.Polyline(vertices)
    self._core:set_anchor(self._core_outline:get_centroid())
end

--- @brief
function rt.PlayerBody:relax()
    if self._body ~= nil then
        self._body:relax()
    end

    if self._core ~= nil then
        self._core:relax()
    end
end

function rt.PlayerBody:update(delta)
    if self._body ~= nil then
        self._body:update(delta)
    end

    if self._core ~= nil then
        self._core:clear_forces()
        self._core:add_linear_force(-self._relative_velocity_x, -self._relative_velocity_y)
        self._core:set_gravity(self._gravity_x, self._gravity_y)
        self._core:update(delta)
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

    self._body_stencil_bodies = t
    local contours = {}
    for body in values(t) do
        for contour in values(body:get_contours()) do
            table.insert(contours, rt.Polyline(contour))
        end
    end

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
    if self._body ~= nil then
        self._body:draw()
    end
    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:draw_core()
    love.graphics.push("all")
    self:_apply_transform()
    if self._core_outline ~= nil then
        self._core_outline:draw()
    end

    --[[
    love.graphics.origin()
    love.graphics.translate(box_r, box_r)
    love.graphics.setLineWidth(2)
    rt.Palette.TRUE_MAGENTA:bind()
    for contour in values(self._core:get_collision_contours()) do
        contour:draw()
    end

    love.graphics.line(self._dbg_contour:get_vertices())
    ]]

    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:set_position(x, y)
    meta.typecheck(x, mt.Number, y, mt.Number)
    self._position_x = x
    self._position_y = y
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
    self._body_color = color
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
function rt.PlayerBody:set_use_contour(b)
    self._use_contour = b
    self._contour_transition_motion:set_target_value(ternary(b, 1, 0))
end

--- @brief
function rt.PlayerBody:draw_bloom()
    love.graphics.push("all")
    self:_apply_transform()
    self._core_color:bind()
    if self._core_outline ~= nil then
        self._core_outline:draw()
    end
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

    if self._body ~= nil then
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
