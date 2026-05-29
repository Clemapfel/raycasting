require "menu.stage_grade_label"
require "common.timed_animation_sequence"

rt.settings.overworld.time_attack_start_countdown = {
    attack_duration = 0.25,
    decay_duration = 0.15,
    hold_duration = 1,
    font_id = "RubikSprayPaint",
    min_scale = 0.2,
    max_scale = 1
}

--- @class ow.TimeAttackStartCountdown
ow.TimeAttackStartCountdown = meta.class("TimeAttackStartCountdown", rt.Widget)
meta.add_signals(ow.TimeAttackStartCountdown,
    "done" -- countdown done
)

local _font = nil
local _shader_no_sdf = rt.Shader("menu/stage_grade_label.glsl", { MODE = 0 })
local _shader_sdf = rt.Shader("menu/stage_grade_label.glsl", { MODE = 1 })
local _lch_texture = rt.LCHTexture(1, 1, 256)

--- @brief
function ow.TimeAttackStartCountdown:instantiate(scene, stage)
    self._is_active = false
    self._was_done = false

    if _font == nil then
        local id = rt.settings.overworld.time_attack_start_countdown.font_id
        _font = rt.Font("assets/fonts/" .. id .. "/" .. id .. "-Regular.ttf")
    end

    self._ready_entry = nil -- cf. size_allocate
    self._set_entry = nil
    self._go_entry = nil

    local settings = rt.settings.overworld.time_attack_start_countdown
    local easings = rt.InterpolationFunctions
    local attack = settings.attack_duration
    local hold = settings.hold_duration
    local decay = settings.decay_duration
    local offset = attack + hold + decay

    local attack_easing = easings.LINEAR
    local decay_easing = easings.LINEAR
    local scale_easing = easings.EXPONENTIAL_ACCELERATION

    self._ready_opacity_animation = rt.AnimationChain(
        attack, 0, 1, attack_easing,
        hold, 1, 1, easings.CONSTANT,
        decay, 1, 0, decay_easing
    )

    self._ready_shimmer_animation = rt.AnimationChain(
        attack, 0, 0, easings.CONSTANT,
        hold, 0, 1, easings.LINEAR,
        decay, 1, 1, easings.CONSTANT
    )

    self._ready_scale_animation = rt.AnimationChain(
        attack, 0, 1, scale_easing,
        hold, 1, 1, easings.CONSTANT,
        decay, 1, 1, easings.CONSTANT
    )

    self._set_opacity_animation = rt.AnimationChain(
        offset, 0, 0, easings.CONSTANT_ZERO,

        attack, 0, 1, attack_easing,
        hold, 1, 1, easings.CONSTANT,
        decay, 1, 0, decay_easing
    )

    self._set_shimmer_animation = rt.AnimationChain(
        offset, 0, 0, easings.CONSTANT_ZERO,

        attack, 0, 0, easings.CONSTANT,
        hold, 0, 1, easings.LINEAR,
        decay, 1, 1, easings.CONSTANT
    )

    self._set_scale_animation = rt.AnimationChain(
        offset, 0, 0, easings.CONSTANT_ZERO,

        attack, 0, 1, scale_easing,
        hold, 1, 1, easings.CONSTANT,
        decay, 1, 1, easings.CONSTANT
    )

    self._go_opacity_animation = rt.AnimationChain(
        offset, 0, 0, easings.CONSTANT_ZERO,
        offset, 0, 0, easings.CONSTANT_ZERO,

        attack, 0, 1, attack_easing,
        hold, 1, 1, easings.CONSTANT,
        decay, 1, 0, decay_easing
    )

    self._go_shimmer_animation = rt.AnimationChain(
        offset, 0, 0, easings.CONSTANT_ZERO,
        offset, 0, 0, easings.CONSTANT_ZERO,

        attack, 0, 0, easings.CONSTANT,
        hold, 0, 1, easings.LINEAR,
        decay, 1, 1, easings.CONSTANT
    )

    self._go_scale_animation = rt.AnimationChain(
        offset, 0, 0, easings.CONSTANT_ZERO,
        offset, 0, 0, easings.CONSTANT_ZERO,

        attack, 0, 1, scale_easing,
        hold, 1, 1, easings.CONSTANT,
        decay, 1, 1, easings.CONSTANT
    )
end

--- @brief
function ow.TimeAttackStartCountdown:size_allocate(x, y, width, height)
    local new_entry = function(text, color, opacity_animation, shimmer_animation, scale_animation)
        local sdf_native = _font:get_native(rt.FontSize.ENORMOUS, rt.FontStyle.REGULAR, true)
        local sdf = love.graphics.newTextBatch(sdf_native, text)
        local sdf_width, sdf_height = sdf_native:getWidth(text), sdf_native:getHeight()

        local no_sdf_native = _font:get_native(rt.FontSize.ENORMOUS, rt.FontStyle.REGULAR, false)
        local no_sdf = love.graphics.newTextBatch(no_sdf_native, text)
        local no_sdf_width, no_sdf_height = no_sdf_native:getWidth(text), no_sdf_native:getHeight()

        return {
            sdf_label = sdf,
            sdf_x = x + 0.5 * width - 0.5 * sdf_width,
            sdf_y = y + 0.5 * height - 0.5 * sdf_height,
            sdf_width = sdf_width,
            sdf_height = sdf_height,

            no_sdf_label = no_sdf,
            no_sdf_x = x + 0.5 * width - 0.5 * no_sdf_width,
            no_sdf_y = y + 0.5 * height - 0.5 * no_sdf_height,
            no_sdf_width = no_sdf_width,
            no_sdf_height = no_sdf_height,

            color = color,
            opacity_animation = opacity_animation,
            shimmer_animation = shimmer_animation,
            scale_animation = scale_animation
        }
    end

    local translation = rt.Translation.time_attack_start_countdown

    self._ready_entry = new_entry(
        translation.ready,
        rt.Palette[rt.StageGrade.C],
        self._ready_opacity_animation,
        self._ready_shimmer_animation,
        self._ready_scale_animation
    )

    self._set_entry = new_entry(
        translation.set,
        rt.Palette[rt.StageGrade.B],
        self._set_opacity_animation,
        self._set_shimmer_animation,
        self._set_scale_animation
    )

    self._go_entry = new_entry(
        translation.go,
        rt.Palette[rt.StageGrade.A],
        self._go_opacity_animation,
        self._go_shimmer_animation,
        self._go_scale_animation
    )
end

--- @brief
function ow.TimeAttackStartCountdown:draw_bloom()

end

--- @brief
function ow.TimeAttackStartCountdown:update(delta)
    if not self._is_active then return end

    local is_done = true
    for entry in range(
        self._ready_entry,
        self._set_entry,
        self._go_entry
    ) do
        for animation in range(
            entry.opacity_animation,
            entry.shimmer_animation,
            entry.scale_animation
        ) do
            animation:update(delta)
            if animation:get_is_done() ~= true then
                is_done = false
            end
        end
    end

    if self._was_done == false and is_done == true then
        self:signal_emit("done")
    end

    self._was_done = is_done
end

--- @brief
function ow.TimeAttackStartCountdown:start()
    _shader_sdf:recompile() -- TODO
    _shader_no_sdf:recompile()

    for entry in range(
        self._ready_entry,
        self._set_entry,
        self._go_entry
    ) do
        for animation in range(
            entry.opacity_animation,
            entry.shimmer_animation,
            entry.scale_animation
        ) do
            animation:reset()
        end
    end

    self._is_active = true
end

--- @brief
function ow.TimeAttackStartCountdown:draw()
    if not self._is_active then return end

    love.graphics.setColor(1, 1, 1, 1)
    local elapsed_offset = 0
    local min_scale = rt.settings.overworld.time_attack_start_countdown.min_scale
    local max_scale = rt.settings.overworld.time_attack_start_countdown.max_scale
    local bounds = self:get_bounds()
    for entry in range(self._ready_entry, self._set_entry, self._go_entry) do
        local opacity = entry.opacity_animation:get_value()
        if opacity > 0 then
            local scale = math.mix(min_scale, max_scale, entry.scale_animation:get_value())

            love.graphics.push()
            local offset_x, offset_y = bounds.x - 0.5 * bounds.width, bounds.y - 0.5 * bounds.height
            love.graphics.translate(-offset_x, -offset_y)
            love.graphics.scale(scale)
            love.graphics.translate(offset_x, offset_y)

            _shader_sdf:bind()
            _shader_sdf:send("white", { rt.Palette.WHITE:unpack() })
            _shader_sdf:send("opacity", opacity)
            love.graphics.draw(entry.sdf_label,
                entry.sdf_x, entry.sdf_y)
            _shader_sdf:unbind()

            entry.color:bind()
            _shader_no_sdf:bind()
            _shader_no_sdf:send("opacity", opacity)
            _shader_no_sdf:send("elapsed", rt.SceneManager:get_elapsed() + elapsed_offset) -- prevent synching of shader
            _shader_no_sdf:send("use_highlight", true)
            _shader_no_sdf:send("use_rainbow", false)
            _shader_no_sdf:send("lch_texture", _lch_texture)
            _shader_no_sdf:send("fraction", entry.shimmer_animation:get_value())
            love.graphics.draw(entry.no_sdf_label, entry.no_sdf_x, entry.no_sdf_y)
            _shader_no_sdf:unbind()

            love.graphics.pop()

            elapsed_offset = elapsed_offset + 10
        end
    end
end

--- @brief
function ow.TimeAttackStartCountdown:get_is_active()
    return self._is_active
end