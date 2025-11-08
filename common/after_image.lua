rt.settings.after_image = {
    texture_format = rt.TextureFormat.RGBA8,
    msaa = 0,
    frame_delay = 4 / 60, -- time between frames
}

--- @class rt.AfterImage
rt.AfterImage = meta.class("AfterImage")

local _shader = rt.Shader("overworld/after_image.glsl")

--- @brief
function rt.AfterImage:instantiate(n_frames, texture_width, texture_height)
    meta.assert(n_frames, "Number", texture_width, "Number", texture_height, "Number")

    local settings = rt.settings.after_image

    self._textures = {}
    self._texture_buffer = meta.make_weak({}) -- fifo queue
    self._color_buffer = {}

    self._n_textures = n_frames
    self._texture_width = texture_width
    self._texture_height = texture_height

    for frame_i = 1, n_frames do
        local texture = rt.RenderTexture(
            texture_width, texture_height,
            settings.msaa,
            settings.texture_format
        )
        texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
        table.insert(self._texture_buffer, texture)
        table.insert(self._color_buffer, {
            rt.lcha_to_rgba(0.8, 1, (frame_i - 1) / n_frames, 1)
        })
    end
end

--- @brief
function rt.AfterImage:bind()
    self._texture_buffer[1]:bind()
end

--- @brief
function rt.AfterImage:unbind()
    self._texture_buffer[1]:unbind()

    for buffer in range(self._texture_buffer, self._color_buffer) do
        local front = self._texture_buffer[1]
        table.remove(self._texture_buffer, 1)
        table.insert(self._texture_buffer, front)
    end
end

--- @brief
function rt.AfterImage:draw(index, ...)
    _shader:bind()
    love.graphics.setColor(self._color_buffer[index])
    love.graphics.draw(
        self._texture_buffer[index]:get_native(),
        ...
    )
    _shader:unbind()
end

--- @brief
function rt.AfterImage:get_n_frames()
    return #self._texture_buffer
end

--- @brief
function rt.AfterImage:get_size()
    return self._texture_width, self._texture_height
end