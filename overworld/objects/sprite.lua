--- @class ow.Sprite
--- @types Rectangle
--- @field render_priority Number?
ow.Sprite = meta.class("OverworldSprite") -- not a rt.Drawable

-- sprite atlas has to list of sprites, sorted by render priority
local _render_priority_to_batches = {} -- Table<Number, Table<love.Texture, Table<ow.Sprite>>>

--- @brief
function ow.Sprite.reinitialize()
    _render_priority_to_batches = {}
end

--- @brief
function ow.Sprite:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper")
    assert(object:get_type() == ow.ObjectType.SPRITE, "In ow.Sprite: object `" .. object:get_id() .. "` is not a sprite")
    self._scene = scene
    self._stage = stage
    self._wrapper = object

    local x, y, w, h = object.x, object.y, object.width, object.height
    local tx, ty, tw, th = object.texture_x, object.texture_y, object.texture_width, object.texture_height
    self._texture = object.texture
    self._quad = object.quad

    self._bounds = rt.AABB(x, y, w, h)

    local round = math.round
    meta.install(self, {
        _x = round(object.x),
        _y = round(object.y),
        _origin_x = round(object.origin_x),
        _origin_y = round(object.origin_y),
        _rotation = object.rotation,
        _offset_x = round(object.offset_x),
        _offset_y = round(object.offset_y),
        _flip_horizontally = object.flip_horizontally,
        _flip_vertically = object.flip_vertically,
        _flip_origin_x = round(object.flip_origin_x),
        _flip_origin_y = round(object.flip_origin_y),
        _rotation_offset = object.rotation_offset,
        _rotation_origin_x = object.rotation_origin_x,
        _rotation_origin_y = object.rotation_origin_y
    })

    self._render_priority = object:get_number("render_priority", false) or 0

    local texture_id = self._texture:get_native()
    local priority_entry = _render_priority_to_batches[self._render_priority]
    if priority_entry == nil then
        priority_entry = {}
        _render_priority_to_batches[self._render_priority] = priority_entry
    end

    local texture_entry = priority_entry[texture_id]
    if texture_entry == nil then
        texture_entry = meta.make_weak({})
        priority_entry[texture_id] = texture_entry
    end

    table.insert(texture_entry, self)
end

--- @brief
function ow.Sprite:_draw()
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
    love.graphics.draw(self._texture:get_native(), self._quad)

    love.graphics.pop()
end

--- @brief
function ow.Sprite.draw_all(priority)
    for priority_entry in values(_render_priority_to_batches) do
        for sprites in values(priority_entry) do
            for sprite in values(sprites) do
                sprite:_draw()
            end
        end
    end
end

--- @brief
function ow.Sprite.list_all_priorities()
    local out = {}
    for priority in keys(_render_priority_to_batches) do
        table.insert(out, priority)
    end
    return out
end