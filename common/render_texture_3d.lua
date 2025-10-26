require "common.transform"

rt.settings.render_texture_3d = {
    near_plane = 10e-3,
    far_plane = 10e5
}

--- @class rt.RenderTexture3D
rt.RenderTexture3D = meta.class("3DCanvas", rt.Texture)

--- @class rt.ProjectionType3D
rt.ProjectionType3D = meta.enum("ProjectionType3D", {
    PERSPECTIVE = "perspective",
    ORTHOGRAPHIC = "orthographic"
})

--- @brief
function rt.RenderTexture3D:instantiate(width, height, msaa, format, is_compute, use_mipmaps)
    meta.assert(width, "Number", height, "Number")

    self._native = love.graphics.newCanvas(width, height, {
        msaa = msaa or 0,
        format = format,
        computewrite = is_compute or false,
        mipmaps = use_mipmaps and "auto" or "none"
    })

    self._fov = 0.5
    self._view = rt.Transform()
    self._model = rt.Transform()
    self._is_bound = false

    self._projection_type = rt.ProjectionType3D.PERSPECTIVE
    self:_update_projections()
end

--- @brief
function rt.RenderTexture3D:_update_projections()
    local near, far = rt.settings.render_texture_3d.near_plane, rt.settings.render_texture_3d.far_plane
    local width, height = self._native:getDimensions()

    self._projection_perspective = rt.Transform():as_perspective_projection(
        math.pi * self._fov,
        width / height,
        near, far
    )

    self._projection_orthographic = rt.Transform():as_orthographic_projection(
        width,
        height,
        near, far
    )
end



--- @brief
function rt.RenderTexture3D:get_projection_transform()
    if self._projection_type == rt.ProjectionType3D.ORTHOGRAPHIC then
        return self._projection_orthographic
    else
        return self._projection_perspective
    end
end

--- @brief
function rt.RenderTexture3D:_bind_transforms()
    local projection
    if self._projection_type == rt.ProjectionType3D.ORTHOGRAPHIC then
        projection = self._projection_orthographic
    elseif self._projection_type == rt.ProjectionType3D.PERSPECTIVE then
        projection = self._projection_perspective
    end

    local mvp = rt.Transform():apply(self._view):apply(self._model) -- sic, no projection
    love.graphics.setProjection(projection:get_native()) -- set here instead
    love.graphics.replaceTransform(mvp:get_native())
end

--- @brief
function rt.RenderTexture3D:set_projection_type(type)
    meta.assert_enum_value(type, rt.ProjectionType3D)
    self._projection_type = type
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.RenderTexture3D:set_view_transform(transform)
    meta.assert(transform, rt.Transform)
    self._view = transform
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.RenderTexture3D:reset_view_transform()
    self._view:reset()
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.RenderTexture3D:set_model_transform(transform)
    meta.assert(transform, rt.Transform)
    self._model = transform
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.RenderTexture3D:reset_model_transform()
    self._model:reset()
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.RenderTexture3D:bind()
    love.graphics.push("all")
    love.graphics.setCanvas({ self._native, depth = true, stencil = true })
    love.graphics.setFrontFaceWinding("cw")
    love.graphics.setDepthMode("less", true)

    self:_bind_transforms()

    self._is_bound = true
end

--- @brief
function rt.RenderTexture3D:unbind()
    self._is_bound = false
    love.graphics.pop()
end

--- @brief
function rt.RenderTexture3D:set_fov(fov)
    if self._fov ~= fov then
        local eps = 10e-3
        self._fov = math.clamp(fov, eps, 1 - eps)
        self:_update_projections()

        if self._is_bound then self:_bind_transforms() end
    end
end

--- @brief
function rt.RenderTexture3D:get_fov()
    return self._fov
end

--- @brief
function rt.RenderTexture3D:draw(...)
    love.graphics.draw(self._native, ...)
end
