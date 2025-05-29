require "common.scene"
require "common.input_subscriber"
require "common.frame"
require "common.game_state"

--- @class mn.SettingsScene
mn.SettingsScene = meta.class("MenuSettingsScene", rt.Scene)

--[[
full screen: on off
    description

vsync: adaptive, off, on
    description

msaa: off, good, better, best
    description
   widget

music level: scale
    description

sound effect leve: scale
    description

dead zone: scale
    description
    widget

textspeed: scale
    description
    widget
]]

--- @brief
function mn.SettingsScene:instantiate()
    self._items = {}
    self._selected_item_i = 1
    self._n_items = 0

    local prefix_prefix = "<b>"
    local prefix_postfix = "</b>"

    function add_option_button(prefix, default_value, ...)
        local item = {
            prefix = rt.Label(prefix_prefix .. prefix .. prefix_postfix),
            frame = rt.Frame(),
            widget = mn.OptionButton(...)
        }

        table.insert(self._items, item)
        self._n_items = self._n_items + 1
        return item
    end

    function add_scale(prefix, default_value, lower, upper, step)
        local item = {
            prefix = rt.Label(prefix_prefix .. prefix .. prefix_postfix),
            frame = rt.Frame(),
            widget = mn.Scale(lower, upper, step)
        }

        table.insert(self._items, item)
        self._n_items = self._n_items + 1
        return item
    end

    local translation = rt.Translation.settings_scene

    -- vsync
    local vsync_to_label = {
        [rt.VSyncMode.ADAPTIVE] = translation.vsync_adaptive,
        [rt.VSyncMode.OFF] = translation.vsync_off,
        [rt.VSyncMode.ON] = translation.vsync_on
    }

    add_option_button(
        translation.vsync_prefix,
        vsync_to_label[rt.GameState:get_vsync_mode()],

    )
end