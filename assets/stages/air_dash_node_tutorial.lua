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
  nextlayerid = 8,
  nextobjectid = 359,
  properties = {
    ["background_id"] = "\"nebula\""
  },
  tilesets = {
    {
      name = "debug_tileset_objects",
      firstgid = 1,
      filename = "../tilesets/debug_tileset_objects.tsx",
      exportfilename = "../tilesets/debug_tileset_objects.lua"
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
      id = 7,
      name = "back",
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
          id = 95,
          name = "",
          type = "Wall",
          shape = "polygon",
          x = -1392,
          y = 832,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 208, y = 0 },
            { x = 688, y = 0 },
            { x = 688, y = -640 },
            { x = 1232, y = -640 },
            { x = 1232, y = -1632 },
            { x = 1872, y = -1632 },
            { x = 1856, y = -1072 },
            { x = 1888, y = -1072 },
            { x = 2128, y = -832 },
            { x = 2800, y = -832 },
            { x = 2800, y = -1200 },
            { x = 2240, y = -1200 },
            { x = 2240, y = -1984 },
            { x = 816, y = -1984 },
            { x = -304, y = 432 },
            { x = 208, y = 432 }
          },
          properties = {}
        },
        {
          id = 152,
          name = "",
          type = "Fireflies",
          shape = "point",
          x = 2096,
          y = -480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["count"] = 7
          }
        },
        {
          id = 162,
          name = "",
          type = "OneWayPlatform",
          shape = "point",
          x = 1904,
          y = -736,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 163 }
          }
        },
        {
          id = 163,
          name = "",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 2032,
          y = -736,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 246,
          name = "",
          type = "OneWayPlatform",
          shape = "point",
          x = 1904,
          y = -1472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 247 }
          }
        },
        {
          id = 247,
          name = "",
          type = "OneWayPlatformNode",
          shape = "point",
          x = 2032,
          y = -1472,
          width = 0,
          height = 0,
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
          id = 89,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -128.151,
          y = -2025.27,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 91,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -1439.08,
          y = 1248,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -256, y = 16 },
            { x = 255.076, y = 16 },
            { x = 255.076, y = -416 },
            { x = 480, y = -416 },
            { x = 479.076, y = 160 },
            { x = -256.924, y = 160 }
          },
          properties = {}
        },
        {
          id = 92,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -1184,
          y = 928,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -96 },
            { x = -16, y = -96 },
            { x = -16, y = 320 },
            { x = -32, y = 336 },
            { x = 0, y = 336 }
          },
          properties = {}
        },
        {
          id = 93,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -1424,
          y = 960,
          width = 224,
          height = 224,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 96,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -864,
          y = 512,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 160, y = -320 },
            { x = 144, y = -320 },
            { x = 144, y = 304 },
            { x = 128, y = 320 },
            { x = 160, y = 320 }
          },
          properties = {}
        },
        {
          id = 97,
          name = "",
          type = "",
          shape = "polygon",
          x = -1184,
          y = 832,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 96, y = 0 },
            { x = 96, y = 576 },
            { x = 848, y = 576 },
            { x = 848, y = -640 },
            { x = 480, y = -640 },
            { x = 480, y = 0 }
          },
          properties = {}
        },
        {
          id = 100,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -944,
          y = 528,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 105,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -1088,
          y = 192,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["direction"] = { id = 106 }
          }
        },
        {
          id = 106,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -919.674,
          y = 148.515,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 109,
          name = "",
          type = "",
          shape = "polygon",
          x = -352,
          y = 192,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 1216 },
            { x = 1744, y = 1216 },
            { x = 1760, y = -192 },
            { x = 1104, y = -192 },
            { x = 1088, y = -192 },
            { x = 848, y = -432 },
            { x = 816, y = -432 },
            { x = 816, y = -992 },
            { x = 192, y = -992 },
            { x = 192, y = 0 }
          },
          properties = {}
        },
        {
          id = 110,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -448,
          y = -96,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 111,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -448,
          y = -400,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 117,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -448,
          y = -704,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 118,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -320,
          y = -128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 160, y = -672 },
            { x = 144, y = -672 },
            { x = 144, y = 304 },
            { x = 128, y = 320 },
            { x = 160, y = 320 }
          },
          properties = {}
        },
        {
          id = 120,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 208,
          y = -1152,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 0 },
            { x = -32, y = 352 },
            { x = 48, y = 352 },
            { x = 48, y = 0 }
          },
          properties = {
            ["axis_x"] = -1,
            ["render_priority"] = -2
          }
        },
        {
          id = 129,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 608,
          y = -720,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -112, y = -80 },
            { x = -112, y = -16 },
            { x = 208, y = -16 },
            { x = 208, y = -80 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1,
            ["render_priority"] = -2
          }
        },
        {
          id = 131,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 512,
          y = -336,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 304, y = 304 },
            { x = 240, y = 304 },
            { x = -16, y = 48 },
            { x = -16, y = -16 }
          },
          properties = {}
        },
        {
          id = 138,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 528,
          y = -896,
          width = 256,
          height = 256,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_x"] = 0,
            ["axis_y"] = 1,
            ["velocity"] = 2
          }
        },
        {
          id = 119,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -176,
          y = -1152,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1024, y = 0 },
            { x = 1024, y = 784 },
            { x = 1584, y = 784 },
            { x = 1584, y = -96 },
            { x = 0, y = -96 }
          },
          properties = {}
        },
        {
          id = 143,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 1008,
          y = -352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 16 },
            { x = 288, y = 160 },
            { x = 400, y = 160 },
            { x = 448, y = 16 },
            { x = 448, y = -16 },
            { x = 400, y = -16 },
            { x = -160, y = -16 },
            { x = -160, y = -800 },
            { x = -192, y = -800 },
            { x = -192, y = 16 }
          },
          properties = {}
        },
        {
          id = 146,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 1008,
          y = -16,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -16 },
            { x = 288, y = -160 },
            { x = 400, y = -160 },
            { x = 448, y = -16 },
            { x = 1472, y = -16 },
            { x = 1472, y = 16 },
            { x = 384, y = 16 },
            { x = -272, y = 16 },
            { x = -512, y = -224 },
            { x = -544, y = -224 },
            { x = -544, y = -784 },
            { x = -512, y = -784 },
            { x = -512, y = -272 },
            { x = -256, y = -16 }
          },
          properties = {}
        },
        {
          id = 150,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 1904,
          y = -704,
          width = 128,
          height = 128,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 155,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 1680,
          y = -384,
          width = 320,
          height = 320,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 156,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 2080,
          y = -512,
          width = 224,
          height = 224,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 144,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1184,
          y = -272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 32 },
            { x = 16, y = 144 },
            { x = 112, y = 96 },
            { x = 224, y = 96 },
            { x = 224, y = 80 },
            { x = 112, y = 80 }
          },
          properties = {
            ["axis_x"] = 1
          }
        },
        {
          id = 164,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1936,
          y = -736,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 0 },
            { x = -32, y = 32 },
            { x = 96, y = 32 },
            { x = 96, y = 0 }
          },
          properties = {
            ["axis_y"] = -1,
            ["render_priority"] = -1
          }
        },
        {
          id = 240,
          name = "",
          type = "Wall",
          shape = "polygon",
          x = -1488,
          y = 2416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = false,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -688 },
            { x = 1648, y = -688 },
            { x = 1648, y = 544 },
            { x = 0, y = 544 }
          },
          properties = {}
        },
        {
          id = 245,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1936,
          y = -1472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 0 },
            { x = -32, y = 32 },
            { x = 96, y = 32 },
            { x = 96, y = 0 }
          },
          properties = {
            ["axis_y"] = -1,
            ["render_priority"] = -1
          }
        },
        {
          id = 260,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = 2224,
          y = -1104,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 261,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = 2000,
          y = -1360,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 263,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 1824,
          y = -1888,
          width = 320,
          height = 320,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.5,
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 265,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 1568,
          y = -2240,
          width = 304,
          height = 304,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.5,
            ["axis_x"] = -1,
            ["axis_y"] = 1
          }
        },
        {
          id = 266,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 2096,
          y = -2240,
          width = 304,
          height = 304,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.5,
            ["axis_x"] = 1,
            ["axis_y"] = 1
          }
        },
        {
          id = 315,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 976,
          y = 1456,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1504, y = -2064 },
            { x = 1104, y = -2160 },
            { x = 1056, y = -2160 },
            { x = 1056, y = -2192 },
            { x = 1552, y = -2192 },
            { x = 1552, y = -1456 },
            { x = 1504, y = -1456 }
          },
          properties = {}
        },
        {
          id = 317,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 976,
          y = 720,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1504, y = -2064 },
            { x = 1104, y = -2160 },
            { x = 1056, y = -2160 },
            { x = 1056, y = -2192 },
            { x = 1552, y = -2192 },
            { x = 1552, y = -1456 },
            { x = 1504, y = -1456 }
          },
          properties = {}
        },
        {
          id = 318,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 976,
          y = -16,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1504, y = -2064 },
            { x = 1104, y = -2160 },
            { x = 1056, y = -2160 },
            { x = 1056, y = -2192 },
            { x = 1552, y = -2192 },
            { x = 1552, y = -1456 },
            { x = 1504, y = -1456 }
          },
          properties = {}
        },
        {
          id = 319,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 2960,
          y = 1456,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -1504, y = -2064 },
            { x = -1104, y = -2160 },
            { x = -1056, y = -2160 },
            { x = -1056, y = -2192 },
            { x = -1552, y = -2192 },
            { x = -1552, y = -1824 },
            { x = -1504, y = -1824 }
          },
          properties = {}
        },
        {
          id = 320,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 2960,
          y = 720,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -1504, y = -2064 },
            { x = -1104, y = -2160 },
            { x = -1056, y = -2160 },
            { x = -1056, y = -2192 },
            { x = -1552, y = -2192 },
            { x = -1552, y = -1456 },
            { x = -1504, y = -1456 }
          },
          properties = {}
        },
        {
          id = 321,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 2960,
          y = -16,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -1504, y = -2064 },
            { x = -1104, y = -2160 },
            { x = -1056, y = -2160 },
            { x = -1056, y = -2192 },
            { x = -1552, y = -2192 },
            { x = -1552, y = -1456 },
            { x = -1504, y = -1456 }
          },
          properties = {}
        },
        {
          id = 329,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 1904,
          y = -1440,
          width = 128,
          height = 128,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 330,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 1680,
          y = -1120,
          width = 320,
          height = 320,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["direction"] = { id = 260 }
          }
        },
        {
          id = 331,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 2080,
          y = -1248,
          width = 224,
          height = 224,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["direction"] = { id = 261 }
          }
        },
        {
          id = 337,
          name = "",
          type = "",
          shape = "ellipse",
          x = 112,
          y = -1072,
          width = 208,
          height = 208,
          rotation = 0,
          visible = true,
          properties = {
            ["x_axis"] = 1
          }
        },
        {
          id = 338,
          name = "",
          type = "MovableHitbox",
          shape = "polygon",
          x = 1359.02,
          y = -1578.96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1.3146, y = -159.201 },
            { x = -174.685, y = -159.201 },
            { x = -176, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 339,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 80,
          y = -1264,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -720 },
            { x = -176, y = -720 },
            { x = -176, y = 0 }
          },
          properties = {}
        },
        {
          id = 341,
          name = "",
          type = "StageThumbnail",
          shape = "rectangle",
          x = 1408,
          y = -736,
          width = 1120,
          height = 736,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 343,
          name = "",
          type = "",
          shape = "polygon",
          x = 528,
          y = -1248,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -16 },
            { x = 128, y = -16 },
            { x = 128, y = 0 }
          },
          properties = {}
        },
        {
          id = 344,
          name = "",
          type = "Path",
          shape = "point",
          x = 1119.02,
          y = -1482.96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["next"] = { id = 345 },
            ["target"] = { id = 338 }
          }
        },
        {
          id = 345,
          name = "",
          type = "PathNode",
          shape = "point",
          x = 1319.42,
          y = -1756.3,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["next"] = { id = 344 }
          }
        },
        {
          id = 346,
          name = "",
          type = "",
          shape = "polygon",
          x = 613.573,
          y = -1477.03,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 114.539, y = 93.1582 },
            { x = 230.605, y = -6.10874 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 347,
          name = "",
          type = "",
          shape = "polygon",
          x = 524.997,
          y = -1542.7,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 25.9621, y = 126.756 },
            { x = 238.241, y = 3.05437 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 348,
          name = "",
          type = "",
          shape = "polygon",
          x = 566.231,
          y = -1616,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 334.453, y = 236.714 },
            { x = 456.628, y = 109.957 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 349,
          name = "",
          type = "",
          shape = "polygon",
          x = 160,
          y = -1536.59,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -13.3708, y = 168.711 },
            { x = 178.629, y = 184.711 },
            { x = 178.629, y = -167.289 },
            { x = 114.629, y = 40.7111 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 350,
          name = "",
          type = "Fireflies",
          shape = "point",
          x = 656,
          y = -1360,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["count"] = 7
          }
        },
        {
          id = 353,
          name = "",
          type = "OneWayPlatform",
          shape = "point",
          x = -1560.4,
          y = -1605.96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["color"] = 0.4,
            ["other"] = { id = 354 }
          }
        },
        {
          id = 354,
          name = "",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -1368.4,
          y = -1861.96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 355,
          name = "",
          type = "",
          shape = "polygon",
          x = 160,
          y = -1856,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 944, y = 192 },
            { x = 144, y = -224 }
          },
          properties = {}
        },
        {
          id = 357,
          name = "",
          type = "Wall",
          shape = "polygon",
          x = -45.5501,
          y = -2154.87,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 45.5501, y = 986.87 },
            { x = 1549.55, y = 970.87 },
            { x = 1485.55, y = -133.13 }
          },
          properties = {
            ["type"] = "FLAT"
          }
        },
        {
          id = 358,
          name = "",
          type = "CameraBounds",
          shape = "polygon",
          x = -45.5501,
          y = -2154.87,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 45.5501, y = 986.87 },
            { x = 1549.55, y = 970.87 },
            { x = 1485.55, y = -133.13 }
          },
          properties = {
            ["type"] = "FLAT"
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 6,
      name = "front",
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
