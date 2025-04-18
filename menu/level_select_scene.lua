require "common.scene"
require "common.input_subscriber"
require "common.game_state"
require "overworld.stage_config"

--- @class mn.LevelSelectScene
mn.LevelSelectScene = meta.class("LevelSelectScene")

--[[
Level Properties:
    Name
    Best Time Any%
    Best Time 100%
    coins total


]]--

--- @brief
function mn.LevelSelectScene:instantiate(state)
    meta.assert(state, rt.GameState)
    meta.install(self, {
        _elements = {},
        _state = state
    })

    self:_create_from(state)
end

--- @brief
function mn.LevelSelectScene:_create_from(state)

end

--- @brief
function mn.LevelSelectScene:size_allocate(x, y, width, height)

end

