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
        stage_id_to_entry = {}
    })
end

stage_list_export = function(self, in_path, out_path)
    log_typecheck(self, StageList_t, in_path, String_t, out_path, String_t)

    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, in_path)
    if not load_success then
        log_error("In stage_list_export: error when parsing file at `", in_path, "`: ", chunk_or_error)
        return self
    end

    if love_error ~= nil then
        log_error("In stage_list_export: error when loading file at `", in_path, "`: ", love_error)
        return self
    end

    local chunk_success, value_or_error = pcall(chunk_or_error)
    if not chunk_success then
        log_error("In stage_list_export: error when running file at `", in_path, "`: ", value_or_error)
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

    local contours = {}
    local contour_to_priority = {}

    local spawn_points = {}
    local spawn_point_to_radius = {}

    local draw_order = 0 -- sequential render priority
    self.stage_id_to_entry = {}
    self.stage_id_in_order = {}
    local stage_id_to_priority = {}

    local layers = get(config, "layers")
    for layer_i, layer in ipairs(layers) do
        local layer_name = get(layer, "name")
        local layer_type = get(layer, "type")
        local layer_offset_x, layer_offset_y = get(layer, "offsetx"), get(layer, "offsety")
        if layer_type == "objectgroup" then
            local objects = get(layer, "objects")
            for object_i, object in ipairs(objects) do
                local object_id = get(object, "id")
                local class = get(object, "type")

                local assert = function(condition, ...)
                    log_assert(condition, "In stage_list_init: for stage `", in_path, "`, on layer `", layer, "`, for object `", object_id, "`: ", ...)
                end

                if class == _stage_t then
                    assert(get(object, "shape") == "rectangle", "object has class `", _stage_t, "`, but it is not a rectangle")

                    local stage_id = get(object, "name")
                    assert(stage_id ~= nil, "object has class `", _stage_t, "` but it does not have `name` set")

                    local entry = self.stage_id_to_entry[stage_id]
                    if entry == nil then
                        entry = {
                            name = nil, -- String_t
                            bounds = nil, -- AABB_t
                            spawn_points = {},
                            contours = {},
                            contour_windings = {},
                            triangulations = {}
                        }
                        self.stage_id_to_entry[stage_id] = entry
                    end

                    local name = object.name
                    if not object_is_string(name) then
                        log_warning("In stage_list_export: stage `", stage_id, "` does not have property `name` set")
                        name = stage_id
                    end
                    entry.name = name

                    local priority = object.priority
                    if priority ~= nil and not object_is_number(priority) then
                        log_error("In stage_list_export: stage `", stage_id, "` has property `priority` specified, but it is not a number")
                    end
                    entry.priority = priority or 0

                    entry.bounds = aabb_new(
                        get(object, "x") + layer_offset_x,
                        get(object, "y") + layer_offset_y,
                        get(object, "width"),
                        get(object, "height")
                    )

                    stage_id_to_priority[name] = get(object, "properties").priority or 0
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

    for id, entry in pairs(self.stage_id_to_entry) do
        local bounds = entry.bounds -- global coords
        entry.bounds = aabb_new(0, 0, bounds.width, bounds.height) -- local coords

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
                table_push(entry.spawn_points, {
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
            entry.triangulations[contour_i] = rt.math.polygonize(3, polyline_get_vertices(contour))
        end

        self.stage_id_to_entry[id] = entry

        table_push(self.stage_id_in_order, id)
    end

    table_stable_sort(self.stage_id_in_order, function(a_id, b_id)
        local a_priority = stage_id_to_priority[a_id]
        local b_priority = stage_id_to_priority[b_id]

        if a_priority == nil then
            log_error("In stage_list_export: no priority for stage `", a_id, "`")
        end

        if b_priority == nil then
            log_error("In stage_list_export: no priority for stage `", b_id, "`")
        end

        return a_priority < b_priority
    end)

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

    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, path)
    if not load_success then
        log_error("In stage_list_init: error when parsing file at `", path, "`: ", chunk_or_error)
        return self
    end

    if love_error ~= nil then
        log_error("In stage_list_init: error when loading file at `", path, "`: ", love_error)
        return self
    end

    local chunk_success, value_or_error = pcall(chunk_or_error)
    if not chunk_success then
        log_error("In stage_list_init: error when running file at `", path, "`: ", value_or_error)
        return self
    end

    log_assert(object_isa(value_or_error, StageList_t), "In stage_list_init: import file at `", path, "` does not contain a valid StageList")
    for k, v in pairs(value_or_error) do
        self[k] = v
    end

    return self
end

stage_list_get_n_stages = function(self)
    log_typecheck(self, StageList_t)
    return table_count(self.stage_id_to_entry)
end

stage_list_get_ids = function(self)
    log_typecheck(self, StageList_t)

    local ids = {}
    for id, _ in pairs(self.stage_id_to_entry) do
        table_push(ids, id)
    end

    return ids
end

stage_new = function(stage_list, id)
    log_typecheck(stage_list, StageList_t, id, String_t)
    local entry = stage_list.stage_id_to_entry[id]
    if entry == nil then
        log_error("In stage_new: no stage with id `", id, "`, present in `", stage_list.path, "`. Available stages are: ", table_concat(iter_collect(iter_keys(stage_list.stage_id_to_entry))))
    end

    local self = object_new(Stage_t, {})

    self.name = entry.name
    self.priority = entry.priority
    self.bounds = table_deepcopy(entry.bounds)

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

    self.contour_entries = {} -- Table<{ contour : Polyline, offset_x, offset_y }>
    self.n_contour_entries = table_sizeof(entry.contours)

    for entry_i = 1, self.n_contour_entries do
        local contour = object_copy(entry.contours[entry_i])
        local triangulation = object_copy(entry.triangulations[entry_i])

        local mesh_data = {}
        for _, tri in ipairs(triangulation) do
            for i = 1, #tri, 2 do
                local x, y = tri[i + 0], tri[i + 1]
                local u, v = to_texture_coords(x, y)
                table_push(mesh_data, { x, y, u, v, 1, 1, 1, 1 })
            end
        end

        local draw_mesh = mesh_new(mesh_data, "static")
        local draw_contour = polyline_close(object_copy(contour))

        table_push(self.contour_entries, {
            contour = contour, -- Polyline
            triangulation = triangulation,
            offset_x = 0,
            offset_y = 0,

            draw_contour = draw_contour,
            draw_mesh = draw_mesh,
            draw_mesh_data = mesh_data,
            is_foreground = polyline_get_winding(contour)
        })
    end

    self.spawn_points = table_deepcopy(entry.spawn_points)

    return self
end

stage_get_draw_contours = function(self)
    log_typecheck(self, Stage_t)
    local out = {}
    for _, entry in ipairs(self.contour_entries) do
        table_push(out, entry.draw_contour)
    end
    return out
end

stage_get_draw_meshes = function(self)
    log_typecheck(self, Stage_t)
    local out = {}
    for _, entry in ipairs(self.contour_entries) do
        table_push(out, entry.draw_mesh)
    end
    return out
end

stage_get_name = function(self)
    log_typecheck(self, Stage_t)
    return self.name
end

stage_get_spawn_points = function(self)
    log_typecheck(self, Stage_t)

    local result = {}
    for _, entry in ipairs(self.spawn_points) do
        table_push(result, {
            x = entry.x,
            y = entry.y,
            radius = entry.radius
        })
    end
    return result
end

stage_get_n_spawn_points = function(self)
    log_typecheck(self, Stage_t)
    return table_count(self.spawn_points)
end

stage_get_hitbox_collision_contours = function(self)
    log_typecheck(self, Stage_t)

    local result = {}
    for _, entry in ipairs(self.contour_entries) do
        table_push(result, polyline_translate(object_copy(entry.contour), entry.offset_x, entry.offset_y))
    end

    return result
end

stage_get_bounds = function(self)
    log_typecheck(self, Stage_t)
    return self.bounds
end

stage_reset = function(self)
    log_typecheck(self, Stage_t)

    for entry in iter_values(self.contour_entries) do
        entry.offset_x = 0
        entry.offset_y = 0
    end
end

stage_update = function(self)
    log_typecheck(self, Stage_t)
end

stage_draw = function(self)
    log_typecheck(self, Stage_t)

    -- background
    rgba_bind(palette_dark_gray)
    graphics_draw_rectangle(aabb_unpack(self.bounds))

    -- hitbox
    for _, entry in ipairs(self.contour_entries) do
        if entry.is_foreground == true then
            rgba_bind(palette_light_gray)
        else
            rgba_bind(palette_gray)
        end

        graphics_translate(entry.offset_x, entry.offset_y)
        mesh_draw(entry.draw_mesh)

        rgba_bind(palette_black)
        graphics_set_line_state(_settings_outline_width)
        polyline_draw(entry.draw_contour)

        rgba_bind(palette_white)
        graphics_set_line_state(_settings_line_width)
        polyline_draw(entry.draw_contour)
    end

    -- spawns
    lcha_bind(lcha_new(0.8, 1, math_fract(love.timer.getTime())))
    graphics_set_line_state(_settings_outline_width)
    for spawn_i, spawn in ipairs(self.spawn_points) do
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
    for spawn_i, spawn in ipairs(self.spawn_points) do
        local x, y = math_round(spawn.x), math_round(spawn.y)
        graphics_draw_line(
            x,
            y,
            x + _settings_spawn_dx * spawn.radius,
            y + _settings_spawn_dy * spawn.radius
        )
    end

    for spawn_i, spawn in ipairs(self.spawn_points) do
        local x, y = math_round(spawn.x), math_round(spawn.y)
        graphics_draw_ellipse_outline(x, y, spawn.radius)
    end
end