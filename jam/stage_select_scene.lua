StageSelectScene_t = "StageSelectScene"

stage_select_scene_new = function()
    return stage_select_scene_init(object_new(StageSelectScene_t, {
        stages = state_get_stage_list()
    }))
end

stage_select_scene_init = function(self)
    log_typecheck(self, StageSelectScene_t)

    self.entries = {}
    for i = 1, stage_list_get_n_stages() do

    end


    self.selected_entry_i = 1

    stage_select_scene_reformat(self, graphics_get_size())

    return self
end

stage_select_scene_reformat = function(self)


end