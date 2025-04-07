
--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _world = stage:get_physics_world(),
        _body = object:create_physics_body(stage:get_physics_world()),
        _cooldown = -math.huge,
    })

    self._body:set_restitution(2)
    local i = 0
    self._body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y, x1, y1, x2, y2, contact)
        local elapsed = love.timer.getTime() - self._cooldown
        if elapsed > rt.settings.overworld.player.bounce_duration / 2 then
            local player = other_body:get_user_data()
            if player == nil or player.bounce == nil then return end

            -- contact normal is not surface normal, to get the
            -- latter, cast a ray from player center to collision point on shape
            local x, y = player:get_physics_body():get_position()
            local shape = table.first(self._body:get_native():getShapes())
            local tx, ty = self._body:get_position()
            local angle = self._body:get_rotation()

            local cx, cy = x1, y1
            if x2 ~= nil or y2 ~= nil then -- if two points, use mean
                cx = (x1 + x2) / 2
                cy = (y1 + y2) / 2
            end

            local success, nx, ny, fraction = pcall(shape.rayCast, shape, x, y, cx, cy, 2, tx, ty, angle)
            if not success or nx == nil or ny == nil then return end

            player:bounce(nx, ny)
            self._cooldown = love.timer.getTime()
        end

        contact:setRestitution(0.9)
    end)
end

--- @brief
function ow.BouncePad:draw()
    rt.Palette.PINK:bind()
    self._body:draw()
end