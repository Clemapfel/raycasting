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
  nextobjectid = 165,
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
      objects = {
        {
          id = 161,
          name = "",
          type = "CameraFit",
          shape = "polygon",
          x = 1408,
          y = -736,
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
        }
      }
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
          visible = false,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 768 },
            { x = 1152, y = 768 },
            { x = 1152, y = -448 },
            { x = 0, y = -448 }
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
          x = -1888,
          y = 1344,
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
            { x = 400, y = -384 },
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
            { x = 448, y = 10.431 },
            { x = 1520, y = 16 },
            { x = 1520, y = -592 },
            { x = 1056, y = -688 },
            { x = 1024, y = -688 },
            { x = 1024, y = -720 },
            { x = 1552, y = -720 },
            { x = 1552, y = 48 },
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
          width = 330.286,
          height = 330.571,
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
