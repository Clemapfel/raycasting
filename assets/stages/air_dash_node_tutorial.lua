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
  nextobjectid = 287,
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
          id = 160,
          name = "",
          type = "Wall",
          shape = "polygon",
          x = 1408,
          y = -736,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 768 },
            { x = 1168, y = 768 },
            { x = 1168, y = -1600 },
            { x = 0, y = -1600 }
          },
          properties = {
            ["type"] = "spheres"
          }
        },
        {
          id = 162,
          name = "",
          type = "OneWayPlatform",
          shape = "point",
          x = 1936,
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
          x = 1936,
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
          x = 64,
          y = -1312,
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
            { x = -16, y = 0 },
            { x = -16, y = 352 },
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
          id = 137,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 96,
          y = -1104,
          width = 256,
          height = 256,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_x"] = 1,
            ["axis_y"] = 0
          }
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
          type = "",
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
            { x = 448, y = -224 },
            { x = 896, y = -352 },
            { x = 928, y = -352 },
            { x = 928, y = -384 },
            { x = 448, y = -384 },
            { x = 448, y = -990.694 },
            { x = 896, y = -1088 },
            { x = 928, y = -1088 },
            { x = 928, y = -1120 },
            { x = 448, y = -1120 },
            { x = 448, y = -1984 },
            { x = 400, y = -1984 },
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
            { x = 448, y = -32 },
            { x = 448, y = 16 },
            { x = 1520, y = 16 },
            { x = 1520, y = -592 },
            { x = 1056, y = -688 },
            { x = 1024, y = -688 },
            { x = 1024, y = -720 },
            { x = 1520, y = -720 },
            { x = 1520, y = -1333.22 },
            { x = 1056, y = -1424 },
            { x = 1024, y = -1424 },
            { x = 1024, y = -1456 },
            { x = 1520, y = -1456 },
            { x = 1520, y = -2320 },
            { x = 1568, y = -2320 },
            { x = 1568, y = 48 },
            { x = 400, y = 48 },
            { x = 400, y = 16 },
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
          x = 1920,
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
          x = 1696,
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
          x = 2112,
          y = -480,
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
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 96, y = 32 },
            { x = 96, y = 0 }
          },
          properties = {
            ["axis_y"] = -1,
            ["render_priority"] = -1
          }
        },
        {
          id = 165,
          name = "",
          type = "CameraFit",
          shape = "polygon",
          x = 1823.87,
          y = -3810.12,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 16 },
            { x = 0, y = 768 },
            { x = 1152, y = 768 },
            { x = 1152, y = 16 }
          },
          properties = {}
        },
        {
          id = 178,
          name = "",
          type = "",
          shape = "polygon",
          x = -1700.47,
          y = 2416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 2138.63, y = 0 },
            { x = 2138.63, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 191,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -1284.63,
          y = 2211.56,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 192 }
          }
        },
        {
          id = 192,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -1214.41,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 193,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -1214.41,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 194 }
          }
        },
        {
          id = 194,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -1027.15,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 195,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -769.667,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 196 }
          }
        },
        {
          id = 196,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -676.037,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 197,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -863.297,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 198 }
          }
        },
        {
          id = 198,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -769.667,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 199,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -1027.15,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 200 }
          }
        },
        {
          id = 200,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -956.926,
          y = 2211.56,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 201,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -1027.15,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 202 }
          }
        },
        {
          id = 202,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -1214.41,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 203,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -1214.41,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 204 }
          }
        },
        {
          id = 204,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -1284.63,
          y = 2211.56,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 205,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -559,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 206 }
          }
        },
        {
          id = 206,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -465.371,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 207,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -676.037,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 208 }
          }
        },
        {
          id = 208,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -559,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 219,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -956.926,
          y = 2211.56,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 220 }
          }
        },
        {
          id = 220,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -1027.15,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 223,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -348.334,
          y = 2211.56,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 224 }
          }
        },
        {
          id = 224,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -278.111,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 225,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -278.111,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 226 }
          }
        },
        {
          id = 226,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -90.8519,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 227,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -90.8519,
          y = 2071.11,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 228 }
          }
        },
        {
          id = 228,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -20.6296,
          y = 2211.56,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 229,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -90.8519,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 230 }
          }
        },
        {
          id = 230,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -278.111,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 231,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -278.111,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 232 }
          }
        },
        {
          id = 232,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -348.334,
          y = 2211.56,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
          }
        },
        {
          id = 233,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = -20.6296,
          y = 2211.56,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25,
            ["other"] = { id = 234 }
          }
        },
        {
          id = 234,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -90.8519,
          y = 2352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["angle_range"] = 0.25
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
          visible = true,
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
          id = 241,
          name = "",
          type = "CameraFit",
          shape = "rectangle",
          x = -1408,
          y = 1808,
          width = 1504,
          height = 816,
          rotation = 0,
          visible = false,
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
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 96, y = 32 },
            { x = 96, y = 0 }
          },
          properties = {
            ["axis_y"] = -1,
            ["render_priority"] = -1
          }
        },
        {
          id = 257,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 1924.95,
          y = -1432.23,
          width = 128,
          height = 128,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 258,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 1700.95,
          y = -1112.23,
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
          id = 259,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 2116.95,
          y = -1208.23,
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
          id = 267,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = 1984,
          y = -2256,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 269 }
          }
        },
        {
          id = 269,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = 1984,
          y = -2480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 274,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = 304,
          y = -1344,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 275 },
            ["velocity"] = 4
          }
        },
        {
          id = 275,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = 384,
          y = -1472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["velocity"] = 4
          }
        },
        {
          id = 276,
          name = "",
          type = "",
          shape = "polygon",
          x = -142.19,
          y = -2128.78,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 190.19, y = 0.783262 },
            { x = 190.94, y = 50.782 },
            { x = -1.81028, y = 48.7833 }
          },
          properties = {}
        },
        {
          id = 278,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = 384,
          y = -1472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 279 },
            ["velocity"] = 4
          }
        },
        {
          id = 279,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = 464,
          y = -1344,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["velocity"] = 4
          }
        },
        {
          id = 281,
          name = "",
          type = "AirDashNode",
          shape = "point",
          x = 464,
          y = -1344,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 282 },
            ["velocity"] = 4
          }
        },
        {
          id = 282,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = 304,
          y = -1344,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["velocity"] = 4
          }
        },
        {
          id = 283,
          name = "",
          type = "MovableHitbox",
          shape = "polygon",
          x = 592,
          y = -1104,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -414.937 },
            { x = -592, y = -288 },
            { x = -512, y = -544 },
            { x = 0, y = -528 },
            { x = 208, y = -528 },
            { x = 208, y = 0 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 284,
          name = "",
          type = "Path",
          shape = "point",
          x = 728.599,
          y = -1063.61,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["next"] = { id = 285 },
            ["target"] = { id = 283 }
          }
        },
        {
          id = 285,
          name = "",
          type = "PathNode",
          shape = "point",
          x = 224,
          y = -1952,
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
