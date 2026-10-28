require "common.label_sdf"
require "common.translation"
require "menu.menu_scene"

rt.settings.title_banner_scene = {

}

--- @class aux.TitleBannerScene
aux.TitleBannerScene = meta.class("TitleBannerScene", rt.Scene)

--- @brief
function aux.TitleBannerScene:reformat(x, y, width, height)
    self._sdf_label = rt.LabelSDF(
        rt.Translation.menu_scene.title_screen.title,
        180,
        rt.Font(rt.settings.menu_scene.title_screen.font_roman)
    )

    local label_w, label_h = self._sdf_label:measure()
    self._sdf_label:reformat(
        x + 0.5 * width - 0.5 * label_w,
        y + 0.5 * height - 0.5 * label_h,
        label_w, label_h
    )

    self._blob_mesh_radius = 0.25 * height
    self._blob_texture_padding = 20
    self._blob_texture = rt.RenderTexture(
        self._blob_mesh_radius + 2 * self._blob_texture_padding,
        self._blob_mesh_radius + 2 * self._blob_texture_padding
    );

    love.graphics.push("all")
    self._blob_texture:bind()
    love.graphics.clear()
    self._blob_texture_shader:bind()
    love.graphics.rectangle("fill", 0, 0, self._blob_texture:get_size())
    self._blob_texture_shader:unbind()
    love.graphics.pop()

    local create_blob_mesh = function(x_scale, y_scale)
        local cx, cy = 0, 0
        local data = {
            { cx, cy, 0.5, 0.5, 1, 1, 1, 1 }
        }

        local n_vertices = 64
        for i = 1, n_vertices do
            local angle = (i - 1) / n_vertices
            local px = math.cos(angle) * x_scale * self._blob_mesh_radius
            local py = math.sin(angle) * y_scale * self._blob_mesh_radius

            table.insert(data, {
                px, py, math.cos(angle), math.sin(angle), 1, 1, 1, 1
            })
        end

        local res = rt.Mesh(data, rt.MeshDrawMode.TRIANGLE_FAN)
        res:set_texture(self._blob_texture)
        return res
    end

    self._blobs = {}
    for blob_i = 1, 256 do
        local angle = rt.random.number(0, math.tau)
    end
end

--- @brief
function aux.TitleBannerScene:draw()
    self._sdf_label:draw()
end