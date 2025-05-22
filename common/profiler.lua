rt.Profiler = {}

function rt.Profiler.measure(chunk, ...)
    local before = love.timer.getTime()
    chunk(...)
    local after = love.timer.getTime()
    dbg(math.floor((after - before) / (1 / 60) * 1000) / 1000)
end

return rt.Profiler