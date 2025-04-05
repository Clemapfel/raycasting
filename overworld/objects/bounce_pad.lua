
--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world())
    })

    self._body:set_restitution(0) -- handled in player update
    self._body:add_tag("unjumpable")
    self._body:add_tag("bouncy")
end

--- @brief
function ow.BouncePad:draw()
    rt.Palette.PINK:bind()
    self._body:draw()
end