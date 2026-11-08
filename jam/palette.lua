palette_bind = function(f)
    log_typecheck(f, Function_t)
    graphics_set_color(log_call(f))
end

palette_black = function()
    return 0, 0, 0, 1
end

palette_dark_gray = function()
    return 0.25, 0.25, 0.25, 1
end

palette_gray = function()
    return 0.5, 0.5, 0.5, 1
end

palette_light_gray = function()
    return 0.75, 0.75, 0.75, 1
end

palette_white = function()
    return 1, 1, 1, 1
end