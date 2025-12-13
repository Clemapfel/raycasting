rt.settings.menu.stage_select_clouds = {
    depression_t = 0.9, -- fraction
    rim_t = 1 -- fraction
}

--- @class mn.StageSelectClouds
mn.StageSelectClouds = meta.class("StageSelectClouds", rt.Widget)

local _shader = rt.Shader("menu/stage_select_clouds.glsl")

--- @brief
function mn.StageSelectClouds:instantiate()
    self._mesh = nil -- rt.Mesh

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

    local t = rt.settings.menu.stage_select_clouds.depression_t
    local w, h = width, height
    local rim_h = rt.settings.menu.stage_select_clouds.rim_t * h

    -- base
    add_vertex(
        x, y + rim_h,
        1, 1
    )


    add_vertex(
        x + 0.5 * w, y + t * h + rim_h,
        1, 1
    )

    add_vertex(
        x + w, y + rim_h,
        1, 1
    )

    add_vertex(
        x, y + h,
        1, 1
    )

    add_vertex(
        x + w, y + h,
        1, 1
    )

    -- rim
    add_vertex(
        x, y,
        0, 0
    )

    add_vertex(
        x + 0.5 * w, y + t * h,
        0, 0
    )

    add_vertex(
        x + w, y,
        0, 0
    )

    if self._mesh == nil then
        self._mesh = rt.Mesh(
            mesh_data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STATIC
        )

        self._mesh:set_vertex_map(
            1, 2, 4, -- left
            3, 2, 5, -- right
            4, 2, 5, -- bottom center

            6, 7, 1, -- rim quads
            7, 1, 2,
            8, 7, 3,
            7, 3, 2
        )
    else
        self._mesh:replace_data(mesh_data)
    end
end

--- @brief
function mn.StageSelectClouds:draw()
    if self._mesh == nil then return end

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
    _shader:unbind()
end
