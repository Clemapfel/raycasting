-- elements
local JUMP = "jump"
local WALL_JUMP = "wall_jump"
local KILL_PLANE = "kill_plane"
local ACCELERATOR_SURFACE = "accelerator_surface"
local AIR_DASH_NODE = "air_dash_node"
local BOOST_FIELD = "boost_field"
local BOUNCE_PAD = "bounce_pad"
local BUBBLE = "bubble"
local BUBBLE_FIELD = "bubble_field"
local DECELERATOR_SURFACE = "decelerator_surface"
local HOOK = "hook"
local MOVING_HITBOX = "moving_hitbox"
local ONE_WAY_PLATFORM = "one_way_platform"
local PORTAL = "portal"

local dependencies = {
    [JUMP] = {

    },

    [WALL_JUMP] = {

    },

    [BUBBLE_FIELD] = {

    },

    [ACCELERATOR_SURFACE] = {

    },

    [AIR_DASH_NODE] = {

    },

    [BOOST_FIELD] = {

    },

    [BOUNCE_PAD] = {

    },

    [BUBBLE] = {
        BOUNCE_PAD,
    },

    [DECELERATOR_SURFACE] = {

    },

    [HOOK] = {

    },

    [MOVING_HITBOX] = {

    },

    [ONE_WAY_PLATFORM] = {

    },

    [PORTAL] = {

    }
}