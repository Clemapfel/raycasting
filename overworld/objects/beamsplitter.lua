--- @class ow.BeamSplitter
ow.BeamSplitter = meta.class("BeamSplitter", rt.Drawable)

--- @brief
function ow.BeamSplitter:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    meta.install(self, {
        _world = world,
        _body = object:create_physics_body(world),
        _object = object,

        _generated_beams = {},
        _valid_rays = {}
    })

    assert(object.type == ow.ObjectType.RECTANGLE)
    self._body:set_user_data(self)
    self._body:set_collision_group(ow.RayMaterial.BEAM_SPLITTER) -- make actual body transmissive

    local x1, y1 = object.x, object.y
    local x2, y2 = object.x + object.width, object.y + object.height

    local x_offset, y_offset = self._body:get_position()
    x1 = x1 + x_offset
    y1 = y1 + y_offset
    x2 = x2 + x_offset
    y2 = y2 + y_offset

    local origin_x, origin_y = object.rotation_origin_x + x_offset, object.rotation_origin_y + y_offset
    local angle = object.rotation + self._body:get_rotation()

    x1, y1 = math.rotate(x1, y1, angle, origin_x, origin_y)
    x2, y2 = math.rotate(x2, y2, angle, origin_x, origin_y)
end

--- @brief
function ow.BeamSplitter:update(delta)
    for key, entry in pairs(self._generated_beams) do
        if not self._valid_rays[key] == true then
            self._generated_beams[key] = nil
        else
            entry.beam:update(delta)
        end
    end
end

--- @brief
function ow.BeamSplitter:draw()
    self._body:draw()

    local object = self._object
    local x1, y1 = object.x, object.y
    local x2, y2 = object.x + object.width, object.y + object.height

    local x_offset, y_offset = self._body:get_position()
    x1 = x1 + x_offset
    y1 = y1 + y_offset
    x2 = x2 + x_offset
    y2 = y2 + y_offset

    local origin_x, origin_y = object.rotation_origin_x + x_offset, object.rotation_origin_y + y_offset
    local angle = object.rotation + self._body:get_rotation()

    x1, y1 = math.rotate(x1, y1, angle, origin_x, origin_y)
    x2, y2 = math.rotate(x2, y2, angle, origin_x, origin_y)

    love.graphics.line(x1, y1, x2, y2)
end

function ow.BeamSplitter:split_ray(beam_id, contact_x, contact_y, dx, dy, normal_x, normal_y)
    local object = self._object
    local x1, y1 = object.x, object.y
    local x2, y2 = object.x + object.width, object.y + object.height

    local x_offset, y_offset = self._body:get_position()
    x1 = x1 + x_offset
    y1 = y1 + y_offset
    x2 = x2 + x_offset
    y2 = y2 + y_offset

    -- get screen intersection
    local origin_x, origin_y = object.rotation_origin_x + x_offset, object.rotation_origin_y + y_offset
    local angle = object.rotation + self._body:get_rotation()

    x1, y1 = math.rotate(x1, y1, angle, origin_x, origin_y)
    x2, y2 = math.rotate(x2, y2, angle, origin_x, origin_y)

    local x3, y3 = contact_x, contact_y
    local x4, y4 = contact_x + dx, contact_y + dy

    local denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

    local intersect_x = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / denominator
    local intersect_y = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / denominator

    local on_segment = (math.min(x1, x2) <= intersect_x and intersect_x <= math.max(x1, x2)) and
        (math.min(y1, y2) <= intersect_y and intersect_y <= math.max(y1, y2))

    if not on_segment or denominator == 0 then
        self._origin_x = 0
        self._origin_y = 0
        self._dx = 0
        self._dy = 0
        return false
    end

    -- normal of the screen
    local ndx, ndy = x2 - x1, y2 - y1
    local nx, ny = ndy, -ndx

    if (nx * dx + ny * dy) > 0 then
        nx = -nx
        ny = -ny
    end

    nx, ny = math.normalize(nx, ny)

    -- reflect
    local dx_before, dy_before = dx, dy
    local dot_product = dx * nx + dy * ny
    dx = dx - 2 * dot_product * nx
    dy = dy - 2 * dot_product * ny

    ndx, ndy = math.normalize(dx, dy)
    return true, intersect_x, intersect_y, ndx, ndy
end