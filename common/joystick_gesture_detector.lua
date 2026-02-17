require "common.input_subscriber"
require "common.direction"

rt.settings.joystick_gesture_detector = {
    magnitude_threshold = 0.25,
    likelihood_threshold = 0.5,
    deadzone = 0.25,
    time_threshold_factor = 1 -- * rt.GameState:get_double_press_threshold
}

--- @class rt.JoystickGestureDetector
rt.JoystickGestureDetector = meta.class("JoystickGestureDetector")
meta.add_signal(rt.JoystickGestureDetector,
    "pressed", -- (rt.JoystickGestureDetector, rt.InputAction, count) -> nil
    "released" -- (rt.JoystickGestureDetector, rt.InputAction, count) -> nil
)

--- @brief
function rt.JoystickGestureDetector:instantiate()
    self._input = rt.InputSubscriber()
    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self:_handle_joystick_moved(x, y)
    end)

    self._current_input_action = nil -- rt.InputAction
    self._input_action_to_data = {}
    
    local now = love.timer.getTime()
    for action in range(
        rt.InputAction.UP,
        rt.InputAction.RIGHT,
        rt.InputAction.DOWN,
        rt.InputAction.LEFT
    ) do
        self._input_action_to_data[action] = {
            timestamp = now,
            count = 0,
            magnitude = 0
        }
    end
end

local _direction_to_input_action = {
    [rt.Direction.RIGHT] = rt.InputAction.RIGHT,
    [rt.Direction.DOWN] = rt.InputAction.DOWN,
    [rt.Direction.LEFT] = rt.InputAction.LEFT,
    [rt.Direction.UP] = rt.InputAction.UP
}

local _input_action_to_direction = {
    [rt.InputAction.RIGHT] = rt.Direction.RIGHT,
    [rt.InputAction.DOWN] = rt.Direction.DOWN,
    [rt.InputAction.LEFT] = rt.Direction.LEFT,
    [rt.InputAction.UP] = rt.Direction.UP
}

--- @brief get which of the four direction, if any, the gesture is most confident is held
function rt.JoystickGestureDetector:is_down(input_action)
    return input_action == self._current_input_action
end

--- @brief get magnitude of each direction
function rt.JoystickGestureDetector:get_magnitude(input_action)
    local joystick_x, joystick_y = rt.InputManager:get_left_joystick()
    local value
    if input_action == rt.InputAction.LEFT then
        value = math.min(0, joystick_x)
    elseif input_action == rt.InputAction.RIGHT then
        value = math.max(0, joystick_x)
    elseif input_action == rt.InputAction.UP then
        value = math.min(0, joystick_y)
    elseif input_action == rt.InputAction.DOWN then
        value = math.max(0, joystick_y)
    else
        value = 0
    end

    return math.abs(value)
    --[[

    local entry = self._input_action_to_data[input_action]
    if entry == nil then return 0 else return entry.magnitude end
    ]]--
end

local _direction_to_angle = {
    [rt.Direction.RIGHT] = 0,
    [rt.Direction.DOWN] = math.pi / 2,
    [rt.Direction.LEFT] = math.pi,
    [rt.Direction.UP] = 3 * math.pi / 2
}

function rt.JoystickGestureDetector:_handle_joystick_moved(x, y)
    if math.magnitude(x, y) < rt.settings.joystick_gesture_detector.deadzone then return end

    local angle = math.normalize_angle(math.angle(x, y))

    local direction_to_likelihood = {}
    local direction_to_magnitude = {}
    local total = 0

    for direction, target_angle in pairs(_direction_to_angle) do
        -- normalize angle difference, max of 180°
        local difference = math.abs(math.angle_distance(angle, target_angle)) / math.pi
        local likelihood = rt.InterpolationFunctions.GAUSSIAN_HIGHPASS(1 - difference)

        local target_x, target_y = math.cos(target_angle), math.sin(target_angle)
        local projection = math.dot(x, y, target_x, target_y)
        local magnitude = math.max(0, projection)

        direction_to_likelihood[direction] = likelihood
        direction_to_magnitude[direction] = magnitude
        total = total + likelihood
    end

    local likelihood_threshold = rt.settings.joystick_gesture_detector.likelihood_threshold
    local magnitude_threshold = rt.settings.joystick_gesture_detector.magnitude_threshold

    -- current down = direction above threshold with max likelihood
    -- log magnitude for all directions
    local max_likelihood, max_direction = -math.huge, nil
    for direction, magnitude in pairs(direction_to_magnitude) do
        local likelihood = direction_to_likelihood[direction]
        if magnitude > magnitude_threshold then
            if likelihood > max_likelihood then
                max_likelihood = likelihood
                max_direction = direction
            end
        end

        local entry = self._input_action_to_data[_direction_to_input_action[direction]]
        entry.magnitude = magnitude
    end

    local before = self._current_input_action
    local after = _direction_to_input_action[max_direction] -- can be nil

    self._current_input_action = after

    local now = love.timer.getTime()
    local time_threshold = rt.GameState:get_double_press_threshold()
    local emit_pressed = function(action)
        local entry = self._input_action_to_data[action]
        if now - entry.timestamp < time_threshold * rt.settings.joystick_gesture_detector.time_threshold_factor then
            entry.count = entry.count + 1
        else
            entry.count = 1
        end
        entry.timestamp = now

        self:signal_emit("pressed", action, entry.count)
    end

    local emit_released = function(action)
        local entry = self._input_action_to_data[action]
        self:signal_emit("released", action, entry.count)
    end

    if before == nil and after ~= nil then
        emit_pressed(after)
    elseif before ~= nil and before ~= after then
        if after == nil then
            emit_released(before)
        else
            emit_released(before)
            emit_pressed(after)
        end
    end
end