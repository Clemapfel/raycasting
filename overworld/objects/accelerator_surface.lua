
--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _particle_texture = nil

local _texture_shader, _derivative_shader, _normal_map_shader

local _instances = {}

function ow.AcceleratorSurface:reinitialize()
    _instances = {}
end

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    if _texture_shader == nil then _texture_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 0 }) end
    if _derivative_shader == nil then _derivative_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 1 }) end
    if _normal_map_shader == nil then _normal_map_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 2 }) end

    self._scene = scene
    table.insert(_instances, self)

    -- mesh
    self._contour = rt.round_contour(object:create_contour(), 10)
    do
        local triangulation = rt.DelaunayTriangulation(self._contour, self._contour):get_triangle_vertex_map()
        local mesh_data = {}
        for i = 1, #self._contour, 2 do
            table.insert(mesh_data, {
                self._contour[i+0],
                self._contour[i+1]
            })
        end
        self._mesh = rt.Mesh(
            mesh_data,
            rt.MeshDrawMode.TRIANGLES,
            {{
                location = rt.VertexAttributeLocation.POSITION,
                name = rt.VertexAttribute.POSITION,
                format = "floatvec2"
            }},
            rt.GraphicsBufferUsage.STATIC
        )
        self._mesh:set_vertex_map(triangulation)
    end

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
end

local _canvas, _swap

--- @brief
function ow.AcceleratorSurface:draw_all()
    if _canvas == nil or _canvas:get_width() ~= love.graphics.getWidth() or _canvas:get_height() ~= love.graphics.getHeight() then
        local w, h = love.graphics.getDimensions()
        _canvas = rt.RenderTexture(w, h, 0, rt.TextureFormat.R8)
    end

    if _swap == nil or _swap:get_width() ~= love.graphics.getWidth() or _swap:get_height() ~= love.graphics.getHeight() then
        local w, h = love.graphics.getDimensions()
        _swap = rt.RenderTexture(w, h, 0, rt.TextureFormat.RG16F)
    end

    -- render masked texture to canvas
    _canvas:bind()
    love.graphics.clear(0, 0, 0, 0)

    _texture_shader:bind()
    local drawn = {}
    for instance in values(_instances) do
        if instance._scene:get_is_body_visible(instance._body) then
            if #drawn == 0 then
                _texture_shader:send("elapsed", rt.SceneManager:get_elapsed())
                _texture_shader:send("camera_scale", instance._scene:get_camera():get_final_scale())
                _texture_shader:send("camera_offset", { instance._scene:get_camera():get_offset() })
            end
            instance._mesh:draw()
            table.insert(drawn, instance)
        end
    end

    _texture_shader:unbind()
    _canvas:unbind()

    if #drawn == 0 then return end

    -- compute derivative of texture
    love.graphics.push()
    love.graphics.origin()
    _swap:bind()
    love.graphics.clear(0, 0, 0, 0)
    _derivative_shader:bind()
    _canvas:draw()
    _derivative_shader:unbind()
    _swap:unbind()
    love.graphics.pop()

    -- draw normal map
    love.graphics.push()
    love.graphics.origin()
    _normal_map_shader:bind()
    _swap:draw()
    _normal_map_shader:unbind()
    love.graphics.pop()

    love.graphics.setLineWidth(3)
    rt.Palette.BLACK:bind()
    for instance in values(drawn) do
        love.graphics.line(instance._contour)
    end
end