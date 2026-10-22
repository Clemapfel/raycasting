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

local label_to_path = {}
local max_w, max_h = -math.huge, -math.huge

for x in range(
    { "HOME", "home.png", font_latin },
    { "ABOUT", "about.png", font_latin },
    { "FAQ", "faq.png", font_latin },
    { "CONTACT", "contact.png", font_latin },
    { "BLOG", "blog.png", font_latin },
    { "404", "404.png", font_latin }
) do
    local text, path, font = table.unpack(x)
    path = bd.join_path(export_prefix, path)
    local label = rt.LabelSDF(
        text,
        font_size,
        font,
        nil
    )

    local w, h = label:measure()
    max_w = math.max(w, max_w)
    max_h = math.max(h, max_h)
    label_to_path[label] = path
end

for label, path in pairs(label_to_path) do
    local w, h = label:measure()
    label:reformat(0, 0, w, max_h)
    label:export(path, rt.ImageEncodingFormat.PNG)
    rt.log("In main_sdf_export: exporting `", path, "` ...")
    last = label
end

rt.log("Done. Took `", love.timer.getTime() - before, "`s")

love.draw = function()
    love.graphics.push()
    love.graphics.translate(last._padding_x, last._padding_y)
    last:draw()
    love.graphics.pop()
end

