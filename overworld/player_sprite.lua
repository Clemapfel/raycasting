rt.settings.player_sprite = {
    texture = "assets/sprites/player_walking.png",
    n_columns = 6,
    n_rows = 8,
}

--- @class ow.PlayerSprite
ow.PlayerSprite = meta.class("PlayerSprite", rt.Drawable)

--- @brief
function ow.PlayerSprite:instantiate()
    meta.install(self, {
        _texture = rt.Texture(rt.settings.player_sprite.walking_texture),
        _quads = {}
    })

    local n_rows = rt.settings.player_sprite.n_rows
    local n_columns = rt.settings.player_sprite.n_columns
    local frame_w = self._texture:get_width() / n_columns
    local frame_h = self._texture:get_height() / n_rows
    for row_i = 1, n_rows do
        for col_i = 1, n_columns do
            table.insert()
        end
    end

end