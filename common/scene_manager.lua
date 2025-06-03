require "common.scene"
require "common.input_subscriber"
require "common.fade"
require "common.thread_pool"
require "menu.pause_menu_scene"

rt.settings.scene_manager = {
    pause_delay_duration = 5 / 60, -- seconds
    max_n_steps_per_frame = 8,
    fade_duration = 0.2,
}

--- @class SceneManager
rt.SceneManager = meta.class("SceneManager")

local _frame_i = 0

--- @brief
function rt.SceneManager:instantiate()
    meta.install(self, {
        _scene_type_to_scene = {},
        _current_scene = nil,
        _current_scene_type = nil,
        _current_scene_varargs = {},
        
        _scene_stack = {}, -- Stack<SceneType>
        _show_performance_metrics = true,
        _width = love.graphics.getWidth(),
        _height = love.graphics.getHeight(),
        _fade = rt.Fade(),

        _pause_menu = mn.PauseMenuScene(),
        _pause_menu_active = false,
        _pause_delay_elapsed = math.huge,
        _use_fixed_timestep = false,

        _input = rt.InputSubscriber(),
    })

    self._fade:set_duration(rt.settings.scene_manager.fade_duration)
    self._pause_menu:realize()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.START then
            self:pause()
        end
    end)
end

--- @brief
function rt.SceneManager:_set_scene(add_to_stack, scene_type, ...)

    local varargs = { ... }
    local on_scene_changed = function()
        local scene = self._scene_type_to_scene[scene_type]
        if scene == nil then
            scene = scene_type(rt.GameState)
            scene:realize()
            self._scene_type_to_scene[scene_type] = scene

            scene._scene_manager_current_width = 0
            scene._scene_manager_current_height = 0
        end

        if add_to_stack == true and self._current_scene ~= nil then
            table.insert(self._scene_stack, 1, {
                self._current_scene_type,
                table.unpack(self._current_scene_vargs)
            })
        end

        local previous_scene = self._current_scene

        self._current_scene = scene
        self._current_scene_type = scene_type
        self._current_scene_vargs = varargs

        if previous_scene ~= nil then
            previous_scene:exit()
            previous_scene._is_active = false
        end

        -- resize if necessary
        local current_w, current_h = self._current_scene._scene_manager_current_width, self._current_scene._scene_manager_current_height
        if current_w ~= self._width or current_h ~= self._height then
            self._current_scene:reformat(0, 0, self._width, self._height)
            self._current_scene._scene_manager_current_width = self._width
            self._current_scene._scene_manager_current_height = self._height
        end

        self._current_scene:enter(table.unpack(varargs))
        self._current_scene._is_active = true

        if self._pause_menu_active and self._current_scene:get_can_pause() == false then
            self:unpause()
        end
    end

    if self._current_scene == nil then -- don't fade at start of game
        on_scene_changed()
    else
        self._fade:signal_connect("hidden", function()
            on_scene_changed()
            return meta.DISCONNECT_SIGNAL
        end)
        self._fade:start()
    end
end

--- @brief
function rt.SceneManager:push(scene_type, ...)
    self:_set_scene(true, scene_type, ...)
end

--- @brief
function rt.SceneManager:pop()
    local last = self._scene_stack[1]
    if last ~= nil then
        table.remove(self._scene_stack, 1)
        self:_set_scene(false, table.unpack(last))
    end
end

--- @brief
function rt.SceneManager:update(delta)
    rt.ThreadPool:update(delta)

    self._fade:update(delta)
    if self._pause_menu_active then
        self._pause_menu:update(delta)
        self._pause_menu:signal_emit("update", delta)
    elseif self._current_scene ~= nil then
        -- delay enter to avoid inputting on the same frame as pause menu exiting
        if self._pause_delay_elapsed > rt.settings.scene_manager.pause_delay_duration then
            self._current_scene:update(delta)
            self._current_scene:signal_emit("update", delta)
        end
        self._pause_delay_elapsed = self._pause_delay_elapsed + delta
    end
end

--- @brief
function rt.SceneManager:draw(...)
    if self._current_scene ~= nil then
        self._current_scene:draw(...)
    end

    if self._pause_menu_active then
        self._pause_menu:draw()
    end

    rt.graphics._stencil_value = 1 -- reset running stencil value
    self._fade:draw()
end

--- @brief
function rt.SceneManager:resize(width, height)
    assert(type(width) == "number" and type(height) == "number")

    self._width = width
    self._height = height
    rt.settings.margin_unit = 10 * rt.get_pixel_scale()

    for scene in range(self._pause_menu, self._current_scene) do
        local current_w, current_h = scene._scene_manager_current_width, scene._scene_manager_current_height
        if current_w ~= self._width or current_w ~= self._height then
            scene:reformat(0, 0, self._width, self._height)
            scene._scene_manager_current_width = self._width
            scene._scene_manager_current_height = self._height
        end
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

local _last_update_times = {}
local _update_sum = 0

local _last_draw_times = {}
local _draw_sum = 0
local _default_font = love.graphics.getFont()

for i = 1, _n_frames_captured do
    table.insert(_last_update_times, 0)
    table.insert(_last_draw_times, 0)
end

--- @brief [internal]
function rt.SceneManager:_draw_performance_metrics()
    local stats = love.graphics.getStats()
    local n_draws = stats.drawcalls
    local fps = love.timer.getFPS()
    local gpu_side_memory = tostring(math.round(stats.texturememory / 1024 / 1024 * 10) / 10)
    local update_percentage = tostring(math.floor(_update_sum / _n_frames_captured * 100))
    local draw_percentage = tostring(math.floor(_draw_sum / _n_frames_captured * 100))

    local str = table.concat({
        fps, " fps | ",             -- love-measure fps
        update_percentage, "% | ",   -- frame usage, how much of a frame was taken up by the game
        draw_percentage, "% | ",
        n_draws, " draws | ",       -- total number of draws
        gpu_side_memory, " mb"       -- vram usage
    })

    love.graphics.setFont(_default_font)
    local str_width = _default_font:getWidth(str)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(str, love.graphics.getWidth() - str_width - 5, 5, math.huge)
end

--- @brief
function rt.SceneManager:pause()
    if self._current_scene == nil then return end
    if not self._current_scene:get_can_pause() then
        rt.warning("In rt.SceneManager.pause: trying to pause current scene `" .. tostring(self._current_scene_type) .. "`, but it cannot be paused")
        return
    end

    if self._current_scene ~= nil then
        self._current_scene:exit()
        self._current_scene._is_active = false
    end

    self._pause_menu_active = true
    self._pause_menu:enter()
    self._pause_menu._is_active = true
end

--- @brief
function rt.SceneManager:unpause()
    self._pause_menu_active = false
    self._pause_menu:exit()
    self._pause_menu._is_active = false
    self._pause_delay_elapsed = 0
end

--- @brief
function rt.SceneManager:get_frame_index()
    return _frame_i
end

--- @brief
function rt.SceneManager:set_use_fixed_timestep(b)
    self._use_fixed_timestep = b
end

--- @brief
function rt.SceneManager:get_use_fixed_timestep()
    return self._use_fixed_timestep
end

rt.SceneManager = rt.SceneManager() -- static global singleton
local _update_elapsed = 0
local _update_step = 1 / 120
local _focused = true

love.focus = function(b)
    _focused = b
end

-- override love.run for metrics
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

        _update_elapsed = _update_elapsed + delta
        if _focused then
            if rt.SceneManager._use_fixed_timestep == true then
                local n_steps = 0
                while _update_elapsed >= _update_step do
                    love.update(_update_step)
                    _update_elapsed = _update_elapsed - _update_step

                    n_steps = n_steps + 1
                    if n_steps > rt.settings.scene_manager.max_n_steps_per_frame then
                        _update_elapsed = 0
                        break
                    end
                end
            else
                love.update(delta)
            end
        end
        update_after = love.timer.getTime()

        if love.graphics and love.graphics.isActive() then
            love.graphics.reset()
            love.graphics.clear(true, true, true)

            draw_before = love.timer.getTime()
            love.draw()
            draw_after = love.timer.getTime()

            if rt.SceneManager._show_performance_metrics then
                love.graphics.push()
                love.graphics.origin()
                rt.SceneManager:_draw_performance_metrics()
                love.graphics.pop()
            end

            love.graphics.present()
            _frame_i = _frame_i + 1
        end

        local fps = love.timer.getFPS()
        if fps == 0 then fps = 60 end

        local update_time = (update_after - update_before) / (1 / fps)
        local draw_time = (draw_after - draw_before) / (1 / fps)

        local update_start = _last_update_times[1]
        table.remove(_last_update_times, 1)
        table.insert(_last_update_times, update_time)
        _update_sum = _update_sum - update_start + update_time

        local draw_start = _last_draw_times[1]
        table.remove(_last_draw_times, 1)
        table.insert(_last_draw_times, draw_time)
        _draw_sum = _draw_sum - draw_start + draw_time

        meta._benchmark = {}
        collectgarbage("step") -- helps catch gc-related bugs

        if love.timer then love.timer.sleep(0.001) end -- prevent cpu running at max rate for empty projects
    end
end

local utf8 = require("utf8")

local function error_printer(msg, layer)
    print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

function love.errorhandler(msg)
    msg = tostring(msg)

    error_printer(msg, 2)

    if not love.window or not love.graphics or not love.event then
        return
    end

    if not love.graphics.isCreated() or not love.window.isOpen() then
        local success, status = pcall(love.window.setMode, 800, 600)
        if not success or not status then
            return
        end
    end

    -- Reset state.
    if love.mouse then
        love.mouse.setVisible(true)
        love.mouse.setGrabbed(false)
        love.mouse.setRelativeMode(false)
        if love.mouse.isCursorSupported() then
            love.mouse.setCursor()
        end
    end
    if love.joystick then
        -- Stop all joystick vibrations.
        for i,v in ipairs(love.joystick.getJoysticks()) do
            v:setVibration()
        end
    end
    if love.audio then love.audio.stop() end

    love.graphics.reset()
    love.graphics.setFont(love.graphics.newFont(15))

    love.graphics.setColor(1, 1, 1)

    local trace = debug.traceback()

    love.graphics.origin()

    local sanitizedmsg = {}
    for char in msg:gmatch(utf8.charpattern) do
        table.insert(sanitizedmsg, char)
    end
    sanitizedmsg = table.concat(sanitizedmsg)

    local err = {}

    table.insert(err, "Error\n")
    table.insert(err, sanitizedmsg)

    if #sanitizedmsg ~= #msg then
        table.insert(err, "Invalid UTF-8 string in error message.")
    end

    table.insert(err, "\n")

    for l in trace:gmatch("(.-)\n") do
        if not l:match("boot.lua") then
            l = l:gsub("stack traceback:", "Traceback\n")
            table.insert(err, l)
        end
    end

    local p = table.concat(err, "\n")

    p = p:gsub("\t", "")
    p = p:gsub("%[string \"(.-)\"%]", "%1")

    local function draw()
        if not love.graphics.isActive() then return end
        local pos = 70
        love.graphics.clear(rt.Palette.RED_5:unpack())
        love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
        love.graphics.present()
    end

    local fullErrorText = p
    local function copyToClipboard()
        if not love.system then return end
        love.system.setClipboardText(fullErrorText)
        p = p .. "\nCopied to clipboard!"
    end

    if love.system then
        p = p .. "\n\nPress Ctrl+C or tap to copy this error"
    end

    if debugger.get_is_active() then
        debugger.break_here()
    end

    return function()
        love.event.pump(0.1)

        for e, a, b, c in love.event.poll() do
            if e == "quit" then
                return 1
            elseif e == "keypressed" and a == "escape" then
                return 1
            elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
                copyToClipboard()
            elseif e == "touchpressed" then
                local name = love.window.getTitle()
                if #name == 0 or name == "Untitled" then name = "Game" end
                local buttons = {"OK", "Cancel"}
                if love.system then
                    buttons[3] = "Copy to clipboard"
                end
                local pressed = love.window.showMessageBox("Quit "..name.."?", "", buttons)
                if pressed == 1 then
                    return 1
                elseif pressed == 3 then
                    copyToClipboard()
                end
            end
        end

        draw()

        if love.timer then
            love.timer.sleep(0.001)
        end
    end
end

return rt.SceneManager