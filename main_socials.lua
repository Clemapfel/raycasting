require "include"
require "common.game_state"
require "common.scene_manager"

-- website header sdf textures
-- require("website.export_sdf")

-- title banner
love.load = function()
    require "website.title_banner_scene"
    rt.SceneManager:push(aux.TitleBannerScene)
end

love.draw = function()
    rt.SceneManager:draw()
end

love.update = function(delta)
    rt.SceneManager:update(delta)
end

love.resize = function(width, height)
    rt.SceneManager:resize()
end