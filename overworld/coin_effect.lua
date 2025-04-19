require "common.render_texture"

--- @class ow.CoinEffect
ow.CoinEffect = meta.class("CoinEffect", rt.Widget)

local _shader = nil

--- @brief
function ow.CoinEffect:instantiate(scene)
    if _shader == nil then
        _shader = rt.Shader("overworld/coin_effect.glsl")
    end

    meta.install(self, {
        _x = 0,
        _y = 0,
        _elapsed = 0,
        _scene = scene
    })

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "q" then
            _shader:recompile()
        end
    end)
end

--- @override
function ow.CoinEffect:size_allocate(x, y, width, height)
    self._x, self._y = x, y
    self._canvas = rt.RenderTexture(width, height)
end

--- @override
function ow.CoinEffect:update(delta)
    self._elapsed = self._elapsed + delta
    self._camera_offset = { self._scene:get_camera():get_offset() }
    self._camera_scale = self._scene:get_camera():get_scale()


    local coins = self._scene:get_current_stage():get_coins()
    self._coin_positions = {}
    self._coin_colors = {}
    self._n_coins = 0
    for coin in values(coins) do
        for v in range(coin:get_position()) do
            table.insert(self._coin_positions, v)
        end

        for v in range(coin:get_color():unpack()) do
            table.insert(self._coin_colors, v)
        end

        self._n_coins = self._n_coins + 1
    end
end

--- @override
function ow.CoinEffect:draw()
    _shader:bind()
    _shader:send("elapsed", self._elapsed)
    _shader:send("camera_offset", self._camera_offset)
    _shader:send("camera_scale", self._camera_scale)
    --_shader:send("coin_positions", self._coin_positions)
    --_shader:send("coin_colors", self._coin_colors)

    local coins = self._scene:get_current_stage():get_coins()
    _shader:send("coin_position", { 0, 0 }) --coins[1]:get_position() })
    _shader:send("coin_color", { coins[1]:get_color():unpack() })
    _shader:send("n_coins", self._n_coins)


    local x, y = self._scene:get_player():get_position()
    self._canvas:draw(self._x, self._y)
    _shader:unbind()
end