rt.settings.overworld.stage_hud = {
}

--- @class ow.StageHUD
ow.StageHUD = meta.class("StageHUD", rt.Widget)

--- @brief
function ow.StageHUD:instantiate(stage)
    meta.assert(stage, ow.Stage)
    meta.install(self, {
        _stage = stage,

        _current_n_coins = 0,
        _max_n_coins = 0,
        _current_time = 0,

        _x = 0,
        _y = 0,

        _coins_label = rt.Label("0"),
        _coin_x = 0,
        _coin_y = 0,
    })

    self:set_n_coins(self._current_n_coins, self._max_n_coins)
end

--- @brief
function ow.StageHUD:size_allocate(x, y, width, height)

end

--- @brief
function ow.StageHUD:set_n_coins(current, max)
    local prefix = "<b>"
    local postfix = "</b>"

    self._coins_label:set_text(prefix .. current .. " / " .. max .. postfix)
end

--- @brief
function ow.StageHUD:draw()
    ow.Coin.draw_coin(self._coin_x, self._coin_y, 1, 1, 1, 1)
    self._coins_label:draw()
end

