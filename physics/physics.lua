slick = require "physics.slick.slick"
b2 = {}

--- @param self b2.Body
--- @param other b2.Body
b2._default_filter = function(self, other, self_shape, other_shape)
    return true
end

require("physics.world")
require("physics.shapes")
require("physics.body")
require("physics.spring")