--- @class ow.PlayerBody
ow.PlayerBody = meta.class("PlayerBody")

local _settings = rt.settings.overworld.player

--- @brief
function ow.PlayerBody:instantiate(player)
    self._hull_tris = {}
    self._hull_color = rt.Palette.BLACK:clone()
    self._hull_color.a = 0.2

    self._center_tris = {}
    self._outline = {}
    self._shader = rt.Shader("overworld/player_body.glsl")

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "c" then
            self._shader:recompile()
            dbg("recompile")
        end
    end)
end

--- @brief
function ow.PlayerBody:update(positions)
    local success, new_tris
    success, new_tris = pcall(love.math.triangulate, positions)
    if not success then
        success, new_tris = pcall(slick.triangulate, { positions })
        self._hull_tris = {}
    end

    if success then
        self._hull_tris = new_tris
    end

    local origin_x, origin_y = positions[1], positions[2]
    table.remove(positions, 1)
    table.remove(positions, 1)

    local center_x, center_y, n = 0, 0, 0

    local node_i = 0
    local n_nodes = #positions / 2
    for i = 1, #positions, 2 do
        local x1 = positions[i]
        local y1 = positions[((i + 0) % #positions) + 1]
        local x2 = positions[((i + 1) % #positions) + 1]
        local y2 = positions[((i + 2) % #positions) + 1]

        local hue = (node_i / n_nodes)
        local r, g, b, a = rt.lcha_to_rgba(0.8, 1, hue, 1)
        local entry = self._outline[i]
        if self._outline[i] == nil then
            entry = {
                x1 = x1,
                y1 = y1,
                x2 = x2,
                y2 = y2,
                r = r,
                g = g,
                b = b,
                a = a
            }
            self._outline[i] = entry
        else
            entry.x1 = x1
            entry.y1 = y1
            entry.x2 = x2
            entry.y2 = y2
            entry.r = r
            entry.g = g
            entry.b = b
            entry.a = a
        end

        center_x = center_x + x1
        center_y = center_y + y1
        n = n + 1

        node_i = node_i + 1
    end

    center_x, center_y = center_x / n, center_y / n
    self._center_x, self._center_y = origin_x, origin_y

    local mesh_data = {}

    for tri in values(self._hull_tris) do
        for i = 1, 6, 2 do
            local x = tri[i+0]
            local y = tri[i+1]
            local dx = x - center_x
            local dy = y - center_y

            local angle = math.angle(dx, dy)

            local alpha = 0
            if math.distance(x, y, origin_x, origin_y) >= 1 then
                table.insert(mesh_data, {
                    x, y, 0.5, 0.5, 1, 1, 1, 1
                })
            else
                table.insert(mesh_data, {
                    x, y,
                    0.5 + math.cos(angle) * 0.5,
                    0.5 + math.sin(angle) * 0.5,
                    1, 1, 1, 1
                })
            end
        end
    end

    self._mesh = rt.Mesh(mesh_data)
end

--- @brief
function ow.PlayerBody:draw(is_bubble)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self._center_x, self._center_y, rt.settings.overworld.player.radius * 0.5)

    rt.Palette.BLACK:bind()
    self._shader:bind()
    love.graphics.draw(self._mesh:get_native())
    self._shader:unbind()

    love.graphics.setLineWidth(1)
    for entry in values(self._outline) do
        love.graphics.setColor(entry.r, entry.g, entry.b, entry.a)
        love.graphics.line(entry.x1, entry.y1, entry.x2, entry.y2)
    end


end