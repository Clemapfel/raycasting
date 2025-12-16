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
  nextobjectid = 287,
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
      objects = {
        {
          id = 234,
          name = "",
          type = "MovableHitbox",
          shape = "polygon",
          x = -1616,
          y = 864,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 0 },
            { x = 848, y = 0 },
            { x = 848, y = -432 },
            { x = 1040, y = -432 },
            { x = 1040, y = 26.3822 },
            { x = 1152, y = 128 },
            { x = 1360, y = 128 },
            { x = 1440, y = 0 },
            { x = 1584, y = 16 },
            { x = 1728, y = 128 },
            { x = 1808, y = 128 },
            { x = 1776, y = -272 },
            { x = 1984, y = -288 },
            { x = 2048, y = 240 },
            { x = 1776, y = 240 },
            { x = 1376, y = 240 },
            { x = 1040, y = 240 },
            { x = 32, y = 240 }
          },
          properties = {}
        },
        {
          id = 235,
          name = "FIrst Jump",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -951.448,
          y = 2244.03,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = -16, y = 32 },
            { x = 32, y = 32 },
            { x = 32, y = -400 },
            { x = 224, y = -400 },
            { x = 224, y = -416 },
            { x = 16, y = -416 }
          },
          properties = {}
        },
        {
          id = 272,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -196.034,
          y = 1657.22,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1072, y = 0 },
            { x = 1072, y = -192 },
            { x = 144, y = -192 },
            { x = 144, y = -384 },
            { x = -144, y = -384 },
            { x = -144, y = 0 }
          },
          properties = {}
        },
        {
          id = 281,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -321.359,
          y = 1412.6,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 0, y = -48 },
            { x = 288, y = -48 },
            { x = 304, y = -48 },
            { x = 304, y = 144 },
            { x = 320, y = 160 },
            { x = 288, y = 160 },
            { x = 288, y = -32 }
          },
          properties = {}
        },
        {
          id = 282,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 27.9664,
          y = 1353.22,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 0 },
            { x = 32, y = 16 },
            { x = 128, y = 16 },
            { x = 128, y = 0 }
          },
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
      name = "front",
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
          x = 112,
          y = -656,
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
          y = -544,
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
          y = -544,
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
          x = -459.839,
          y = 826.015,
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
          y = -560,
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
          y = -560,
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
          y = -560,
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
          x = -928,
          y = -736,
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
          x = -816,
          y = -736,
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
          x = -816,
          y = -752,
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
          x = -928,
          y = -752,
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
          x = -928,
          y = -752,
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
          id = 184,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -928,
          y = -640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 185 }
          }
        },
        {
          id = 185,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -816,
          y = -640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 186,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -816,
          y = -656,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 187 }
          }
        },
        {
          id = 187,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -928,
          y = -656,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 188,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -928,
          y = -656,
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
            ["axis_x"] = -1,
            ["axis_y"] = 0,
            ["render_priority"] = -1
          }
        },
        {
          id = 196,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -768,
          y = -848,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 197 }
          }
        },
        {
          id = 197,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -368,
          y = -848,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 198,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -400,
          y = -864,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 199 }
          }
        },
        {
          id = 199,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -768,
          y = -864,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 200,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -768,
          y = -864,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 366.067, y = 16 },
            { x = 366.067, y = 0 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0,
            ["render_priority"] = -1
          }
        },
        {
          id = 201,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -928,
          y = -464,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.1,
            ["other"] = { id = 202 }
          }
        },
        {
          id = 202,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -816,
          y = -464,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 206,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -320,
          y = -720,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 207 }
          }
        },
        {
          id = 207,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 241.895,
          y = -957.143,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 208,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = 208,
          y = -960,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 209 }
          }
        },
        {
          id = 209,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -320,
          y = -736,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 211,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -320,
          y = -736,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 528, y = -208 },
            { x = 528, y = -224 }
          },
          properties = {}
        },
        {
          id = 212,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -96,
          y = -1040,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 213 }
          }
        },
        {
          id = 213,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 368,
          y = -1040,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 214,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = 368,
          y = -1056,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 215 }
          }
        },
        {
          id = 215,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -64,
          y = -1056,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 216,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -112,
          y = -1056,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 48, y = 0 },
            { x = 48, y = 16 },
            { x = 478.268, y = 16 },
            { x = 478.268, y = 0 }
          },
          properties = {
            ["axis_x"] = -1,
            ["axis_y"] = 0,
            ["render_priority"] = -1
          }
        },
        {
          id = 217,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -192,
          y = -1264,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 218 }
          }
        },
        {
          id = 218,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -192,
          y = -1072,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 219,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -176,
          y = -1072,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 220 }
          }
        },
        {
          id = 220,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -176,
          y = -1264,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 223,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -112,
          y = -1168,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = 96 },
            { x = -64, y = 96 },
            { x = -64, y = -96 },
            { x = -80, y = -96 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 224,
          name = "",
          type = "Goal",
          shape = "point",
          x = -192,
          y = -1408,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 226,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -464,
          y = -432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.1,
            ["other"] = { id = 227 }
          }
        },
        {
          id = 227,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -128,
          y = -480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 228,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -128,
          y = -480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.1,
            ["other"] = { id = 229 }
          }
        },
        {
          id = 229,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -464,
          y = -496,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 254,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -1152,
          y = 752,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 255 }
          }
        },
        {
          id = 255,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -832,
          y = 752,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 260,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -1040,
          y = 640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 261 }
          }
        },
        {
          id = 261,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -832,
          y = 640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 262,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -928,
          y = 528,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 263 }
          }
        },
        {
          id = 263,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -832,
          y = 528,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 266,
          name = "path_to",
          type = "PathNode",
          shape = "point",
          x = -583.862,
          y = 1326.14,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 267,
          name = "path_from",
          type = "Path",
          shape = "point",
          x = -528,
          y = 288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["next"] = { id = 266 },
            ["target"] = { id = 234 },
            ["velocity"] = 1.5
          }
        },
        {
          id = 269,
          name = "up_from",
          type = "OneWayPlatform",
          shape = "point",
          x = 80,
          y = 416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 270 }
          }
        },
        {
          id = 270,
          name = "up_to",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 272,
          y = 416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 264,
          name = "",
          type = "",
          shape = "point",
          x = -851,
          y = 448,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["teno"] = { id = 265 }
          }
        },
        {
          id = 265,
          name = "",
          type = "",
          shape = "point",
          x = -1267,
          y = 864,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 283,
          name = "down_from",
          type = "OneWayPlatform",
          shape = "point",
          x = 272,
          y = 464,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 284 }
          }
        },
        {
          id = 284,
          name = "down_to",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 80,
          y = 464,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 286,
          name = "",
          type = "MovableHitbox",
          shape = "polygon",
          x = -209.771,
          y = 415.425,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 112 },
            { x = 209.771, y = 112.575 },
            { x = 209.771, y = 0.574794 }
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
