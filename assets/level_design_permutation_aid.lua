local JUMP = "jump"
local WALL_JUMP = "wall_jump"
local SQUEEZE = "squeeze"
local KILL_PLANE = "kill_plane"
local STICKY = "sticky"
local SLIPPERY = "slippery"
local SLOPES = "slopes"
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

local priority = {
    [JUMP] = 0,
    [WALL_JUMP] = 1,
    [KILL_PLANE] = 1,
    [STICKY] = 1,
    [SLIPPERY] = 1,
    [SQUEEZE] = 1,
    [SLOPES] = 2,
    [BUBBLE_FIELD] = 2,
    [PORTAL] = 3,
    [BOOST_FIELD] = 3,
    [ONE_WAY_PLATFORM] = 3,
    [MOVING_HITBOX] = 4,
    [BOUNCE_PAD] = 5,
    [BUBBLE] = 5,
    [ACCELERATOR_SURFACE] = 5,
    [AIR_DASH_NODE] = 5,
    [DECELERATOR_SURFACE] = 5,
    [HOOK] = 5,
}

local dependencies = {
    [JUMP] = {},
    [WALL_JUMP] = { JUMP },
    [KILL_PLANE] = { JUMP },
    [STICKY] = { JUMP, WALL_JUMP },
    [SLIPPERY] = { JUMP, WALL_JUMP },
    [SLOPES] = { STICKY, SLIPPERY },
    [SQUEEZE] = { JUMP, STICKY, SLIPPERY, SLOPES, BOOST_FIELD },
    [ACCELERATOR_SURFACE] = { SLOPES },
    [AIR_DASH_NODE] = { JUMP, WALL_JUMP, BUBBLE_FIELD},
    [BOOST_FIELD] = { JUMP, WALL_JUMP, BUBBLE_FIELD },
    [BOUNCE_PAD] = { JUMP },
    [BUBBLE] = { JUMP, BOUNCE_PAD },
    [BUBBLE_FIELD] = { JUMP },
    [DECELERATOR_SURFACE] = { SLOPES },
    [HOOK] = { JUMP },
    [MOVING_HITBOX] = { JUMP, SLOPES },
    [ONE_WAY_PLATFORM] = { JUMP },
    [PORTAL] = { JUMP }
}

local sorted = {}
do -- topological sort with priority tie-breaking
    local sorted_order = {}
    local visited = {}
    local mark_circular = {}

    local function visit(node)
        if mark_circular[node] then
            rt.critical("Circular dependency detected at: " .. node)
        end

        if not visited[node] then
            mark_circular[node] = true

            for dependency in values(dependencies[node] or {}) do
                visit(dependency)
            end

            mark_circular[node] = false
            visited[node] = true
            table.insert(sorted_order, node)
        end
    end

    local all_nodes = {}
    for node in keys(dependencies) do
        table.insert(all_nodes, node)
    end

    table.sort(all_nodes, function(a, b)
        return (priority[a] or math.huge) < (priority[b] or math.huge)
    end)

    for node in values(all_nodes) do visit(node) end
    sorted = sorted_order
end

dbg(sorted)

