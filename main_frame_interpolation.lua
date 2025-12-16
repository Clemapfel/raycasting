--[[
Frame Interpolation in Love2D
Author: Clem Cords, licensed MIT, free to use in commercial projects

This is a demonstration of how to run a game at a fixed frame rate while 
keeping drawing smooth. If a game is out of sync with the monitor refresh rate,
stuttering can occur. To address this, we need to perform what is called 
*frame interpolation*, which predicts the objects current position independent
of the games frame rate. We then use this predicted position for drawing, which vastly reduces 
stuttering, especially when the game refresh rate is lower than the monitor refresh rate.

PLEASE READ BEFORE USING

`FrameInterpolationHelper` is designed to be easily extracted and used in any of 
your projects. To do this, perform the following steps:

1. Create a file "frame_interpolation_helper.lua" and copy the first part of this gist into it

2. Uncomment `return FrameInterpolationHelper` (line 177) below

3. Modify your love.run to use a fixed update cycle duration. See `love.run` below how to achieve this.

4. Make sure to call `FrameInterpolationHelper:notify_end_of_update()` either in your `love.run` or at the end of your `love.update`

You can now import the helper like so:

```lua
-- at the top of the file, in global scope
local FrameInterpolationHelper = require("frame_interpolation_helper")

-- in your `love.update` or `love.run`, after the simulation step
FrameInterpolationHelper:notify_end_of_update()

-- inside an objects `draw` routine
local x, y = FrameInterpolationHelper:predict_position_based_on_velocity(
    self.current_position_x, self.current_position_y,
    self.current_velocity_x, self.current_velocity_y
)
-- use x, y to draw
```

Where you may need to modify the require path depending on where the file is located.
]]--

--- ### frame_interpolation_helper.lua ### ---

--- @class FrameInterpolationHelper
--- @brief helper class to predict an objects position using frame interpolation.
---     Make sure to call `notify_end_of_update` at the end of your update function
--- @field _timestamp Number (private) temporal position of last update, in seconds
--- @field _timestep Number (private) fixed timestep, 1 / fps
--- @source https://gist.github.com/Clemapfel/197b1eb961daac06dd5be3a6e77a6098
local FrameInterpolationHelper = {
    _timestamp = 0,
    _timestep = 1 / 60,

    --- @brief (private) get current timestamp
    --- @param self FrameInterpolationHelper
    --- @return number
    _get_time = function(_)
        if love ~= nil and love.timer and love.timer.getTime then
            return love.timer.getTime()
        else
            return os.time()
        end
    end,

    --- @brief (private) assertion helper
    --- @param ... any
    _assert = function(...)
        local arg_i = 1
        for i = 1, select("#", ...) - 1, 2 do
            local arg = select(i + 0, ...)
            local expected = select(i + 1, ...)
            local got = arg ~= nil and type(arg) or "nil"

            if got ~= expected then
                local prefix = ""
                if debug ~= nil and debug.getinfo ~= nil then
                    local info = debug.getinfo(3, "Sl")
                    if info ~= nil and info.short_src ~= nil and info.currentline ~= nil then
                        prefix = string.format(" %s:%d: ", info.short_src, info.currentline)
                    end
                end
                error(prefix .. ("error for argument #%d: expected `%s`, got `%s`"):format(arg_i, expected, got))
            end
            arg_i = arg_i + 1
        end
    end,

    --- @brief set fps
    --- @param self FrameInterpolationHelper
    --- @param fps number integer, for example `60`
    set_fps = function(self, fps)
        self._assert(self, "table", fps, "number")
        assert(fps > 0, "In FrameInterpolationHelper.set_fps: fps cannot be negative")
        self._timestep = 1 / fps
    end,

    --- @brief get fixed timestep
    --- @param self FrameInterpolationHelper
    --- @return number seconds
    get_timestep = function(self)
        self._assert(self, "table")
        return self._timestep
    end,

    --- @brief get target fps
    --- @param self FrameInterpolationHelper
    --- @return number integer
    get_fps = function(self)
        self._assert(self, "table")
        return 1 / self._timestep
    end,

    --- @brief notify start of frame, needs to be called every frame, immediately at the end of the update step
    --- @param self FrameInterpolationHelper
    notify_end_of_update = function(self)
        self._assert(self, "table")
        self._timestamp = self:_get_time()
    end,

    --- @brief get predicted position using explicit velocity
    --- @param self FrameInterpolationHelper
    --- @param current_position_x number x-coordinate of current position
    --- @param current_position_y number y-coordinate of current position
    --- @param velocity_x number x-component of current velocity, px per second
    --- @param velocity_y number y-component of current velocity, px per second
    --- @return number, number x- and y-component of predicted position
    predict_position_based_on_velocity = function(self,
                                                  current_position_x, current_position_y,
                                                  velocity_x, velocity_y
    )
        self._assert(
            self, "table",
            current_position_x, "number",
            current_position_y, "number",
            velocity_x, "number",
            velocity_y, "number"
        )

        if self._timestamp == nil then -- if uninitialized
            self:notify_end_of_update()
        end

        local elapsed = self:_get_time() - self._timestamp
        local delta = math.max(0, math.min(elapsed, self._timestep))
        local predicted_x = current_position_x + velocity_x * delta
        local predicted_y = current_position_y + velocity_y * delta

        return predicted_x, predicted_y
    end,

    --- @brief get predicted position using current and the position during the last simulation step
    --- @param self FrameInterpolationHelper
    --- @param current_x number x-coordinate of current position
    --- @param current_y number y-coordinate of current position
    --- @param last_x number x-coordinate of last position
    --- @param last_y number y-coordinate of last position
    --- @return number, number x- and y-component of predicted position
    predict_position_based_on_last_position = function(self, current_x, current_y, last_x, last_y)
        self._assert(
            self, "table",
            current_x, "number",
            current_y, "number",
            last_x, "number",
            last_y, "number"
        )
        local step = self._timestep
        local velocity_x = (current_x - last_x) / step
        local velocity_y = (current_y - last_y) / step
        return self:predict_position_based_on_velocity(current_x, current_y, velocity_x, velocity_y)
    end,
}

-- make sure to uncomment the following when using `frame_interpolation_helper.lua` in your project
--return FrameInterpolationHelper

--- ### main.lua ### ---

--local FrameInterpolationHelper = require("frame_interpolation_helper")

-- ### GAME STATE ###
local fps = { 15, 30, 60, 144, 280, 69 } -- allowed fixed fps
local fps_i = 1 -- current fps index
local fps_switch_key = "space" -- scancode to swap fps

local vsync = { -1, 0, 1 } -- possible vsync modes
local vsync_i = 1 -- current vsync mode index
local vsync_switch_key = "return" -- scancode to swap vsync modes

local drawables = {} -- cf. love.load

-- (private) helper to update the graphics state
local _update_window = function()
    local aspect_ratio = 16 / 9
    local native_height = 600
    love.window.setMode(
        native_height * aspect_ratio,
        native_height,
        {
            fullscreen = false,
            resizable = true,
            vsync = vsync[vsync_i],
            msaa = 4
        }
    )
end

-- ### INTERACTABILITY ###
love.keypressed = function(which)
    if which == fps_switch_key then -- cycle through fps
        fps_i = fps_i + 1
        if fps_i > #fps then fps_i = 1 end

        FrameInterpolationHelper:set_fps(fps[fps_i]) -- notify helper

    elseif which == vsync_switch_key then -- cycle through vsync modes
        vsync_i = vsync_i + 1
        if vsync_i > #vsync then vsync_i = 1 end

        _update_window() -- update window state
    end
end

-- ### MAIN LOOP ###
-- use this love.run for a fixed step size update while keeping the draw rate
-- user-dependend, this is the best of both worlds, the game can run at arbitrary
-- fps while the user or the users driver decides the best refresh rate
-- without frame interpolation, certain update-fps / draw-fps combinations cause
-- severe stuttering
function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end

    -- tell the helper about the target fps
    FrameInterpolationHelper:set_fps(fps[fps_i])
    FrameInterpolationHelper:notify_end_of_update() -- initialize

    -- override settings in conf.lua for better demonstation
    _update_window()

    -- upvalues needed for fixed fps update
    local _elapsed = 0 -- accumulated delta time
    local _delta = 0 -- non-fixed timestep

    return function()
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
            end
        end

        if love.timer then _delta = love.timer.step() end

        _elapsed = _elapsed + _delta -- accumulate time
        local step = 1 / fps[fps_i] -- calculate current step size

        -- work through queued up time
        local current_n_steps = 0
        while _elapsed >= step do
            _elapsed = _elapsed - step

            if love.update then
                love.update(step) -- love update uses *fixed* step size, not variable delta

                -- notify the interpolation manager, this has to happen here,
                -- at the end of update
                FrameInterpolationHelper:notify_end_of_update()
            end

            current_n_steps = current_n_steps + 1
            if current_n_steps >= 8 then
                -- prevent death spiral by limiting the number of steps per frame
                -- there are more elegant ways to do this but there should be some
                -- kind of protection in place
                _elapsed = 0
                break
            end
        end

        -- draw kept unlimited, still respects vsync mode
        if love.graphics and love.graphics.isActive() then
            love.graphics.reset()
            love.graphics.clear(love.graphics.getBackgroundColor())
            if love.draw then love.draw() end
            love.graphics.present()
        end

        -- limit max fps when vsync is off
        if love.timer then love.timer.sleep(1 / 420) end
    end
end

-- ### INITIALIZATION ###
-- your objects need to have the following properties
--      current position (xy) : mandatory
--      last position (xy)    : optional if velocity is present
--      current velocity (xy) : optional if last position is present
--
-- to apply frame interpolation, call FrameInterpolationHelper:predict_position_based_on_*
-- during *draw*, use that position for drawing, not the position the simulation (either
-- love.physics or a custom simulation like here) reports
love.load = function()
    local w, h = love.graphics.getDimensions()

    --- @class Drawable
    --- @field current_position_x number x-component of the simulation position
    --- @field current_position_y number y-component of "
    --- @field last_position_x number x-component of the position during the simulation step
    --- @field last_position_y number y-component of "
    --- @field velocity_x number x-component of the current velocity, in px / s
    --- @field velocity_y number y-component of "
    --- @field _radius number (private) radius for drawing
    --- @field _line_width number (private) line width for drawing
    --- @field _elapsed number (private) object-local accumulated time
    local to_draw = {
        current_position_x = 0,
        current_position_y = 0,

        last_position_x = 0,
        last_position_y = 0,

        velocity_x = 0,
        velocity_y = 0,

        _radius = 0.1 * math.min(w, h),
        _line_width = 10,
        _elapsed = 0,

        --- @brief update the object state
        --- @param self Drawable
        --- @param delta number time step, usually fixed at 1 / fps
        update = function(self, delta)
            -- update position of last frame
            self.last_position_x = self.current_position_x
            self.last_position_y = self.current_position_y

            -- integrate velocity to update position
            self.current_position_x = self.current_position_x + delta * self.velocity_x
            self.current_position_y = self.current_position_y + delta * self.velocity_y

            -- update velocity for pathing
            self._elapsed = self._elapsed + delta

            -- component-swapped lemniscate derivative (don't try to understand how this works)
            local scale = math.min(w, h) * 1 / 4
            local t = self._elapsed
            self.velocity_x = scale * (math.cos(t) * math.cos(t) - math.sin(t) * math.sin(t))
            self.velocity_y = -1 * scale * math.cos(t)
        end,

        --- @brief draw the object with no frame interpolation
        --- @param self Drawable
        draw_without_interpolation = function(self)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(self._line_width)

            -- use regular position for drawing
            love.graphics.circle("line",
                self.current_position_x, self.current_position_y,
                self._radius
            )
        end,

        --- @brief draw the object with frame interpolation
        --- @param self Drawable
        draw_with_interpolation = function(self)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(self._line_width)

            -- get interpolated position using velocity
            local px, py = FrameInterpolationHelper:predict_position_based_on_velocity(
                self.current_position_x,
                self.current_position_y,
                self.velocity_x,
                self.velocity_y
            )

            -- or, equivalently:
            -- local px, py = FrameInterpolationHelper:predict_position_based_on_last_position(
            --     self.current_position_x,
            --     self.current_position_y,
            --     self.last_position_x,
            --     self.last_position_y
            -- )

            -- use new interpolated position for drawing
            love.graphics.circle("line", px, py, self._radius)
        end,
    }

    table.insert(drawables, to_draw) -- add to state
end

-- ### UPDATE ###
-- step the simulation
love.update = function(delta)
    -- step world
    for _, drawable in pairs(drawables) do
        drawable:update(delta)
    end

    -- if not doing so in love.run, `FrameInterpolationHelper` has to be
    -- notified here, **at the end of update**
    -- FrameInterpolationHelper:notify_end_of_update()
end

-- ### DRAWING ###
local white = { 1, 1, 1, 1 }
local gray = { 0.5, 0.5, 0.5, 1 }
local black = { 0, 0, 0, 1 }

local with_label_text = "with interpolation"
local without_label_text = "without interpolation"
local button_prompt_label_text = table.concat({
    "Press ", string.upper(fps_switch_key), " to swap between different fps\n",
    "Press ", string.upper(vsync_switch_key), " to swap between vsync modes"
}, "")

local with_label_w = love.graphics.getFont():getWidth(with_label_text)
local without_label_w = love.graphics.getFont():getWidth(without_label_text)
local button_prompt_label_w = love.graphics.getFont():getWidth(button_prompt_label_text)
local margin = 10

-- vsync cleartext names for the UI
local vsync_value_to_name = {
    [-1] = "ADAPTIVE",
    [ 0] = "OFF",
    [ 1] = "ON"
}

love.draw = function()
    local w, h = love.graphics.getDimensions()
    local text_y_offset = 0.4 * h

    local without_x, without_y = 0.25 * w, 0.5 * h
    local with_x, with_y = 0.75 * w, 0.5 * h

    -- draw background
    love.graphics.setColor(gray)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setLineStyle("smooth")

    -- draw without interpolation
    love.graphics.push()
    love.graphics.translate(without_x, without_y)
    for _, drawable in pairs(drawables) do
        drawable:draw_without_interpolation()
    end
    love.graphics.pop()

    love.graphics.setColor(white)
    love.graphics.print(
        without_label_text,
        math.floor(without_x - 0.5 * without_label_w),
        math.floor(without_y + text_y_offset)
    )

    -- center division
    love.graphics.setColor(black)
    love.graphics.setLineWidth(2)
    love.graphics.line(0.5 * w, 0, 0.5 * w, h)

    -- draw with interpolation
    love.graphics.push()
    love.graphics.translate(with_x, with_y)
    for _, drawable in pairs(drawables) do
        drawable:draw_with_interpolation()
    end
    love.graphics.pop()

    love.graphics.setColor(white)
    love.graphics.print(
        with_label_text,
        math.floor(with_x - 0.5 * with_label_w),
        math.floor(with_y + text_y_offset)
    )

    -- UI
    love.graphics.setColor(white)
    love.graphics.print(
        table.concat({
            "Update fps:  ", tostring(fps[fps_i]), "\n",
            "Draw fps:  ", tostring(love.timer.getFPS()), "\n",
            "vsync mode: ", vsync_value_to_name[vsync[vsync_i]]
        }),
        2 * margin, margin
    )

    love.graphics.print(
        button_prompt_label_text,
        w - button_prompt_label_w - 2 * margin, margin
    )
end
