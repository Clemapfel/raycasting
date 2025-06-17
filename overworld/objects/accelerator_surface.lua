require "common.contour"

--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _draw_shader

-- particles
local _particle_texture
local _particle_left, _particle_right = 1, 2
local _particle_which_to_quad = {}

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    if _draw_shader == nil then _draw_shader = rt.Shader("overworld/objects/accelerator_surface_draw.glsl") end
    self._scene = scene

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "l" then
            _draw_shader:recompile()
        end
    end)

    -- collision
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag(
        "use_friction",
        "stencil",
        "slippery"
    )
    self._body:set_friction(object:get_number("friction") or -1)
    self._body:set_user_data(self)
    self._body:set_collides_with(bit.bor(
        rt.settings.player.player_collision_group,
        rt.settings.player.player_outer_body_collision_group
    ))

    self._is_active = false
    self._body:signal_connect("collision_start", function()
        self._is_active = true
        self:update(0)
    end)

    -- graphics
    self._contour = object:create_contour()
    table.insert(self._contour, self._contour[1])
    table.insert(self._contour, self._contour[2])

    self._mesh = object:create_mesh()

    -- particles

    if _particle_texture == nil then
        local padding = 5
        local canvas_w = 100 * rt.get_pixel_scale()
        _particle_texture = rt.RenderTexture(2 * (canvas_w + 2 * padding), canvas_w + 2 * padding)

        local left_x = padding + 0.5 * canvas_w
        local right_x = padding + canvas_w + padding + padding + 0.5 * canvas_w
        local y = 0.5 * (canvas_w + padding)

        _particle_texture:bind()

        -- left_particle
        local mesh = rt.MeshCircle(0, 0, 0.5 * canvas_w)
        for i = 2, mesh:get_n_vertices() do
            mesh:set_vertex_color(i, 1, 1, 1, 0.0)
        end

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(mesh:get_native(), left_x, y)

        _particle_which_to_quad[_particle_left] = love.graphics.newQuad(
            0, 0, canvas_w + 2 * padding, canvas_w + 2 * padding, _particle_texture:get_size()
        )

        -- right particle
        love.graphics.setLineWidth(2 * rt.get_pixel_scale())
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("line", right_x, y, 0.5 * canvas_w)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.circle("fill", right_x, y, 0.5 * canvas_w)

        _particle_which_to_quad[_particle_right] = love.graphics.newQuad(
            padding + canvas_w + padding, 0, canvas_w + 2 * padding, canvas_w + 2 * padding, _particle_texture:get_size()
        )

        _particle_texture:unbind()
    end
end

--- @brief
function ow.AcceleratorSurface:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end
end

--- @brief
function ow.AcceleratorSurface:draw()
    love.graphics.setColor(1, 1, 1, 0.5)
    
    _draw_shader:bind()
    _draw_shader:send("elapsed", rt.SceneManager:get_elapsed())
    local scene = rt.SceneManager:get_current_scene()
    local camera = scene:get_camera()
    local player = scene:get_player()
    _draw_shader:send("camera_offset", { scene:get_camera():get_offset() })
    _draw_shader:send("camera_scale", scene:get_camera():get_scale())
    _draw_shader:send("player_position", { camera:world_xy_to_screen_xy(player:get_physics_body():get_position()) })
    _draw_shader:send("player_color", { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1)})
    _draw_shader:send("player_flow", player:get_flow())
    love.graphics.draw(self._mesh:get_native())
    _draw_shader:unbind()

    love.graphics.setLineWidth(4)
    rt.Palette.BLACK:bind()
    love.graphics.line(self._contour)

    rt.Palette.WHITE:bind()
    love.graphics.line(self._contour)

    love.graphics.origin()
    love.graphics.clear()
    love.graphics.draw(_particle_texture:get_native(), _particle_which_to_quad[_particle_left])
    love.graphics.draw(_particle_texture:get_native(), _particle_which_to_quad[_particle_right])
end