require "common.mesh"
require "common.blend_mode"

rt.settings.overworld.player_body = {
    texture_scale = 4
}

--- @class ow.PlayerBody
ow.PlayerBody = meta.class("PlayerBody")

local _alpha = 1

--- @brief
function ow.PlayerBody:instantiate(player)
    self._player = player

    -- generate teardrop mesh
    -- see: https://mathworld.wolfram.com/TeardropCurve.html

    local n_outer_vertices = 32

    -- generate vertices
    local radius = player._radius * 0.5
    local x_radius = radius

    local n_bodies = rt.settings.overworld.player.n_outer_bodies
    local circumference = 2 * math.pi * radius
    local y_radius = (circumference / n_bodies) * 2 * 1.3

    local small_radius = player._spring_body_radius
    local cx, cy = 0, 0
    local vertices = {
        {cx, cy}
    }

    local m = 4
    local n = 0
    local step = 2 * math.pi / n_outer_vertices
    for angle = 0, 2 * math.pi + step, step do
        local x = cx + math.cos(angle) * x_radius
        local y = cy + (math.sin(angle) * math.sin(0.5 * angle)^m) * y_radius
        table.insert(vertices, {x, y})
        n = n + 1
    end

    -- calculate midpoint by weighing tris by area
    local total_area = 4 * math.sqrt(math.pi) * math.gamma((3 + m) / 2) / math.gamma(3 + m / 2)
    local x_sum, y_sum, tri_n = 0, 0, 0

    for i = 2, n do
        local i1, i2, i3 = i, i + 1, 1

        local x1, y1 = vertices[i1][1], vertices[i1][2]
        local x2, y2 = vertices[i2][1], vertices[i2][2]
        local x3, y3 = cx, cy
        local area = 0.5 * math.abs(x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
        local fraction = area / total_area

        x_sum = x_sum + (x1 + x2 + x3) * fraction
        y_sum = y_sum + (y1 + y2 + y3) * fraction
        tri_n = tri_n + 3 * fraction
    end

    do
        local x1, y1 = vertices[n-1][1], vertices[n-1][2]
        local x2, y2 = vertices[n][1], vertices[n][2]
        local x3, y3 = cx, cy
        local area = 0.5 * math.abs(x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
        local fraction = area / total_area

        x_sum = x_sum + (x1 + x2 + x3) * fraction
        y_sum = y_sum + (y1 + y2 + y3) * fraction
        tri_n = tri_n + 3 * fraction
    end

    local mid_x, mid_y = x_sum / tri_n, y_sum / tri_n
    vertices[1][1] = mid_x
    vertices[1][2] = mid_y

    -- generate mesh data
    local data = {}
    local indices = {}
    for i = 1, n do
        local x, y = vertices[i][1], vertices[i][2]

        local r, g, b, a
        if i == 1 then
            r, g, b, a = 1, 1, 1, 1
        else
            r, g, b, a = 1, 1, 1, _alpha
        end

        table.insert(data, {x, y,  0, 0,  r, g, b, a})

        if i < n then
            for index in range(i, i + 1, 1) do
                table.insert(indices, index)
            end
        end
    end

    for index in range(n, 1, 2) do
        table.insert(indices, index)
    end

    self._mesh = rt.Mesh(data, rt.MeshDrawMode.TRIANGLES)
    self._mesh:set_vertex_map(indices)
    self._mesh_origin_x, self._mesh_origin_y = mid_x, mid_y

    self._center = rt.MeshCircle(0, 0, 0.5 * (self._player._radius - self._player._spring_body_radius))
    for i = 1, self._center:get_n_vertices() do
        local r, g, b, a
        if i == 1 then
            r, g, b, a = 1, 1, 1, 1
        else
            r, g, b, a = 1, 1, 1, _alpha
        end
        self._center:set_vertex_color(i, r, g, b, a)
    end

    self._centers_x = {}
    self._centers_y = {}
    self._scales = {}
    self._centroid_x = 0
    self._centroid_y = 0

    local padding = player._max_spring_length - player._radius
    local scale = rt.settings.overworld.player_body.texture_scale
    self._texture = rt.RenderTexture(
        2 * radius * scale + 2 * padding * scale,
        2 * radius * scale + 2 * padding * scale,
        8
    )
    self._texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

    self._shader = rt.Shader("overworld/player_platform.glsl")
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "escape" then
            self._shader:recompile()
        end
    end)
end

--- @brief
function ow.PlayerBody:update()
    self._centers_x = {}
    self._centers_y = {}

    local x_sum, y_sum, n = 0, 0, 0
    local player_x, player_y = self._player._body:get_position()
    local small_radius = self._player._spring_body_radius
    for body in values(self._player._spring_bodies) do
        local x, y = body:get_position()
        local dx, dy = math.normalize(x - player_x, y - player_y)
        x, y = x - dx * small_radius * 2, y - dy * small_radius * 2
        table.insert(self._centers_x, x)
        table.insert(self._centers_y, y )

        x_sum = x_sum + x
        y_sum = y_sum + y
        n = n + 1
    end

    self._centroid_x, self._centroid_y = x_sum / n, y_sum / n

    self._scales = {}
    self._colors = {}

    for i, joint in ipairs(self._player._spring_joints) do
        local scale = math.max(1 + joint:get_distance() / (self._player._radius - self._player._spring_body_radius), 0)
        table.insert(self._scales, scale)

        table.insert(self._colors, rt.RGBA(rt.lcha_to_rgba(0.8, 1, i / n, 1)))
    end
end

--- @brief
function ow.PlayerBody:draw()
    --self._texture:bind()
    local scale = rt.settings.overworld.player_body.texture_scale / 2

    love.graphics.push()
    --love.graphics.origin()
    --love.graphics.clear(0, 0, 0, 0)
    local w, h = self._texture:get_size()
    --love.graphics.translate(0.5 * w, 0.5 * h)
    --love.graphics.scale(scale, scale)

    local player_x, player_y = self._player._body:get_predicted_position()

    rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.NORMAL)
    love.graphics.setColor(1, 1, 1, 1)

    --love.graphics.translate(-player_x, -player_y)
    for i, scale in ipairs(self._scales) do
        local x = self._centers_x[i]
        local y = self._centers_y[i]

        local origin_x = self._mesh_origin_x
        local origin_y = self._mesh_origin_y

        local angle = math.angle(x - player_x, y - player_y) + math.pi

        self._colors[i]:bind()
        love.graphics.draw(self._mesh._native,
            x, y,
            angle, -- rotation
            scale, 1, -- scale
            origin_x, origin_y -- origin
        )

        love.graphics.setPointSize(2)
    end

    love.graphics.setColor(1, 1, 1, 1)
    --love.graphics.draw(self._center._native, self._centroid_x, self._centroid_y)
    --love.graphics.draw(self._center._native, self._centroid_x, self._centroid_y)
    love.graphics.pop()

    rt.graphics.set_blend_mode(nil)
    --self._texture:unbind()

    --love.graphics.push()
    --self._shader:bind()
    --love.graphics.draw(self._texture._native, player_x - 0.5 * w / scale, player_y - 0.5 * h / scale, 0, 1 / scale, 1 / scale)

    --self._shader:unbind()
    --love.graphics.pop()
end
