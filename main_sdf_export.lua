require "include"
require "common.game_state"
require "common.scene_manager"
require "common.label_sdf"

require "overworld.normal_map"
require "menu.menu_scene"

bd.mount_path(bd.join_path(bd.get_source_directory(), "website"), "website")
local export_prefix = "website/export"
if not bd.is_directory(export_prefix) then bd.create_directory(export_prefix) end

local font = rt.Font(rt.settings.menu_scene.title_screen.font)
local font_size = rt.FontSize.MAX

local last
local before = love.timer.getTime()
for string_filename in range(
    { "Contact", "contact_sdf.png" },
    { "Why", "home_sdf.png" }
) do
    local path = bd.join_path(export_prefix, string_filename[2])
    last = rt.LabelSDF(
        string_filename[1],
        font_size,
        font
    )

    last:export(path)
    rt.log("In main_sdf_export: exporting `", path, "` ...")
end

rt.log("Done. Took `", love.timer.getTime() - before, "`s")

love.draw = function()
    love.graphics.push()
    love.graphics.translate(last._padding, last._padding)
    last:draw()
    love.graphics.pop()
end

