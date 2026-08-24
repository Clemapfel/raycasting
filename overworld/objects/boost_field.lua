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
    hue_gradient_reference_length = 600
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

--- @brief
function ow.BoostField:instantiate(object, stage, scene)
    object:validate_schema(schema, ow.ShapeType.NOT_A_POINT)

    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)
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
    self._contour = rt.contour.close(rt.contour.subdivide(
        object:create_contour(translate_to_origin),
        20
    ))

    self._tris = rt.math.triangulate(self._contour)

    do
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
                table.insert(mesh_data, {
                    x, y,
                    t, -- u: arc length parameterized t
                    t * length / reference_length,  -- v: hue
                    1, 1, 1, 1
                })
            end
        end

        self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    end

    -- init hue table
    do
        local n_steps = 512
        local image = rt.Image(1, n_steps, rt.TextureFormat.RGBA32F)

        local function cbrt(x) return x < 0 and -math.pow(-x, 1/3) or math.pow(x, 1/3) end
        local function clamp(x) return math.max(0, math.min(1, x)) end

        local function oklch_to_oklab(l, c, h)
            local hue_rad = h * math.pi * 2.0
            return l, c * math.cos(hue_rad), c * math.sin(hue_rad)
        end

        local function oklab_to_linear_srgb(l, a, b)
            local l_ = l + 0.3963377774 * a + 0.2158037573 * b
            local m_ = l - 0.1055613458 * a - 0.0638541728 * b
            local s_ = l - 0.0894841775 * a - 1.2914855480 * b

            local l3 = l_ * l_ * l_
            local m3 = m_ * m_ * m_
            local s3 = s_ * s_ * s_

            local r =  4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
            local g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
            local b_val = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3

            return r, g, b_val
        end

        local function linear_srgb_to_oklab(r, g, b_val)
            local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b_val
            local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b_val
            local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b_val

            l, m, s = cbrt(l), cbrt(m), cbrt(s)

            local L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
            local a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
            local b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s

            return L, a, b
        end

        -- 2. Generate high-resolution arc-length mapping
        local HIGH_RES = 2048 * 2
        local eval_L = 0.9 -- A representative lightness from your shader noise
        local eval_C = 0.9 -- The hardcoded chroma from your shader

        local dists = {0}
        local prev_l, prev_a, prev_b

        for i = 1, HIGH_RES do
            local h = (i - 1) / (HIGH_RES - 1)
            local ol, oa, ob = oklch_to_oklab(eval_L, eval_C, h)
            local r, g, b = oklab_to_linear_srgb(ol, oa, ob)

            -- The non-linearity comes from this clamp! We measure perceptual distance AFTER clipping.
            r, g, b = clamp(r), clamp(g), clamp(b)
            local cl, ca, cb = linear_srgb_to_oklab(r, g, b)

            if i > 1 then
                local dl, da, db = cl - prev_l, ca - prev_a, cb - prev_b
                dists[i] = dists[i-1] + math.sqrt(dl*dl + da*da + db*db)
            end
            prev_l, prev_a, prev_b = cl, ca, cb
        end

        local total_dist = dists[HIGH_RES]

        -- 3. Bake uniform perceptual steps into the texture LUT
        for i = 1, n_steps do
            local target_dist = ((i - 1) / (n_steps - 1)) * total_dist

            -- Binary search to find where we are along the path
            local low, high = 1, HIGH_RES
            while low < high - 1 do
                local mid = math.floor((low + high) / 2)
                if dists[mid] <= target_dist then low = mid else high = mid end
            end

            -- Linear interpolation for exact hue
            local d1, d2 = dists[low], dists[high]
            local t = (d2 > d1) and ((target_dist - d1) / (d2 - d1)) or 0
            local corrected_hue = (low - 1 + t) / (HIGH_RES - 1)

            image:set(1, i, corrected_hue, 0.0, 0.0, 1.0)
        end

        self._hue_texture = image:create_texture()
        self._hue_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    self:_init_particles()
end

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

    self:_update_particles(delta)
end

--- @brief
function ow.BoostField:draw()
    if not self._stage:get_is_body_visible(self._body)
        or not self._is_visible
    then
        return
    end

    love.graphics.push("all")
    love.graphics.translate(self._body:get_position())

    love.graphics.setLineJoin("miter")
    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(2)
    love.graphics.line(self._contour)
    self._mesh:draw()

    --[[
    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("velocity_factor", self._velocity_factor)

    local hue = self._scene:get_player():get_hue()
    _shader:send("min_hue", 0) --hue - rt.settings.overworld.boost_field.hue_span)
    _shader:send("max_hue", 1) --hue + rt.settings.overworld.boost_field.hue_span)
    _shader:send("screen_to_world_transform", self._scene:get_camera():get_transform():inverse())

    _shader:send("hue_texture", self._hue_texture)
    love.graphics.setColor(1, 1, 1, rt.settings.overworld.boost_field.opacity)
    self._mesh:draw()
    _shader:unbind()
    ]]

    self:_draw_particles()

    love.graphics.pop()
end

--- @brief
function ow.BoostField:draw_bloom()
    if not self._stage:get_is_body_visible(self._body)
        or not self._is_visible
    then
        return
    end
end

--- @brief
function ow.BoostField:reset()
    self._is_active = false
end

do
    local function _point_in_triangle(px, py, x1, y1, x2, y2, x3, y3)
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

    local _x_offset = 0
    local _y_offset = 1
    local _radius_offset = 2
    local _velocity_offset = 3
    local _last_vx_offset = 4
    local _last_vy_offset = 5
    local _hue_offset = 6
    local _opacity_offset = 7
    local _lifetime_offset = 8
    local _lifetime_elapsed_offset = 9

    local _stride = _lifetime_elapsed_offset + 1
    local _particle_i_to_data_offset = function(particle_i)
        return (particle_i - 1) * _stride + 1 -- 1-based
    end

    local settings = {
        n_hue_steps = 256,
        density = 1.2, -- factor
        velocity = 10,
        radius = 8,
        max_lifetime = 0.5,
        attack_fraction = 0.05,
        release_fraction = 0.1
    }

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
            -- vose's aliasing method https://en.wikipedia.org/wiki/Alias_method
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
                local i = rt.random.number(1, n)
                local coin = rt.random.number(0, 1 - math.eps)

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

        local particle_i = 1
        for tri, area in pairs(tri_to_area) do
            local n_particles = settings.density * (area / settings.radius)
            local ax, ay, bx, by, cx, cy = table.unpack(tri)

            -- distribute points in triangular lattice using barycentric coordinates
            -- (k+1)th triangular number is (k+1)(k+2)/2, # points in triangular grid with k+1 points per side
            -- solving (k+1)(k+2)/2 = n_particles, using quadratic formula, gives:
            local k = math.floor((-3 + math.sqrt(1 + 8 * n_particles)) / 2)
            if k < 1 then k = 1 end

            for i = 0, k do
                for j = 0, k - i do
                    local l1 = i / k
                    local l2 = j / k
                    local l3 = 1 - l1 - l2

                    local x = math.dot3(l1, l2, l3, ax, bx, cx)
                    local y = math.dot3(l1, l2, l3, ay, by, cy)
                    table.insert(seed_points, { x, y })

                    local before = #particle_data

                    local pi = _particle_i_to_data_offset(particle_i)
                    particle_data[pi + _x_offset] = x
                    particle_data[pi + _y_offset] = y
                    particle_data[pi + _radius_offset] = settings.radius
                    particle_data[pi + _velocity_offset] = settings.velocity
                    particle_data[pi + _last_vx_offset] = 0
                    particle_data[pi + _last_vy_offset] = 0
                    particle_data[pi + _hue_offset] = particle_path:get_fraction(x, y)
                    particle_data[pi + _opacity_offset] = 0
                    particle_data[pi + _lifetime_elapsed_offset] = 0
                    particle_data[pi + _lifetime_offset] = settings.max_lifetime
                    particle_i = particle_i + 1
                end
            end
        end

        -- init hue lookup table
        local hue_to_rgba = {}
        for i = 1, settings.n_hue_steps + 1 do
            local r, g, b, a = rt.lcha_to_rgba(0.8, 1, (i - 1) / settings.n_hue_steps, 1)
            hue_to_rgba[i] = { r, g, b, a }
        end

        self._get_seed = function()
            local entry = seed_points[rt.random.integer(1, #seed_points)]
            return table.unpack(entry)
        end

        self._hue_to_rgba = function(hue)
            hue = math.floor(hue * settings.n_hue_steps)
            local entry = hue_to_rgba[hue]
            assert(entry ~= nil)
            return table.unpack(entry)
        end

        self._particle_path = particle_path
        self._particle_data = particle_data
        self._n_particles = particle_i - 1
    end

    function ow.BoostField:_update_particles(delta)
        local data = self._particle_data
        local path = self._particle_path

        local envelope = rt.InterpolationFunctions.ENVELOPE
        local attack = settings.attack_fraction
        local release = settings.release_fraction
        local opacity_easing = function(t)
            return envelope(math.min(t, 1), attack, release)
        end

        for pi = 1, self._n_particles do
            local i = _particle_i_to_data_offset(pi)

            local x = data[i + _x_offset]
            local y = data[i + _y_offset]
            local velocity = data[i + _velocity_offset]

            local t = path:get_fraction(x, y)
            data[i + _hue_offset] = t

            local dx, dy = path:tangent_at(t)
            x = x + dx * velocity * delta
            y = y + dy * velocity * delta

            local elapsed = data[i + _lifetime_elapsed_offset]
            elapsed = elapsed + delta

            local lifetime = data[i + _lifetime_offset]
            local lifetime_t = elapsed / lifetime

            if lifetime_t > 1 then
                data[i + _opacity_offset] = 0

                --[[ respawn at new position
                local new_x, new_y = self._get_seed()
                data[i + _x_offset] = new_x
                data[i + _y_offset] = new_y
                data[i + _last_vx_offset] = 0
                data[i + _last_vy_offset] = 0
                data[i + _opacity_offset] = 0
                -- hue queried next update
                ]]
            else
                data[i + _x_offset] = x
                data[i + _y_offset] = y
                data[i + _lifetime_elapsed_offset] = elapsed
                data[i + _opacity_offset] = math.min(lifetime_t, 1)
            end
        end
    end

    function ow.BoostField:_draw_particles()
        local data = self._particle_data
        for pi = 1, self._n_particles do
            local i = _particle_i_to_data_offset(pi)
            local x = data[i + _x_offset]
            local y = data[i + _y_offset]
            local r, g, b, a = self._hue_to_rgba(data[i + _hue_offset])
            a = a * data[i + _opacity_offset]
            local radius = data[i + _radius_offset]

            love.graphics.setColor(r, g, b, a)
            love.graphics.circle("fill", x, y, radius)
        end
    end
end
