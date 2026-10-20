require "include"
require "common.game_state"
require "common.scene_manager"
require "common.label_sdf"

require "overworld.normal_map"
require "menu.menu_scene"

bd.mount_path(bd.join_path(bd.get_source_directory(), "website"), "website")
local export_prefix = "website/game/public"
if not bd.is_directory(export_prefix) then bd.create_directory(export_prefix) end

local font_latin = rt.Font(rt.settings.menu_scene.title_screen.font_latin)
local font_japanese = rt.Font(rt.settings.menu_scene.title_screen.font_japanese)
local font_size = rt.FontSize.MAX

local last
local before = love.timer.getTime()
for x in range(
    { "HOME", "contact_en.png", font_latin },
    { "ABOUT", "about_en.png", font_latin },
    { "FAQ", "faq_en.png", font_latin },
    { "CONTACT", "home_en.png", font_latin },
    { "BLOG", "blog_en.png", font_latin },

    { "404", "404.png", font_latin }
) do
    local text, path, font = table.unpack(x)
    path = bd.join_path(export_prefix, path)
    last = rt.LabelSDF(
        text,
        font_size,
        font,
        nil,
        false -- fill center
    )

    last:export(path, rt.ImageEncodingFormat.PNG)
    rt.log("In main_sdf_export: exporting `", path, "` ...")
end

rt.log("Done. Took `", love.timer.getTime() - before, "`s")

love.draw = function()
    love.graphics.push()
    love.graphics.translate(last._padding, last._padding)
    last:draw()
    love.graphics.pop()
end

