require "common.smoothed_motion_1d"
require "common.impulse_manager"
require "overworld.movable_object"

rt.settings.overworld.boost_field = {
    acceleration_duration = 10 / 60, -- seconds to accelerate player from 0 to max
    target_velocity_non_bubble = 1500,
    target_velocity_bubble = 1000,

    outline_width = 2.5,
    opacity = 0.8,
    hue_span = 0.1,
    hue_gradient_reference_length = 600, -- unitless
    segment_light_subdivision = 150, -- px
    segment_light_intensity = 0.6,
    bloom_intensity = 1.0,

    particles = {
        n_hue_steps = 512,
        spatial_hash_cell_size = 8,
        extrude_offset = 0, -- px
        blend_opacity = 0.5,

        density = 0.01, -- factor
        min_velocity = 20,
        max_velocity = 30,
        min_radius = 12,
        max_radius = 15,
        min_lifetime = 1.0,
        max_lifetime = 1.5,
        attack_fraction = 0.4, -- in [0, 0.5)
        release_fraction = 0.4 -- in [0, 0.5)
    }
}

local schema = {
    axis_x = ow.Number,
    axis_y = ow.Number,
    axis = ow.Object,
    path = ow.Object,
    use_smoothing = ow.Boolean,
    is_visible = ow.Boolean,
    has_outline = ow.Boolean,
    velocity = ow.Number,
    hue = { ow.String, ow.Number }
}

local path_node_schema = {
    next = ow.Object
}

--- @class ow.BoostField
ow.BoostField = meta.class("BoostField", ow.MovableObject)

--- @class ow.BoostFieldAxis
ow.BoostFieldAxis = meta.class("BoostFieldAxis")

--- @class ow.BoostFieldPathNode
ow.BoostFieldPathNode = meta.class("BoostFieldPath")

local _shader = rt.Shader("overworld/objects/boost_field.glsl")
local _particle_texture = nil
local _particle_texture_shader = rt.Shader("overworld/objects/boost_field_particle_texture.glsl")
local _particle_draw_shader = rt.Shader("overworld/objects/boost_field_particle_draw.glsl")

--- @brief
function ow.BoostField:instantiate(object, stage, scene)
    object:validate_schema(schema, ow.ShapeType.NOT_A_POINT)

    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)
    self._body:add_tag(b2.Tag.SEGMENT_LIGHT_SOURCE)
    self._body:set_user_data(self)

    self._is_active = self._body:test_point(self._scene:get_player():get_position())

    -- physics
    self._velocity_factor = object:get_number("velocity", false) or 1

    local path = object:get_object("path")
    local axis = object:get_object("axis")
    local axis_x = object:get_number("axis_x")
    local axis_y = object:get_number("axis_y")

    local warn_priority = function(higher_priority, lower_priority)
        if higher_priority ~= nil and lower_priority ~= nil then
            rt.critical("In ow.BoostField: object `", object:get_id(), "` has `", higher_priority, "` and `", lower_priority, "` specified. `", higher_priority, "` will take priority")
        end
    end

    if path ~= nil then
        if axis ~= nil then
            warn_priority("path", "axis")
        end

        if axis_x ~= nil then
            warn_priority("path", "axis_x")
        end

        if axis_y ~= nil then
            warn_priority("path", "axis_y")
        end
    end

    if axis ~= nil then
        if axis_x ~= nil then
            warn_priority("axis", "axis_x")
        end

        if axis_y ~= nil then
            warn_priority("axis", "axis_y")
        end
    end

    if path == nil and axis == nil and axis_x == nil and axis_y == nil then
        rt.critical("In ow.BoostField: object `", object:get_id(), "` has neither `path`, `axis`, `axis_x` or `axis_y` specified")
    end

    if path ~= nil then
        local points = {}
        local offset_x, offset_y = self._body:get_position()
        local current = path
        repeat
            current:validate_schema(path_node_schema, ow.ShapeType.POINT)
            table.insert(points, current.x - offset_x)
            table.insert(points, current.y - offset_y)
            current = current:get_object("next", false)
        until current == nil

        if #points == 2 then
            self._axis_x, self._axis_y = math.normalize(math.subtract(path.x, path.y, object:get_centroid()))
            rt.warning("In ow.BoostField: object `", object:get_id(), "` has `path` set, but it the path only a single a node. It will be treated like an axis")
        else
            if object:get_boolean("use_smoothing", false) == true then
                self._path = rt.Path(rt.Spline(points):discretize())
            else
                self._path = rt.Path(points)
            end
        end
    elseif axis ~= nil then
        self._axis_x, self._axis_y = math.normalize(math.subtract(axis.x, axis.y, object:get_centroid()))
    else
        if axis_x == nil then axis_x = 0 end
        if axis_y == nil then axis_y = 0 end
        self._axis_x, self._axis_y = math.normalize(axis_x, axis_y)
    end

    -- graphics
    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = true end

    self._has_outline = object:get_boolean("has_outline", false)
    if self._has_outline == nil then self._has_outline = true end

    local translate_to_origin = true
    self._contour = rt.contour.close(object:create_contour(translate_to_origin))
    local _, tris = object:create_mesh(translate_to_origin)
    self._tris = tris

    do -- mesh & segment lights
        local total_area = 0
        local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
        for _, tri in ipairs(self._tris) do
            for i = 1, #tri, 2 do
                local x, y = tri[i+0], tri[i+1]
                min_x = math.min(min_x, x)
                min_y = math.min(min_y, y)
                max_x = math.max(max_x, x)
                max_y = math.max(max_y, y)
            end
        end

        local cx, cy = 0, 0 -- path already at origin
        local dx, dy = self._axis_x, self._axis_y
        local dist = math.distance(min_x, min_y, max_x, max_y) / 2

        local particle_path
        if self._path ~= nil then
            particle_path = rt.Path():create_from_and_reparameterize(
                self._path:get_points()
            )
        else
            particle_path = rt.Path():create_from_and_reparameterize(
                cx - dx * dist,
                cx - dy * dist,
                cx + dx * dist,
                cy + dy * dist
            )
        end

        local length = particle_path:get_length()
        local reference_length = rt.settings.overworld.boost_field.hue_gradient_reference_length

        local mesh_data = {}
        for tri in values(self._tris) do
            for i = 1, #tri, 2 do
                local x, y = tri[i+0], tri[i+1]
                local t = particle_path:get_fraction(x, y)
                local dx, dy = particle_path:tangent_at(t)
                table.insert(mesh_data, {
                    x, y,
                    t, -- u: arc length parameterized t
                    t * length / reference_length,  -- v: hue
                    1, 1, 1, 1
                })
            end
        end

        self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)

        local subdivision_length = rt.settings.overworld.boost_field.segment_light_subdivision
        local subdivide = function(x1, y1, x2, y2)
            local dx = x2 - x1
            local dy = y2 - y1
            local length = math.magnitude(dx, dy)

            if length <= subdivision_length then
                return {{ x1, y1, x2, y2 }}
            else
                local n = math.ceil(length / subdivision_length)
                local segments = {}
                for i = 0, n - 1 do
                    local t1 = i / n
                    local t2 = (i + 1) / n
                    table.insert(segments, {
                        x1 + dx * t1, y1 + dy * t1,
                        x1 + dx * t2, y1 + dy * t2
                    })
                end
                return segments
            end
        end

        local lights = {}
        local contour = self._contour
        for i = 1, #contour, 2 do
            for division in values(subdivide(
                contour[i+0],
                contour[i+1],
                contour[math.wrap(i+2, #contour)],
                contour[math.wrap(i+3, #contour)]
            )) do
                local x1, y1, x2, y2 = table.unpack(division)
                local t = particle_path:get_fraction(
                    math.mix2(x1, y1, x2, y2, 0.5)
                ) * (length / reference_length)

                table.insert(lights, {
                    x1, y1, x2, y2,
                    rt.lcha_to_rgba(0.8, 1, t, 1)
                })

                if #lights > 10 then break end
            end
        end

        self._segment_lights = lights
    end


    -- particles
    self._particles_need_update = true
    self:_init_particles()

    if _particle_texture == nil then
        do -- particle texture
            local w =  2 * rt.settings.overworld.boost_field.particles.max_radius
            local h = w
            _particle_texture = rt.RenderTexture(w, h)

            love.graphics.push("all")
            love.graphics.reset()
            _particle_texture:bind()
            _particle_texture_shader:bind()

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill",
                0, 0, w, h
            )

            _particle_texture_shader:unbind()
            _particle_texture:unbind()
            love.graphics.pop()
        end
    end
end

local _first = nil -- TODO
local with_sum, with_n = 0, 0

--- @brief
function ow.BoostField:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local player = self._scene:get_player()
    local px, py = player:get_position()

    local ox, oy = math.subtract(px, py, self._body:get_position())

    if self._body:test_point(player:get_position()) then -- body already compensate for offset
        local dir_x, dir_y

        if self._path ~= nil then
            local cx, cy, ct = self._path:get_closest_point(ox, oy)
            dir_x, dir_y = self._path:tangent_at(ct)
        else
            dir_x, dir_y = self._axis_x, self._axis_y
        end

        local vx, vy = player:get_velocity()
        local current = math.magnitude(vx, vy)
        local target_magnitude = ternary(player:get_is_bubble(),
            rt.settings.overworld.boost_field.target_velocity_bubble,
            rt.settings.overworld.boost_field.target_velocity_non_bubble
        ) * self._velocity_factor

        local target_vx, target_vy = dir_x * target_magnitude, dir_y * target_magnitude
        local dx = target_vx - vx
        local dy = target_vy - vy

        -- prevent decreasing velocity if already above target
        if (dx > 0 and target_vx < 0) or (dx < 0 and target_vx > 0) then
            dx = 0
        end

        if (dy > 0 and target_vy < 0) or (dy < 0 and target_vy > 0) then
            dy = 0
        end

        local duration = rt.settings.overworld.boost_field.acceleration_duration
        local new_vx = vx + dx * (1 / duration) * delta
        local new_vy = vy + dy * (1 / duration) * delta

        player:set_velocity(new_vx, new_vy)
    end

    if _first then self._dbg = true; _first = nil end
    local before = love.timer.getTime()

    if self._particles_need_update == true then
        --self:_update_particles(delta)
        self._particles_need_update = false
    end

    if self._dbg then
        local duration = (love.timer.getTime() - before) / (1 / 60)
        with_sum = with_sum + duration
        with_n = with_n + 1
        dbg(meta.hash(self), with_sum / with_n)
    end
end

--- @brief
function ow.BoostField:reset()
    self._is_active = false
end

--- @brief
function ow.BoostField:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    love.graphics.translate(self._body:get_position())

    self:_draw_particles()

    love.graphics.setLineStyle("smooth")
    love.graphics.setLineWidth(1.0)
    rt.Palette.BLACK:bind()
    love.graphics.line(self._contour)

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("velocity_factor", self._velocity_factor)
    _shader:send("screen_to_world_transform", self._scene:get_camera():get_transform():inverse())
    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
    _shader:unbind()


    love.graphics.pop()
end

--- @brief
function ow.BoostField:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    love.graphics.setLineWidth(3)
    local t = rt.settings.overworld.boost_field.bloom_intensity
    for _, light in ipairs(self._segment_lights) do
        local ax, ay, bx, by, r, g, b, a = table.unpack(light)
        love.graphics.setColor(t * r, t * g, t * b, t * a) -- premultiplied
        love.graphics.line(
            ax + offset_x,
            ay + offset_y,
            bx + offset_x,
            by + offset_y
        )
    end
end

--- @brief
function ow.BoostField:collect_segment_lights(callback)
    if not self._stage:get_is_body_visible(self._body) then return end

    local t = rt.settings.overworld.boost_field.segment_light_intensity
    local offset_x, offset_y = self._body:get_position()
    for _, light in ipairs(self._segment_lights) do
        local ax, ay, bx, by, r, g, b, a = table.unpack(light)
        callback(
            ax + offset_x,
            ay + offset_y,
            bx + offset_x,
            by + offset_y,
            r, g, b,
            a * t -- not premultiplied
        )
    end
end

do
    local function _tri_area(ax, ay, bx, by, cx, cy)
        local abx, aby = bx - ax, by - ay
        local acx, acy = cx - ax, cy - ay
        return math.abs(math.cross(abx, aby, acx, acy)) / 2
    end

    local function _random_point_in_tri(ax, ay, bx, by, cx, cy)
        -- generate random point in rectangle, then fold to tri
        local r1, r2 = rt.random.number(0, 1), rt.random.number(0, 1)
        if r1 + r2 > 1 then
            r1, r2 = 1 - r1, 1 - r2
        end

        local x = ax + r1 * (bx - ax) + r2 * (cx - ax)
        local y = ay + r1 * (by - ay) + r2 * (cy - ay)

        return x, y
    end

    local extrude = function(offset, ax, ay, bx, by, cx, cy)
        -- radially scale, this may distort the triangle but we only
        -- extrude to have particle seed points fall slightly outside the tris
        local ox, oy = (ax + bx + cx) / 3, (ay + by + cy) / 3
        local dax, day = math.subtract(ax, ay, ox, oy)
        local dbx, dby = math.subtract(bx, by, ox, oy)
        local dcx, dcy = math.subtract(cx, cy, ox, oy)

        local a_len = math.magnitude(dax, day)
        local b_len = math.magnitude(dbx, dby)
        local c_len = math.magnitude(dcx, dcy)

        local a_scale = (a_len + offset) / a_len
        local b_scale = (b_len + offset) / b_len
        local c_scale = (c_len + offset) / c_len

        ax, ay = math.add(ox, oy, math.multiply(dax, day, a_scale, a_scale))
        bx, by = math.add(ox, oy, math.multiply(dbx, dby, b_scale, b_scale))
        cx, cy = math.add(ox, oy, math.multiply(dcx, dcy, c_scale, c_scale))

        return ax, ay, bx, by, cx, cy, _tri_area(ax, ay, bx, by, cx, cy)
    end

    local function _is_point_in_tri(px, py, x1, y1, x2, y2, x3, y3)
        local v0x, v0y = x3 - x1, y3 - y1
        local v1x, v1y = x2 - x1, y2 - y1
        local v2x, v2y = px - x1, py - y1

        local dot00 = v0x * v0x + v0y * v0y
        local dot01 = v0x * v1x + v0y * v1y
        local dot02 = v0x * v2x + v0y * v2y
        local dot11 = v1x * v1x + v1y * v1y
        local dot12 = v1x * v2x + v1y * v2y

        local denom = dot00 * dot11 - dot01 * dot01
        if denom == 0 then
            return false -- degenerate
        end

        local u = (dot11 * dot02 - dot01 * dot12) * (1 / denom)
        local v = (dot00 * dot12 - dot01 * dot02) * (1 / denom)

        return (u >= 0) and (v >= 0) and (u + v <= 1)
    end

    local _x_offset = 0
    local _y_offset = 1
    local _radius_offset = 2
    local _velocity_offset = 3
    local _hue_offset = 4
    local _opacity_offset = 5
    local _lifetime_offset = 6
    local _lifetime_elapsed_offset = 7

    local _stride = _lifetime_elapsed_offset + 1
    local _particle_i_to_data_offset = function(particle_i)
        return (particle_i - 1) * _stride + 1 -- 1-based
    end

    local settings = rt.settings.overworld.boost_field.particles

    local _get_tangent_t = function(x, y, cell_size, i_offset, j_offset, spatial_hash, particle_path)
        local i = math.floor(x / cell_size) + i_offset
        local j = math.floor(y / cell_size) + j_offset

        local row = spatial_hash[i]
        if row == nil then
            row = {}
            spatial_hash[i] = row
        end

        local entry = row[j]
        if entry == nil then
            local cell_x = (i - i_offset) * cell_size + 0.5 * cell_size
            local cell_y = (j - j_offset) * cell_size + 0.5 * cell_size
            local t = particle_path:get_fraction(cell_x, cell_y)
            local dx, dy = particle_path:tangent_at(t)
            entry = { t, dx, dy }
            row[j] = entry
        end

        return entry[1], entry[2], entry[3]
    end

    local _hue_to_rgba = function(hue, hue_to_rgba_table, n_hue_steps)
        hue = math.floor(hue * n_hue_steps) + 1
        local offset = (hue - 1) * 4
        local r, g, b, a = hue_to_rgba_table[offset + 1], hue_to_rgba_table[offset + 2], hue_to_rgba_table[offset + 3], hue_to_rgba_table[offset + 4]
        assert(r ~= nil, hue)
        return r, g, b, a
    end

    --- @brief
    function ow.BoostField:_init_particles()
        local tris = self._tris
        local total_area = 0
        local tri_to_area = {}

        -- get bounding box
        local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
        for _, tri in ipairs(tris) do
            for i = 1, #tri, 2 do
                local x, y = tri[i+0], tri[i+1]
                min_x = math.min(min_x, x)
                min_y = math.min(min_y, y)
                max_x = math.max(max_x, x)
                max_y = math.max(max_y, y)
            end

            local area = _tri_area(table.unpack(tri))
            tri_to_area[tri] = area
            total_area = total_area + area
        end

        -- uniform sample triangle based on weight
        local random_tri
        do
            -- vose's alias method https://en.wikipedia.org/wiki/Alias_method
            local n = #tris
            local prob = {}
            local alias = {}

            local scaled = {}
            local small, large = {}, {}

            for i, tri in ipairs(tris) do
                scaled[i] = (tri_to_area[tri] / total_area) * n
                if scaled[i] < 1 then
                    table.insert(small, i)
                else
                    table.insert(large, i)
                end
            end

            while #small > 0 and #large > 0 do
                local l = table.remove(small)
                local g = table.remove(large)

                prob[l] = scaled[l]
                alias[l] = g

                scaled[g] = (scaled[g] + scaled[l]) - 1
                if scaled[g] < 1 then
                    table.insert(small, g)
                else
                    table.insert(large, g)
                end
            end

            -- set leftover to 1 exactl to address floating point
            while #large > 0 do
                local g = table.remove(large)
                prob[g] = 1
            end

            while #small > 0 do
                local l = table.remove(small)
                prob[l] = 1
            end

            -- sample routine
            random_tri = function()
                local i = rt.random.integer(1, n)
                local coin = rt.random.number(0, 1)

                if coin < prob[i] then
                    return tris[i]
                else
                    return tris[alias[i]]
                end
            end
        end

        local particle_path
        if self._path ~= nil then
            particle_path = rt.Path():create_from_and_reparameterize(
                self._path:get_points()
            )
        else
            local cx, cy = 0, 0 -- path already at origin
            local dx, dy = self._axis_x, self._axis_y
            local dist = math.distance(min_x, min_y, max_x, max_y) / 2
            particle_path = rt.Path():create_from_and_reparameterize(
                cx - dx * dist,
                cx - dy * dist,
                cx + dx * dist,
                cy + dy * dist
            )
        end

        -- particle spawn point table
        local seed_points = {}

        -- particle data
        local particle_data = {}

        local avg_radius = math.mix(settings.min_radius, settings.max_radius, 0.5)
        local target_n_particles = math.max(1, math.ceil(settings.density * (total_area / avg_radius)))

        local particle_i = 1
        for _ = 1, target_n_particles do
            local tri = random_tri()
            local ax, ay, bx, by, cx, cy = extrude(settings.extrude_offset, table.unpack(tri))
            local x, y = _random_point_in_tri(ax, ay, bx, by, cx, cy)

            table.insert(seed_points, x)
            table.insert(seed_points, y)

            local pi = _particle_i_to_data_offset(particle_i)
            particle_data[pi + _x_offset] = x
            particle_data[pi + _y_offset] = y
            particle_data[pi + _radius_offset] = rt.random.number(settings.min_radius, settings.max_radius)
            particle_data[pi + _velocity_offset] = rt.random.number(settings.min_velocity, settings.max_velocity)
            particle_data[pi + _hue_offset] = particle_path:get_fraction(x, y)
            particle_data[pi + _opacity_offset] = 0

            local lifetime = settings.max_lifetime
            particle_data[pi + _lifetime_elapsed_offset] = rt.random.number(0, lifetime)
            particle_data[pi + _lifetime_offset] = lifetime
            particle_i = particle_i + 1
        end

        -- init hue lookup table (flat array: 4 floats per entry instead of {r,g,b,a} sub-tables)
        local hue_to_rgba = {}
        for i = 1, settings.n_hue_steps + 1 do
            local r, g, b, a = rt.lcha_to_rgba(0.8, 1, (i - 1) / settings.n_hue_steps, 1)
            local offset = (i - 1) * 4
            hue_to_rgba[offset + 1] = r
            hue_to_rgba[offset + 2] = g
            hue_to_rgba[offset + 3] = b
            hue_to_rgba[offset + 4] = a
        end

        do
            local seed_order = {}
            for i = 1, #seed_points / 2 do table.insert(seed_order, i) end
            seed_order = rt.random.shuffle(seed_order)

            local rand = math.random
            local rand_r = settings.min_radius

            local seed_i = 1
            self._get_seed = function()
                local idx = seed_order[seed_i % #seed_order + 1]
                local offset = (idx - 1) * 2
                seed_i = seed_i + 1
                local x, y = seed_points[offset + 1], seed_points[offset + 2]

                -- offsetting the seed every time compensates for
                -- random holes in seed distribution
                -- poisson disk sampling or lloyd relaxation where too expensive
                x = x + (rand() * 2 - 1) * rand_r
                y = y + (rand() * 2 - 1) * rand_r
                return x, y
            end
        end

        self._hue_to_rgba_table = hue_to_rgba

        -- init spatial hash
        local spatial_hash = {}
        local cell_size = settings.spatial_hash_cell_size
        local i_offset = -math.floor(min_x / cell_size) + 1
        local j_offset = -math.floor(min_y / cell_size) + 1

        do -- force initialize spatial hash in bounding box
            local min_i, max_i = math.floor(min_x / cell_size), math.floor(max_x / cell_size)
            local min_j, max_j = math.floor(min_y / cell_size), math.floor(max_y / cell_size)

            for i = min_i, max_i do
                for j = min_j, max_j do
                    local x = (i + 0.5) * cell_size
                    local y = (j + 0.5) * cell_size
                    _get_tangent_t(x, y, cell_size, i_offset, j_offset, spatial_hash, particle_path)
                end
            end
        end

        self._seed_points = seed_points
        self._spatial_hash = spatial_hash
        self._particle_path = particle_path
        self._particle_data = particle_data
        self._n_particles = particle_i - 1
        self._cell_size = cell_size
        self._i_offset = i_offset
        self._j_offset = j_offset

        -- init instanced draw
        self._instance_mesh = rt.MeshRectangle(-1, -1, 2, 2)
        self._instance_mesh:set_texture(_particle_texture)

        -- init GPU-side buffer
        local data_mesh_format = {
            {
                location = 3,
                format = rt.GraphicsBufferDataFormat.FLOAT_VEC2,
                name = "instance_position"
            },

            {
                location = 4,
                format = rt.GraphicsBufferDataFormat.FLOAT,
                name = "instance_radius"
            },

            {
                location = 5,
                format = rt.GraphicsBufferDataFormat.FLOAT_VEC4,
                name = "instance_color"
            }
        }

        -- init GPU-side particle data
        if ffi ~= nil then
            local n_components = (2 + 1 + 4)
            self._instance_data_buffer_data = rt.ByteData(rt.ByteDataFormat.FLOAT32, n_components * self._n_particles)
            local ptr = ffi.cast("float*", self._instance_data_buffer_data:get_pointer())
            for pi = 1, self._n_particles do
                local data_i = _particle_i_to_data_offset(pi)
                local ptr_i = (pi - 1) * n_components

                ptr[ptr_i + 0] = particle_data[data_i + _x_offset]
                ptr[ptr_i + 1] = particle_data[data_i + _y_offset]
                ptr[ptr_i + 2] = particle_data[data_i + _radius_offset]

                local r, g, b, a = _hue_to_rgba(particle_data[data_i + _hue_offset], hue_to_rgba, settings.n_hue_steps)
                ptr[ptr_i + 3] = r
                ptr[ptr_i + 4] = g
                ptr[ptr_i + 5] = b
                ptr[ptr_i + 6] = a * particle_data[data_i + _opacity_offset]
            end
        else
            self._instance_data_buffer_data = table.new(self._n_particles, 0)
            for pi = 1, self._n_particles do
                local i = _particle_i_to_data_offset(pi)

                local entry = {}
                entry[1 + 0] = particle_data[i + _x_offset]
                entry[1 + 1] = particle_data[i + _y_offset]
                entry[1 + 2] = particle_data[i + _radius_offset]

                local r, g, b, a = _hue_to_rgba(particle_data[i + _hue_offset], hue_to_rgba, settings.n_hue_steps)
                entry[1 + 3] = r
                entry[1 + 4] = g
                entry[1 + 5] = b
                entry[1 + 6] = a * particle_data[i + _opacity_offset]

                table.insert(self._instance_data_buffer_data, entry)
            end
        end

        self._instance_data_buffer = rt.Mesh(
            self._instance_data_buffer_data,
            rt.MeshDrawMode.POINTS,
            data_mesh_format
        )

        for entry in values(data_mesh_format) do
            self._instance_mesh:attach_attribute(
                self._instance_data_buffer,
                entry.name,
                rt.MeshAttributeAttachmentMode.PER_INSTANCE
            )
        end
    end

    local _HUE_UPDATE_NEEDED = -1

    -- linear ASR envelope
    local attack = settings.attack_fraction
    local release = settings.release_fraction
    local _opacity_easing = function(t)
        t = math.min(t, 1)
        if attack > 0 and t < attack then
            return t / attack
        elseif t < 1 - release then
            return 1
        elseif release > 0 then
            return (1 - t) / release
        else
            return 1
        end
    end

    function ow.BoostField:_update_particles(delta)
        local data = self._particle_data
        local path = self._particle_path

        local velocity_interpolation = settings.velocity_interpolation
        local velocity_factor = self._velocity_factor

        local get_seed = self._get_seed
        local velocity_delta = self._velocity_factor * delta

        local cell_size = self._cell_size
        local i_offset = self._i_offset
        local j_offset = self._j_offset
        local spatial_hash = self._spatial_hash
        local hue_to_rgba_table = self._hue_to_rgba_table
        local n_hue_steps = settings.n_hue_steps

        local stride = _stride
        local max_i = self._n_particles * stride
        for i = 1, max_i, stride do
            local x = data[i + _x_offset]
            local y = data[i + _y_offset]

            local velocity = data[i + _velocity_offset]

            local t, dx, dy = _get_tangent_t(x, y, cell_size, i_offset, j_offset, spatial_hash, path)
            if data[i + _hue_offset] == _HUE_UPDATE_NEEDED then
                data[i + _hue_offset] = t
            end

            x = x + dx * velocity * velocity_delta
            y = y + dy * velocity * velocity_delta

            local elapsed = data[i + _lifetime_elapsed_offset]
            elapsed = elapsed + delta

            local lifetime = data[i + _lifetime_offset]
            local lifetime_t = elapsed / lifetime

            if lifetime_t > 1 then
                data[i + _opacity_offset] = 0
                local new_x, new_y = get_seed()
                data[i + _x_offset] = new_x
                data[i + _y_offset] = new_y
                data[i + _opacity_offset] = 0
                data[i + _lifetime_elapsed_offset] = 0
                data[i + _hue_offset] = _HUE_UPDATE_NEEDED
            else
                data[i + _x_offset] = x
                data[i + _y_offset] = y
                data[i + _lifetime_elapsed_offset] = elapsed
                data[i + _opacity_offset] = _opacity_easing(math.min(lifetime_t, 1))
            end
        end

        -- init GPU-side particle data
        if ffi ~= nil then
            local t = settings.blend_opacity
            local ptr = ffi.cast("float*", self._instance_data_buffer_data:get_pointer())
            for pi = 1, self._n_particles do
                local i = _particle_i_to_data_offset(pi)
                local out = (pi - 1) * 7

                ptr[out + 0] = data[i + _x_offset]
                ptr[out + 1] = data[i + _y_offset]
                ptr[out + 2] = data[i + _radius_offset]

                local hue = data[i + _hue_offset]
                if hue == _HUE_UPDATE_NEEDED then
                    ptr[out + 3] = 0
                    ptr[out + 4] = 0
                    ptr[out + 5] = 0
                    ptr[out + 6] = 0
                else
                    local r, g, b, a = _hue_to_rgba(hue, hue_to_rgba_table, n_hue_steps)
                    a = a * data[i + _opacity_offset]
                    ptr[out + 3] = t * r * a
                    ptr[out + 4] = t * g * a
                    ptr[out + 5] = t * b * a
                    ptr[out + 6] = t * a
                end
            end
        else
            local t = settings.blend_opacity
            for pi = 1, self._n_particles do
                local i = _particle_i_to_data_offset(pi)

                local entry = self._instance_data_buffer_data[pi]
                entry[1 + 0] = data[i + _x_offset]
                entry[1 + 1] = data[i + _y_offset]
                entry[1 + 2] = data[i + _radius_offset]

                local hue = data[i + _hue_offset]
                if hue == _HUE_UPDATE_NEEDED then
                    entry[1 + 3] = 0
                    entry[1 + 4] = 0
                    entry[1 + 5] = 0
                    entry[1 + 6] = 0
                else
                    local r, g, b, a = _hue_to_rgba(hue, hue_to_rgba_table, n_hue_steps)
                    a = a * data[i + _opacity_offset]
                    entry[1 + 3] = t * r * a
                    entry[1 + 4] = t * g * a
                    entry[1 + 5] = t * b * a
                    entry[1 + 6] = t * a * data[i + _opacity_offset]
                end
            end
        end

        self._instance_data_buffer:replace_data(self._instance_data_buffer_data)
    end

    function ow.BoostField:_draw_particles()
        love.graphics.push("all")

        rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
        _particle_draw_shader:bind()
        _particle_draw_shader:send("instance_texture", _particle_texture)
        --self._instance_mesh:draw_instanced(self._n_particles)
        _particle_draw_shader:unbind()
        love.graphics.pop()

        --[[
        love.graphics.push("all")

        local data = self._particle_data
        local hue_to_rgba = self._hue_to_rgba
        local w, h = _particle_texture:get_size()
        local ox, oy = 0.5 * w, 0.5 * h
        local native = _particle_texture:get_native()
        local t = settings.additive_scale or 1

        local stride = _stride
        local max_i = self._n_particles * stride
        for i = 1, max_i, stride do
            local opacity = data[i + _opacity_offset]

            if opacity > 0 then
                local x = data[i + _x_offset]
                local y = data[i + _y_offset]
                local r, g, b, a = hue_to_rgba(data[i + _hue_offset])
                a = a * opacity
                local radius = data[i + _radius_offset]

                local scale = 2 * radius / (w / 2)
                love.graphics.setColor(t * r, t * g, t * b, t * a)
                love.graphics.draw(native,
                    x, y,
                    0,
                    scale, scale,
                    ox, oy
                )

                --love.graphics.setColor(r, g, b, a)
                --love.graphics.circle("fill", x, y, radius)
            end
        end

        love.graphics.pop()
        ]]
    end
end -- particles