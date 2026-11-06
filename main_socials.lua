require "include"
require "common.game_state"
require "common.scene_manager"

-- website header sdf textures
-- require("website.export_sdf")

local screenshot_mounted, video_mounted = false, false
DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == rt.KeyboardKey.M then
        local mount_point = "screenshots"
        if not screenshot_mounted then
            bd.mount_path(
            bd.join_path(bd.get_source_directory(), "website", "screenshots"), mount_point)
            screenshot_mounted = true
        end

        rt.SceneManager:screenshot(bd.join_path(mount_point, string.unique_timestamp() .. ".png"))
    elseif which == rt.KeyboardKey.N then
        local mount_point = "screen_recordings"
        if not video_mounted then bd.mount_path(
            bd.join_path(bd.get_source_directory(), "website", "screen_recordings"), mount_point)
            video_mounted = true
        end

        local recorder = rt.SceneManager:get_screen_recorder()
        if recorder:get_is_recording() then
            recorder:stop()
        else
            recorder:start(mount_point)
        end
    end
end)

-- title banner
love.load = function()
    rt.SceneManager:pop()
    rerequire "website.title_banner_scene"
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