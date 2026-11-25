require "include"
require "common.error_handler"

if _G.PROFILE then
    profiler = require "common.profiler"
end

if _G.DEBUG then
    debugger = require "common.debugger"
end

require "common.scene_manager"
require "common.log"
require "common.profiler"

love.load = function(args)
    bd.load("website/export_sdf.lua", false)
end