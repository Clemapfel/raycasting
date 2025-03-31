local IS_PLATFORMER = true
if not IS_PLATFORMER then
    require("overworld.player_top_down")
else
    require("overworld.player_platform")
end