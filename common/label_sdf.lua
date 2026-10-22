require "common.widget"
require "common.label"
require "common.blend_mode"
require "overworld.normal_map"

rt.settings.label_sdf = {
    export_texture_format = rt.TextureFormat.NORMAL, -- needs to be 4-component for png export
    max_distance = 32,
    padding_horizontal = 30, -- px
    padding_vertical = 30
}

--- @class rt.LabelSDF
rt.LabelSDF = meta.class("LabelSDF", rt.Widget)

local _group_size = 16
local defines = function(mode)
    return {
        MODE = mode,
        WORK_GROUP_SIZE_X = _group_size,
        WORK_GROUP_SIZE_Y = _group_size,
        MASK_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(rt.settings.overworld.normal_map.mask_texture_format),
        JFA_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(rt.settings.overworld.normal_map.jfa_texture_format),
        EXPORT_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(rt.settings.label_sdf.export_texture_format)
    }
end

local _init_shader = rt.ComputeShader("common/label_sdf.glsl", defines(0))
local _jump_shader = rt.ComputeShader("common/label_sdf.glsl", defines(1))
local _export_shader = rt.ComputeShader("common/label_sdf.glsl", defines(2))

function rt.LabelSDF:instantiate(text, font_size, font, max_distance)
    meta.assert(
        text, mt.String,
        font_size, rt.FontSize,
        font, rt.Font,
        max_distance, mt.Optional(mt.Number)
    )

    if max_distance == nil then max_distance = rt.settings.label_sdf.max_distance end

    self._label = rt.Label(text, font_size, font)

    self._label:realize()
    self._label:set_wrap_mode(rt.LabelWrapMode.SINGLE_LINE)
    self._label:reformat(0, 0)

    self._max_distance = max_distance
    self._sdf_needs_export = true

    self._padding_x, self._padding_y = 0, 0
    self._is_initialized = false
end

function rt.LabelSDF:reformat(x, y, width, height)
    local label_w, label_h = self._label:measure()
    local padding_horizontal = rt.settings.label_sdf.padding_horizontal
    local padding_vertical = rt.settings.label_sdf.padding_vertical

    local texture_w = math.max(width, label_w + 2 * padding_horizontal)
    local texture_h = math.max(height, label_h + 2 * padding_vertical)

    self._padding_x = (texture_w - label_w) / 2
    self._padding_y = (texture_h - label_h) / 2

    free(self._mask_texture, self._jfa_texture, self._export_texture)

    -- init mask
    self._mask_texture = rt.RenderTexture(texture_w, texture_h, {
        format = rt.settings.overworld.normal_map.mask_texture_format,
        is_compute = true
    })
    self._mask_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

    self._jfa_texture = rt.RenderTextureArray(texture_w, texture_h,
        2, -- n layers
        {
            format = rt.settings.overworld.normal_map.jfa_texture_format,
            is_compute = true
        }
    )

    self._export_texture = rt.RenderTexture(texture_w, texture_h, {
        format = rt.settings.label_sdf.export_texture_format,
        is_compute = true
    })

    self._dispatch_x, self._dispatch_y = math.ceil(texture_w / _group_size),
    math.ceil(texture_h / _group_size)

    self._is_initialized = true
end

function rt.LabelSDF:_compute()
    -- write to mask
    love.graphics.push("all")
    love.graphics.reset()
    self._mask_texture:bind()
    love.graphics.clear()

    love.graphics.push()
    love.graphics.translate(self._padding_x, self._padding_y)
    self._label:draw()
    love.graphics.pop()

    self._mask_texture:unbind()

    -- init jfa
    _init_shader:send("mask_texture", self._mask_texture)
    _init_shader:send("jfa_texture_array", self._jfa_texture)
    _init_shader:dispatch(self._dispatch_x, self._dispatch_y)

    -- jfa
    local jump = math.max(self._mask_texture:get_size())
    local current_layer = 0

    _jump_shader:send("jfa_texture_array", self._jfa_texture)
    while jump > 0.5 do -- jfa+1, necessary
        local input_layer = current_layer
        local output_layer = 1 - current_layer

        _jump_shader:send("input_layer", input_layer)
        _jump_shader:send("output_layer", output_layer)
        _jump_shader:send("jump_distance", math.ceil(jump))
        _jump_shader:dispatch(self._dispatch_x, self._dispatch_y)

        current_layer = output_layer
        jump = jump / 2
    end

    -- export
    _export_shader:send("layer", current_layer)
    _export_shader:send("jfa_texture_array", self._jfa_texture)
    _export_shader:send("export_texture", self._export_texture)
    _export_shader:send("mask_texture", self._mask_texture)
    _export_shader:send("max_distance", rt.settings.label_sdf.max_distance)
    _export_shader:dispatch(self._dispatch_x, self._dispatch_y)

    self._sdf_needs_export = false
    love.graphics.pop() -- all
end

function rt.LabelSDF:draw()
    if self._is_initialized ~= true then
        rt.error("In rt.LabelSDF: `draw` was called before `reformat`")
    end

    if self._sdf_needs_export then self:_compute() end
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.translate(-self._padding_x, -self._padding_y)
    self._export_texture:draw()
    love.graphics.pop()
end

function rt.LabelSDF:update(delta)
    self._label:update(delta)
end

function rt.LabelSDF:measure()
    local w, h = self._label:measure()
    local padding_horizontal = rt.settings.label_sdf.padding_horizontal
    local padding_vertical = rt.settings.label_sdf.padding_vertical
    return w + 2 * padding_horizontal, h + 2 * padding_vertical
end

function rt.LabelSDF:export(path, format)
    meta.assert(path, mt.String, format, mt.Optional(rt.ImageEncodingFormat))
    if self._sdf_needs_export then self:_compute() end
    self._export_texture:download():save_to(path, format)
end
