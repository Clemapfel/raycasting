StageList_t = "StageList"
Stage_t = "Stage"

local _settings_contour_texture_scale = 1 / 100
local _settings_default_player_radius = 32
local _settings_spawn_dx = 0
local _settings_spawn_dy = -1

local _settings_outline_width = 3
local _settings_line_width = 1

-- tiled classes
local _contour_t = "Contour"
local _stage_t = "Stage"
local _spawn_t = "Spawn"

local _winding_clockwise = true
local _winding_counterclockwise = false

stage_list_new = function()
    return object_new(StageList_t, {
        stage_name_to_entry = {}
    })
end

stage_list_export = function(self, in_path, out_path)
    log_typecheck(self, StageList_t, in_path, String_t, out_path, String_t)

    self.path = in_path

    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, self.path)
    if not load_success then
        log_error("In stage_list_init: error when parsing file at `", self.path, "`: ", chunk_or_error)
        return self
    end

    if love_error ~= nil then
        log_error("In stage_list_init: error when loading file at `", self.path, "`: ", love_error)
        return self
    end

    local chunk_success, value_or_error = pcall(chunk_or_error)
    if not chunk_success then
        log_error("In stage_list_init: error when running file at `", self.path, "`: ", value_or_error)
        return self
    end

    local config = value_or_error

    local get = function(t, key)
        local value = t[key]
        if value == nil then
            log_error("In stage_list_init: trying to access property `", key, "` of config, but it does not exist")
        end
        return value
    end

    local name_to_bounds = {}
    local contours = {}
    local contour_to_priority = {}

    local spawn_points = {}
    local spawn_point_to_radius = {}

    local draw_order = 0 -- sequential render priority
    self.stage_name_to_entry = {}

    local layers = get(config, "layers")
    for layer_i, layer in ipairs(layers) do
        local layer_name = get(layer, "name")
        local layer_type = get(layer, "type")
        local layer_offset_x, layer_offset_y = get(layer, "offsetx"), get(layer, "offsety")
        if layer_type == "objectgroup" then
            local objects = get(layer, "objects")
            for object_i, object in ipairs(objects) do
                local id = get(object, "id")
                local class = get(object, "type")

                local assert = function(condition, ...)
                    log_assert(condition, "In stage_list_init: for stage `", self.path, "`, on layer `", layer, "`, for object `", id, "`: ", ...)
                end

                if class == _stage_t then
                    assert(get(object, "shape") == "rectangle", "object has class `", _stage_t, "`, but it is not a rectangle")

                    local name = get(object, "name")
                    assert(name ~= nil, "object has class `", _stage_t, "` but it does not have `name` set")

                    name_to_bounds[name] = aabb_new(
                        get(object, "x") + layer_offset_x,
                        get(object, "y") + layer_offset_y,
                        get(object, "width"),
                        get(object, "height")
                    )

                elseif class == _contour_t then
                    assert(get(object, "shape") == "polygon", "object has class `", _contour_t, "`, but it is not a polygon")
                    local offset_x = get(object, "x") + layer_offset_x
                    local offset_y = get(object, "y") + layer_offset_y

                    local winding = get(object, "properties")["winding"]
                    if winding == nil then winding = _winding_clockwise end

                    local points = get(object, "polygon")
                    local n_nodes = table_sizeof(points)
                    local from, to, step
                    if winding == _winding_counterclockwise then
                        from, to, step = n_nodes, 1, -1
                    elseif winding == _winding_clockwise then
                        from, to, step = 1, n_nodes, 1
                    else
                        assert(object_is_boolean(winding), "object has class `", _contour_t, "`, but property `winding` is not a boolean")
                    end

                    local nodes = {}
                    for i = from, to, step do
                        local point = get(points, i)
                        table_push(nodes, get(point, "x") + offset_x)
                        table_push(nodes, get(point, "y") + offset_y)
                    end

                    local polyline = polyline_new(nodes)
                    table_push(contours, polyline)
                    draw_order = draw_order + 1
                    contour_to_priority[polyline] = draw_order
                elseif class == _spawn_t then
                    log_assert(object.shape == "point", "object has class `", _spawn_t, "` but is not a `point`")
                    table_push(spawn_points, {
                        get(object, "x") + layer_offset_x,
                        get(object, "y") + layer_offset_y,
                    })

                    local radius = get(object, "properties").radius
                    if radius == nil then radius = _settings_default_player_radius end
                    log_assert(object_is_number(radius), "object has class `", _spawn_t, "`, but property `radius` is not a number")
                    table_push(spawn_point_to_radius, radius)
                else
                    assert(false, "unhandled object type `", class, "`")
                end
            end
        end
    end

    -- preserve render order from layers
    table_sort(contours, function(a, b)
        return contour_to_priority[a] < contour_to_priority[b]
    end)

    for name, bounds in pairs(name_to_bounds) do
        local entry = {
            bounds = aabb_new(0, 0, bounds.width, bounds.height), -- offset to origin
            spawns = {},
            contours = {},
            contour_windings = {},
            triangulations = {}
        }

        for contour_i, contour in ipairs(contours) do
            if aabb_overlaps_polyline(bounds, contour) then
                table_push(entry.contours, object_copy(polyline_translate( -- offset to origin
                    contour, -bounds.x, -bounds.y
                )))
                table_push(entry.contour_windings, polyline_get_winding(contour))
            end
        end

        for spawn_i, spawn in ipairs(spawn_points) do
            local x, y = table_unpack(spawn)
            local radius = spawn_point_to_radius[spawn_i]
            if aabb_overlaps_point(bounds, x, y) then
                table_push(entry.spawns, {
                    x = x - bounds.x,
                    y = y - bounds.y,
                    radius = radius,
                    index = spawn_i
                })
            end
        end

        -- triangulate
        local success = pcall(require, "common.triangulate")
        if not success then
            log_error("In stage_list_export: unable to access `triangulate` module, is this running on web?")
            return self
        end

        for contour_i, contour in ipairs(entry.contours) do
            entry.triangulations[contour_i] = rt.math.triangulate(polyline_get_vertices(contour))
        end

        self.stage_name_to_entry[name] = entry
    end

    local serialize_success, serialized_or_error = pcall(table_serialize, self)
    if not serialize_success then
        log_error("In stage_list_export: when serializing instance:", serialized_or_error)
        return self
    end

    local serialized = "return " .. serialized_or_error

    local write_success, love_success = pcall(love.filesystem.write, out_path, serialized)
    if not write_success or not love_success then
        log_error("In stage_list_export: unable to write file to `", out_path, "`")
        return self
    end

    log_log("Wrote StageList to `", out_path, "`")
    return self
end

stage_list_init = function(self, path)
    log_typecheck(self, StageList_t, path, String_t)

    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, self.path)
    if not load_success then
        log_error("In stage_list_init: error when parsing file at `", self.path, "`: ", chunk_or_error)
        return self
    end

    if love_error ~= nil then
        log_error("In stage_list_init: error when loading file at `", self.path, "`: ", love_error)
        return self
    end

    local chunk_success, value_or_error = pcall(chunk_or_error)
    if not chunk_success then
        log_error("In stage_list_init: error when running file at `", self.path, "`: ", value_or_error)
        return self
    end

    log_assert(object_isa(value_or_error, Stagelist_t), "In stage_list_init: import file at `", self.path, "` does not contain a valid StageList")
    for k, v in pairs(value_or_error) do
        self[k] = v
    end

    return self
end

stage_new = function(stage_list, id)
    log_typecheck(stage_list, StageList_t, id, String_t)
    local entry = stage_list.stage_name_to_entry[id]
    if entry == nil then
        log_error("In stage_new: no stage with id `", id, "`, present in `", stage_list.path, "`. Available stages are: ", table_concat(iter_collect(iter_keys(stage_list.stage_name_to_entry))))
    end

    local self = object_new(Stage_t, {})
    self.bounds = table_deepcopy(entry.bounds)
    self.contours = table_deepcopy(entry.contours)
    self.triangulations = table_deepcopy(entry.triangulations)

    log_assert(table_sizeof(self.contours) == table_sizeof(self.triangulations), "In stage_new: not all contours are triangulated")

    self.draw_contours = {}
    self.draw_meshes = {}
    self.draw_mesh_to_is_foreground = {}

    self.spawns = table_deepcopy(entry.spawns)

    local to_texture_coords
    do -- compute bounds for normalized, global uv
        local min_x, min_y, max_x, max_y = math_positive_inf, math_positive_inf, math_negative_inf, math_negative_inf
        for contour in iter_values(entry.contours) do
            for i = 1, #contour, 2 do
                local x, y = contour[i + 0], contour[i + 1]
                if x < min_x then min_x = x end
                if y < min_y then min_y = y end
                if x > max_x then max_x = x end
                if y > max_y then max_y = y end
            end
        end

        to_texture_coords = function(x, y)
            return (x - min_x) / (max_x - min_x) * _settings_contour_texture_scale,
            (y - min_y) / (max_y - min_y) * _settings_contour_texture_scale
        end
    end

    for contour_i = 1, table_sizeof(entry.contours) do
        local contour = entry.contours[contour_i]
        table_push(self.draw_contours, polyline_close(contour))

        local triangulation = entry.triangulations[contour_i]
        local mesh_data = {}

        for _, tri in ipairs(triangulation) do
            for i = 1, #tri, 2 do
                local x, y = tri[i + 0], tri[i + 1]
                local u, v = to_texture_coords(x, y)
                table_push(mesh_data, { x, y, u, v, 1, 1, 1, 1 })
            end
        end

        local draw_mesh = love.graphics.newMesh(mesh_data, "triangles", "static")
        table_push(self.draw_meshes, draw_mesh)
        table_push(self.draw_mesh_to_is_foreground, entry.contour_windings[contour_i] == true)
    end

    return self
end

stage_draw = function(self)
    log_typecheck(self, Stage_t)

    -- background
    rgba_bind(palette_dark_gray)
    graphics_draw_rectangle(aabb_unpack(self.bounds))

    -- hitbox
    for i = 1, table_sizeof(self.draw_meshes) do
        if self.draw_mesh_to_is_foreground[i] == true then
            rgba_bind(palette_light_gray)
        else
            rgba_bind(palette_gray)
        end
        graphics_draw_mesh(self.draw_meshes[i])

        local contour = self.contours[i]

        rgba_bind(palette_black)
        graphics_set_line_state(_settings_outline_width)
        polyline_draw(contour)

        rgba_bind(palette_white)
        graphics_set_line_state(_settings_line_width)
        polyline_draw(contour)
    end

    -- spawns
    lcha_bind(lcha_new(0.8, 1, math_fract(love.timer.getTime())))
    graphics_set_line_state(_settings_outline_width)
    for spawn_i, spawn in ipairs(self.spawns) do
        local x, y = math_round(spawn.x), math_round(spawn.y)
        graphics_draw_line(
            x,
            y,
            x + _settings_spawn_dx * spawn.radius,
            y + _settings_spawn_dy * spawn.radius
        )
    end

    rgba_bind(palette_white)
    graphics_set_line_state(_settings_line_width)
    for spawn_i, spawn in ipairs(self.spawns) do
        local x, y = math_round(spawn.x), math_round(spawn.y)
        graphics_draw_line(
            x,
            y,
            x + _settings_spawn_dx * spawn.radius,
            y + _settings_spawn_dy * spawn.radius
        )
    end

    for spawn_i, spawn in ipairs(self.spawns) do
        local x, y = math_round(spawn.x), math_round(spawn.y)
        graphics_draw_ellipse_outline(x, y, spawn.radius)
    end
end