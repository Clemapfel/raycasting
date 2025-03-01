require "common.graphics_buffer_usage"

local _usage = {
    shaderstorage = true,
    usage = "dynamic"
}

--- @class rt.GraphicsBuffer
rt.GraphicsBuffer = meta.class("GraphicsBuffer")

--- @brief
function rt.GraphicsBuffer:instantiate(format, n_elements, usage)
    local usage_config = _usage
    if usage ~= nil then
        meta.assert_typeof(usage, "String", 3)
        usage_config = {
            shaderstorage = true,
            usage = usage
        }
    end

    meta.install(self,{
        _native = love.graphics.newBuffer(format, n_elements, usage_config),
        _format = format,
        _readback = nil,
        _formatting_initialized = false
    })
end

--- @brief
function rt.GraphicsBuffer:replace_data(data, data_index, buffer_index, n_elements)
    self._native:setArrayData(data, data_index, buffer_index, n_elements)
end

--- @brief
function rt.GraphicsBuffer:start_readback()
    self._readback = love.graphics.readbackBufferAsync(self._native)
end

--- @brief
function rt.GraphicsBuffer:readback_now()
    self._readback = love.graphics.readbackBufferAsync(self._native)
    self._readback:wait()
end

--- @brief
function rt.GraphicsBuffer:get_is_readback_ready()
    return self._readback:isComplete()
end

--- @brief
function rt.GraphicsBuffer:get_n_elements()
    return self._native:getElementCount()
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
    if self._readback:isComplete() ~= true then
        self._readback:wait()
    end

    local data = self._readback:getBufferData()
    local element_length = 0
    local getter = {}

    local i = 1
    for e in values(self._native:getFormat()) do
        local n_components = _format_to_n_components[e.format]
        local component_size = _format_to_component_size[e.format]
        local element_offset = e.offset

        if e.arraylength > 0 then
            rt.error("In rt.GraphicsBuffer._initialize_formatting: unhandled array length `" .. e.array_length .. "`")
        end

        if e.format == "uint32" then
            getter[i] = function(offset)
                return data:getUInt32(offset + element_offset)
            end
            i = i + 1
        elseif e.format == "int32" then
            getter[i] = function(offset)
                return data:getInt32(offset + element_offset)
            end
            i = i + 1
        elseif e.format == "float" then
            getter[i] = function(offset)
                return data:getFloat(offset + element_offset)
            end
            i = i + 1
        elseif e.format == "floatvec2" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getFloat(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        elseif e.format == "floatvec3" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getFloat(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        elseif e.format == "floatvec4" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getFloat(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        elseif e.format == "int32vec2" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getInt32(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        elseif e.format == "int32vec3" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getInt32(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        elseif e.format == "int32vec4" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getInt32(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        elseif e.format == "uint32vec2" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getUInt32(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        elseif e.format == "uint32vec3" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getUInt32(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        elseif e.format == "uint32vec4" then
            for j = 0, n_components - 1 do
                getter[i] = function(offset)
                    return data:getUInt32(offset + element_offset + j * component_size)
                end
                i = i + 1
            end
        else
            rt.error("In rt.GraphicsBuffer:_initialize_formatting: unhandled format `" .. e.format .. "`")
        end
    end

    self._n_components = math.max(i - 1, 0)
    self._element_size = self._native:getElementStride()
    self._getter = getter
    self._formatting_initialized = true
end

--- @brief
--- @param i Number 1-based
function rt.GraphicsBuffer:at(i, component_i)
    if self._formatting_initialized ~= true then self:_initialize_formatting() end -- also waits for readback
    local offset = self._element_size * (i - 1)

    if component_i == nil then
        local out = {}
        for j = 1, self._n_components do
            out[j] = self._getter[j](offset)
        end
        return out
    else
        return self._getter[component_i](offset)
    end
end