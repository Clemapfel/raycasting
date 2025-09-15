require "overworld.dialog_box"
require "common.label"
require "common.translation"

rt.settings.overworld.dialog_emitter = {
    interact_range_factor = 10, -- * player radius
    asset_prefix = "assets/text/"
}

--- @class ow.DialogEmitter
ow.DialogEmitter = meta.class("DialogEmitter")

--- @brief
function ow.DialogEmitter:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.DialogEmitter: object is not a point")
    self._stage = stage
    self._scene = scene
    self._world = self._stage:get_physics_world()

    self._target_wrapper = object:get_object("target", true)
    self._target_instance = nil -- any
    self._target_body = nil -- b2.Body
    self._target_contour = self._target_wrapper:create_contour()
    table.insert(self._target_contour, self._target_contour[1])
    table.insert(self._target_contour, self._target_contour[2])

    local throw = function(msg)
        rt.error("In ow.DialogEmitter: for object `" .. object:get_id() .."` : " .. msg)
    end

    do -- gen trigger area
        require "common.player"
        self._x, self._y = object.x, object.y

        local radius = rt.settings.overworld.dialog_emitter.interact_range_factor * rt.settings.player.radius
        self._radius = radius
        self._bottom_x, self._bottom_y = self._world:query_ray(
            self._x, self._y, 0, radius
        )

        if self._bottom_x == nil then
            self._bottom_x = self._x
            self._bottom_y = self._y + radius
        end

        local bottom_x, bottom_y = 0, self._bottom_y - self._y
        local x_radius, y_radius = radius, self._bottom_y - self._y

        -- generate sensor shape as half-circle
        local vertices = {}
        local n_vertices = 8
        for i = 1, n_vertices do
            local angle = (2 * math.pi) - ((i - 1) / (n_vertices - 1)) * (math.pi)
            table.insert(vertices, bottom_x + math.cos(angle) * x_radius)
            table.insert(vertices, bottom_y + math.sin(angle) * y_radius)
        end

        self._sensor = b2.Body(
            self._world, b2.BodyType.STATIC,
            self._x, self._y,
            b2.Polygon(vertices)
        )
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.INTERACT then
            self:emit()
        end
    end)

    self._sensor:set_is_sensor(true)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)
    self._sensor:signal_connect("collision_start", function(_, other_body)
        self._input:activate()
    end)

    self._sensor:signal_connect("collision_end", function(_, other_body)
        self._input:deactivate()
    end)

    self._stage:signal_connect("initialized", function(_)
        self._target_instance = self._stage:object_wrapper_to_instance(self._target_wrapper)

        -- use target body or aabb for visiblity testing
        self._target_body = self._target_instance._body
        if self._target_body == nil then
            local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
            for i = 1, #self._target_contour, 2 do
                local x = self._target_contour[i+0]
                local y = self._target_contour[i+1]
                min_x = math.min(min_x, x)
                max_x = math.max(max_x, x)
                min_y = math.min(min_y, y)
                max_y = math.max(max_y, y)
            end

            self._target_aabb = rt.AABB(min_x, min_y, max_x - min_x, max_y - min_y)
        end
    end)

    do -- load dialog config from file
        local id = object:get_string("id", true)

        string.gsub(id, "^/|/$", "") -- remove prefix or postfix /
        local path = rt.settings.overworld.dialog_emitter.asset_prefix .. id .. ".lua"

        if love.filesystem.getInfo(path) == nil then
            throw("file at `" .. path .. "` does not exist")
        end

        local chunk, error_maybe = love.filesystem.load(path)
        if error_maybe ~= nil then
            throw("unable to load file at `" .. path .. "`: " .. error_maybe)
        end

        local success, config_or_error = pcall(chunk)

        if success == false then
            throw("error when running file at `" .. path .. "`: " .. config_or_error)
        end

        self._dialog_id = id
        self._dialog_config = config_or_error
        self._dialog_box = ow.DialogBox(self._dialog_config)
    end
end

--- @brief
function ow.DialogEmitter:emit()
    dbg(self._dialog_id)
end

--- @brief
function ow.DialogEmitter:draw()
    if self._target_body ~= nil then
        if not self._stage:get_is_body_visible(self._target_body) then return end
    else
        if not self._scene:get_camera():get_world_bounds():overlaps(self._target_aabb) then return end
    end

    rt.Palette.SELECTION:bind()
    love.graphics.setLineWidth(1.5)
    love.graphics.line(self._target_contour)

    love.graphics.setColor(1, 1, 1, 1)
    self._sensor:draw()
    love.graphics.circle("line", self._x, self._y, 5)
    local h = love.graphics.getFont():getHeight()
    local w = love.graphics.getFont():getWidth(self._dialog_id)
    love.graphics.print(
        self._dialog_id,
        self._x - 0.5 * w,
        self._y - rt.settings.margin_unit - h
    )

    love.graphics.line(
        self._x, self._y,
        self._bottom_x, self._bottom_y
    )
end
