rt.settings.menu.stage_select_clouds = {
    top_fraction = 0.15,
    bottom_fraction = 1
}

--- @class mn.StageSelectClouds
mn.StageSelectClouds = meta.class("StageSelectClouds", rt.Widget)

local _shader = rt.Shader("menu/stage_select_clouds.glsl")

--- @brief
function mn.StageSelectClouds:instantiate()
    self._mesh = nil -- rt.Mesh
    self._hue = 0
    self._speedup = 1
    self._elapsed = 0
    self._opacity = 0

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then _shader:recompile() end
    end)
end

--- @brief
function mn.StageSelectClouds:size_allocate(x, y, width, height)
    local mesh_data = {}
    local add_vertex = function(x, y, u, v)
        table.insert(mesh_data, {
            x, y, u, v, 1, 1, 1, 1
        })
    end

    local w, h = width, height
    local top_fraction = rt.settings.menu.stage_select_clouds.top_fraction
    local bottom_fraction = rt.settings.menu.stage_select_clouds.bottom_fraction

    add_vertex(
        x, y + top_fraction * h,
        0, 0
    )

    add_vertex(
        x + 0.5 * w, y + bottom_fraction * h,
        0.5, 0
    )

    add_vertex(
        x + w, y + top_fraction * h,
        1, 0
    )

    add_vertex(
        x, y + bottom_fraction * h,
        0, 1
    )

    add_vertex(
        x + 0.5 * w, y + bottom_fraction * h + top_fraction * h,
        0.5, 1
    )

    add_vertex(
        x + w, y + bottom_fraction * h,
        1, 1
    )

    if self._mesh == nil then
        self._mesh = rt.Mesh(
            mesh_data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STATIC
        )

        self._mesh:set_vertex_map(
            1, 2, 4,
            2, 4, 5,
            3, 2, 6,
            2, 5, 6
        )
    else
        self._mesh:replace_data(mesh_data)
    end
end

--- @brief
function mn.StageSelectClouds:update(delta)
    self._elapsed = self._elapsed + (1 + self._speedup) * delta
end

--- @brief
function mn.StageSelectClouds:draw()
    if self._mesh == nil then return end

    _shader:bind()
    _shader:send("elapsed", self._elapsed)
    _shader:send("hue", self._hue)
    _shader:send("opacity", self._opacity)
    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
    _shader:unbind()
end

--- @brief
function mn.StageSelectClouds:set_hue(hue)
    self._hue = hue
end

--- @brief
function mn.StageSelectClouds:set_speedup(speedup)
    self._speedup = speedup
end

--- @brief
function mn.StageSelectClouds:set_opacity(opacity)
    self._opacity = opacity
end