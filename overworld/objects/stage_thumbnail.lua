--- @class ow.StageThumbnail
ow.StageThumbnail = meta.class("StageThumbnail")

--- @brief
function ow.StageThumbnail:instantiate(object, stage, scene)
    rt.assert(
        object:get_type() == ow.ObjectType.RECTANGLE
            and object:get_rotation() == 0,
        "In ow.StageThumbnail: object is not an axis-aligned rectangle"
    )

    -- proxy, used by mn.StagePreview only
end