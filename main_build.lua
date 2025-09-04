require "include"
require "build.build"
love.filesystem.setSymlinksEnabled(true)
bd.build(false)
exit(0)