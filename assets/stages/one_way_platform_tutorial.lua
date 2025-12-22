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
  nextobjectid = 336,
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
          x = -800,
          y = 832,
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
          x = -192,
          y = 1103.57,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1376, y = 0.428574 },
            { x = 1376, y = -383.571 },
            { x = 1168, y = -383.571 },
            { x = 1168, y = -191.571 },
            { x = 144, y = -192 },
            { x = 144, y = -384 },
            { x = -144, y = -384 },
            { x = -144, y = 0 }
          },
          properties = {}
        },
        {
          id = 281,
          name = "Horizontal Sidedness",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -336,
          y = 751.571,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 0, y = -48 },
            { x = 304, y = -48 },
            { x = 304, y = 144 },
            { x = 1296, y = 144.429 },
            { x = 1296, y = -47.5714 },
            { x = 1520, y = -47.5714 },
            { x = 1520, y = -31.5714 },
            { x = 1312, y = -31.5714 },
            { x = 1312, y = 160.429 },
            { x = 288, y = 160 },
            { x = 288, y = -32 }
          },
          properties = {}
        },
        {
          id = 304,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -1568,
          y = 1440,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 1616 },
            { x = 176, y = 1616 },
            { x = 176, y = 0 }
          },
          properties = {}
        },
        {
          id = 305,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -512,
          y = 1440,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 1616 },
            { x = -1056, y = 1616 },
            { x = -1056, y = 1824 },
            { x = 176, y = 1824 },
            { x = 176, y = 0 }
          },
          properties = {}
        },
        {
          id = 306,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -1392,
          y = 1440,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = 1616 },
            { x = 0, y = 1616 }
          },
          properties = {}
        },
        {
          id = 307,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -528,
          y = 1440,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = 1616 },
            { x = 0, y = 1616 }
          },
          properties = {}
        },
        {
          id = 308,
          name = "from",
          type = "OneWayPlatform",
          shape = "point",
          x = -1248,
          y = 2816,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 309 }
          }
        },
        {
          id = 309,
          name = "to",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -1248,
          y = 2928,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 310,
          name = "path_from",
          type = "Path",
          shape = "point",
          x = -1248,
          y = 2928,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["next"] = { id = 311 },
            ["target"] = { id = 308 }
          }
        },
        {
          id = 311,
          name = "path_to",
          type = "PathNode",
          shape = "point",
          x = -1248,
          y = 1616,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 314,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -26.4434,
          y = 2363.12,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -5.55663, y = 4.87968 },
            { x = -5.55663, y = 116.88 },
            { x = 1466.44, y = 116.88 },
            { x = 1466.44, y = -651.12 },
            { x = 1226.44, y = -651.12 },
            { x = 1226.44, y = 4.87968 },
            { x = 634.443, y = 4.87968 },
            { x = 634.443, y = -187.12 },
            { x = 554.443, y = -187.12 },
            { x = 554.443, y = 4.87968 }
          },
          properties = {}
        },
        {
          id = 315,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 1184,
          y = 2336,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = 32 },
            { x = 16, y = 32 },
            { x = 16, y = -624 },
            { x = 256, y = -624 },
            { x = 256, y = -640 },
            { x = 0, y = -640 }
          },
          properties = {}
        },
        {
          id = 316,
          name = "from",
          type = "OneWayPlatform",
          shape = "point",
          x = 320,
          y = 2128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 317 }
          }
        },
        {
          id = 317,
          name = "to",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 320,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 318,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 640,
          y = 1712,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 176, y = 32 },
            { x = 176, y = 0 }
          },
          properties = {}
        },
        {
          id = 319,
          name = "from",
          type = "OneWayPlatform",
          shape = "point",
          x = 48,
          y = 2288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 320 }
          }
        },
        {
          id = 320,
          name = "to",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 224,
          y = 2288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 321,
          name = "from",
          type = "OneWayPlatform",
          shape = "point",
          x = 416,
          y = 1984,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 322 }
          }
        },
        {
          id = 322,
          name = "to",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 416,
          y = 2032,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 323,
          name = "from",
          type = "OneWayPlatform",
          shape = "point",
          x = 512,
          y = 1840,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 324 }
          }
        },
        {
          id = 324,
          name = "to",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 512,
          y = 1888,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 328,
          name = "from",
          type = "OneWayPlatform",
          shape = "point",
          x = 384,
          y = 2224,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 329 }
          }
        },
        {
          id = 329,
          name = "to",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 384,
          y = 2368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 330,
          name = "double jump",
          type = "DoubleJumpTether",
          shape = "point",
          x = 660.784,
          y = 1995.08,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 331,
          name = "hook",
          type = "Hook",
          shape = "point",
          x = -219.939,
          y = 2215.2,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 332,
          name = "",
          type = "MovableHitbox",
          shape = "polygon",
          x = 48,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 224, y = 0 },
            { x = 208, y = -80 },
            { x = -16, y = -64 }
          },
          properties = {}
        },
        {
          id = 333,
          name = "path_from",
          type = "Path",
          shape = "point",
          x = 492.503,
          y = 2122.02,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["next"] = { id = 334 },
            ["target"] = { id = 332 }
          }
        },
        {
          id = 334,
          name = "path_to",
          type = "PathNode",
          shape = "point",
          x = -96,
          y = 2112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 335,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 851.545,
          y = 2191.25,
          width = 110,
          height = 110,
          rotation = 0,
          visible = true,
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
          x = 793.206,
          y = 2298.99,
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
          id = 293,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = -32,
          y = 704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["has_end_cap"] = false,
            ["hue"] = 0.333333333,
            ["other"] = { id = 294 }
          }
        },
        {
          id = 294,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 352,
          y = 704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.333333333
          }
        },
        {
          id = 295,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = 672,
          y = 704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["has_end_cap"] = false,
            ["hue"] = 0.333333333,
            ["other"] = { id = 296 }
          }
        },
        {
          id = 296,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 960,
          y = 704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.333333333
          }
        },
        {
          id = 297,
          name = "From",
          type = "OneWayPlatform",
          shape = "point",
          x = 672,
          y = 704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["has_end_cap"] = false,
            ["hue"] = 0.333333333,
            ["other"] = { id = 298 }
          }
        },
        {
          id = 298,
          name = "To",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 352,
          y = 704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.333333333
          }
        },
        {
          id = 299,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 240,
          y = 767.571,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -192, y = 48.4286 },
            { x = -192, y = 128.429 },
            { x = 720, y = 128.429 },
            { x = 720, y = 48.4286 }
          },
          properties = {
            ["axis_x"] = -1,
            ["axis_y"] = 0,
            ["hue"] = 0.33333,
            ["velocity"] = 2
          }
        },
        {
          id = 300,
          name = "Coin",
          type = "Coin",
          shape = "point",
          x = 724.089,
          y = 878.08,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = 0.333333,
            ["should_move_in_place"] = false
          }
        },
        {
          id = 303,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 240,
          y = 767.571,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -192, y = 128.857 },
            { x = -272, y = 128.429 },
            { x = -272, y = 48 },
            { x = -192, y = 48.4286 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1,
            ["hue"] = 0.33333
          }
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
