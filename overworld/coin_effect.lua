require "common.render_texture"

rt.settings.overworld.coin_effect = {
    n_coin_buffer_size = 20
}

--- @class ow.CoinEffect
ow.CoinEffect = meta.class("CoinEffect", rt.Widget)

local _shader = nil
local _canvas = nil
local _mask = nil

--- @brief
function ow.CoinEffect:_initialize_buffers()
    local max_n_coins = rt.settings.overworld.coin_effect.n_coin_buffer_size
    self._coin_positions = table.rep({0, 0}, max_n_coins )
    self._coin_colors = table.rep({0, 0, 0, 0}, max_n_coins)
    self._coin_elapsed = table.rep(math.huge, max_n_coins)
    self._coin_is_active = table.rep(0, max_n_coins)
    self._n_coins = 0
end

--- @brief
function ow.CoinEffect:instantiate(scene)
    meta.assert(scene, ow.OverworldScene)

    if _shader == nil then
        _shader = rt.Shader("overworld/coin_effect.glsl", {
            MAX_N_COINS = rt.settings.overworld.coin_effect.n_coin_buffer_size
        })
    end

    meta.install(self, {
        _x = 0,
        _y = 0,
        _elapsed = 0,
        _scene = scene,

        _camera_offset = { 0, 0 },
        _camera_scale = 1,
        _player_position = { 0, 0 },
        _player_color = {0, 0, 0, 0},
        _pulse_elapsed = math.huge
    })

    self:_initialize_buffers()
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "q" then
            _shader:recompile()
            self._elapsed = 0
        end
    end)
end

--- @override
function ow.CoinEffect:size_allocate(x, y, width, height)
    self._x, self._y = x, y
    _canvas = rt.RenderTexture(width, height, 8)
    _mask = rt.RenderTexture(width, height, 4)
end

--- @override
function ow.CoinEffect:update(delta)
    self._elapsed = self._elapsed + delta
    self._camera_offset = { self._scene:get_camera():get_offset() }
    self._camera_scale = self._scene:get_camera():get_scale()
    self._player_position = { self._scene:get_player():get_physics_body():get_predicted_position() }
    self._pulse_elapsed = self._pulse_elapsed + delta

    self:_initialize_buffers()
    local coins = self._scene:get_current_stage():get_coins()

    local i = 1
    for coin in values(coins) do
        self._coin_positions[i] = { coin:get_position() }
        self._coin_colors[i] = { coin:get_color():unpack() }
        local elapsed = coin:get_time_since_collection()
        self._coin_elapsed[i] = elapsed

        local is_active
        if elapsed == math.huge then
            is_active = 0
        else
            is_active = 1
        end

        self._coin_is_active[i] = is_active
        i = i + 1
    end
    self._n_coins = i
end

--- @brief
function ow.CoinEffect:bind()
    _canvas:bind()
    love.graphics.clear(0, 0, 0, 0)
end

--- @brief
function ow.CoinEffect:unbind()
    _canvas:unbind()
end

--- @brief
function ow.CoinEffect:bind_mask()
    _mask:bind()
    love.graphics.clear(0, 0, 0, 0)
end

--- @brief
function ow.CoinEffect:unbind_mask()
    _mask:unbind()
end

--- @brief
function ow.CoinEffect:pulse()
    self._pulse_elapsed = 0
end

--- @override
function ow.CoinEffect:draw()
    _shader:bind()
    _shader:send("elapsed", self._elapsed)
    _shader:send("camera_offset", self._camera_offset)
    _shader:send("camera_scale", self._camera_scale)
    _shader:send("player_position", self._player_position)
    _shader:send("player_color", {1, 1, 1, 1})
    _shader:send("player_pulse_elapsed", self._pulse_elapsed)
    _shader:send("bubble_mask", _mask:get_native())

    _shader:send("coin_positions", table.unpack(self._coin_positions))
    _shader:send("coin_colors",  table.unpack(self._coin_colors))
    _shader:send("coin_elapsed", table.unpack(self._coin_elapsed))
    _shader:send("coin_is_active", table.unpack(self._coin_is_active))
    _shader:send("n_coins", self._n_coins)

    love.graphics.setColor(1, 1, 1, 1)
    _canvas:draw()
    _shader:unbind()
end