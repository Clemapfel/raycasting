--- @class ow.BubbleField
ow.BubbleField = meta.class("BubbleField")

--- @brief
function ow.BubbleField:instantiate(object, stage, scene)
    self._scene = scene
    self._world = stage:get_physics_world()

    -- calculate contour
    local segments = {}
    local mesh, tris = object:create_mesh()
    self._mesh = mesh
    for tri in values(tris) do
        for segment in range(
            {tri[1], tri[2], tri[3], tri[4]},
            {tri[3], tri[4], tri[5], tri[6]},
            {tri[1], tri[2], tri[5], tri[6]}
        ) do
            table.insert(segments, segment)
        end
    end

    local _hash = function(points)
        local x1, y1, x2, y2 = math.floor(points[1]), math.floor(points[2]), math.floor(points[3]), math.floor(points[4])
        if x1 < x2 or (x1 == x2 and y1 < y2) then -- swap so point order does not matter
            x1, y1, x2, y2 = x2, y2, x1, y1
        end
        return tostring(x1) .. "," .. tostring(y1) .. "," .. tostring(x2) .. "," .. tostring(y2)
    end

    local _unhash = function(hash)
        return { hash:match("([^,]+),([^,]+),([^,]+),([^,]+)") }
    end

    local tuples = {}
    local n_total = 0
    for segment in values(segments) do
        local hash = _hash(segment)
        local current = tuples[hash]
        if current == nil then
            tuples[hash] = 1
        else
            tuples[hash] = current + 1
        end
        n_total = n_total + 1
    end

    local contour, shapes = {}, {}
    for hash, count in pairs(tuples) do
        if count == 1 then
            local segment = _unhash(hash)
            table.insert(contour, segment)
            table.insert(shapes, b2.Segment(segment))
        end
    end

    self._contour = contour

    self._body = object:create_physics_body(self._world) --b2.Body(self._world, b2.BodyType.KINEMATIC, 0, 0, table.unpack(shapes))
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)

    self._body:signal_connect("collision_start", function()
        local player = scene:get_player()
        if player:get_is_bubble() == false and not self._blocked then
            self:_block_signals()

            player:set_is_bubble(true)
        end
    end)

    self._body:signal_connect("collision_end", function()
        local player = scene:get_player()
        if player:get_is_bubble() == true and not self._blocked then
            self:_block_signals()

            -- check if player is actually outside body
            if self._body:test_point(player:get_physics_body():get_position()) then
                return
            end

            player:set_is_bubble(false)
        end
    end)
end

--- @brief
function ow.BubbleField:draw()
    rt.Palette.BLUE_1:bind()
    love.graphics.setLineWidth(2)
    love.graphics.setLineJoin("bevel")
    for segment in values(self._contour) do
        love.graphics.line(segment)
    end
end

--- @brief
function ow.BubbleField:_block_signals()
    -- block signals until next step to avoid infinite loops
    -- because set_is_bubble can teleport
    self._body:signal_set_is_blocked("collision_start", true)
    self._body:signal_set_is_blocked("collision_end", true)

    self._world:signal_connect("step", function()
        self._body:signal_set_is_blocked("collision_start", false)
        self._body:signal_set_is_blocked("collision_end", false)
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.BubbleField:get_render_priority()
    return -math.huge
end