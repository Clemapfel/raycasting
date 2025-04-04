
--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world())
    })

    self._body:set_restitution(2)
    self._body:add_tag("slippery")
end

--- @brief
function ow.BouncePad:draw()
    self._body:draw()
end