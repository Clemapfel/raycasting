require "common.widget"
require "common.label"
require "common.input_subscriber"

--- @class mn.MainMenuScene
mn.MainMenuScene = meta.class("MainMenuScene", rt.Scene)

--- @brief
function mn.MainMenuScene:instantiate()
    meta.install(self, {
        _label = rt.Label("<wave> TEST </wave>", rt.settings.font.default_huge),
        _input = rt.InputSubscriber()
    })
end

--- @see Scene.realize
function mn.MainMenuScene:realize()
    self._label:realize()
end

--- @see Scene.size_allocate
function mn.MainMenuScene:size_allocate(x, y, width, height)
    local label_w, label_h = self._label:measure()
    self._label:reformat(
        0.5 * width - 0.5 * label_w,
        0.5 * height - 0.5 * label_h,
        math.huge,
        height
    )
end

--- @see Scene.update
function mn.MainMenuScene:update(delta)
    self._label:update(delta)
end

--- @see Scene.draw
function mn.MainMenuScene:draw()
    self._label:draw()
end

--- @see Scene.enter
function mn.MainMenuScene:enter()
    -- noop
end

--- @see Scene.exit
function mn.MainMenuScene:exit()
    -- noop
end



