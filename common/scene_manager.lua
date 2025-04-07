require "common.scene"

--- @class SceneManager
rt.SceneManager = meta.class("SceneManager")

--- @brief
function rt.SceneManager:instantiate()
    meta.install(self, {
        _scene_type_to_scene = {},
        _current_scene = nil,
        _current_scene_type = nil,
        _previous_scene = nil,
        _previous_scene_type = nil,
        _show_performance_metrics = true,
        _width = love.graphics.getWidth(),
        _height = love.graphics.getHeight()
    })
end

--- @brief
function rt.SceneManager:set_scene(scene_type, ...)
    assert(meta.typeof(scene_type) == "Type", "In SceneManager.setScene: expected a type inheriting from `Scene`, got `" .. meta.typeof(scene_type) .. "`")

    local scene = self._scene_type_to_scene[scene_type]
    if scene == nil then
        scene = scene_type()
        scene:realize()
        self._scene_type_to_scene[scene_type] = scene

        scene._scene_manager_current_size_x = 0
        scene._scene_manager_current_size_y = 0
    end

    self._previous_scene = self._current_scene
    self._previous_scene_type = self._current_scene_type
    self._current_scene = scene
    self._current_scene_type = scene_type

    if self._previous_scene ~= nil then
        self._previous_scene:exit()
    end

    local current_w, current_h = self._current_scene._scene_manager_current_size_x, self._current_scene._scene_manager_current_size_y
    if current_w ~= self._width or current_w ~= self._height then
        self._current_scene:reformat(0, 0, self._width, self._height)
        self._current_scene._scene_manager_current_size_x = self._width
        self._current_scene._scene_manager_current_size_y = self._height
    end

    self._current_scene:enter(...) -- forward vararg
end

--- @brief
function rt.SceneManager:update(delta)
    assert(type(delta) == "number")

    if self._current_scene ~= nil then
        self._current_scene:update(delta)
        self._current_scene:signal_emit("update", delta)
    end
end

--- @brief
function rt.SceneManager:draw(...)
    if self._current_scene ~= nil then
        self._current_scene:draw(...)
    end

    rt.graphics._stencil_value = 1
end

--- @brief
function rt.SceneManager:resize(width, height)
    assert(type(width) == "number" and type(height) == "number")

    self._width = width
    self._height = height

    if self._current_scene ~= nil then
        self._current_scene:reformat(0, 0, self._width, self._height)
    end
end

--- @brief
function rt.SceneManager:get_previous_scene()
    return self._previous_scene_type
end

--- @brief
function rt.SceneManager:get_current_scene()
    return self._current_scene
end

--- @brief
function rt.SceneManager:set_show_performance_metrics(b)
    assert(type(b) == "boolean")
    self._show_performance_metrics = b
end

--- @brief
function rt.SceneManager:get_show_performance_metrics()
    return self._show_performance_metrics
end

local _n_frames_captured = 120
local _last_frame_usages = {}
local _frame_usage_sum = 0

for i = 1, _n_frames_captured do
    table.insert(_last_frame_usages, 0)
    _frame_usage_sum = _frame_usage_sum + 0
end

--- @brief [internal]
function rt.SceneManager:_draw_performance_metrics()
    local stats = love.graphics.getStats()
    local n_draws = stats.drawcalls
    local fps = love.timer.getFPS()
    local gpu_side_memory = tostring(math.round(stats.texturememory / 1024 / 1024 * 10) / 10)
    local total_percentage = tostring(math.floor(_frame_usage_sum / _n_frames_captured * 100))

    local str = table.concat({
        fps, " fps | ",             -- love-measure fps
        total_percentage, "% | ",   -- frame usage, how much of a frame was taken up by the game
        n_draws, " draws | ",       -- total number of draws
        gpu_side_memory, " mb"       -- vram usage
    })

    local str_width = love.graphics.getFont():getWidth(str)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(str, love.graphics.getWidth() - str_width - 5, 5, math.huge)
end

function love.run()
    io.stdout:setvbuf("no") -- makes it so love2d error message is printed to console immediately

    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end

    local delta = 0
    return function()
        if love.event then
            love.event.pump()
            for name, a,b,c,d,e,f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a or 0
                    end
                end
                love.handlers[name](a,b,c,d,e,f)
            end
        end

        if love.timer then delta = love.timer.step() end

        local update_before, update_after, draw_before, draw_after

        update_before = love.timer.getTime()
        if love.update then love.update(delta) end
        update_after = love.timer.getTime()

        if love.graphics and love.graphics.isActive() then
            love.graphics.reset()
            love.graphics.clear(true, true, true)

            draw_before = love.timer.getTime()
            if love.draw then love.draw() end
            draw_after = love.timer.getTime()

            if true then --rt.SceneManager._show_performance_metrics then
                love.graphics.push()
                love.graphics.origin()
                rt.SceneManager:_draw_performance_metrics()
                love.graphics.pop()
            end

            love.graphics.present()
        end

        local fps = love.timer.getFPS()
        if fps == 0 then fps = 60 end

        local frame_usage = ((update_after - update_before) + (draw_after - draw_before)) / (1 / fps)
        local start = _last_frame_usages[1]
        table.remove(_last_frame_usages, 1)
        table.insert(_last_frame_usages, frame_usage)
        _frame_usage_sum = _frame_usage_sum - start + frame_usage

        collectgarbage("collect") -- helps catch gc-related bugs
        if love.timer then love.timer.sleep(0.001) end -- prevent cpu running at max rate for empty projects
    end
end

return rt.SceneManager()