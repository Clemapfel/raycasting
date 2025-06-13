require "common.translation"
require "common.game_state"
require "overworld.stage_config"
require "common.camera"
require "physics.physics"

rt.settings.overworld.stage_title_card_scene = {
    font_path = "assets/fonts/DejaVuSans/DejaVuSansCondensed-Bold.ttf",
    stage_id = "stage_title_cards", -- tile map used for text geometry
    layer_i = 2, -- layer i in that tile map
}

--- @class ow.StageTitleCardScene
ow.StageTitleCardScene = meta.class("StageTitleCardScene", rt.Scene)

local _shader

--- @brief
function ow.StageTitleCardScene:instantiate(state)
    if _shader == nil then _shader = rt.Shader("overworld/stage_title_card_scene.glsl") end
    self._state = state
    self._player = state:get_player()
    self._camera = rt.Camera()
    self._camera_position_x, self._camera_position_y = 0, 0
    self._elapsed = 0

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "^" then
            self:_initialize()
        end
    end)
end

local _config

--- @brief
function ow.StageTitleCardScene:_initialize()
    -- use tiled map to get layer geometry
    local settings = rt.settings.overworld.stage_title_card_scene
    --if _config == nil then
        _config = ow.StageConfig(settings.stage_id)
    --end

    self._objects = {}
    for object in values(_config:get_layer_object_wrappers(settings.layer_i)) do
        if object.class == self._stage_id then
            table.insert(self._objects, object)
        end
    end

    self._world = b2.World()
    self._bodies = {}
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for object in values(self._objects) do
        local body = object:create_physics_body(self._world, b2.BodyType.STATIC)
        body:add_tag("stencil")
        local aabb = body:compute_aabb()
        min_x = math.min(min_x, aabb.x)
        min_y = math.min(min_y, aabb.y)
        max_x = math.max(max_x, aabb.x + aabb.width)
        max_y = math.max(max_y, aabb.y + aabb.height)
        table.insert(self._bodies, body)
    end

    self._camera_bounds = rt.AABB(min_x, min_y, max_x - min_x, max_y - min_y)
    self._camera_anchor_x, self._camera_anchor_y = math.mix2(min_x, min_y, max_x, max_y, 0.5)
    self._camera:set_position(self._camera_anchor_x, self._camera_anchor_y)

    self._player:move_to_world(self._world)
    self._player:set_is_bubble(true)
    self._player:set_opacity(1)
    self._player:enable()

    local screen_h = self._camera:screen_xy_to_world_xy(0, love.graphics.getHeight())
    self._player:teleport_to(self._camera_anchor_x, self._camera_anchor_y - 100)
end

--- @brief
function ow.StageTitleCardScene:realize()
    if self:already_realized() then return end
end

--- @brief
function ow.StageTitleCardScene:size_allocate(x, y, width, height)
    self._bounds:reformat(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_m = 2 * m
end

--- @brief
function ow.StageTitleCardScene:update(delta)
    self._elapsed = self._elapsed + delta
    self._fraction = (math.sin(self._elapsed) + 1) / 2

    self._world:update(delta)
    self._player:update(delta)
    self._camera:update(delta)
end

--- @brief
function ow.StageTitleCardScene:draw()
    love.graphics.push()
    love.graphics.origin()
    rt.Palette.BLACK:bind()
    love.graphics.rectangle("fill", self._bounds:unpack())

    self._camera:bind()

    rt.Palette.WHITE:bind()
    for body in values(self._bodies) do
        body:draw()
    end

    self._player:draw()
    local x, y = self._player:get_position()

    self._camera:unbind()
    love.graphics.pop()
end

--- @brief
function ow.StageTitleCardScene:enter(stage_id)
    meta.assert(stage_id, "String")
    self._stage_id = stage_id
    self._stage_index = rt.GameState:get_stage_index(stage_id)
    self:_initialize()
end

--- @brief
function ow.StageTitleCardScene:exit()

end