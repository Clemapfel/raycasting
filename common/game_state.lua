rt.settings.game_state = {
    save_file = "debug_save.lua",

}

--- @brief rt.GameState
rt.GameState = meta.class("GameState")

--- @brief
function rt.GameState:instantiate()
    self._levels = {}

end

--- @brief
function rt.GameState:list_level_ids()

end


rt.GameState = rt.GameState()