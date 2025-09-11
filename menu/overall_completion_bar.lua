rt.settings.menu.overall_completion_bar = {
    coin_size = 16
}

--- @class mn.OverallCompletionBar
mn.OverallCompletionBar = meta.class("OverallCompletionBar", rt.Widget)

--- @brief
function mn.OverallCompletionBar:instantiate()
    local coin_radius = rt.settings.menu.overall_completion_bar.coin_size
    local particle_canvas_w = 2 * coin_radius * rt.get_pixel_scale() + 2 * 5
    self._particle_canvas = rt.RenderTexture(particle_canvas_w, particle_canvas_w)
end

--- @brief
function mn.OverallCompletionBar:size_allocate(x, y, width, height)

end

--- @brief
function mn.OverallCompletionBar:update(delta)

end

--- @brief
function mn.OverallCompletionBar:draw()
    --self:draw_bounds()
end