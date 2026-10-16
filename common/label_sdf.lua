require "common.label"
require "common.blend_mode"
require "overworld.normal_map"

rt.settings.label_sdf = {
    export_texture_format = rt.TextureFormat.NORMAL, -- needs to be 4-component for png export
    max_distance = 32,
    padding = 0.15 -- fraction of size
}

--- @class rt.LabelSDF
rt.LabelSDF = meta.class("LabelSDF")

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

function rt.LabelSDF:instantiate(text, font_size, font, max_distance, should_draw_inside)
    meta.assert(
        text, mt.String,
        font_size, rt.FontSize,
        font, rt.Font,
        max_distance, mt.Optional(mt.Number),
        should_draw_inside, mt.Optional(mt.Boolean)
    )

    if max_distance == nil then max_distance = rt.settings.label_sdf.max_distance end
    if should_draw_inside == nil then should_draw_inside = false end

    self._label = rt.Label(text, font_size, font)

    self._label:realize()
    self._label:set_wrap_mode(rt.LabelWrapMode.SINGLE_LINE)
    self._label:reformat(0, 0)

    local width, height = self._label:measure()
    self._padding = rt.settings.label_sdf.padding * math.max(width, height)

    local texture_w, texture_h = width + 2 * self._padding,
        height + 2 * self._padding

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

    self._max_distance = max_distance
    self._should_draw_inside = should_draw_inside
    self._sdf_needs_export = true
end

function rt.LabelSDF:_compute()
    -- write to mask
    love.graphics.push("all")
    love.graphics.reset()
    self._mask_texture:bind()
    love.graphics.clear()

    love.graphics.push()
    love.graphics.translate(self._padding, self._padding)
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
    _export_shader:send("use_mask", self._should_draw_inside)
    _export_shader:send("max_distance", rt.settings.label_sdf.max_distance)
    _export_shader:dispatch(self._dispatch_x, self._dispatch_y)

    self._sdf_needs_export = false
    love.graphics.pop() -- all
end

function rt.LabelSDF:draw()
    if self._sdf_needs_export then self:_compute() end
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.translate(-self._padding, -self._padding)
    self._export_texture:draw()
    love.graphics.pop()
end

function rt.LabelSDF:update(delta)
    self._label:update(delta)
end

function rt.LabelSDF:export(path, format)
    meta.assert(path, mt.String, format, mt.Optional(rt.ImageEncodingFormat))
    if self._sdf_needs_export then self:_compute() end
    self._export_texture:download():save_to(path, format)
end
