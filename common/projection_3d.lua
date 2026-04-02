require "common.transform"

rt.settings.render_texture_3d = {
    near_plane = 10e-3,
    far_plane = 10e5
}

--- @class rt.Projection3D
rt.Projection3D = meta.class("Projection3D")

--- @enum rt.ProjectionType
rt.ProjectionType = meta.enum("ProjectionType", {
    PERSPECTIVE = "perspective",
    ORTHOGRAPHIC = "orthographic"
})

--- @brief
function rt.Projection3D:instantiate()
    self._fov = 0.5
    self._view = rt.Transform()
    self._model = rt.Transform()
    self._is_bound = false

    self._projection_type = rt.ProjectionType.PERSPECTIVE
    self:_update_projections()
end

--- @brief
function rt.Projection3D:_update_projections()
    local near, far = rt.settings.render_texture_3d.near_plane, rt.settings.render_texture_3d.far_plane
    local width, height = love.graphics.getDimensions()

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
function rt.Projection3D:get_projection_transform()
    if self._projection_type == rt.ProjectionType.ORTHOGRAPHIC then
        return self._projection_orthographic
    else
        return self._projection_perspective
    end
end

--- @brief
function rt.Projection3D:_bind_transforms()
    local projection
    if self._projection_type == rt.ProjectionType.ORTHOGRAPHIC then
        projection = self._projection_orthographic
    elseif self._projection_type == rt.ProjectionType.PERSPECTIVE then
        projection = self._projection_perspective
    end

    love.graphics.replaceTransform(self:get_transform():get_native()) -- has no projection
    love.graphics.setProjection(projection:get_native()) -- set here instead
end

--- @brief
function rt.Projection3D:get_transform()
    return rt.Transform():apply(self._view):apply(self._model)
end

--- @brief
function rt.Projection3D:set_projection_type(type)
    meta.assert_enum_value(type, rt.ProjectionType)
    self._projection_type = type
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.Projection3D:set_view_transform(transform)
    meta.assert(transform, rt.Transform)
    self._view = transform
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.Projection3D:reset_view_transform()
    self._view:reset()
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.Projection3D:set_model_transform(transform)
    meta.assert(transform, rt.Transform)
    self._model = transform
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.Projection3D:reset_model_transform()
    self._model:reset()
    if self._is_bound then self:_bind_transforms() end
end

--- @brief
function rt.Projection3D:bind()
    love.graphics.push("all")
    love.graphics.setFrontFaceWinding("cw")
    love.graphics.setDepthMode("less", true)

    self:_bind_transforms()
    self._is_bound = true
end

--- @brief
function rt.Projection3D:unbind()
    self._is_bound = false
    love.graphics.pop()
end

--- @brief
function rt.Projection3D:set_fov(fov)
    if self._fov ~= fov then
        local eps = 10e-3
        self._fov = math.clamp(fov, eps, 1 - eps)
        self:_update_projections()

        if self._is_bound then self:_bind_transforms() end
    end
end

--- @brief
function rt.Projection3D:get_fov()
    return self._fov
end
