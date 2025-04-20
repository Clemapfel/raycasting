require "common.render_texture"

--- @class ow.CoinEffect
ow.CoinEffect = meta.class("CoinEffect", rt.Widget)

local _shader = nil
local _canvas = nil

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
    _canvas = rt.RenderTexture(width, height)
end

--- @override
function ow.CoinEffect:update(delta)
    self._elapsed = self._elapsed + delta
    self._camera_offset = { self._scene:get_camera():get_offset() }
    self._camera_scale = self._scene:get_camera():get_scale()

    local coins = self._scene:get_current_stage():get_coins()

    local max_n_coins = 10
    self._coin_positions = table.rep({0, 0}, max_n_coins )
    self._coin_colors = table.rep({0, 0, 0, 0}, max_n_coins)
    self._n_coins = 0

    local i = 1
    for coin in values(coins) do
        self._coin_positions[i] = { coin:get_position() }
        self._coin_colors[i] = { coin:get_color():unpack() }
        i = i + 1
    end
    self._n_coins = i
end

--- @override
function ow.CoinEffect:draw()
    --[[
    _shader:bind()
    --shader:send("elapsed", self._elapsed)
    _shader:send("camera_offset", self._camera_offset)
    _shader:send("camera_scale", self._camera_scale)
    _shader:send("coin_positions",table.unpack(self._coin_positions))
    _shader:send("coin_colors", table.unpack(self._coin_colors))
    _shader:send("n_coins", self._n_coins)

    local x, y = self._scene:get_player():get_position()
    _canvas:draw(self._x, self._y)
    _shader:unbind()
    ]]--
end