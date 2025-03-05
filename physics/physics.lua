-- pixel scaling
B2_METER_TO_PIXEL = 100
B2_PIXEL_TO_METER = 1 / B2_METER_TO_PIXEL

--- @brief physics
b2 = {}

require "physics.math"
require "physics.circle"
require "physics.capsule"
require "physics.polygon"
require "physics.segment"
require "physics.shape"
require "physics.body"
require "physics.world"

return b2