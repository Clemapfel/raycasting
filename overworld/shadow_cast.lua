require "overworld.visibility_query"

rt.settings.overworld.shadow_cast = {}

--- @class ow.ShadowCast
ow.ShadowCast = meta.class("ShadowCast")

local _shader = rt.Shader("overworld/shadow_cast.glsl")

--- @brief
function ow.ShadowCast:instantiate(scene)
    meta.assert(scene, ow.OverworldScene)

    self._scene = scene
    self._query = ow.VisibilityQuery()
    self._intensity = 1

    self._entries = {}
    self._polygons = {}
    self._points = {}

    self._offset_x = 0
    self._offset_y = 0
end

--- @brief
function ow.ShadowCast:initialize(non_reflective_contours, reflective_contours)
    meta.assert(reflective_contours, mt.Table, non_reflective_contours, mt.Table)
    self._query:initialize(
        non_reflective_contours,
        reflective_contours
    )
end

local function _get_ts(segment, subsegment)
    local ax1, ay1, ax2, ay2 = table.unpack(segment)
    local sx1, sy1, sx2, sy2 = table.unpack(subsegment)

    local dx, dy = ax2 - ax1, ay2 - ay1
    local magnitude = math.magnitude(dx, dy)

    if magnitude == 0 then
        return 0, 0
    end

    local ndx, ndy = math.normalize(dx, dy)

    local function fraction_of(px, py)
        local vx, vy = px - ax1, py - ay1
        local proj = math.dot(vx, vy, ndx, ndy)
        return proj / magnitude
    end

    local t1 = fraction_of(sx1, sy1)
    local t2 = fraction_of(sx2, sy2)

    return math.min(t1, t2), math.max(t1, t2)
end

local function _ray_line_intersection(x, y, dir_x, dir_y, ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    local det = dir_x * dy - dir_y * dx

    if math.abs(det) < math.eps then
        return nil
    end

    local oax = ax - x
    local oay = ay - y
    local distance = (oax * dy - oay * dx) / det

    if distance >= 0 then
        local hit_x = x + dir_x * distance
        local hit_y = y + dir_y * distance

        return distance, hit_x, hit_y
    end
    return nil
end

--- @brief
function ow.ShadowCast:update(delta)
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end

    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()
    bounds.x = bounds.x - self._offset_x
    bounds.y = bounds.y - self._offset_y

    local px, py = self._scene:get_player():get_position()
    px = px - self._offset_x
    py = py - self._offset_y

    self._entries = {}
    for data in values(self._query:get_visible_subsegments(px, py, bounds)) do
        table.insert(self._entries, data)
    end

    self._polygons = {}
    self._points = {}

    for entry in values(self._entries) do
        local a_x, a_y, b_x, b_y = table.unpack(entry.subsegment)

        table.insert(self._points, a_x)
        table.insert(self._points, a_y)
        table.insert(self._points, b_x)
        table.insert(self._points, b_y)

        local dax, day = math.normalize(a_x - px, a_y - py)
        local dbx, dby = math.normalize(b_x - py, b_y - py)

        local lx = 2 * bounds.width
        local ly = 2 * bounds.height
        table.insert(self._polygons, {
            a_x, a_y,
            a_x + dax * lx, a_y + day * ly,
            b_x + dbx * lx, b_y + dby * ly,
            b_x, b_y
        })
    end
end

--- @brief
function ow.ShadowCast:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.ShadowCast:get_offset()
    return self._offset_x, self._offset_y
end

--- @brief
function ow.ShadowCast:set_intensity(t)
    self._intensity = t
end

--- @brief
function ow.ShadowCast:draw()
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end
end

--- @brief
function ow.ShadowCast:draw_bloom()
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end
    local r, g, b, a = self._scene:get_player():get_color():unpack()
    local t = self._intensity

    local px, py = self._scene:get_player():get_position()
    px, py = self._scene:get_camera():world_xy_to_screen_xy(px, py)

    _shader:bind()
    _shader:send("player_position", { px, py })

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)
    love.graphics.setLineWidth(4)
    love.graphics.setColor(t * r, t * g, t * b, t * a)
    for entry in values(self._entries) do
        local ax, ay, bx, by = table.unpack(entry.subsegment)
        love.graphics.line(ax, ay, bx, by)
    end
    love.graphics.pop()

    _shader:unbind()
end

--- @brief
function ow.ShadowCast:collect_segment_lights(callback)
    local r, g, b, a = self._scene:get_player():get_color():unpack()
    local t = self._intensity

    love.graphics.setColor(r, g, b, a)
    local ox, oy = self._offset_x, self._offset_y
    for entry in values(self._entries) do
        local ax, ay, bx, by = table.unpack(entry.subsegment)
        callback(
            ax + ox, ay + oy,
            bx + ox, by + oy,
            r, g, b, 0
        )
    end
end

