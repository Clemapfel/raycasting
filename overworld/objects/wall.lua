rt.settings.overworld.wall = {
    texture_format = rt.TextureFormat.RGBA8,
    work_group_size_x = 16,
    work_group_size_y = 16,
    texture_size = 1024 * 4,
    world_size = 2048,
}

local schema = {
    opacity = ow.Number,
    type = ow.String
}

--- @class ow.Wall
ow.Wall = meta.class("Wall")

--- @enum ow.WallPatternType
ow.WallPatternType = meta.enum("WallPatternType", {
    FLAT = "FLAT",
    SQUARES = "SQUARES",
    SPHERES = "SPHERES",
    TRIANGLES = "TRIANGLES",
    HEXAGONS = "HEXAGONS"
})

local _textures_initialized = false
local _pattern_type_to_texture = {}
local _pattern_type_to_ambient = {}
local _pattern_to_scale = {}

local _draw_shader = rt.Shader("overworld/objects/wall_draw.glsl")

function ow.Wall:instantiate(object, stage, scene)
    if _textures_initialized ~= true then
        ow.Wall._initialize_textures()

        DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
            if which == rt.KeyboardKey.CIRCUMFLEX then
                ow.Wall._initialize_textures()
            end
        end)

        _textures_initialized = true
    end
    object:validate_schema(schema, ow.ShapeType.NOT_A_POINT)

    self._scene = scene
    self._stage = stage
    self._mesh = object:create_mesh()
    self._contour = rt.contour.close(object:create_contour())

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_collision_group(0x0)
    self._body:set_collides_with(0x0)
    self._body:add_tag(b2.Tag.USE_LIGHTING)

    self._opacity = object:get_number("opacity") or rt.Palette.WALL.a

    local pattern = object:get_string("type") or ow.WallPatternType.FLAT
    self._pattern = string.upper(pattern)
    meta.assert(self._pattern, ow.WallPatternType)

    local texture = _pattern_type_to_texture[self._pattern]
    local mesh = self._mesh
    mesh:set_texture(texture)

    local size_x, size_y = texture:get_size()
    local pattern_world_size = rt.settings.overworld.wall.world_size
    local world_size_x = size_x / size_y * pattern_world_size
    local world_size_y = pattern_world_size
    for i = 1, mesh:get_n_vertices() do
        local x, y = mesh:get_vertex_attribute(i, 1)
        mesh:set_vertex_attribute(i, 2, x / world_size_x, y / world_size_y)
    end

    if ow.Wall._impulse == nil then
        ow.Wall._impulse = rt.ImpulseSubscriber()
    end
end

--- @brief
function ow.Wall:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push("all")
    _draw_shader:bind()

    local light_map = rt.SceneManager:get_light_map()
    _draw_shader:send("light_intensity", light_map:get_light_intensity())
    _draw_shader:send("light_direction", light_map:get_light_direction())
    _draw_shader:send("wall_texture", _pattern_type_to_texture[self._pattern])
    _draw_shader:send("ambient", _pattern_type_to_ambient[self._pattern])

    local r, g, b =  rt.Palette.WALL:unpack()
    love.graphics.setColor(r, g, b, self._opacity)
    self._mesh:draw()
    _draw_shader:unbind()

    rt.Palette.WALL_OUTLINE:bind()
    love.graphics.setLineWidth(rt.settings.overworld.hitbox.slippery_outline_width)
    love.graphics.line(self._contour)

    love.graphics.pop()
end

function ow.Wall:get_render_priority()
    return -math.huge
end

function ow.Wall._initialize_textures() -- sic, static
    local size = rt.settings.overworld.wall.texture_size
    local get_size = function(x_ratio, y_ratio)
        if y_ratio == nil then y_ratio = x_ratio end
        x_ratio = y_ratio / x_ratio
        y_ratio = 1

        return { x_ratio * size, y_ratio * size }
    end

    local type_to_texture_size = {
        [ow.WallPatternType.FLAT] = { 1, 1 },
        [ow.WallPatternType.SQUARES] = get_size(1, math.sqrt(2)),
        [ow.WallPatternType.SPHERES] = get_size(1, math.sqrt(3) / 3),
        [ow.WallPatternType.TRIANGLES] = get_size(2, 2 * math.sqrt(3)),
        [ow.WallPatternType.HEXAGONS] = get_size(1, 1)
    }

    local get_ambient = function(x, y, z, intensity)
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        if z == nil then z = 0.5 end
        if intensity == nil then intensity = 0.5 end
        return { x, y, 0.5, intensity }
    end

    _pattern_type_to_ambient = {
        [ow.WallPatternType.FLAT] = get_ambient(0, 0, 0, 0),
        [ow.WallPatternType.SQUARES] = get_ambient(0),
        [ow.WallPatternType.SPHERES] = get_ambient(-1, -1, 0.5, 0.3),
        [ow.WallPatternType.TRIANGLES] = get_ambient(-1, -1, 0.5, 0.3),
        [ow.WallPatternType.HEXAGONS] = get_ambient(1)
    }

    for texture in values(_pattern_type_to_texture) do
        texture:free()
    end

    for i, type in ipairs({
        ow.WallPatternType.FLAT, -- 1
        ow.WallPatternType.SPHERES, -- 2
        ow.WallPatternType.TRIANGLES, -- 3
        ow.WallPatternType.SQUARES, -- 4
        ow.WallPatternType.HEXAGONS -- 5
    }) do
        local settings = rt.settings.overworld.wall
        local size_x, size_y = table.unpack(type_to_texture_size[type])
        local work_group_size_x, work_group_size_y = settings.work_group_size_x, settings.work_group_size_y

        local texture = rt.RenderTexture(size_x, size_y, {
            is_compute = true,
            format = settings.texture_format
        })

        local dispatch_x, dispatch_y = math.ceil(size_x / work_group_size_x),
            math.ceil(size_y / work_group_size_y)

        local shader = rt.ComputeShader("overworld/objects/wall_compute.glsl", {
            PATTERN_TYPE = i,
            TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(settings.texture_format),
            WORK_GROUP_SIZE_X = work_group_size_x,
            WORK_GROUP_SIZE_Y = work_group_size_y
        })

        shader:send("texture", texture)
        shader:dispatch(dispatch_x, dispatch_y)

        texture:set_wrap_mode(rt.TextureWrapMode.REPEAT)
        texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
        _pattern_type_to_texture[type] = texture
    end

    _draw_shader:recompile()
end
