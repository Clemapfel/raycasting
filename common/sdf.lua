require "common.compute_shader"

--- @class SDF
rt.SDF = meta.class("SDF")

local _sdf_texture_config = {
    format = rt.TextureFormat.RGBA32F,
    computewrite = true
} -- xy: nearest true wall pixel or gradient, z: distance

local _hitbox_texture_config = {
    format = rt.TextureFormat.RGBA8,
    computewrite = true,
    msaa = 4
} -- r: is wall

rt.SDFWallMode = meta.enum("SDFMode", {
    BOTH = 0,   -- computed everywhere
    INSIDE = 1, -- only computed inside hitbox
    OUTSIDE = 2 -- only computed outside hitbox
})

--- @brief
function rt.SDF:instantiate(width, height)
    meta.assert(width, "Number", height, "Number")

    self._area_w, self._area_h = width, height
    self._sdf_draw_shader = rt.Shader("common/sdf_draw.glsl")
    self._sdf_init_shader = rt.ComputeShader("common/sdf_compute.glsl", {MODE = 0})
    self._sdf_step_shader = rt.ComputeShader("common/sdf_compute.glsl", {MODE = 1})
    self._sdf_compute_gradient_shader = rt.ComputeShader("common/sdf_compute.glsl", {MODE = 2})

    self._hitbox_texture = love.graphics.newCanvas(self._area_w, self._area_h, _hitbox_texture_config)
    self._sdf_texture_a = love.graphics.newCanvas(self._area_w, self._area_h, _sdf_texture_config)
    self._sdf_texture_b = love.graphics.newCanvas(self._area_w, self._area_h, _sdf_texture_config)
    self._draw_texture = self._hitbox_texture

    for name_value in range(
        {"input_texture", self._sdf_texture_a},
        {"output_texture", self._sdf_texture_b}
    ) do
        self._sdf_init_shader:send(table.unpack(name_value))
        self._sdf_step_shader:send(table.unpack(name_value))
    end
    self._sdf_init_shader:send("hitbox_texture", self._hitbox_texture)
    self._is_gradient = false

    self:set_wall_mode(rt.SDFWallMode.BOTH)
end

local _before = nil

--- @brief
function rt.SDF:bind()
    _before = love.graphics.getCanvas()
    love.graphics.setCanvas(self._hitbox_texture)
end

--- @brief
function rt.SDF:unbind()
    love.graphics.setCanvas(_before)
end

--- @brief
function rt.SDF:set_wall_mode(mode)
    self._wall_mode = mode
    for shader in range(
        self._sdf_draw_shader,
        self._sdf_init_shader,
        self._sdf_step_shader,
        self._sdf_compute_gradient_shader
    ) do
        shader:send("wall_mode", self._wall_mode)
    end
end

--- @brief
function rt.SDF:compute(compute_gradient)
    if compute_gradient == nil then compute_gradient = false end

    -- jump flood fill
    local dispatch_size_x, dispatch_size_y = math.ceil(self._area_w) / 32 + 1, math.ceil(self._area_h) / 32 + 1
    self._sdf_init_shader:dispatch(dispatch_size_x, dispatch_size_y)

    local jump = 0.5 * math.min(self._area_w, self._area_h)
    local jump_a_or_b = true
    while jump >= 0.5 do -- JFA+1
        if jump_a_or_b then
            self._sdf_step_shader:send("input_texture", self._sdf_texture_a)
            self._sdf_step_shader:send("output_texture", self._sdf_texture_b)
        else
            self._sdf_step_shader:send("input_texture", self._sdf_texture_b)
            self._sdf_step_shader:send("output_texture", self._sdf_texture_a)
        end

        self._sdf_step_shader:send("jump_distance", math.ceil(jump))
        self._sdf_step_shader:dispatch(dispatch_size_x, dispatch_size_y)

        jump_a_or_b = not jump_a_or_b
        jump = jump / 2
    end

    if jump_a_or_b then
        self._sdf_compute_gradient_shader:send("input_texture", self._sdf_texture_a)
        self._sdf_compute_gradient_shader:send("output_texture", self._sdf_texture_b)
        self._draw_texture = self._sdf_texture_b
    else
        self._sdf_compute_gradient_shader:send("input_texture", self._sdf_texture_b)
        self._sdf_compute_gradient_shader:send("output_texture", self._sdf_texture_a)
        self._draw_texture = self._sdf_texture_a
    end

    if compute_gradient == true then
        self._sdf_compute_gradient_shader:dispatch(dispatch_size_x, dispatch_size_y)
    end

    self._is_gradient = compute_gradient
end

--- @brief
function rt.SDF:get_texture()
    return self._hitbox_texture
end

--- @brief
function rt.SDF:get_sdf_texture()
    return self._draw_texture
end

--- @brief
function rt.SDF:draw(...)
    self._sdf_draw_shader:bind()
    self._sdf_draw_shader:send("is_gradient", self._is_gradient)
    love.graphics.draw(self._draw_texture, ...)
    self._sdf_draw_shader:unbind()
end