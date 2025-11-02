
--- @class ow.Wall
ow.Wall = meta.class("Wall")

local _shader = rt.Shader("overworld/objects/wall.glsl")

-- global batching
local _tris = {}
local _lines = {}
local _mesh = nil

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "k" then _shader:recompile() end
end)

function ow.Wall:instantiate(object, stage, scene)
    local _, tris = object:create_mesh()
    for tri in values(tris) do
        table.insert(_tris, tri)
    end

    local contour =  object:create_contour()
    table.insert(contour, contour[1])
    table.insert(contour, contour[2])
    table.insert(_lines, contour)
end

--- @brief
function ow.Wall:reinitialize()
    _tris = {}
    _lines = {}
    _mesh = nil
end

local _try_initialize = function()
    if _mesh ~= nil then return end -- already initialized

    local data = {}
    local format = { {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"} }
    local mode, usage = rt.MeshDrawMode.TRIANGLES, rt.GraphicsBufferUsage.STATIC

    for tri in values(_tris) do
        table.insert(data, { tri[1], tri[2] })
        table.insert(data, { tri[3], tri[4] })
        table.insert(data, { tri[5], tri[6] })
    end

    _mesh = love.graphics.newMesh(format, data, mode, usage)
end

--- @brief
function ow.Wall:draw_all(camera, point_light_sources, point_light_colors, segment_light_sources, segment_light_colors)
    _try_initialize()

    love.graphics.setColor(1, 1, 1, 1)

    local scene = rt.SceneManager:get_current_scene()

    local point_local = {}
    for source in values(point_light_sources) do
        table.insert(point_local, { camera:world_xy_to_screen_xy(table.unpack(source))})
    end

    local segment_local = {}
    for source in values(segment_light_sources) do
        local ax, ay = camera:world_xy_to_screen_xy(source[1], source[2])
        local bx, by = camera:world_xy_to_screen_xy(source[3], source[4])
        table.insert(segment_local, { ax, ay, bx, by })
    end

    rt.Palette.WALL:bind()
    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("n_point_lights", #point_local)
    if #point_local > 0 then
        _shader:send("point_lights", table.unpack(point_local))
        _shader:send("point_colors", table.unpack(point_light_colors))
    end

    _shader:send("n_segment_lights", #segment_local)
    if #segment_local > 0 then
        _shader:send("segment_lights", table.unpack(segment_local))
        _shader:send("segment_colors", table.unpack(segment_light_colors))
    end
    _shader:send("screen_to_world_transform", camera:get_transform():inverse())
    _shader:send("outline_color", { rt.Palette.WALL:unpack() })
    love.graphics.draw(_mesh)
    _shader:unbind()


    rt.Palette.WALL_OUTLINE:bind()
    love.graphics.setLineWidth(rt.settings.overworld.hitbox.outline_width)
    for line in values(_lines) do
        love.graphics.line(line)
    end
end


