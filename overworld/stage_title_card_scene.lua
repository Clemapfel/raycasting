require "common.translation"
require "common.game_state"
require "common.marching_squares"

rt.settings.overworld.stage_title_card_scene = {
    font_path = "assets/fonts/DejaVuSans/DejaVuSansCondensed-Bold.ttf"
}

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

    self._target_time_prefix_label = rt.Label(rt.Translation.stage_title_card_scene.target_time_prefix)
    self._target_time_colon_label = rt.Label(":")
    self._target_time_value_label = rt.Label("TODO")

    self._title_label = rt.Label("", rt.FontSize.HUGE, rt.Font(rt.settings.overworld.stage_title_card_scene.font_path))
    self._title_label:set_justify_mode(rt.JustifyMode.CENTER)
end

--- @brief
function ow.StageTitleCardScene:realize()
    if self:already_realized() then return end

    for widget in range(
        self._title_label,
        self._target_time_prefix_label,
        self._target_time_colon_label,
        self._target_time_value_label
    ) do
        widget:realize()
    end
end

--- @brief
function ow.StageTitleCardScene:size_allocate(x, y, width, height)
    self._bounds:reformat(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_m = 2 * m


    local padding = 3

    self._title_label:set_justify_mode(rt.JustifyMode.LEFT)
    self._title_label:reformat(
        padding, padding, width - 2 * outer_m, 0
    )
    local title_w, title_h = self._title_label:measure()
    if title_w > 0 then
        local canvas_w, canvas_h = title_w + 2 * padding, title_h + 2 * padding
        canvas_w = math.ceil(canvas_w / 4) * 4
        canvas_h = math.ceil(canvas_h / 4) * 4
        local canvas = rt.RenderTexture(
            canvas_w, canvas_h,
            0, rt.TextureFormat.R8F
        )
        canvas:bind()
        self._title_label:draw()
        canvas:unbind()
        self._title_canvas = canvas
        self._tris = rt.contour_from_canvas(canvas)
    end
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
    --love.graphics.rectangle("fill", self._bounds:unpack())
    _shader:unbind()
    love.graphics.pop()

    self._title_canvas:draw()
    love.graphics.setColor(1, 0, 1, 1)
    for tri in values(self._tris) do
        love.graphics.polygon("fill", tri)
    end
    love.graphics.points(self._tris)
    self._target_time_prefix_label:draw()
    self._target_time_colon_label:draw()
    self._target_time_value_label:draw()
end

--- @brief
function ow.StageTitleCardScene:enter(stage_id)
    meta.assert(stage_id, "String")
    self._stage_id = stage_id
    self._is_started = true

    local stage_title = rt.GameState:get_stage_title(stage_id)
    local time_to_beat = string.format_time(rt.GameState:get_stage_target_time(stage_id))

    self._title_label:set_text(
        rt.Translation.stage_title_card_scene.stage_index_to_title_prefix(rt.GameState:get_stage_index(stage_id)) .. "\n" ..
        stage_title
    )
    self._target_time_value_label:set_text(time_to_beat)

    self:reformat()
end

--- @brief
function ow.StageTitleCardScene:exit()

end