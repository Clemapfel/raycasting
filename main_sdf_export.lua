require "include"
require "common.game_state"
require "common.scene_manager"
require "common.label_sdf"

require "overworld.normal_map"
require "menu.menu_scene"

bd.mount_path(bd.join_path(bd.get_source_directory(), "website"), "website")
local export_prefix = "website/game/public"
if not bd.is_directory(export_prefix) then bd.create_directory(export_prefix) end

local font_roman = rt.Font(rt.settings.menu_scene.title_screen.font_roman)
local font_japanese = rt.Font(rt.settings.menu_scene.title_screen.font_japanese)
local font_size = rt.FontSize.MAX

local last
local before = love.timer.getTime()
for x in range(
    { "Home", "contact.png", font_japanese },
    { "Contact", "home.png", font_japanese },
    { "404", "404.png", font_japanese }
) do
    local text, path, font = table.unpack(x)
    path = bd.join_path(export_prefix, path)
    last = rt.LabelSDF(
        text,
        font_size,
        font,
        nil,
        true
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

