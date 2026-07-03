--- @enum rt.InternalResolutionScaling
rt.InternalResolutionScaling = {
    NONE = 1,
    HALF = 2,
    QUARTER = 4,
    EIGHTH = 8
}
rt.InternalResolutionScaling = meta.enum("InternalResolution", rt.InternalResolutionScaling)

--- @enum rt.InternalResolutionScalingMode
rt.InternalResolutionScalingMode = {
    NEAREST = "nearest",
    LINEAR = "linear"
}

--- @enum rt.InternalResolution
rt.InternalResolution = {
    -- 16:9
    RESOLUTION_3840_2160 = { 3840, 2160 },
    RESOLUTION_2560_1440 = { 2560, 1440 },
    RESOLUTION_1920_1080 = { 1920, 1080 },
    RESOLUTION_1600_900  = { 1600, 900 },
    RESOLUTION_1280_720  = { 1280, 720 },
    RESOLUTION_960_540   = { 960, 540 },
    RESOLUTION_640_360   = { 640, 360 },
    RESOLUTION_320_180   = { 320, 180 },

    -- 16:10
    RESOLUTION_2560_1600 = { 2560, 1600 },
    RESOLUTION_1920_1200 = { 1920, 1200 },
    RESOLUTION_1680_1050 = { 1680, 1050 },
    RESOLUTION_1440_900  = { 1440, 900 },
    RESOLUTION_1280_800  = { 1280, 800 },
    RESOLUTION_1024_640  = { 1024, 640 },
    RESOLUTION_512_320   = { 512, 320 },

    -- 4:3
    RESOLUTION_1024_768 = { 1024, 768 },
    RESOLUTION_800_600  = { 800, 600 },
    RESOLUTION_640_480  = { 640, 480 },
    RESOLUTION_400_300  = { 400, 300 },

    -- 21:9
    RESOLUTION_5120_2160 = { 5120, 2160 },
    RESOLUTION_3440_1440 = { 3440, 1440 },
    RESOLUTION_2560_1080 = { 2560, 1080 },
    RESOLUTION_1720_720  = { 1720, 720 },
    RESOLUTION_1280_540  = { 1280, 540 },
    RESOLUTION_860_360   = { 860, 360 },

    -- 32:9 (super ultrawide)
    RESOLUTION_5120_1440 = { 5120, 1440 },
    RESOLUTION_3840_1080 = { 3840, 1080 },
    RESOLUTION_2560_720  = { 2560, 720 },
    RESOLUTION_1720_480  = { 1720, 480 },

    -- 5:4
    RESOLUTION_2560_2048 = { 2560, 2048 },
    RESOLUTION_1280_1024 = { 1280, 1024 },
    RESOLUTION_640_512   = { 640, 512 },
    RESOLUTION_320_256   = { 320, 256 },

    -- 3:2
    RESOLUTION_2160_1440 = { 2160, 1440 },
    RESOLUTION_1920_1280 = { 1920, 1280 },
    RESOLUTION_1350_900  = { 1350, 900 },
    RESOLUTION_720_480   = { 720, 480 },

    -- 1:1 (square)
    RESOLUTION_2048_2048 = { 2048, 2048 },
    RESOLUTION_1024_1024 = { 1024, 1024 },
    RESOLUTION_512_512   = { 512, 512 },
    RESOLUTION_256_256   = { 256, 256 }
}
rt.InternalResolution = meta.enum("InternalResolution", rt.InternalResolution)

--- @brief
function rt.graphics.internal_resolution_to_native(internal_resolution)
    meta.assert(internal_resolution, rt.InternalResolution)
    return internal_resolution[1], internal_resolution[2]
end

--- @brief
function rt.graphics.internal_resolution_scaling_mode_to_texture_scale_mode(internal_resolution_scale_mode)
    meta.assert(internal_resolution_scale_mode, rt.InternalResolutionScalingMode)

    require "common.texture"
    if internal_resolution_scale_mode == rt.InternalResolutionScalingMode.NEAREST then
        return rt.TextureScaleMode.NEAREST
    elseif internal_resolution_scale_mode == rt.InternalResolutionScalingMode.LINEAR then
        return rt.TextureScaleMode.LINEAR
    else
        rt.error("In rt.graphics.internal_resolution_scaling_mode_to_texture_scale_mode: unhandled internal resolution scale mode `", internal_resolution_scale_mode, "`")
        return nil
    end
end

do
    local _resolutions_16_9 = {
        rt.InternalResolution.RESOLUTION_3840_2160,
        rt.InternalResolution.RESOLUTION_2560_1440,
        rt.InternalResolution.RESOLUTION_1920_1080,
        rt.InternalResolution.RESOLUTION_1600_900,
        rt.InternalResolution.RESOLUTION_1280_720,
        rt.InternalResolution.RESOLUTION_960_540,
        rt.InternalResolution.RESOLUTION_640_360,
        rt.InternalResolution.RESOLUTION_320_180,
    }

    local _resolutions_16_10 = {
        rt.InternalResolution.RESOLUTION_2560_1600,
        rt.InternalResolution.RESOLUTION_1920_1200,
        rt.InternalResolution.RESOLUTION_1680_1050,
        rt.InternalResolution.RESOLUTION_1440_900,
        rt.InternalResolution.RESOLUTION_1280_800,
        rt.InternalResolution.RESOLUTION_1024_640,
        rt.InternalResolution.RESOLUTION_512_320,
    }

    local _resolutions_4_3 = {
        rt.InternalResolution.RESOLUTION_1024_768,
        rt.InternalResolution.RESOLUTION_800_600,
        rt.InternalResolution.RESOLUTION_640_480,
        rt.InternalResolution.RESOLUTION_400_300,
    }

    local _resolutions_21_9 = {
        rt.InternalResolution.RESOLUTION_5120_2160,
        rt.InternalResolution.RESOLUTION_3440_1440,
        rt.InternalResolution.RESOLUTION_2560_1080,
        rt.InternalResolution.RESOLUTION_1720_720,
        rt.InternalResolution.RESOLUTION_1280_540,
        rt.InternalResolution.RESOLUTION_860_360,
    }

    local _resolutions_32_9 = {
        rt.InternalResolution.RESOLUTION_5120_1440,
        rt.InternalResolution.RESOLUTION_3840_1080,
        rt.InternalResolution.RESOLUTION_2560_720,
        rt.InternalResolution.RESOLUTION_1720_480,
    }

    local _resolutions_5_4 = {
        rt.InternalResolution.RESOLUTION_2560_2048,
        rt.InternalResolution.RESOLUTION_1280_1024,
        rt.InternalResolution.RESOLUTION_640_512,
        rt.InternalResolution.RESOLUTION_320_256,
    }

    local _resolutions_3_2 = {
        rt.InternalResolution.RESOLUTION_2160_1440,
        rt.InternalResolution.RESOLUTION_1920_1280,
        rt.InternalResolution.RESOLUTION_1350_900,
        rt.InternalResolution.RESOLUTION_720_480,
    }

    local _resolutions_1_1 = {
        rt.InternalResolution.RESOLUTION_2048_2048,
        rt.InternalResolution.RESOLUTION_1024_1024,
        rt.InternalResolution.RESOLUTION_512_512,
        rt.InternalResolution.RESOLUTION_256_256,
    }

    -- calculate eps
    local _max_eps
    do
        local aspect_ratios = {
            16 / 9,
            16 / 10,
            4 / 3,
            21 / 9,
            32 / 9,
            5 / 4,
            3 / 2,
            1 / 1
        }

        _max_eps = math.huge
        for _, ratio_a in ipairs(aspect_ratios) do
            for _, ratio_b in ipairs(aspect_ratios) do
                if ratio_a ~= ratio_b then
                    _max_eps = math.min(_max_eps, math.abs(ratio_a - ratio_b))
                end
            end
        end

        _max_eps = 0.5 * _max_eps
    end

    --- @brief
    function rt.graphics.internal_resolution_list_valid(window_w, window_h)

        local to_check
        local aspect = window_w / window_h
        if math.equals(aspect, 16 / 9, _max_eps) then
            to_check = _resolutions_16_9
        elseif math.equals(aspect, 16 / 10, _max_eps) then
            to_check = _resolutions_16_10
        elseif math.equals(aspect, 4 / 3, _max_eps) then
            to_check = _resolutions_4_3
        elseif math.equals(aspect, 21 / 9, _max_eps) then
            to_check = _resolutions_21_9
        elseif math.equals(aspect, 32 / 9, _max_eps) then
            to_check = _resolutions_32_9
        elseif math.equals(aspect, 5 / 4, _max_eps) then
            to_check = _resolutions_5_4
        elseif math.equals(aspect, 3 / 2, _max_eps) then
            to_check = _resolutions_3_2
        elseif math.equals(aspect, 1 / 1, _max_eps) then
            to_check = _resolutions_1_1
        else
            to_check = meta.instances(rt.InternalResolution) -- all
        end

        local valid = {}
        for resolution in values(to_check) do
            if resolution[1] <= window_w and resolution[2] <= window_h then
                table.insert(valid, resolution)
            end
        end

        -- sort by number of pixels
        table.sort(valid, function(a, b)
            return a[1] * a[2] > b[1] * b[2]
        end)

        return valid
    end

    --- @brief
    function rt.graphics.resolution_to_internal_resolution(resolution_x, resolution_y, scale_factor)
        meta.assert(resolution_x, mt.Number, resolution_y, mt.Number, scale_factor, rt.InternalResolutionScaling)

        local valid = rt.graphics.internal_resolution_list_valid(resolution_x, resolution_y)
        if #valid == 0 then return resolution_x, resolution_y end

        local none_x, none_y = resolution_x, resolution_y
        local half_x, half_y, quarter_x, quarter_y, eighth_x, eighth_y

        if valid[2] ~= nil then
            half_x, half_y = valid[2][1], valid[2][2]
        else
            half_x, half_y = none_x, none_y
        end

        if valid[3] ~= nil then
            quarter_x, quarter_y = valid[3][1], valid[3][2]
        else
            quarter_x, quarter_y = half_x, half_y
        end

        if valid[4] ~= nil then
            eighth_x, eighth_y = valid[4][1], valid[4][2]
        else
            eighth_x, eighth_y = quarter_x, quarter_y
        end

        if scale_factor == rt.InternalResolutionScaling.NONE then
            return resolution_x, resolution_y
        elseif scale_factor == rt.InternalResolutionScaling.HALF then
            return half_x, half_y
        elseif scale_factor == rt.InternalResolutionScaling.QUARTER then
            return quarter_x, quarter_y
        elseif scale_factor == rt.InternalResolutionScaling.EIGHTH then
            return eighth_x, eighth_y
        else
            rt.fatal("unreachable")
        end
    end
end