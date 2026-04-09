require "common.graphics_buffer_usage"

local _usage = {
    shaderstorage = true,
    usage = "dynamic"
}

--- @class rt.GraphicsBuffer
rt.GraphicsBuffer = meta.class("GraphicsBuffer")

--- @brief
function rt.GraphicsBuffer:instantiate(format, n_elements_or_table, usage)
    if meta.is_table(n_elements_or_table) and meta.is_function(n_elements_or_table.get_native) then
        n_elements_or_table = n_elements_or_table:get_native()
    end

    if usage == nil then usage = rt.GraphicsBufferUsage.DYNAMIC end
    if usage == rt.GraphicsBufferUsage.STREAM then
        -- map stream to dynamic, keep local bytedata
        self._native = love.graphics.newBuffer(format, n_elements_or_table, {
            shaderstorage = true,
            usage = rt.GraphicsBufferUsage.DYNAMIC
        })
        self:download()
    else
        self._native = love.graphics.newBuffer(format, n_elements_or_table, {
            shaderstorage = true,
            usage = usage
        })
    end

    self._format = format
    self:_initialize_formatting()
end

--- @brief
function rt.GraphicsBuffer:replace_data(data, data_index, buffer_index, n_elements)
    if meta.is_table(data) and meta.is_function(data.get_native) then
        data = data:get_native()
    end

    self._native:setArrayData(data, data_index, buffer_index, n_elements)
end

--- @brief
function rt.GraphicsBuffer:get_n_elements()
    return self._native:getElementCount()
end

--- @brief
function rt.GraphicsBuffer:get_native()
    return self._native
end

rt.DataFormat = {
    FLOAT = "float",
    FLOAT_VEC2 = "floatvec2",
    FLOAT_VEC4 = "floatvec4",

    INT32 = "int32",
    INT32_VEC2 = "int32vec2",
    INT32_VEC4 = "int32vec4",

    UINT32 = "uint32",
    UINT32_VEC2 = "uint32vec2",
    UINT32_VEC4 = "uint32vec4",

    UNORM8_VEC4 = "unorm8vec4",
    SNORM8_VEC4 = "snorm8vec4",
    INT8_VEC4 = "int8vec4",
    UINT8_VEC4 = "uint8vec4",

    UNORM16_VEC2 = "unorm16vec2",
    UNORM16_VEC4 = "unorm16vec4",

    INT16_VEC2 = "int16vec2",
    INT16_VEC4 = "int16vec4",

    UINT16 = "uint16",
    UINT16_VEC2 = "uint16vec2",
    UINT16_VEC4 = "uint16vec4",
}
rt.DataFormat = meta.enum("DataFormat", rt.DataFormat)

local _format_to_n_components = {
    [rt.DataFormat.FLOAT] = 1,
    [rt.DataFormat.FLOAT_VEC2] = 2,
    [rt.DataFormat.FLOAT_VEC4] = 4,

    [rt.DataFormat.INT32] = 1,
    [rt.DataFormat.INT32_VEC2] = 2,
    [rt.DataFormat.INT32_VEC4] = 4,

    [rt.DataFormat.UINT32] = 1,
    [rt.DataFormat.UINT32_VEC2] = 2,
    [rt.DataFormat.UINT32_VEC4] = 4,

    [rt.DataFormat.UNORM8_VEC4] = 4,
    [rt.DataFormat.SNORM8_VEC4] = 4,
    [rt.DataFormat.INT8_VEC4] = 4,
    [rt.DataFormat.UINT8_VEC4] = 4,

    [rt.DataFormat.UNORM16_VEC2] = 2,
    [rt.DataFormat.UNORM16_VEC4] = 4,

    [rt.DataFormat.INT16_VEC2] = 2,
    [rt.DataFormat.INT16_VEC4] = 4,

    [rt.DataFormat.UINT16] = 1,
    [rt.DataFormat.UINT16_VEC2] = 2,
    [rt.DataFormat.UINT16_VEC4] = 4
}

local _format_to_size = {
    [rt.DataFormat.FLOAT] = 4,
    [rt.DataFormat.FLOAT_VEC2] = 8,
    [rt.DataFormat.FLOAT_VEC4] = 16,

    [rt.DataFormat.INT32] = 4,
    [rt.DataFormat.INT32_VEC2] = 8,
    [rt.DataFormat.INT32_VEC4] = 16,

    [rt.DataFormat.UINT32] = 4,
    [rt.DataFormat.UINT32_VEC2] = 8,
    [rt.DataFormat.UINT32_VEC4] = 16,

    [rt.DataFormat.UNORM8_VEC4] = 4,
    [rt.DataFormat.SNORM8_VEC4] = 4,
    [rt.DataFormat.INT8_VEC4] = 4,
    [rt.DataFormat.UINT8_VEC4] = 4,

    [rt.DataFormat.UNORM16_VEC2] = 4,
    [rt.DataFormat.UNORM16_VEC4] = 8,

    [rt.DataFormat.INT16_VEC2] = 4,
    [rt.DataFormat.INT16_VEC4] = 8,

    [rt.DataFormat.UINT16] = 2,
    [rt.DataFormat.UINT16_VEC2] = 4,
    [rt.DataFormat.UINT16_VEC4] = 8
}

--- @brief
function rt.GraphicsBuffer:_initialize_formatting()
    local n = self._native:getElementCount()
    local stride = self._native:getElementStride()
    self._i_to_format = {}
    self._field_name_to_field_i = {}

    for i, e in ipairs(self._native:getFormat()) do
        local n_components = _format_to_n_components[e.format]
        local size = _format_to_size[e.format]
        local format = {
            name = e.name,
            n_components = n_components,
            component_i_to_offset = {}
        }

        self._i_to_format[i] = format

        local component_size = size / _format_to_n_components[e.format]
        local offset = e.offset
        for component_i = 1, n_components do
            format.component_i_to_offset[component_i] = offset
            offset = offset + component_size
        end

        self._field_name_to_field_i[e.name] = i
    end
end

--- @brief
function rt.GraphicsBuffer:field_name_to_field_i(name)
    local result = self._element_name_to_i[name]
    if result == nil then
        rt.error("In rt.GraphicsBuffer.get_element_i: no element with name `", name, "` present in buffer")
    end
    return result
end

--- @brief
function rt.GraphicsBuffer:get_element_name(i)
    local format = self._format[i]
    if format == nil then
        rt.error("In rt.GraphicsBuffer.get_element_name: index `", i, "` out of range for buffer with `", #self._native:getFormat(), "` fields")
    end

    return format.name
end

--- @brief
function rt.GraphicsBuffer:get_byte_data_offset(field_i, component_i)
    if meta.is_string(field_i) then field_i = self:field_name_to_field_i(field_i) end

    local format = self._i_to_format[field_i]
    if format == nil then
        rt.error("In rt.GraphicsBuffer.get_byte_data_offset: field index `", field_i, "` out of range for buffer with `", #self._native:getFormat(), "` fields")
    end

    if component_i == nil then component_i = 1 end

    if component_i > format.n_components then
        rt.error("In rt.GraphicsBuffer.get_byte_data_offset: component index `", component_i, "` out of range for field `", format.name, "` with `", format.n_components, "` components")
    end

    if field_i <= 0 then
        rt.error("In rt.GraphicsBuffer.get_byte_data_offset: field index <= 0. field indices are 1-based")
    end

    if component_i <= 0 then
        rt.error("In rt.GraphicsBuffer.get_byte_data_offset: component index <= 0. component indices are 1-based")
    end

    return format.component_i_to_offset[component_i]
end

--- @brief
function rt.GraphicsBuffer:get_element_stride()
    return self._native:getElementStride()
end

--- @brief
function rt.GraphicsBuffer:get_n_element()
    return self._native:getElementCount()
end

--- @brief
function rt.GraphicsBuffer:download()
    self._data = love.graphics.readbackBuffer(self._native)
end

--- @brief
function rt.GraphicsBuffer:upload()
    self._native:setArrayData(self._data)
end

--- @brief
function rt.GraphicsBuffer:get_byte_data()
    if self._data == nil then self:download() end
    return rt.ByteData(rt.ByteDataFormat.UNKNOWN, self._data)
end
