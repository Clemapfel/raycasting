require "common.widget"
require "common.label"
require "common.input_subscriber"
require "common.shader"
require "common.input_mapping"
require "common.background"
require "common.mesh"

--- @class mn.MainMenuScene
mn.MainMenuScene = meta.class("MainMenuScene", rt.Scene)

--- @brief
function mn.MainMenuScene:instantiate()
    meta.install(self, {
        _label = rt.Label("<o><wave> TEST </wave></o>", rt.settings.font.default_huge),
        _input = rt.InputSubscriber(),
        _background = rt.Background("menu/main_menu_scene.glsl")
    })

    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.A then
            self._background:recompile()

            for name_color in range(
                {"a", rt.Palette.PINK_4},
                {"b", rt.Palette.PINK_5},
                {"c", rt.Palette.MINT_4},
                {"d", rt.Palette.MINT_3},
                {"e", rt.Palette.MINT_1}
            ) do
                local name, color = table.unpack(name_color)
                local r, g, b, a = rt.color_unpack(color)
                self._background:send("color_" .. name, { r, g, b })
            end
        end
    end)
end

--- @see Scene.realize
function mn.MainMenuScene:realize()
    self._label:realize()
    self._background:realize()
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

    self._background:reformat(x, y, width, height)
end

--- @see Scene.update
function mn.MainMenuScene:update(delta)
    self._label:update(delta)

    if love.keyboard.isDown("space") then
        self._background:update(delta)
    end
end

--- @see Scene.draw
function mn.MainMenuScene:draw()
    self._background:draw()
    --self._label:draw()
end

--- @see Scene.enter
function mn.MainMenuScene:enter()
    -- noop
end

--- @see Scene.exit
function mn.MainMenuScene:exit()
    -- noop
end



