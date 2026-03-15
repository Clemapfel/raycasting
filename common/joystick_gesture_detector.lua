require "common.input_subscriber"
require "common.direction"

rt.settings.joystick_gesture_detector = {
    engage_magnitude = 0.35,
    release_magnitude = 0.20,
}

rt.JoystickGestureDetector = meta.class("JoystickGestureDetector")
meta.add_signal(rt.JoystickGestureDetector,
    "pressed",  -- (self, rt.InputAction, count) -> nil
    "released"  -- (self, rt.InputAction, count) -> nil
)

function rt.JoystickGestureDetector:instantiate()
    self._input = rt.InputSubscriber()
    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self:_handle_joystick_moved(x, y)
    end)

    self._current_input_action = nil

    local now = love.timer.getTime()
    self._input_action_to_data = {}
    for action in range(
        rt.InputAction.UP,
        rt.InputAction.RIGHT,
        rt.InputAction.DOWN,
        rt.InputAction.LEFT
    ) do
        self._input_action_to_data[action] = { timestamp = now, count = 0 }
    end
end

-- atan2 with y-axis pointing down: angle 0 = right, increases clockwise.
-- Sectors are 90° wide, centred on each cardinal direction.
-- Diagonal inputs snap to the axis with the larger absolute component.
local function joystick_to_input_action(x, y)
    local magnitude = math.sqrt(x * x + y * y)
    if magnitude < 1e-6 then return nil end

    -- Snap to dominant axis before sector classification, preventing diagonal drift
    local abs_x, abs_y = math.abs(x), math.abs(y)
    if abs_x > abs_y then
        y = 0
    else
        x = 0
    end

    -- atan2 returns [-π, π]; remap to [0, 2π] with 0 = right, clockwise
    local angle = math.atan2(y, x)
    if angle < 0 then angle = angle + 2 * math.pi end

    -- Each sector spans 90° (π/2). Boundaries at 45°, 135°, 225°, 315°.
    local sector = math.floor((angle + math.pi / 4) / (math.pi / 2)) % 4
    -- sector 0 = right, 1 = down, 2 = left, 3 = up
    if sector == 0 then return rt.InputAction.RIGHT
    elseif sector == 1 then return rt.InputAction.DOWN
    elseif sector == 2 then return rt.InputAction.LEFT
    else return rt.InputAction.UP
    end
end

function rt.JoystickGestureDetector:is_down(input_action)
    return input_action == self._current_input_action
end

function rt.JoystickGestureDetector:get_magnitude(input_action)
    local x, y = rt.InputManager:get_left_joystick()
    if input_action == rt.InputAction.LEFT  then return math.max(0, -x)
    elseif input_action == rt.InputAction.RIGHT then return math.max(0,  x)
    elseif input_action == rt.InputAction.UP    then return math.max(0, -y)
    elseif input_action == rt.InputAction.DOWN  then return math.max(0,  y)
    else return 0
    end
end

function rt.JoystickGestureDetector:_handle_joystick_moved(x, y)
    local magnitude = math.sqrt(x * x + y * y)
    local settings = rt.settings.joystick_gesture_detector
    local before = self._current_input_action
    local after

    if before == nil then
        -- Not currently held: require full engage threshold to activate
        if magnitude >= settings.engage_magnitude then
            after = joystick_to_input_action(x, y)
        else
            after = nil
        end
    else
        -- Currently held: keep direction unless magnitude drops below release threshold,
        -- OR the stick has moved decisively to a different direction beyond engage threshold
        if magnitude < settings.release_magnitude then
            after = nil
        elseif magnitude >= settings.engage_magnitude then
            local candidate = joystick_to_input_action(x, y)
            -- Only switch direction if the new sector is unambiguous (dominant axis differs)
            after = candidate ~= nil and candidate or before
        else
            -- In hysteresis band: hold current direction
            after = before
        end
    end

    self._current_input_action = after

    if before == after then return end

    local now = love.timer.getTime()
    local time_threshold = rt.GameState:get_double_press_threshold()

    if before ~= nil then
        self:signal_emit("released", before, self._input_action_to_data[before].count)
    end

    if after ~= nil then
        local entry = self._input_action_to_data[after]
        if now - entry.timestamp < time_threshold then
            entry.count = entry.count + 1
        else
            entry.count = 1
        end
        entry.timestamp = now
        self:signal_emit("pressed", after, entry.count)
    end
end