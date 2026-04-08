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

local _format_to_n_components = {
    float = 1,
    floatvec2 = 2,
    floatvec3 = 3,
    floatvec4 = 4,
    int32 = 1,
    int32vec2 = 2,
    int32vec3 = 3,
    int32vec4 = 4,
    uint32 = 1,
    uint32vec2 = 2,
    uint32vec3 = 3,
    uint32vec4 = 4
}

local _format_to_component_size = {
    float = 32 / 8,
    floatvec2 = 32 / 8,
    floatvec3 = 32 / 8,
    floatvec4 = 32 / 8,
    int32 = 32 / 8,
    int32vec2 = 32 / 8,
    int32vec3 = 32 / 8,
    int32vec4 = 32 / 8,
    uint32 = 32 / 8,
    uint32vec2 = 32 / 8,
    uint32vec3 = 32 / 8,
    uint32vec4 = 32 / 8
}

--- @brief
function rt.GraphicsBuffer:_initialize_formatting()
    local element_length = 0
    local getters, setters = {}, {}

    local i = 1
    for e in values(self._native:getFormat()) do
        local n_components = _format_to_n_components[e.format]
        local component_size = _format_to_component_size[e.format]
        local element_offset = e.offset

        if e.arraylength > 0 then
            rt.error("In rt.GraphicsBuffer._initialize_formatting: unhandled array length `", e.array_length, "`")
        end

        if e.format == "uint32" then
            getters[i] = function(data, offset)
                return data:getUInt32(offset + element_offset)
            end
            setters[i] = function(data, offset, value)
                data:setUInt32(offset + element_offset, value)
            end
            i = i + 1
        elseif e.format == "int32" then
            getters[i] = function(data, offset)
                return data:getInt32(offset + element_offset)
            end
            setters[i] = function(data, offset, value)
                data:setInt32(offset + element_offset, value)
            end
            i = i + 1
        elseif e.format == "float" then
            getters[i] = function(data, offset)
                return data:getFloat(offset + element_offset)
            end
            setters[i] = function(data, offset, value)
                data:setFloat(offset + element_offset, value)
            end
            i = i + 1
        elseif e.format == "floatvec2" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getFloat(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setFloat(offset + component_offset, value)
                end
                i = i + 1
            end
        elseif e.format == "floatvec3" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getFloat(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setFloat(offset + component_offset, value)
                end
                i = i + 1
            end
        elseif e.format == "floatvec4" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getFloat(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setFloat(offset + component_offset, value)
                end
                i = i + 1
            end
        elseif e.format == "int32vec2" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getInt32(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setInt32(offset + component_offset, value)
                end
                i = i + 1
            end
        elseif e.format == "int32vec3" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getInt32(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setInt32(offset + component_offset, value)
                end
                i = i + 1
            end
        elseif e.format == "int32vec4" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getInt32(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setInt32(offset + component_offset, value)
                end
                i = i + 1
            end
        elseif e.format == "uint32vec2" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getUInt32(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setUInt32(offset + component_offset, value)
                end
                i = i + 1
            end
        elseif e.format == "uint32vec3" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getUInt32(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setUInt32(offset + component_offset, value)
                end
                i = i + 1
            end
        elseif e.format == "uint32vec4" then
            for j = 0, n_components - 1 do
                local component_offset = element_offset + j * component_size
                getters[i] = function(data, offset)
                    return data:getUInt32(offset + component_offset)
                end
                setters[i] = function(data, offset, value)
                    data:setUInt32(offset + component_offset, value)
                end
                i = i + 1
            end
        else
            rt.error("In rt.GraphicsBuffer:_initialize_formatting: unhandled format `", e.format, "`")
        end
    end

    self._n_components = math.max(i - 1, 0)
    self._element_size = self._native:getElementStride()
    self._getter = getters
    self._setters = setters

    self._formatting_initialized = true
end

--- @brief
--- @param i Number 1-based
function rt.GraphicsBuffer:at(i, component_i)
    if self._data == nil then self:download() end
    return self._getters[component_i](self._data, self._element_size * (i - 1))
end

--- @brief
--- @param i Number 1-based
function rt.GraphicsBuffer:set(i, component_i, value)
    if self._data == nil then self:download() end
    local offset = self._element_size * (i - 1)
    return self._setters[component_i](self._data, offset, value)
end

--- @brief
function rt.GraphicsBuffer:get_element_stride()
    return self._native:getElementStride()
end

--- @brief
function rt.GraphicsBuffer:get_n_element()
    return self._native.getElementCount()
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
function rt.GraphicsBuffer:create_byte_data()
    if self._data == nil then self:download() end
    return rt.ByteData(rt.ByteDataFormat.UNKNOWN, self._data)
end