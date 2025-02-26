ffi = require "ffi"

-- load box2d
box2d = ffi.load("box2d")
local cdef = love.filesystem.read("physics/box2d_cdef.h")
ffi.cdef(cdef)

-- load enkiTS
enkiTS = ffi.load("enkiTS")
cdef = love.filesystem.read("physics/enkits_cdef.h")
ffi.cdef(cdef)

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