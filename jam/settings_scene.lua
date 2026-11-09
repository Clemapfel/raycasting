SettingsScene_t = "SettingsScene"

settings_scene_new = function()
    settings_scene_init(object_new(SettingsScene_t, {

    }))
end

settings_scene_init = function(self)
    log_typecheck(self, SettingsScene_t)
end