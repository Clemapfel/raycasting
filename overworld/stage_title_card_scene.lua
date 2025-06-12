--- @class ow.StageTitleCardScene
ow.StageTitleCardScene = meta.class("StageTitleCardScene", rt.Scene)

local _shader

--- @brief
function ow.StageTitleCardScene:instantiate(state)
    if _shader == nil then _shader = rt.Shader("overworld/stage_title_card_scene.glsl") end
    self._state = state
    self._player = state:get_player()

    self._is_stated = false
    self._fraction = 0
    self._elapsed = 0
    self._bounds = rt.AABB()
end

--- @brief
function ow.StageTitleCardScene:realize()
    if self:already_realized() then return end
end

--- @brief
function ow.StageTitleCardScene:size_allocate(x, y, width, height)
    self._bounds:reformat(x, y, width, height)
end

--- @brief
function ow.StageTitleCardScene:update(delta)
    self._elapsed = self._elapsed + delta
    self._fraction = (math.sin(self._elapsed) + 1) / 2
end

--- @brief
function ow.StageTitleCardScene:draw()
    rt.Palette.BLACK:bind()
    love.graphics.push()
    love.graphics.origin()
    _shader:bind()
    _shader:send("fraction", self._fraction)
    love.graphics.rectangle("fill", self._bounds:unpack())
    love.graphics.pop()
end

--- @brief
function ow.StageTitleCardScene:enter(stage_id)
    self._stage_id = stage_id
    self._is_started = true
end

--- @brief
function ow.StageTitleCardScene:exit()

end