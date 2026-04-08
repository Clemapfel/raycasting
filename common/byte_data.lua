--- @class rt.ByteData
rt.ByteData = meta.class("ByteData")

--- @enum rt.ByteDataFormat
rt.ByteDataFormat = {
    INT8 = "int8_t",
    INT16 = "int16_t",
    INT32 = "int32_t",
    INT64 = "int64_t",
    UINT8 = "uint8_t",
    UINT16 = "uint16_t",
    UINT32 = "uint32_t",
    UINT64 = "uint64_t",
    FLOAT32 = "float",
    FLOAT64 = "double",
    UNKNOWN = "void"
}
rt.ByteDataFormat = meta.enum("ByteDataFormat", rt.ByteDataFormat)

--- @brief
rt.ByteData.format_to_n_bytes = function(format)
    if format == rt.ByteDataFormat.INT8 or format == rt.ByteDataFormat.UINT8 then
        return 1
    elseif format == rt.ByteDataFormat.INT16 or format == rt.ByteDataFormat.UINT16 then
        return 2
    elseif format == rt.ByteDataFormat.INT32 or format == rt.ByteDataFormat.UINT32 or format == rt.ByteDataFormat.FLOAT32 then
        return 4
    elseif format == rt.ByteDataFormat.INT64 or format == rt.ByteDataFormat.UINT64 or format == rt.ByteDataFormat.FLOAT64 then
        return 8
    end
end

local _format_to_getter_setter = {
    [rt.ByteDataFormat.UNKNOWN] = { get = "getUInt8", set = "setUInt8" },
    [rt.ByteDataFormat.INT8]    = { get = "getInt8",   set = "setInt8"   },
    [rt.ByteDataFormat.INT16]   = { get = "getInt16",  set = "setInt16"  },
    [rt.ByteDataFormat.INT32]   = { get = "getInt32",  set = "setInt32"  },
    [rt.ByteDataFormat.INT64]   = { get = "getInt64",  set = "setInt64"  },
    [rt.ByteDataFormat.UINT8]   = { get = "getUInt8",  set = "setUInt8"  },
    [rt.ByteDataFormat.UINT16]  = { get = "getUInt16", set = "setUInt16" },
    [rt.ByteDataFormat.UINT32]  = { get = "getUInt32", set = "setUInt32" },
    [rt.ByteDataFormat.UINT64]  = { get = "getUInt64", set = "setUInt64" },
    [rt.ByteDataFormat.FLOAT32] = { get = "getFloat",  set = "setFloat"  },
    [rt.ByteDataFormat.FLOAT64] = { get = "getDouble", set = "setDouble" },
}

local use_ffi, _ = pcall(require, "ffi")
use_ffi = true

--- @brief
function rt.ByteData:instantiate(format, count_or_native)
    meta.assert_enum_value(format, rt.ByteDataFormat, 1)

    if meta.is_function(count_or_native.typeOf) and count_or_native:typeOf("ByteData") then
        self._native = count_or_native
    else
        rt.assert(meta.is_number(count_or_native) and count_or_native >= 0 and math.fract(count_or_native) == 0, "In rt.ByteData.instantiate: for argument #2: count `", count_or_native, "` is not an integer")
        self._native = love.data.newByteData(rt.ByteData.format_to_n_bytes * count_or_native)
    end

    self:cast(format)
end

--- @brief
function rt.ByteData:cast(format)
    meta.assert_enum_value(format, rt.ByteDataFormat, 1)
    self._format = format
    self._stride = rt.ByteData.format_to_n_bytes(format)

    if not use_ffi then
        local entry = _format_to_getter_setter[self._format]
        self._getter = self._native[entry.get]
        self._setter = self._native[entry.set]
    else
        self._pointer = ffi.cast(self._format .. "*", self._native:getFFIPointer())
    end

    return self
end

if use_ffi then
    --- @brief
    function rt.ByteData:get(i)
        return self._pointer[i - 1]
    end

    --- @brief
    function rt.ByteData:set(i, value)
        self._pointer[i - 1] = value
    end

    --- @brief
    function rt.ByteData:get_pointer()
        return ffi.cast(self._format .. "*", self._native:getFFIPointer())
    end
else
    --- @brief
    function rt.ByteData:get(i)
        return self._getter(self._native, i - 1)
    end

    --- @brief
    function rt.ByteData:set(i, value)
        self._setter(self._native, i - 1, value)
    end

    --- @brief
    function rt.ByteData:get_pointer()
        return self._native:getPointer()
    end
end

--- @brief
function rt.ByteData:get_native()
    return self._native
end

--- @brief
function rt.ByteData:get_n_elements()
    return self._native:getSize() / self._stride
end
