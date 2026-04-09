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
    -- float scalars / vectors
    FLOAT = "float",
    FLOAT_VEC2 = "floatvec2",
    FLOAT_VEC3 = "floatvec3",
    FLOAT_VEC4 = "floatvec4",

    -- float matrices
    FLOAT_MAT2X2 = "floatmat2x2",
    FLOAT_MAT2X3 = "floatmat2x3",
    FLOAT_MAT2X4 = "floatmat2x4",

    FLOAT_MAT3X2 = "floatmat3x2",
    FLOAT_MAT3X3 = "floatmat3x3",
    FLOAT_MAT3X4 = "floatmat3x4",

    FLOAT_MAT4X2 = "floatmat4x2",
    FLOAT_MAT4X3 = "floatmat4x3",
    FLOAT_MAT4X4 = "floatmat4x4",

    -- int32
    INT32 = "int32",
    INT32_VEC2 = "int32vec2",
    INT32_VEC3 = "int32vec3",
    INT32_VEC4 = "int32vec4",

    -- uint32
    UINT32 = "uint32",
    UINT32_VEC2 = "uint32vec2",
    UINT32_VEC3 = "uint32vec3",
    UINT32_VEC4 = "uint32vec4",

    -- packed 8-bit
    SNORM8_VEC4 = "snorm8vec4",
    UNORM8_VEC4 = "unorm8vec4",
    INT8_VEC4   = "int8vec4",
    UINT8_VEC4  = "uint8vec4",

    -- 16-bit normalized
    SNORM16_VEC2 = "snorm16vec2",
    SNORM16_VEC4 = "snorm16vec4",
    UNORM16_VEC2 = "unorm16vec2",
    UNORM16_VEC4 = "unorm16vec4",

    -- int16
    INT16_VEC2 = "int16vec2",
    INT16_VEC4 = "int16vec4",

    -- uint16
    UINT16 = "uint16",
    UINT16_VEC2 = "uint16vec2",
    UINT16_VEC4 = "uint16vec4",

    -- bool
    BOOL = "bool",
    BOOL_VEC2 = "boolvec2",
    BOOL_VEC3 = "boolvec3",
    BOOL_VEC4 = "boolvec4",
}
rt.DataFormat = meta.enum("DataFormat", rt.DataFormat)

local _format_to_n_components = {
    [rt.DataFormat.FLOAT] = 1,
    [rt.DataFormat.FLOAT_VEC2] = 2,
    [rt.DataFormat.FLOAT_VEC3] = 3,
    [rt.DataFormat.FLOAT_VEC4] = 4,

    [rt.DataFormat.FLOAT_MAT2X2] = 4,
    [rt.DataFormat.FLOAT_MAT2X3] = 6,
    [rt.DataFormat.FLOAT_MAT2X4] = 8,

    [rt.DataFormat.FLOAT_MAT3X2] = 6,
    [rt.DataFormat.FLOAT_MAT3X3] = 9,
    [rt.DataFormat.FLOAT_MAT3X4] = 12,

    [rt.DataFormat.FLOAT_MAT4X2] = 8,
    [rt.DataFormat.FLOAT_MAT4X3] = 12,
    [rt.DataFormat.FLOAT_MAT4X4] = 16,

    [rt.DataFormat.INT32] = 1,
    [rt.DataFormat.INT32_VEC2] = 2,
    [rt.DataFormat.INT32_VEC3] = 3,
    [rt.DataFormat.INT32_VEC4] = 4,

    [rt.DataFormat.UINT32] = 1,
    [rt.DataFormat.UINT32_VEC2] = 2,
    [rt.DataFormat.UINT32_VEC3] = 3,
    [rt.DataFormat.UINT32_VEC4] = 4,

    [rt.DataFormat.SNORM8_VEC4] = 4,
    [rt.DataFormat.UNORM8_VEC4] = 4,
    [rt.DataFormat.INT8_VEC4] = 4,
    [rt.DataFormat.UINT8_VEC4] = 4,

    [rt.DataFormat.SNORM16_VEC2] = 2,
    [rt.DataFormat.SNORM16_VEC4] = 4,
    [rt.DataFormat.UNORM16_VEC2] = 2,
    [rt.DataFormat.UNORM16_VEC4] = 4,
    [rt.DataFormat.INT16_VEC2] = 2,
    [rt.DataFormat.INT16_VEC4] = 4,

    [rt.DataFormat.UINT16] = 1,
    [rt.DataFormat.UINT16_VEC2] = 2,
    [rt.DataFormat.UINT16_VEC4] = 4,

    [rt.DataFormat.BOOL] = 1,
    [rt.DataFormat.BOOL_VEC2] = 2,
    [rt.DataFormat.BOOL_VEC3] = 3,
    [rt.DataFormat.BOOL_VEC4] = 4,
}

local _format_to_size = {
    [rt.DataFormat.FLOAT] = 4,
    [rt.DataFormat.FLOAT_VEC2] = 8,
    [rt.DataFormat.FLOAT_VEC3] = 12,
    [rt.DataFormat.FLOAT_VEC4] = 16,

    [rt.DataFormat.FLOAT_MAT2X2] = 16,
    [rt.DataFormat.FLOAT_MAT2X3] = 24,
    [rt.DataFormat.FLOAT_MAT2X4] = 32,

    [rt.DataFormat.FLOAT_MAT3X2] = 24,
    [rt.DataFormat.FLOAT_MAT3X3] = 36,
    [rt.DataFormat.FLOAT_MAT3X4] = 48,

    [rt.DataFormat.FLOAT_MAT4X2] = 32,
    [rt.DataFormat.FLOAT_MAT4X3] = 48,
    [rt.DataFormat.FLOAT_MAT4X4] = 64,

    [rt.DataFormat.INT32] = 4,
    [rt.DataFormat.INT32_VEC2] = 8,
    [rt.DataFormat.INT32_VEC3] = 12,
    [rt.DataFormat.INT32_VEC4] = 16,

    [rt.DataFormat.UINT32] = 4,
    [rt.DataFormat.UINT32_VEC2] = 8,
    [rt.DataFormat.UINT32_VEC3] = 12,
    [rt.DataFormat.UINT32_VEC4] = 16,

    [rt.DataFormat.SNORM8_VEC4] = 4,
    [rt.DataFormat.UNORM8_VEC4] = 4,
    [rt.DataFormat.INT8_VEC4] = 4,
    [rt.DataFormat.UINT8_VEC4] = 4,

    [rt.DataFormat.SNORM16_VEC2] = 4,
    [rt.DataFormat.SNORM16_VEC4] = 8,
    [rt.DataFormat.UNORM16_VEC2] = 4,
    [rt.DataFormat.UNORM16_VEC4] = 8,
    [rt.DataFormat.INT16_VEC2] = 4,
    [rt.DataFormat.INT16_VEC4] = 8,

    [rt.DataFormat.UINT16] = 2,
    [rt.DataFormat.UINT16_VEC2] = 4,
    [rt.DataFormat.UINT16_VEC4] = 8,

    [rt.DataFormat.BOOL] = 1,
    [rt.DataFormat.BOOL_VEC2] = 2,
    [rt.DataFormat.BOOL_VEC3] = 3,
    [rt.DataFormat.BOOL_VEC4] = 4,
}

local _type_to_getter_setter = {
    float  = { get = "getFloat",  set = "setFloat"  },
    int32  = { get = "getInt32",  set = "setInt32"  },
    uint32 = { get = "getUInt32", set = "setUInt32" },

    int8   = { get = "getInt8",   set = "setInt8"   },
    uint8  = { get = "getUInt8",  set = "setUInt8"  },

    int16  = { get = "getInt16",  set = "setInt16"  },
    uint16 = { get = "getUInt16", set = "setUInt16" },

    bool   = { get = "getBool",   set = "setBool"   },
}

local _format_to_getter_setter = {
    [rt.DataFormat.FLOAT] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_VEC2] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_VEC3] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_VEC4] = _type_to_getter_setter.float,

    [rt.DataFormat.FLOAT_MAT2X2] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_MAT2X3] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_MAT2X4] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_MAT3X2] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_MAT3X3] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_MAT3X4] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_MAT4X2] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_MAT4X3] = _type_to_getter_setter.float,
    [rt.DataFormat.FLOAT_MAT4X4] = _type_to_getter_setter.float,

    [rt.DataFormat.INT32] = _type_to_getter_setter.int32,
    [rt.DataFormat.INT32_VEC2] = _type_to_getter_setter.int32,
    [rt.DataFormat.INT32_VEC3] = _type_to_getter_setter.int32,
    [rt.DataFormat.INT32_VEC4] = _type_to_getter_setter.int32,

    [rt.DataFormat.UINT32] = _type_to_getter_setter.uint32,
    [rt.DataFormat.UINT32_VEC2] = _type_to_getter_setter.uint32,
    [rt.DataFormat.UINT32_VEC3] = _type_to_getter_setter.uint32,
    [rt.DataFormat.UINT32_VEC4] = _type_to_getter_setter.uint32,

    [rt.DataFormat.SNORM8_VEC4] = _type_to_getter_setter.int8,
    [rt.DataFormat.UNORM8_VEC4] = _type_to_getter_setter.uint8,
    [rt.DataFormat.INT8_VEC4]   = _type_to_getter_setter.int8,
    [rt.DataFormat.UINT8_VEC4]  = _type_to_getter_setter.uint8,

    [rt.DataFormat.SNORM16_VEC2] = _type_to_getter_setter.int16,
    [rt.DataFormat.SNORM16_VEC4] = _type_to_getter_setter.int16,
    [rt.DataFormat.UNORM16_VEC2] = _type_to_getter_setter.uint16,
    [rt.DataFormat.UNORM16_VEC4] = _type_to_getter_setter.uint16,
    [rt.DataFormat.INT16_VEC2] = _type_to_getter_setter.int16,
    [rt.DataFormat.INT16_VEC4] = _type_to_getter_setter.int16,

    [rt.DataFormat.UINT16] = _type_to_getter_setter.uint16,
    [rt.DataFormat.UINT16_VEC2] = _type_to_getter_setter.uint16,
    [rt.DataFormat.UINT16_VEC4] = _type_to_getter_setter.uint16,

    [rt.DataFormat.BOOL] = _type_to_getter_setter.bool,
    [rt.DataFormat.BOOL_VEC2] = _type_to_getter_setter.bool,
    [rt.DataFormat.BOOL_VEC3] = _type_to_getter_setter.bool,
    [rt.DataFormat.BOOL_VEC4] = _type_to_getter_setter.bool,
}

local _type_to_normalization_constant = {
    other = 1,
    unorm8 = 2^8 - 1,
    unorm16 = 2^16 - 1,
    snorm8 = 2^7 - 1,
    snorm16 = 2^15 - 1,
}

local _format_to_normalization_constant = {
    [rt.DataFormat.SNORM8_VEC4] = _type_to_normalization_constant.snorm8,
    [rt.DataFormat.UNORM8_VEC4] = _type_to_normalization_constant.unorm8,
    [rt.DataFormat.SNORM16_VEC2] = _type_to_normalization_constant.snorm16,
    [rt.DataFormat.SNORM16_VEC4] = _type_to_normalization_constant.snorm16,
    [rt.DataFormat.UNORM16_VEC2] = _type_to_normalization_constant.unorm16,
    [rt.DataFormat.UNORM16_VEC4] = _type_to_normalization_constant.unorm16,
}

for other in values(meta.instances(rt.DataFormat)) do
    if _format_to_normalization_constant[other] == nil then
        _format_to_normalization_constant[other] = _type_to_normalization_constant.other
    end
end

--- @brief
function rt.GraphicsBuffer:_initialize_formatting()
    local n = self._native:getElementCount()
    local stride = self._native:getElementStride()
    self._field_i_to_format = {}
    self._field_name_to_field_i = {}

    for i, e in ipairs(self._native:getFormat()) do
        local n_components = _format_to_n_components[e.format]
        local size = _format_to_size[e.format]
        local format = {
            name = e.name,
            n_components = n_components,
            components = {}
        }

        self._field_i_to_format[i] = format

        rt.assert(_format_to_n_components[e.format] ~= nil
            and _format_to_getter_setter[e.format] ~= nil
            and _format_to_n_components[e.format] ~= nil
            and _format_to_normalization_constant[e.format] ~= nil,
            "In rt.GraphicsBuffer._initialize_formatting: unhandled data type: `", e.format, "`"
        )

        rt.assert(e.arraylength == 0,
            "In rt.GraphicsBuffer._initialize_formatting: unhandled data type: `", e.format, "[" .. e.arraylength .. "]`"
        )

        local component_size = size / _format_to_n_components[e.format]
        local offset = e.offset
        for component_i = 1, n_components do
            local getter_setter = _format_to_getter_setter[e.format]
            format.components[component_i] = {
                offset = offset,
                getter = getter_setter.get,
                setter = getter_setter.set,
                normalization_constant = _format_to_normalization_constant[e.format]
            }
            offset = offset + component_size
        end

        self._field_name_to_field_i[e.name] = i
    end
end

--- @brief
function rt.GraphicsBuffer:field_name_to_field_i(name)
    local result = self._field_name_to_field_i[name]
    if result == nil then
        rt.error("In rt.GraphicsBuffer.get_element_i: no element with name `", name, "` present in buffer")
    end
    return result
end

--- @brief
function rt.GraphicsBuffer:get_byte_offset(field_i, component_i)
    if meta.is_string(field_i) then field_i = self:field_name_to_field_i(field_i) end

    local format = self._field_i_to_format[field_i]
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

    return format.components[component_i].offset
end

--- @brief
function rt.GraphicsBuffer:get_element_stride()
    return self._native:getElementStride()
end

--- @brief
function rt.GraphicsBuffer:get_n_element()
    return self._native:getElementCount()
end

--- @brief update the local copy of buffer data
function rt.GraphicsBuffer:download()
    self._data = love.graphics.readbackBuffer(self._native)
    return nil
end

--- @brief
function rt.GraphicsBuffer:flush(...)
    if self._data == nil then self:download() end
    self._native:setArrayData(self._data, ...)
end

--- @brief
function rt.GraphicsBuffer:get_byte_data()
    if self._data == nil then self:download() end
    return rt.ByteData(rt.ByteDataFormat.UNKNOWN, self._data)
end

--- @brief readback buffer, then convert to lua table
function rt.GraphicsBuffer:get_data()
    local out = {}
    local data = love.graphics.readbackBuffer(self._native)

    local stride = self._native:getElementStride()
    for element_i = 1, self._native:getElementCount() do
        local element = {}
        for field_i, field in ipairs(self._field_i_to_format) do
            for component_i, component in ipairs(field.components) do
                local value = data[component.getter](data, (element_i - 1) * stride + component.offset)
                value = value * component.normalization_constant
                table.insert(element, value)
            end
        end
        table.insert(out, element)
    end

    return out
end
