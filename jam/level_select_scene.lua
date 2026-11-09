LevelSelectScene_t = "LevelSelectScene"

level_select_scene_new = function()
    level_select_scene_init(object_new(LevelSelectScene_t, {

    }))
end

level_select_scene_init = function(self)
    log_typecheck(self, LevelSelectScene_t)
end