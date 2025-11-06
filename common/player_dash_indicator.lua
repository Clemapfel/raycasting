rt.settings.player_dash_indicator = {
    radius_factor = 0.5
}

--- @class rt.PlayerDashIndicator
rt.PlayerDashIndicator = meta.class("PlayerDashIndicator")

--- @brief
function rt.PlayerDashIndicator:instantiate(player_radius)
    self._x, self._y = 0, 0
    self._direction_x, self._direction_y = 0, -1

    self._radius = rt.settings.player_dash_indicator.radius_factor * player_radius
    self._margin = 4
    do -- init shape
        local w, h, t = self._radius, self._radius / 2.5, 0.25 * self._radius
        self._half_width = w / 2
        self._half_height = h / 2
        self._step = h
        self._thickness = t + 1
    end
end

--- @brief
function rt.PlayerDashIndicator:draw(player_x, player_y, player_radius, dx, dy, count)
    if count == nil then count = 1 end

    love.graphics.setColor(1, 1, 1, 1)

    local step = self._step
    for pair in values({
        { self._thickness + 1, rt.Palette.BLACK },
        { self._thickness, rt.Palette.WHITE }
    }) do
        local thickness, color = table.unpack(pair)

        love.graphics.setLineWidth(thickness)
        color:bind()

        for i = 1, count do

            local center_x = player_x + dx * (player_radius + self._half_height + (i - 1) * step)
            local center_y = player_y + dy * (player_radius + self._half_width + (i - 1) * step)

            local tip_x = center_x + dx * self._half_height
            local tip_y = center_y + dy * self._half_height

            local perpendicularx, perpendiculary = math.turn_left(dx, dy)

            local left_x = center_x - dx * self._half_height + perpendicularx * self._half_width
            local left_y = center_y - dy * self._half_height + perpendiculary * self._half_width

            local right_x = center_x - dx * self._half_height - perpendicularx * self._half_width
            local right_y = center_y - dy * self._half_height - perpendiculary * self._half_width

            love.graphics.circle("fill", left_x, left_y, 0.5 * thickness)
            love.graphics.circle("fill", right_x, right_y, 0.5 * thickness)

            love.graphics.line(
                left_x, left_y,
                tip_x, tip_y,
                right_x, right_y
            )
        end
    end

end