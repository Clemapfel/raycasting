local _current_sound_handler = 1

SoundID_t = String_t
SoundHandler_t = Number_t

SoundID = {
    menu_up = "TODO",
    menu_down = "TODO",
    menu_accept = "TODO",
    menu_back = "TODO",
    menu_swipe_left = "TODO",
    menu_swipe_right = "TODO"
}

audio_play_sound = function(self, sound_id, to_stop)
    log_typecheck(self, Table_t, sound_id, SoundID_t)
    if to_stop ~= nil then log_typecheck_arg_i(to_stop, SoundHandler_t, 3) end

    local handler = _current_sound_handler
    _current_sound_handler = _current_sound_handler + 1

    if to_stop ~= nil then
        audio_stop_sound(self, to_stop)
    end

    return handler
end

audio_replay_sound = function(self, sound_id)
    log_typecheck(self, Table_t, sound_id, SoundID_t)

    if self.sound_handlers == nil then self.sound_handlers = {} end
    self.sound_handlers[sound_id] = audio_play_sound(self, sound_id, self.sound_handlers[sound_id])
end

audio_stop_sound = function(self, handler_id)
    log_typecheck(self, Table_t, handler_id, SoundHandler_t)


end

