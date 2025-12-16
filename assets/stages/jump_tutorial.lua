return {
  version = "1.10",
  luaversion = "5.1",
  tiledversion = "1.11.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 32,
  height = 32,
  tilewidth = 16,
  tileheight = 16,
  nextlayerid = 7,
  nextobjectid = 184,
  properties = {},
  tilesets = {
    {
      name = "debug_tileset_objects",
      firstgid = 1,
      filename = "../tilesets/debug_tileset_objects.tsx",
      exportfilename = "../tilesets/debug_tileset_objects.lua"
    },
    {
      name = "debug_tileset",
      firstgid = 7,
      filename = "../tilesets/debug_tileset.tsx",
      exportfilename = "../tilesets/debug_tileset.lua"
    }
  },
  layers = {
    {
      type = "imagelayer",
      image = "../tilesets/debug_tileset_16x16/tile.png",
      id = 3,
      name = "background",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      repeatx = true,
      repeaty = true,
      properties = {}
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 5,
      name = "aux",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {}
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 6,
      name = "hitbox",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {}
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
      name = "main",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 3,
          name = "Goal",
          type = "Goal",
          shape = "point",
          x = 631.506,
          y = -239.407,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "Checkpoint",
          type = "Checkpoint",
          shape = "point",
          x = -493.091,
          y = -444.572,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 159,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -1056,
          y = -384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 880, y = 0 },
            { x = 880, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 160,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -928,
          y = -496,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.1,
            ["other"] = { id = 162 }
          }
        },
        {
          id = 162,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -816,
          y = -496,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 163,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -998.195,
          y = -425.993,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 164,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -996.39,
          y = -425.993,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 169,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -816,
          y = -512,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.1,
            ["other"] = { id = 170 }
          }
        },
        {
          id = 170,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -928,
          y = -512,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 172,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -928,
          y = -512,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 112, y = 16 },
            { x = 112, y = 0 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0,
            ["hue"] = 0.1,
            ["render_priority"] = -1
          }
        },
        {
          id = 173,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -720,
          y = -560,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 174 }
          }
        },
        {
          id = 174,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -608,
          y = -560,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 175,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -608,
          y = -576,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 176 }
          }
        },
        {
          id = 176,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -720,
          y = -576,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 177,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -720,
          y = -576,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 112, y = 16 },
            { x = 112, y = 0 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0,
            ["render_priority"] = -1
          }
        },
        {
          id = 178,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -896,
          y = -416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.1,
            ["other"] = { id = 179 }
          }
        },
        {
          id = 179,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -784,
          y = -416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 180,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -784,
          y = -432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.1,
            ["other"] = { id = 181 }
          }
        },
        {
          id = 181,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -896,
          y = -432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 183,
          name = "",
          type = "",
          shape = "polygon",
          x = -736,
          y = -416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = 176, y = 0 },
            { x = 176, y = -16 },
            { x = 16, y = -16 },
            { x = -32, y = -32 },
            { x = -32, y = -48 },
            { x = 208, y = -48 },
            { x = 208, y = 32 },
            { x = -32, y = 32 },
            { x = -32, y = 16 }
          },
          properties = {}
        }
      }
    },
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 32,
      height = 32,
      id = 4,
      name = "noop",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "base64",
      compression = "zlib",
      chunks = {}
    }
  }
}
