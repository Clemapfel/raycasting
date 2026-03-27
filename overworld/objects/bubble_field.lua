require "common.contour"
require "overworld.movable_object"

rt.settings.overworld.bubble_field = {
    -- wave equation solver
    excitation_amplitude = 0.00025, -- in frequency space
    excitation_width = 5, -- n vertices

    dx = 0.2,
    dt = 0.05,
    damping = 0.99,
    magnitude = 20, -- px
    deactivation_threshold = 1, -- px

    -- contour
    segment_length = 7,
    n_smoothing_iterations = 3,
    depth = -5, -- negative to account for smoothing contraction

    -- base draw
    opacity = 0.4,
    hue_offset = 0.1
}

--- @class ow.BubbleField
--- @types Polygon, Rectangle, Ellipse
--- @field inverted Boolean? if false, non-bubble -> bubble, otherwise bubble -> non-bubble
ow.BubbleField = meta.class("BubbleField", ow.MovableObject)

local _base_shader = rt.Shader("overworld/objects/bubble_field_base.glsl")
local _outline_shader = rt.Shader("overworld/objects/bubble_field_outline.glsl")

local _noise_texture = rt.NoiseTexture(64, 64, 8,
    rt.NoiseType.GRADIENT,
    16 -- frequency
)

local _lch_texture = rt.LCHTexture(1, 1, 256)

-- shape mesh indices
local _origin_x_index = 1
local _origin_y_index = 2
local _direction_x_index = 3
local _direction_y_index = 4
local _magnitude_index = 5

-- data mesh indices
local _offset_index = 1

--- @brief
function ow.BubbleField:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    self._x, self._y = self._body:get_position()

    self._inverted = object:get_boolean("inverted")
    if self._inverted == nil then self._inverted = false end

    local start_b = not self._inverted
    local end_b = self._inverted

    self._is_colliding = false

    self._collision_start = function(self)
        local player = self._scene:get_player()
        if player:get_is_bubble() == (not start_b) then
            player:request_is_bubble(self, start_b)

            local x, y = player:get_position()
            local vx, vy = player:get_velocity()
            self:_excite_wave(x, y, vx, vy, -1, false) -- inward
        end
    end

    self._collision_end = function(self)
        local player = scene:get_player()
        if player:get_is_bubble() == (not end_b) then
            player:request_is_bubble(self, end_b)
            local x, y = player:get_position()
            local vx, vy = player:get_velocity()
            self:_excite_wave(x, y, vx, vy, 1, true) -- outwards
        end
    end

    local settings = rt.settings.overworld.bubble_field
    
    -- contour
    local contour = object:create_contour()

    local centroid_x, centroid_y = rt.contour.get_centroid(contour)
    for i = 1, #contour, 2 do
        contour[i+0] = contour[i+0] - centroid_x
        contour[i+1] = contour[i+1] - centroid_y
    end

    contour = rt.contour.close(contour)
    contour = rt.contour.subdivide(contour, settings.segment_length)
    contour = rt.contour.smooth(contour, settings.n_smoothing_iterations)

    self._contour = {}

    local shape_mesh_format = {
        { location = 0, name = "origin", format = "floatvec2" }, -- absolute xy
        { location = 1, name = "direction", format = "floatvec2" }, -- normalized xy
        { location = 2, name = "magnitude", format = "float" }, -- px
    }

    local data_mesh_format = {
        { location = 3, name = "offset", format = "float" }, -- px
    }

    local shape_mesh_data = {}
    local data_mesh_data = {}
    
    do -- compute origin vectors
        local path = rt.Path():create_from_and_reparameterize(contour)
        
        local origins = {}
        for i = 1, #contour, 2 do
            local x1, y1 = contour[i+0], contour[i+1]
            local x2, y2 = contour[math.wrap(i+2, #contour)], contour[math.wrap(i+3, #contour)]
            local normal_x, normal_y = math.turn_right(math.normalize(math.subtract(x1, y1, x2, y2)))
            
            table.insert(origins, {
                vertex_offset = i,
                x = x1,
                y = y1,
                normal_x = normal_x,
                normal_y = normal_y,
                magnitude = settings.depth
            })
        end
        
        -- clip origins to polygon
        for origin in values(origins) do
            local intersections = path:get_intersections(
                origin.x,
                origin.y,
                origin.x + origin.normal_x * origin.magnitude,
                origin.y + origin.normal_y * origin.magnitude
            )

            for i = 1, #intersections, 2 do
                local ix, iy = intersections[i+0], intersections[i+1]
                if math.distance(ix, iy, origin.x, origin.y) > 1 then
                    local length = math.max(0, math.distance(origin.x, origin.y, ix, iy) - settings.padding)
                    if length < origin.length then
                        origin.magnitude = length
                    end
                end
            end
            
            table.insert(shape_mesh_data, {
                [_origin_x_index] = origin.x,
                [_origin_y_index] = origin.y,
                [_direction_x_index] = origin.normal_x,
                [_direction_y_index] = origin.normal_y,
                [_magnitude_index] = origin.magnitude
            })
            
            table.insert(data_mesh_data, {
                [_offset_index] = 0
            })
        end
    end

    self._shape_mesh_data = shape_mesh_data
    self._shape_mesh = rt.Mesh(
        shape_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        shape_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
    self._shape_mesh:set_vertex_map(
        rt.DelaunayTriangulation(contour, contour):get_triangle_vertex_map()
    )

    self._data_mesh_data = data_mesh_data
    self._data_mesh = rt.Mesh(
        data_mesh_data,
        rt.MeshDrawMode.POINTS,
        data_mesh_format,
        rt.GraphicsBufferUsage.STREAM
    )

    self._shape_mesh:attach_attribute(self._data_mesh, "offset", "pervertex")

    -- wave equation solver
    self._elapsed = 0
    self._n_points = #self._shape_mesh_data
    self._wave = {
        previous = table.rep(0, self._n_points),
        current = table.rep(0, self._n_points),
        next = table.rep(0, self._n_points)
    }

    self._is_active = true
    self:update(0) -- initialize contour
    self._is_active = false
end

--- @brief
function ow.BubbleField:_excite_wave(x, y, velocity_x, velocity_y, sign)

    local body_x, body_y = self._body:get_position()
    x = x - body_x
    y = y - body_y

    -- find closest verrtex
    local min_distance, center_index = math.huge, nil
    for i = 1, self._n_points do
        local data = self._shape_mesh_data[i]
        local distance = math.distance(
            data[_origin_x_index] + data[_direction_x_index] * data[_magnitude_index],
            data[_origin_y_index] + data[_direction_y_index] * data[_magnitude_index],
            x, y
        )

        if distance < min_distance then
            min_distance = distance
            center_index = i
        end
    end

    if center_index == nil then return end

    local amplitude = sign * math.magnitude(velocity_x, velocity_y) * rt.settings.overworld.bubble_field.excitation_amplitude
    local width = rt.settings.overworld.bubble_field.excitation_width

    for i = 1, self._n_points do
        local distance = math.abs(i - center_index)
        distance = math.min(distance, self._n_points - distance)
        self._wave.current[i] = self._wave.current[i] + amplitude * math.exp(-((distance / width) ^ 2))
    end

    self._is_active = true
end

--- @brief
function ow.BubbleField:update(delta)
    if self._stage:get_is_body_visible(self._body) then
        -- update bubble
        local current = self._is_colliding
        local next = self._body:test_point(self._scene:get_player():get_position())
        if current == false and next == true then
            self:_collision_start()
        elseif current == true and next == false then
            self:_collision_end()
        end

        self._is_colliding = next
    end

    if self._is_active then
        local settings = rt.settings.overworld.bubble_field
        local n_points = self._n_points
        local offset_max = 0

        local dt = settings.dt
        local dx = settings.dx
        local damping = settings.damping
        local courant = dt / dx
        local magnitude = settings.magnitude

        local wave_previous, wave_current, wave_next = self._wave.previous, self._wave.current, self._wave.next

        local contour_i = 1
        local contour = self._contour

        local max_offset = 0

        for i = 1, n_points do
            local left = math.wrap(i-1, n_points)
            local right = math.wrap(i+1, n_points)

            local new = 2 * wave_current[i] - wave_previous[i] + courant^2 * (wave_current[left] - 2 * wave_current[i] + wave_current[right])
            new = new * damping

            wave_next[i] = new

            local shape_data = self._shape_mesh_data[i]
            local offset_data = self._data_mesh_data[i]

            local offset_magnitude = new * magnitude
            offset_data[_offset_index] = offset_magnitude

            max_offset = math.max(max_offset, math.abs(offset_magnitude))

            contour[contour_i+0] = shape_data[_origin_x_index] + shape_data[_direction_x_index] * (shape_data[_magnitude_index] + offset_magnitude)
            contour[contour_i+1] = shape_data[_origin_y_index] + shape_data[_direction_y_index] * (shape_data[_magnitude_index] + offset_magnitude)
            contour_i = contour_i + 2
        end

        if math.distance(contour[1], contour[2], contour[#contour-1], contour[#contour]) > 1 then
            contour[1], contour[2] = contour[#contour-1], contour[#contour]
        end

        self._wave.previous, self._wave.current, self._wave.next = wave_current, wave_next, wave_previous
        self._data_mesh:replace_data(self._data_mesh_data)

        self._is_active = max_offset >= settings.deactivation_threshold
    end
end

--- @brief
function ow.BubbleField:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local transform = self._scene:get_camera():get_transform():inverse()

    local x, y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(x, y)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("none")

    local elapsed = rt.SceneManager:get_elapsed() + meta.hash(self)
    local hue = self._scene:get_player():get_hue()

    love.graphics.setColor(1, 1, 1, rt.settings.overworld.bubble_field.opacity)
    _base_shader:bind()
    _base_shader:send("noise_texture", _noise_texture)
    _base_shader:send("screen_to_world_transform", transform)
    _base_shader:send("elapsed", elapsed)
    _base_shader:send("hue", hue)
    _base_shader:send("hue_offset", rt.settings.overworld.bubble_field.hue_offset)
    _base_shader:send("lch_texture", _lch_texture)

    love.graphics.draw(self._shape_mesh:get_native())

    _base_shader:unbind()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.setLineJoin("none")
    _outline_shader:bind()
    _outline_shader:send("noise_texture", _noise_texture)
    _outline_shader:send("screen_to_world_transform", transform)
    _outline_shader:send("elapsed", elapsed)
    _outline_shader:send("hue", hue)
    _outline_shader:send("lch_texture", _lch_texture)

    love.graphics.line(self._contour)

    _outline_shader:unbind()

    love.graphics.pop()
end