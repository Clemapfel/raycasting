require "common.label"
require "overworld.normal_map"

--- @class rt.ExportSDF
rt.ExportSDF = meta.class("ExportSDF")

function rt.ExportSDF:instantiate(text, font, font_size)
    meta.assert(text, mt.String, font, rt.Font, font_size, rt.FontSize)

    self._label = rt.Label(text, font_size, font)

    self._label:realize()
    self._label:set_wrap_mode(rt.LabelWrapMode.SINGLE_LINE)
    self._label:reformat(0, 0)

    local width, height = self._label:measure()
    self._padding = math.max(0.1 * width, 0.1 * height)

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
        format = rt.TextureFormat.R8,
        is_compute = true
    })

    local group_size = 16
    self._dispatch_x, self._dispatch_y = math.ceil(texture_w / group_size),
        math.ceil(texture_h / group_size)

    local defines = function(mode)
        return {
            MODE = mode,
            WORK_GROUP_SIZE_X = group_size,
            WORK_GROUP_SIZE_Y = group_size,
            MASK_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(self._mask_texture:get_format()),
            JFA_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(self._jfa_texture:get_format()),
            EXPORT_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(self._export_texture:get_format())
        }
    end
    
    self._init_shader = rt.ComputeShader("website/export_sdf.glsl", defines(0))
    self._jump_shader = rt.ComputeShader("website/export_sdf.glsl", defines(1))
    self._export_shader = rt.ComputeShader("website/export_sdf.glsl", defines(2))

    self:_compute()
end

function rt.ExportSDF:_compute()
    -- write to mask
    love.graphics.push("all")
    love.graphics.reset()
    self._mask_texture:bind()
    love.graphics.clear()
    love.graphics.translate(self._padding, self._padding)
    self._label:draw()
    self._mask_texture:unbind()
    love.graphics.pop()

    -- init jfa
    self._init_shader:send("mask_texture", self._mask_texture)
    self._init_shader:send("jfa_texture_array", self._jfa_texture)
    self._init_shader:dispatch(self._dispatch_x, self._dispatch_y)

    -- jfa
    local jump = math.max(self._mask_texture:get_size())
    local current_layer = 0

    self._jump_shader:send("jfa_texture_array", self._jfa_texture)
    while jump > 0.5 do -- jfa+1, necessary
        local input_layer = current_layer
        local output_layer = 1 - current_layer

        self._jump_shader:send("input_layer", input_layer)
        self._jump_shader:send("output_layer", output_layer)
        self._jump_shader:send("jump_distance", math.ceil(jump))
        self._jump_shader:dispatch(self._dispatch_x, self._dispatch_y)

        current_layer = output_layer
        jump = jump / 2
    end

    -- export
    self._export_shader:send("layer", current_layer)
    self._export_shader:send("jfa_texture_array", self._jfa_texture)
    self._export_shader:send("export_texture", self._export_texture)
    self._export_shader:dispatch(self._dispatch_x, self._dispatch_y)
end

function rt.ExportSDF:draw()
    love.graphics.clear()
    self._export_texture:draw()
end

function rt.ExportSDF:update(delta)
    self._label:update(delta)
    self:_compute()
end
