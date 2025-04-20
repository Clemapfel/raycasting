--- @class ow.CameraBounds
ow.CameraBounds = meta.class("CameraBounds")

--- @brief
function ow.CameraBounds:instantiate(object, stage, scene)
    assert(object.type == ow.ObjectType.RECTANGLE and object.rotation == 0, "In ow.Stage: object of class `" .. camera_bounds_class_name .. "` is not an axis-aligned rectangle")
    scene:set_camera_bounds(rt.AABB(object.x, object.y, object.width, object.height))
end