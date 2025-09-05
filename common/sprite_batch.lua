require "common.mesh"
require "common.shader"
require "common.graphics_buffer"

rt.settings.sprite_batch = {
    use_subpixel_filtering = true
}

--- @class rt.SpriteBatch
rt.SpriteBatch = meta.class("SpriteBatch")

local _shader
do
    local defines = {}
    if rt.settings.sprite_batch.use_subpixel_filtering then
        defines.APPLY_ANTI_ALIAS_CORRECTION = 1
    end

    _shader = rt.Shader("common/sprite_batch.glsl", defines)
end

--- @brief
function rt.SpriteBatch:instantiate(texture)
    assert(meta.isa(texture, rt.Texture), "In rt.SpriteBatch: expected `Texture`, got `" .. meta.typeof(texture) .. "`")
    texture:set_wrap_mode(rt.TextureWrapMode.REPEAT)

    if rt.settings.sprite_batch.use_subpixel_filtering then
        texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
    else
        texture:set_scale_mode(rt.TextureScaleMode.NEAREST)
    end

    meta.install(self, {
        _texture = texture,
        _mesh = rt.MeshRectangle(0, 0, 1, 1),
        _buffer = nil,
        _needs_update = true,
        _first_index_that_needs_update = 1,
        _last_index_that_needs_update = 0,
        _data = {},
        _current_i = 0
    })
end

function rt.SpriteBatch._params_to_data(x, y, w, h, tx, ty, tw, th, flip_horizontally, flip_vertically, angle)
    local flip_v, flip_h
    if flip_horizontally == true then flip_h = 1 else flip_h = 0 end
    if flip_vertically == true then flip_v = 1 else flip_v = 0 end

    return {
        x + 0, y + 0, -- top_left
        x + w, y + 0, -- top_right
        x + w, y + h, -- bottom_left
        x + 0, y + h, -- bottom_right

        tx +  0, ty +  0, -- texture_top_left
        tx + tw, ty +  0, -- texture_top_right
        tx + tw, ty + th, -- texture_bottom_right
        tx +  0, ty + th, -- texture_bottom_left

        x + w, y + h, -- origin (bottom left)
        flip_h, flip_v,
        angle
    }
end

--- @brief
--- @param rotation radians rotates bottom left corner
--- @return
function rt.SpriteBatch:add(x, y, w, h, tx, ty, tw, th, flip_horizontally, flip_vertically, angle)
    if flip_horizontally == nil then flip_horizontally = false end
    if flip_vertically == nil then flip_vertically = false end
    if angle == nil then angle = 0 end

    meta.assert(
        x, "Number",
        y, "Number",
        w, "Number",
        h, "Number",
        tx, "Number",
        ty, "Number",
        tw, "Number",
        th, "Number",
        flip_horizontally, "Boolean",
        flip_vertically, "Boolean",
        angle, "Number"
    )

    table.insert(self._data, self._params_to_data(
        x, y, w, h,
        tx, ty, tw, th,
        flip_horizontally, flip_vertically,
        angle
    ))

    self._current_i = self._current_i + 1
    self._needs_update = true
    self._first_index_that_needs_update = math.min(self._first_index_that_needs_update, 1)
    self._last_index_that_needs_update = math.max(self._last_index_that_needs_update, self._current_i)
    return self._current_i
end

--- @brief
function rt.SpriteBatch:set(i, x, y, w, h, tx, ty, tw, th, flip_horizontally, flip_vertically, angle)
    if flip_horizontally == nil then flip_horizontally = false end
    if flip_vertically == nil then flip_vertically = false end
    if angle == nil then angle = 0 end

    meta.assert(
        x, "Number",
        y, "Number",
        w, "Number",
        h, "Number",
        tx, "Number",
        ty, "Number",
        tw, "Number",
        th, "Number",
        flip_horizontally, "Boolean",
        flip_vertically, "Boolean",
        angle, "Number"
    )

    if i > self._current_i then
        rt.error("In rt.SpriteBatch.set: index `" .. i .. "` is out of bounds for a batch with `" .. self._current_i .. "` sprites")
        return
    end

    self._data[i] = self._params_to_data(
        x, y, w, h,
        tx, ty, tw, th,
        flip_horizontally, flip_vertically,
        angle
    )

    self._needs_update = true
    self._first_index_that_needs_update = math.min(self._first_index_that_needs_update, i)
    self._last_index_that_needs_update = math.max(self._last_index_that_needs_update, i)
end

--- @brief
function rt.SpriteBatch:_upload()
    if self._buffer == nil then
        self._buffer_format = _shader:get_buffer_format("SpriteBuffer")
        self._buffer = rt.GraphicsBuffer(self._buffer_format, self._current_i)
    end

    if self._first_index_that_needs_update == math.huge or self._last_index_that_needs_update == -math.huge then
        return
    end

    self._buffer:replace_data(self._data,
        self._first_index_that_needs_update, -- data offset
        self._first_index_that_needs_update, -- buffer offset
        self._last_index_that_needs_update - self._first_index_that_needs_update + 1 -- count
    )

    self._mesh:set_texture(self._texture)
    self._first_index_that_needs_update = math.huge
    self._last_index_that_needs_update = -math.huge
end

--- @brief
function rt.SpriteBatch:draw()
    if self._needs_update then
        self:_upload()
        self._needs_update = false
    end

    _shader:bind()
    _shader:send("SpriteBuffer", self._buffer)
    _shader:send("texture_resolution", { self._texture:get_size() })
    self._mesh:draw_instanced(self._current_i)
    _shader:unbind()
end