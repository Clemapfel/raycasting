--- @class ow.Sprite
ow.Sprite = meta.class("OverworldSprite", rt.Drawable)

local _vertex_format = {
    { location = 0, name = "VertexPosition", format = "floatvec2" },
    { location = 1, name = "VertexTexCoord", format = "floatvec2" },
    { location = 2, name = "VertexColor", format = "floatvec4" },
}

--- @brief
function ow.Sprite:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper")
    assert(object:get_type() == ow.ObjectType.SPRITE, "In ow.Sprite: object `" .. object:get_id() .. "` is not a sprite")
    self._scene = scene
    self._stage = stage
    self._wrapper = object

    local x, y, w, h = 0, 0, object.width, object.height
    local tx, ty, tw, th = object.texture_x, object.texture_y, object.texture_width, object.texture_height
    self._mesh = love.graphics.newMesh(
        _vertex_format,
        {
            { x + 0, y + 0, tx +  0, ty +  0, 1, 1, 1, 1 },
            { x + w, y + 0, tx + tw, ty +  0, 1, 1, 1, 1 },
            { x + w, y + h, tx + tw, ty + th, 1, 1, 1, 1 },
            { x + 0, y + h, tx +  0, ty + th, 1, 1, 1, 1 }
        },
        rt.MeshDrawMode.TRIANGLE_FAN
    )
    self._mesh:setTexture(object.texture._native)
    object.texture:set_scale_mode(rt.TextureScaleMode.NEAREST)

    self._bounds = rt.AABB(x, y, w, h)

    for which in range(
        "x", "y",
        "origin_x", "origin_y", "rotation",
        "offset_x", "offset_y",
        "flip_horizontally", "flip_vertically",
        "flip_origin_x", "flip_origin_y",
        "rotation_offset",
        "rotation_origin_x", "rotation_origin_y"
    ) do
        self["_" .. which] = object[which]
    end

    for which in range(
        "x", "y", "origin_x", "origin_y", "offset_x", "offset_y", "flip_origin_x", "flip_origin_y"
    ) do
        self["_" .. which] = math.round(self["_" .. which])
    end
end

--- @brief
function ow.Sprite:draw()
    if not self._scene:get_camera():get_world_bounds():overlaps(self._bounds) then return end

    love.graphics.push()

    love.graphics.translate(self._origin_x, self._origin_y)
    love.graphics.rotate(self._rotation)
    love.graphics.translate(-self._origin_x, -self._origin_y)

    love.graphics.translate(self._x, self._y)

    love.graphics.translate(self._rotation_origin_x, self._rotation_origin_y)
    love.graphics.rotate(self._rotation_offset)
    love.graphics.translate(-self._rotation_origin_x, -self._rotation_origin_y)

    love.graphics.translate(self._offset_x, self._offset_y)

    if self._flip_horizontally or self._flip_vertically then
        love.graphics.translate(self._flip_origin_x, self._flip_origin_y)
        love.graphics.scale(
            self._flip_horizontally and -1 or 1,
            self._flip_vertically and -1 or 1
        )
        love.graphics.translate(-self._flip_origin_x, -self._flip_origin_y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._mesh)

    love.graphics.pop()
end
