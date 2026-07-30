
require "include"
require "common.error_handler"
require "build.config"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"
require "common.routine"

ffi = require "ffi"

-- ### CONFIG ###

-- usage mode, decides which LÖVE 12.0 method to use for representing the instance date
local BUFFER_MODE_USE_VERTEX_BUFFER = "vertexbuffer"
local BUFFER_MODE_USE_TEXEL_BUFFER = "texelbuffer"
local BUFFER_MODE_USE_STORAGE_BUFFER = "storagebuffer"
local BUFFER_MODE = BUFFER_MODE_USE_TEXEL_BUFFER

-- upload mode, decides whether to use lua tables, `ByteData` or ffi data to upload the instance data
local DATA_MODE_USE_TABLES = "table"
local DATA_MODE_USE_BYTE_DATA = "bytedata"
local DATA_MODE_USE_FFI_DATA = "ffi"
local DATA_MODE = DATA_MODE_USE_BYTE_DATA

-- ### GLOBALS ###

local drawMeshFormat -- table, vertex attribute format of mesh that will be drawn
local drawMesh -- love.Mesh, actual mesh that will be the shape of the particles
local drawShader -- love.Shader, custom shader that retrieves the per-instance data

local instanceCount = 2000 -- number of draw instances
local perInstanceFormat -- table, vertex attribute format of data mesh
local perInstanceData -- table of `love.ByteData`, CPU-side copy of per-instance data
local perInstanceDataBuffer -- `love.GraphicsBuffer`, GPU-side copy of per-instance data

--- ### INITIALIZATION ###

local generateIsVisible, generateOffset, generateScale
local modifyIsVisible, modifyOffset, modifyScale
love.load = function()

    -- (x.0) declare vertex attribute format of draw mesh
    drawMeshFormat = {
        { -- instance mesh attribute #1: position
            location = 0,            -- attribute #1 (0-based)
            name = "VertexPosition", -- name
            format = "floatvec2"     -- glsl format: vec2 (2 components)
        },

        { -- instance mesh attribute #2: texture coordinates
            location = 1,            -- attribute #2 (0-based)
            name = "VertexTextureCoordinates",
            format = "floatvec2"     -- glsl format: vec2 (2 components)
        },

        { -- instance mesh attribute #2: texture coordinates
            location = 2,            -- attribute #3 (0-based)
            name = "VertexColor",
            format = "floatvec4"     -- glsl format: vec4 (2 components)
        },
    }

    -- (x.1) declare format of data buffer

    do
        if BUFFER_MODE == BUFFER_MODE_USE_VERTEX_BUFFER then
            -- if using mesh as a buffer, location needs to be appended to locations of drawMeshFormat
            perInstanceFormat = {
                {
                    location = 3,
                    name = "InstanceIsVisible",
                    format = "uint16"
                },

                {
                    location = 4,
                    name = "InstanceOffset",
                    format = "floatvec2"
                },

                {
                    location = 5,
                    name = "InstanceScale",
                    format = "float"
                }
            }
        elseif BUFFER_MODE == BUFFER_MODE_USE_STORAGE_BUFFER then
            -- if using storage buffer, locations start at 0
            perInstanceFormat = {
                {
                    location = 0,
                    name = "InstanceIsVisible",
                    format = "uint16"
                },

                {
                    location = 1,
                    name = "InstanceOffset",
                    format = "floatvec2"
                },

                {
                    location = 2,
                    name = "InstanceScale",
                    format = "float"
                }
            }
        elseif BUFFER_MODE == BUFFER_MODE_USE_TEXEL_BUFFER then
            -- if using texel buffer, all components need to have the same format
            local format = "float"
            perInstanceFormat = {
                {
                    location = 0,
                    name = "InstanceIsVisible",
                    format = "floatvec4"
                }
            }
        end
    end

    -- (x.1) initialize draw mesh as circle
    do
        local nVertices = 16
        local drawMeshData = {}
        for i = 1, nVertices + 1 do
            local angle = (i - 1) / nVertices * (2 * math.pi)
            table.insert(drawMeshData, {
                math.cos(angle), -- Attribute #1: VertexPosition.x (x)
                math.sin(angle), -- Attribute #1: VertexPosition.y (y)
                math.cos(angle), -- Attribute #2: VertexTextureCoordinates.x (u)
                math.sin(angle), -- Attribute #2: VertexTextureCoordinates.y (v)
                1, -- Attribute #3: VertexColor.x (r)
                1, -- Attribute #3: VertexColor.y (g)
                1, -- Attribute #3: VertexColor.z (b)
                1, -- Attribute #3: VertexColor.w (a)
            })
        end
        table.insert(drawMeshData, 1,  { 0, 0, 0, 0, 1, 1, 1, 1 }) -- add center vertex

        drawMesh = love.graphics.newMesh(
            drawMeshFormat, -- vertex attribute format
            drawMeshData,   -- vertex data
            "fan",   -- draw mode
            "static" -- buffer usage
        )

        -- we use draw mode `fan` to correctly draw a filled circle
        -- we use buffer usage `static`, since `drawMesh` will never change, only the per-instance data will
    end

    -- (x.2) initialize the data buffer with per instance data

    perInstanceData = {}
    for instanceIndex = 1, instanceCount do
        local isVisible = generateIsVisible(instanceIndex) -- 1 uint16
        local x, y = generateOffset(instanceIndex) -- 2 floats
        local scale = generateScale(instanceIndex) -- 1 float
        table.insert(perInstanceData, {
            isVisible,
            x, y,
            scale
        })
    end

    if DATA_MODE == DATA_MODE_USE_TABLES then
        -- noop, keep `perInstanceData` as a table

    elseif DATA_MODE == DATA_MODE_USE_BYTE_DATA then
        -- instance size is `InstanceisVisible` + `InstanceOffset` + `InstanceScale`
        local perInstanceSize
        if BUFFER_MODE == BUFFER_MODE_USE_TEXEL_BUFFER  then
            perInstanceSize = ffi.sizeof("float") + 2 * ffi.sizeof("float") + ffi.sizeof("float")
        else
            perInstanceSize = ffi.sizeof("uint16_t") + 2 * ffi.sizeof("float") + ffi.sizeof("float")
        end

        -- data size is (number of instances) * (size per instance)
        perInstanceData = love.data.newByteData(instanceCount * perInstanceSize)

    elseif DATA_MODE == DATA_MODE_USE_FFI_DATA then
        -- we need to allocate as `love.ByteData` anyway, even though we use ffi to modify it later
        local perInstanceSize
        if BUFFER_MODE == BUFFER_MODE_USE_TEXEL_BUFFER  then
            perInstanceSize = ffi.sizeof("float") + 2 * ffi.sizeof("float") + ffi.sizeof("float")
        else
            perInstanceSize = ffi.sizeof("uint16_t") + 2 * ffi.sizeof("float") + ffi.sizeof("float")
        end

        perInstanceData = love.data.newByteData(instanceCount * perInstanceSize)
    end

    -- (x.3) initialize the graphics buffer

    if BUFFER_MODE == BUFFER_MODE_USE_VERTEX_BUFFER then
        -- usage mesh as storage buffer
        local perInstanceDataMesh = love.graphics.newMesh(
            perInstanceFormat,
            perInstanceData,
            "points", -- draw mode unused
            "stream"
        )

        -- attach the mesh to the draw mesh
        for _, entry in pairs(perInstanceFormat) do
            drawMesh:attachAttribute(entry.name, perInstanceDataMesh, "perinstance")
        end

        -- convert mesh to a buffer for love.update
        perInstanceDataBuffer = perInstanceDataMesh:getVertexBuffer()
    elseif BUFFER_MODE == BUFFER_MODE_USE_STORAGE_BUFFER then
        -- allocate the buffer directly
        perInstanceDataBuffer = love.graphics.newBuffer(
            perInstanceFormat, -- buffer format
            perInstanceData,    -- initial buffer data
            { shaderstorage = true } -- declare as storage buffer
        )
    elseif BUFFER_MODE == BUFFER_MODE_USE_TEXEL_BUFFER then
        perInstanceDataBuffer = love.graphics.newBuffer(
            perInstanceFormat,
            perInstanceData,
            { texel = true } -- declare as texel buffer
        )
    end

    -- (x.4) initialize the shader

    if BUFFER_MODE == BUFFER_MODE_USE_VERTEX_BUFFER then
        drawShader = love.graphics.newShader("temp.glsl")
    elseif BUFFER_MODE == BUFFER_MODE_USE_STORAGE_BUFFER then
        drawShader = love.graphics.newShader("temp_storage.glsl")
    elseif BUFFER_MODE == BUFFER_MODE_USE_TEXEL_BUFFER then
        drawShader = love.graphics.newShader("temp_texel.glsl")
    end
end -- love.load

-- (x.1) draw loop
love.draw = function()
    love.graphics.clear()

    -- store graphics state, including shader, color, etc.
    love.graphics.push("all")

    -- bind shader
    love.graphics.setShader(drawShader)

    -- assign the draw mesh texture if present
    if drawMesh:getTexture() ~= nil then
        drawShader:send("drawTexture", drawMesh:getTexture())
    end

    -- assign the storage / texel buffer if present
    if drawShader:hasUniform("perInstanceDataBuffer") then
        drawShader:send("perInstanceDataBuffer", perInstanceDataBuffer)
    end

    -- set color / transform
    love.graphics.setColor(1, 1, 1, 1)

    -- draw `instanceCount` many copies of the mesh instanced
    -- each instance will read the correct data using the vertex shader
    love.graphics.drawInstanced(drawMesh, instanceCount)

    -- unbind shader, etc.
    love.graphics.pop() -- all
end

-- (x.2) update loop

love.update = function()
    -- modify the per-instance data

    if DATA_MODE == DATA_MODE_USE_TABLES then
        -- `perInstanceData` is a simple table, modify it using regular lua

        local isVisible = 1 -- per-instance attribute #3 component #1: InstanceIsVisible (uint16)
        local offsetX = 2   -- per-instance #1 component #1: InstanceOffset.x
        local offsetY = 3   -- per-instance #1 component #2: InstanceOffset.y
        local scale = 4     -- per-instane attribute #2 component #1: InstanceScale.x (float

        for instanceIndex = 1, instanceCount do
            -- extract per-instance data
            local instanceData = perInstanceData[instanceIndex]

            -- write new per-instance attributes to CPU-side copy of instance data
            instanceData[offsetX], instanceData[offsetY] = modifyOffset(instanceIndex,
                instanceData[offsetX],
                instanceData[offsetY]
            )

            instanceData[scale] = modifyScale(instanceIndex,
                instanceData[scale]
            )

            instanceData[isVisible] = modifyIsVisible(instanceIndex,
                instanceData[isVisible]
            )
        end
    elseif DATA_MODE == DATA_MODE_USE_BYTE_DATA then
        -- `perInstanceData` is a `love.ByteDatA`, use `set*` / `get*`

        -- get the size of one instance data element, in bytes
        local stride = perInstanceDataBuffer:getElementStride()

        local isVisibleType
        if BUFFER_MODE == BUFFER_MODE_USE_TEXEL_BUFFER then
            isVisibleType = "float"
        else
            isVisibleType = "uint16_t"
        end

        local offset = 0
        for instanceIndex = 1, instanceCount do
            local startOffset = offset

            -- read per-instance properties from byte data
            local readOffset = startOffset

            local visible = perInstanceData:getUInt16(readOffset)
            readOffset = readOffset + ffi.sizeof(isVisibleType)

            local x = perInstanceData:getFloat(readOffset)
            readOffset = readOffset + ffi.sizeof("float")

            local y = perInstanceData:getFloat(readOffset)
            readOffset = readOffset + ffi.sizeof("float")

            local scale = perInstanceData:getFloat(readOffset)
            readOffset = readOffset + ffi.sizeof("float")

            -- mutate
            visible = modifyIsVisible(instanceIndex, visible)
            x, y = modifyOffset(instanceIndex, x, y)
            scale = modifyScale(instanceIndex, scale)

            -- write per-instance properties to byte data
            local writeOffset = startOffset

            perInstanceData:setUInt16(writeOffset, visible)
            writeOffset = writeOffset + ffi.sizeof(isVisibleType)

            perInstanceData:setFloat(writeOffset, x)
            writeOffset = writeOffset + ffi.sizeof("float")

            perInstanceData:setFloat(writeOffset, y)
            writeOffset = writeOffset + ffi.sizeof("float")

            perInstanceData:setFloat(writeOffset, scale)
            writeOffset = writeOffset + ffi.sizeof("float")

            offset = offset + stride
        end

    elseif DATA_MODE == DATA_MODE_USE_FFI_DATA then
        -- cast to 8-bit array so we can use byte offsets as before
        local perInstanceDataPtr = ffi.cast("uint8_t*", perInstanceData:getFFIPointer())

        -- get the size of one instance data element, in bytes
        local stride = perInstanceDataBuffer:getElementStride()

        local offset = 0
        for instanceIndex = 1, instanceCount do
            local startOffset = offset

            -- read per-instance properties from byte data
            local readOffset = startOffset

            -- cast the byte pointer at this offset to the appropriate type pointer, then dereference using `[0]`
            local x = ffi.cast("float*", perInstanceDataPtr + readOffset)[0]
            readOffset = readOffset + ffi.sizeof("float")

            local y = ffi.cast("float*", perInstanceDataPtr + readOffset)[0]
            readOffset = readOffset + ffi.sizeof("float")

            local scale = ffi.cast("float*", perInstanceDataPtr + readOffset)[0]
            readOffset = readOffset + ffi.sizeof("float")

            -- mutate
            visible = modifyIsVisible(instanceIndex, visible)
            x, y = modifyOffset(instanceIndex, x, y)
            scale = modifyScale(instanceIndex, scale)

            -- write per-instance properties to byte data
            local writeOffset = startOffset

            ffi.cast("uint16_t*", perInstanceDataPtr + writeOffset)[0] = visible
            writeOffset = writeOffset + ffi.sizeof("uint16_t")

            ffi.cast("float*", perInstanceDataPtr + writeOffset)[0] = x
            writeOffset = writeOffset + ffi.sizeof("float")

            ffi.cast("float*", perInstanceDataPtr + writeOffset)[0] = y
            writeOffset = writeOffset + ffi.sizeof("float")

            ffi.cast("float*", perInstanceDataPtr + writeOffset)[0] = scale
            writeOffset = writeOffset + ffi.sizeof("float")

            offset = offset + stride
        end
    end
    
    -- update the per-instance data buffer
    perInstanceDataBuffer:setArrayData(perInstanceData)
end

-- ### INTERNALS ###

generateIsVisible = function(instanceIndex)
    return 0x1
end

generateOffset = function(instanceIndex)
    local xMargin, yMargin = 50, 50
    return xMargin + love.math.random() * (love.graphics.getWidth() - 2 * xMargin),
        yMargin +  love.math.random() * (love.graphics.getHeight() - 2 * yMargin)
end

generateScale = function(instanceIndex)
    return love.math.random(1, 8)
end

modifyOffset = function(instanceIndex, x, y)
    local maxOffset = 100 * love.timer.getDelta()
    local t = love.timer.getTime()

    local seedX = instanceIndex * 17.3
    local seedY = -instanceIndex * 31.1777777
    local newX = x + maxOffset * (love.math.perlinNoise(seedX, t) * 2 - 1)
    local newY = y + maxOffset * (love.math.perlinNoise(seedY, t) * 2 - 1)

    local minX, maxX = 0, love.graphics.getWidth()
    local minY, maxY = 0, love.graphics.getHeight()

    if newX < minX then
        newX = minX + (minX - newX)
    elseif newX > maxX then
        newX = maxX - (newX - maxX)
    end

    if newY < minY then
        newY = minY + (minY - newY)
    elseif newY > maxY then
        newY = maxY - (newY - maxY)
    end

    return newX, newY
end

modifyIsVisible = function(instanceIndex, isVisible)
    return isVisible
end

modifyScale = function(instanceIndex, scale)
    return 1 + 9 * (math.sin(love.timer.getTime() + (instanceIndex / instanceCount) * (2 * math.pi)) + 1) / 2
end

-- local instanceDataBuffer = love.graphics.newGraphicsBuffer(instanceDataFormat, nInstances)

--[[

require "include"
require "common.error_handler"
require "build.config"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"
require "common.routine"

love.load = function(args)
    local w, h = love.graphics.getDimensions()

    require "common.texture_format"
    local texture = rt.TextureScaleMode

    local result_screen = 1
    local overworld = 2
    local keybinding = 3
    local settings = 4
    local menu = 5

    for to_preallocate in range(
        -- result_screen
        --, overworld
        --, keybinding
        --, settings
        --, menu
    ) do
        if to_preallocate == 1 then
            require "overworld.result_screen_scene"
            rt.SceneManager:preallocate(ow.ResultScreenScene)
        elseif to_preallocate == 2 then
            require "overworld.overworld_scene"
            rt.SceneManager:preallocate(ow.OverworldScene)
        elseif to_preallocate == 3 then
            require "menu.keybinding_scene"
            rt.SceneManager:preallocate(mn.KeybindingScene)
        elseif to_preallocate == 4 then
            require "menu.settings_scene"
            rt.SceneManager:preallocate(mn.SettingsScene)
        elseif to_preallocate == 5 then
            require "menu.menu_scene"
            rt.SceneManager:preallocate(mn.MenuScene)
        end
    end

    require "overworld.overworld_scene"
    --rt.SceneManager:push(ow.OverworldScene, "air_dash_node_tutorial", ow.StageEntryMode.INSTANT)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    rt.SceneManager:push(mn.MenuScene, true)


    rt.SceneManager:set_is_cursor_visible(true)

end

love.update = function(delta)
    if rt.SceneManager ~= nil then
        debugger.push("update")
        rt.SceneManager:update(delta)
        debugger.pop("update")
    end

    if love.keyboard.isDown("m") then
        love.keypressed("space", "space")
    end
end

love.draw = function()
    love.graphics.clear(0.5, 0.5, 0.5, 1)

    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize()
    end
end
]]