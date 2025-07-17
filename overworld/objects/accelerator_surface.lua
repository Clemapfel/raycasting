
--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _body_shader, _outline_shader

local _first = true -- TODO

local _particle_texture, _particle_quads = nil, {}
local _vertex_counts = {}
do
    for _ = 1, 1 do table.insert(_vertex_counts, 3) end
    for _ = 1, 2 do table.insert(_vertex_counts, 4) end
    for _ = 1, 4 do table.insert(_vertex_counts, 5) end
    for _ = 1, 3 do table.insert(_vertex_counts, 6) end
    for _ = 1, 2 do table.insert(_vertex_counts, 7) end
end

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    if _particle_texture == nil then
        love.graphics.push("all")
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)

        local radius = 30
        local padding = 5
        local max_offset = 10
        local frame_w = 2 * radius + 2 * padding + 2 * max_offset
        local frame_h = frame_w

        local n_frames = #_vertex_counts
        local canvas_w = frame_w * n_frames
        local canvas_h = frame_h

        _particle_texture = rt.RenderTexture(canvas_w, canvas_h, 4)

        local frame_i = 1
        local center_x, center_y = 0.5 * frame_w, 0.5 * frame_h
        for n_vertices in values(_vertex_counts) do
            local vertices = {}
            local centroid_x, centroid_y = 0, 0
            for i = 1, n_vertices do
                local angle = (i - 1) *  (2 * math.pi) / n_vertices
                local length = radius + rt.random.number(-1, 1) * max_offset
                local dx, dy = math.cos(angle) * length, math.sin(angle) * length
                table.insert(vertices, dx)
                table.insert(vertices, dy)
                centroid_x = centroid_x + dx
                centroid_y = centroid_y + dy
            end

            centroid_x = centroid_x / n_vertices
            centroid_y = centroid_y / n_vertices

            local x, y = (frame_i - 1) * frame_w, 0
            local quad = love.graphics.newQuad(
                x, y,
                frame_w, frame_h,
                canvas_w, canvas_h
            )

            table.insert(_particle_quads, quad)

            love.graphics.push()
            _particle_texture:bind()
            love.graphics.translate(x + center_x - centroid_x, y + center_y - centroid_y)
            love.graphics.polygon("fill", vertices)
            love.graphics.pop()

            frame_i = frame_i + 1
        end

        love.graphics.pop()
    end

    if _first then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "c" then
                _body_shader:recompile()
                _outline_shader:recompile()
            end
        end)
        _first = false
    end

    if _body_shader == nil then _body_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 0 }) end
    if _outline_shader == nil then _outline_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 1 }) end

    self._scene = scene
    self._elapsed = 0
    self._particles = {}
    self._particle_elapsed = 0

    -- mesh
    self._contour = rt.round_contour(object:create_contour(), 10)
    self._mesh = object:create_mesh()

    -- collision
    do
        local shapes = {}
        local slick = require "dependencies.slick.slick"
        for shape in values(slick.polygonize(6, { self._contour })) do
            table.insert(shapes, b2.Polygon(shape))
        end

        self._body = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, 0, 0, shapes)
    end

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

    self._mesh = object:create_mesh()
    self._outline = object:create_contour()

    table.insert(self._outline, self._outline[1])
    table.insert(self._outline, self._outline[2])
end

function _get_friction(nx, ny, vx, vy)
    local dot = vx * nx + vy * ny
    local tangent_vx = vx - dot * nx
    local tangent_vy = vy - dot * ny

    if math.magnitude(tangent_vx, tangent_vy) == 0 then
        return 0, 0
    end

    return -tangent_vx, -tangent_vy
end

--- @brief
function ow.AcceleratorSurface:update(delta)
    if not self._scene:get_is_body_visible(self._body) then
        self._particles = {}
        return
    end

    local player = self._scene:get_player()
    self._elapsed = self._elapsed + delta * math.magnitude(player:get_velocity()) / 1000

    do
        if player:get_is_colliding_with(self._body) == true then
            self._particle_elapsed = self._particle_elapsed + delta
            local normal_x, normal_y = player:get_collision_normal(self._body)
            local velocity_x, velocity_y = math.normalize(player:get_velocity())
            local dx, dy = _get_friction(normal_x, normal_y, velocity_x, velocity_y)
            local px, py = player:get_contact_point(self._body)


            require "common.debug"
            local n_particle_per_second = math.mix(
                0,
                debugger.get("max"),
                rt.InterpolationFunctions.EXPONENTIAL_ACCELERATION(math.min(math.magnitude(dx, dy) * debugger.get("t"), 1))
            )
            local step = 1 / n_particle_per_second
            local min_speed, max_speed = 100, 200
            local min_lifetime, max_lifetime = 0.2, 0.5
            local min_scale, max_scale = 0.1, 0.4

            dx, dy = math.normalize(dx, dy)
            dx, dy = math.mix2(dx, dy, normal_x, normal_y, 0.5)

            while self._particle_elapsed > step do
                local speed = rt.random.number(min_speed, max_speed)
                local particle = {
                    x = px,
                    y = py,
                    velocity_x = dx * speed,
                    velocity_y = dy * speed,
                    elapsed = 0,
                    scale = rt.random.number(min_scale, max_scale),
                    lifetime = rt.random.number(min_lifetime, max_lifetime),
                    angle = rt.random.number(0, 2 * math.pi),
                    quad = rt.random.choose(_particle_quads),
                }

                table.insert(self._particles, particle)
                self._particle_elapsed = self._particle_elapsed - step
            end
        end

        local to_remove = {}
        for i, particle in ipairs(self._particles) do
            particle.x = particle.x + particle.velocity_x * delta
            particle.y = particle.y + particle.velocity_y * delta
            particle.elapsed = particle.elapsed + delta
            if particle.elapsed > particle.lifetime then
                table.insert(to_remove, i)
            end
        end

        if #to_remove > 0 then
            table.sort(to_remove, function(a, b) return a > b end)
            for i in values(to_remove) do
                table.remove(self._particles, i)
            end
        end
    end
end

--- @brief
function ow.AcceleratorSurface:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    local outline_width = 2
    local outline_color = rt.Palette.GRAY_3;
    love.graphics.setColor(1, 1, 1, 1)

    local offset_x, offset_y = self._scene:get_camera():get_offset()

    _body_shader:bind()
    _body_shader:send("camera_offset", { offset_x, offset_y })
    _body_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _body_shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position()) })
    _body_shader:send("elapsed", self._elapsed + meta.hash(self) * 100)
    _body_shader:send("outline_width", outline_width)
    _body_shader:send("outline_color", { outline_color:unpack() })
    _body_shader:send("player_hue", self._scene:get_player():get_hue())
    _body_shader:send("shape_centroid", { self._scene:get_camera():world_xy_to_screen_xy(self._body:get_center_of_mass())})
    love.graphics.push("all")
    self._mesh:draw()
    love.graphics.pop("all")
    _body_shader:unbind()

    outline_color:bind()
    _outline_shader:bind()
    _outline_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _outline_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _outline_shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position()) })
    _outline_shader:send("elapsed", self._elapsed + meta.hash(self) * 100)
    _outline_shader:send("noise_scale", 5)
    love.graphics.setLineWidth(outline_width)
    love.graphics.line(self._outline)

    _outline_shader:send("noise_scale", 20)

    local frame_h = _particle_texture:get_height()
    local texture = _particle_texture:get_native()
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, 1)
    for particle in values(self._particles) do
        love.graphics.draw(texture, particle.quad, particle.x, particle.y, particle.angle, particle.scale, particle.scale, 0.5 * frame_h, 0.5 * frame_h)
    end
    love.graphics.pop()

    _outline_shader:unbind()
end
