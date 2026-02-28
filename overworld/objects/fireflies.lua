require "common.path1d"
require "overworld.firefly_particle"

rt.settings.overworld.fireflies = {
    radius = 10, -- px

    flow_source_duration = 2, -- seconds
    flow_source_magnitude = 0.25, -- fraction
}

--- @class ow.Fireflies
ow.Fireflies = meta.class("Fireflies")

function ow.Fireflies.reinitialize(scene, stage)
    require "overworld.firefly_manager"
    if stage.firefly_manager ~= nil then
        stage.firefly_manager:clear()
    end
    stage.firefly_manager = ow.FireflyManager(scene, stage)
    stage.firefly_manager_is_first = true
end

function ow.Fireflies.get_point_light_sources(stage)
    if stage.firefly_manager ~= nil then
        return stage.firefly_manager:get_point_light_sources()
    else
        return {}, {}
    end
end

--- @brief
function ow.Fireflies:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.POINT, "In ow.Fireflies: object `", object:get_id(), "` is not a point")

    if stage.firefly_manager_is_first == true then
        -- first per stage is proxy instance
        self.update = function(self, delta)
            stage.firefly_manager:update(delta)
        end

        self.draw = function(self)
            stage.firefly_manager:draw()
        end

        self.get_render_priority = function(self)
            return math.huge
        end

        stage.firefly_manager_is_first = false
    else
        self.update = nil
        self.draw = nil
        self.get_render_priority = nil
    end

    self._should_move_in_place = object:get_boolean("should_move_in_place", false)
    if self._should_move_in_place == nil then self._should_move_in_place = true end
    self._count = object:get_number("count") or rt.random.number(3, 5)

    self._id = stage.firefly_manager:register(
        object.x, object.y,
        self._count,
        self._should_move_in_place
    )

    self._stage = stage
    self._scene = scene
    self._world = stage:get_physics_world()

    self._body = b2.Body(
        self._world,
        b2.BodyType.DYNAMIC,
        object.x, object.y,
        b2.Circle(0, 0, rt.settings.overworld.fireflies.radius + rt.settings.overworld.firefly_manager.max_hover_offset)
    )

    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            self._stage.firefly_manager:notify_collected_by_player(self._id)
        end
    end)

    self._stage:signal_connect("respawn", function(_)
        self._stage.firefly_manager:notify_reset(self._id)
    end)
end
