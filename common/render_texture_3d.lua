--- @class rt.RenderTexture3D
rt.RenderTexture3D = meta.class("3DCanvas")

--- @brief
function rt.RenderTexture3D:instantiate(width, height, msaa, format)
    self._native = love.graphics.newCanvas(width, height, {
        msaa = msaa or 0,
        format = format
    })
end

--- @brief
function rt.RenderTexture3D:bind()
    love.graphics.push("all")
    love.graphics.setCanvas({ self._native, depth = true, stencil = true })
    love.graphics.setMeshCullMode("back")
    love.graphics.setFrontFaceWinding("ccw")
    love.graphics.setDepthMode("less", true)
end

--- @brief
function rt.RenderTexture3D:unbind()
    love.graphics.pop()
end

--- @brief
function rt.RenderTexture3D:draw()
    love.graphics.draw(self._native)
end

--- @brief
function rt.RenderTexture3D:get_size()
    return self._native:getDimensions()
end

--- @brief
function rt.RenderTexture3D:get_width()
    return self._native:getWidth()
end

--- @brief
function rt.RenderTexture3D:get_height()
    return self._native:getHeight()
end

--- @brief
function rt.RenderTexture3D:draw(...)
    love.graphics.draw(self._native, ...)
end
