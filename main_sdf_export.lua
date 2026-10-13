require "include"
require "common.game_state"
require "common.scene_manager"
require "website.export_sdf"

local instance = rt.ExportSDF("<wave>鬱殺 ono wats dis</wave>", rt.settings.font.default, rt.FontSize.ENORMOUS)

love.update = function(delta)
    instance:update(delta)
end

love.draw = function()
    instance:draw()
end