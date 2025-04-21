rt.settings.overworld.stage_hud = {
}

--- @class ow.StageHUD
ow.StageHUD = meta.class("StageHUD", rt.Widget)

--- @brief
function ow.StageHUD:instantiate()
    meta.install(self, {
        _current_n_coins = 0,
        _max_n_coins = 0,
        _current_time = 0,

        _x = 0,
        _y = 0,

        _coins_label = rt.Label("0", rt.settings.font.default_small, rt.settings.font.default_mono_small),
        _coin_x = 0,
        _coin_y = 0,
    })

    self:set_n_coins(self._current_n_coins, self._max_n_coins)
end

--- @brief
function ow.StageHUD:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local label_w, label_h = self._coins_label:measure()
    self._coins_label:reformat(x + m, y + m, math.huge)
end

--- @brief
function ow.StageHUD:set_n_coins(current, max)
    local prefix = "<b><o><mono>"
    local postfix = "</mono></b></o>"

    local formatted_time = "0.314:24"
    self._coins_label:set_text(prefix .. formatted_time ..  postfix )
end

--- @brief
function ow.StageHUD:draw()
    ow.Coin.draw_coin(self._coin_x, self._coin_y, 1, 1, 1, 1)
    self._coins_label:draw()
end

