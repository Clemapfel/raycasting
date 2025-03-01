require "include"
require "common.mesh"
require "common.render_texture"
require "common.shader"
require "common.compute_shader"

local SceneManager = require "common.scene_manager"

--- @class
rt.Cilia = meta.class("CiliaBackground")

function rt.Cilia:instantiate(resolution_x, resolution_y)
    self._elapsed = 0

    self._resolution_x = resolution_x
    self._resolution_y = resolution_y
    self._line_width = 2.5
    self._n_instances = self._resolution_x * self._resolution_y

    self._line_instance_mesh = rt.MeshRectangle(
        0, 0, 0, 0
    )

    self._circle_instance_mesh = rt.MeshCircle(
        0, 0, self._line_width / 2
    )

    self._noise_texture = rt.RenderTexture(
        self._resolution_x, self._resolution_y, 0,
        rt.TextureFormat.R32F,
        true
    ) -- r: value

    self._noise_texture:set_wrap_mode(rt.TextureWrapMode.MIRROR)

    self._derivative_texture = rt.RenderTexture(
        self._resolution_x, self._resolution_y, 0,
        rt.TextureFormat.RGBA32F,
        true
    ) -- r: dFdx, g: dFdy, b: noise

    self._update_noise_shader = rt.ComputeShader("playground/cilia/cilia_compute.glsl", { MODE = 0 })
    self._update_derivative_shader = rt.ComputeShader("playground/cilia/cilia_compute.glsl", { MODE = 1 })

    self._update_noise_shader:send("elapsed", self._elapsed)
    self._update_noise_shader:send("noise_texture", self._noise_texture)

    self._update_derivative_shader:send("noise_texture", self._noise_texture)
    self._update_derivative_shader:send("derivative_texture", self._derivative_texture)

    function self:_update_texture()
        local dispatch_x, dispatch_y = math.ceil(self._resolution_x / 16), math.ceil(self._resolution_y / 16)
        self._update_noise_shader:send("elapsed", self._elapsed)
        self._update_noise_shader:dispatch(dispatch_x, dispatch_y)
        self._update_derivative_shader:dispatch(dispatch_x, dispatch_y)
    end

    self._draw_line_shader = rt.Shader("playground/cilia/cilia_draw_instances.glsl", { MODE = 0 })
    self._draw_circle_shader = rt.Shader("playground/cilia/cilia_draw_instances.glsl", { MODE = 1 })

    for shader in range(self._draw_line_shader, self._draw_circle_shader) do
        shader:send("derivative_texture", self._derivative_texture)
        shader:send("image_size", {self._resolution_x, self._resolution_y})
        shader:send("line_width", self._line_width)
        shader:send("line_length", math.max(
            1 / self._resolution_x * love.graphics.getWidth(),
               1 / self._resolution_y * love.graphics.getHeight()
        ))
    end

    function self:_draw_instances()
        self._draw_line_shader:send("screen_size", { love.graphics.getWidth(), love.graphics.getHeight() })
        self._draw_circle_shader:send("screen_size", { love.graphics.getWidth(), love.graphics.getHeight() })
        love.graphics.setColor(1, 1, 1, 1)

        self._draw_circle_shader:bind()
        self._circle_instance_mesh:draw_instanced(self._n_instances)
        self._draw_circle_shader:unbind()

        self._draw_line_shader:bind()
        self._line_instance_mesh:draw_instanced(self._n_instances)
        self._draw_line_shader:unbind()
    end

    self._noise_mesh = rt.MeshRectangle(0, 0, love.graphics.getDimensions())
    self._noise_mesh:set_texture(self._noise_texture)
    function self:_draw_noise()
        self._noise_mesh:draw()
    end

    self._derivative_mesh = rt.MeshRectangle(0, 0, love.graphics.getDimensions())
    self._derivative_mesh:set_texture(self._derivative_texture)
    function self:_draw_derivative()
        self._derivative_mesh:draw()
    end
end

--- @brief
function rt.Cilia:update(delta)
    self._elapsed = self._elapsed + delta / 15
    self._derivative_texture:bind()
    love.graphics.clear(0, 0, 0, 0)
    self._derivative_texture:unbind()

    self:_update_texture()
end

--- @brief
function rt.Cilia:draw()
    --self:_draw_noise()
    --self:_draw_derivative()
    self:_draw_instances()
end

local cilia
love.keypressed = function(which)
    if which == "space" then
        cilia:instantiate(cilia._resolution_x, cilia._resolution_y)
    end
end

-- ###

love.load = function()
    love.window.updateMode(
        800, 800, {
        msaa = 4,
        vsync = -1
    })
    cilia = rt.Cilia(75, 75)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    cilia:draw()

    SceneManager:draw()
end

love.update = function(delta)
    cilia:update(delta)
end

