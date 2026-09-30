rt.settings.social_media_banner_generator = {
    shader_path = "socials/social_media_banner_generator.glsl",
    texture_format = rt.TextureFormat.RGBA8,
    export_path = "socials/export",
    export_format = "png",
    export_postfix = "_banner"
}

local _1500x500 = function(name) return { 1500, 500, name } end -- banner resolution xy, export name
local _2560x1440 = function(name) return { 2560, 1440, name } end

--- @enum rt.SocialMediaPlatform
rt.SocialMediaPlatform = meta.enum("SocialMediaPlatform", {
    YOUTUBE = _2560x1440("youtube"),
    TWITTER = _1500x500("twitter"),
    BLUESKY = _1500x500("bluesky"),
    MASTODON = _1500x500("mastodon")
})

--- @class rt.SocialMediaBannerGenerator
rt.SocialMediaBannerGenerator = meta.class("SocialMediaBannerGenerator", rt.Widget)

local group_x, group_y = 16, 16

--- @brief
function rt.SocialMediaBannerGenerator:instantiate(platform)
    meta.assert(platform, rt.SocialMediaPlatform)

    self._resolution_x, self._resolution_y, self._export_name = table.unpack(platform)
    self._elapsed = 0

    local postfix = rt.settings.social_media_banner_generator.export_postfix
    if meta.is_string(postfix) then
        self._export_name = self._export_name .. postfix
    end

    self._texture = rt.RenderTexture(self._resolution_x, self._resolution_y, {
        format = rt.settings.social_media_banner_generator.texture_format,
        is_compute = true,
        use_mipmaps = false
    })
    self._texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

    self._mesh = nil -- rt.Mesh

    self:regenerate()
end

--- @brief
function rt.SocialMediaBannerGenerator:regenerate()
    local settings = rt.settings.social_media_banner_generator
    local success, shader_or_error = pcall(function()
        local a = love.timer.getTime()
        local shader = rt.ComputeShader(settings.shader_path, {
            TEXTURE_FORMAT = settings.texture_format,
            WORK_GROUP_SIZE_X = 16,
            WORK_GROUP_SIZE_Y = 16
        })

        local b = love.timer.getTime()
        shader:send("texture", self._texture)
        shader:dispatch(
            math.ceil(self._resolution_x / group_x),
            math.ceil(self._resolution_y / group_y)
        )
        local c = love.timer.getTime()



        return shader
    end)

    if success then
        self._shader = shader_or_error
        self._elapsed = 0
    else
        rt.critical("In rt.SocialmediaBannerGenerator.regenerate: ", shader_or_error)
    end
end

--- @brief
function rt.SocialMediaBannerGenerator:size_allocate(x, y, w, h)
    self._mesh = rt.MeshRectangle(x, y, w, h)
    self._mesh:set_texture(self._texture)
end

--- @brief
function rt.SocialMediaBannerGenerator:update(delta)
    self._elapsed = self._elapsed + delta
    if self._shader ~= nil then
        self._shader:send("elapsed", self._elapsed)
        self._shader:dispatch(
            math.ceil(self._resolution_x / group_x),
            math.ceil(self._resolution_y / group_y)
        )
    end
end

--- @brief
function rt.SocialMediaBannerGenerator:draw()
    if self._mesh == nil then self:reformat(0, 0, love.graphics.getDimensions()) end

    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
end

--- @brief
function rt.SocialMediaBannerGenerator:export()
    local settings = rt.settings.social_media_banner_generator
    bd.mount_path(bd.normalize_path(
        bd.get_source_directory() .. "/" .. settings.export_path
    ), settings.export_path)

    local export_name = bd.normalize_path(settings.export_path
        .. "/"
        .. self._export_name
        .. "."
        .. settings.export_format
    )

    love.graphics.readbackTexture(self._texture:get_native()):encode(settings.export_format, export_name)
    rt.log("In rt.SocialMediaBannerGenerator: wrote to `", export_name, "`")
end