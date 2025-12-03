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
  nextlayerid = 6,
  nextobjectid = 83,
  properties = {},
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
          id = 22,
          name = "",
          type = "ControlIndicatorTrigger",
          shape = "rectangle",
          x = -2031.82,
          y = 497.413,
          width = 554.03,
          height = 971.316,
          rotation = 0,
          visible = true,
          properties = {
            ["type"] = "AIR_DASH"
          }
        },
        {
          id = 32,
          name = "",
          type = "ControlIndicatorTrigger",
          shape = "rectangle",
          x = -2147.13,
          y = 2021.16,
          width = 700.073,
          height = 1094.81,
          rotation = 0,
          visible = true,
          properties = {
            ["type"] = "AIR_DASH"
          }
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
          id = 1,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -96,
          y = 16,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1200, y = 0 },
            { x = 1200, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 2,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -1367.8,
          y = 1984.3,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "Goal",
          type = "Goal",
          shape = "point",
          x = 992,
          y = 0,
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
          x = 512,
          y = 0,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 7,
          name = "Introduce Controls",
          type = "Hitbox",
          shape = "polygon",
          x = -2560,
          y = 1472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1074.38, y = 0 },
            { x = 1072, y = -944 },
            { x = 1040, y = -976 },
            { x = 1072, y = -976 },
            { x = 1264, y = -976 },
            { x = 1264, y = 144 },
            { x = 0, y = 144 }
          },
          properties = {}
        },
        {
          id = 11,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -1568,
          y = 608,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 48, y = -112 },
            { x = 80, y = -80 },
            { x = 80, y = 864 },
            { x = 48, y = 864 }
          },
          properties = {}
        },
        {
          id = 12,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -1904,
          y = 1024,
          width = 300,
          height = 300,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 17,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -1904,
          y = 560,
          width = 300,
          height = 300,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 18,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -2048,
          y = 608,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = -352 },
            { x = 704, y = -352 },
            { x = 704, y = -304 },
            { x = 160, y = -304 },
            { x = 32, y = -192 },
            { x = 32, y = 816 },
            { x = -32, y = 800 }
          },
          properties = {}
        },
        {
          id = 19,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -2016,
          y = 1440,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = 16 },
            { x = -64, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 20,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -2080,
          y = 1408,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 48 },
            { x = 64, y = 32 },
            { x = 64, y = 16 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0,
            ["render_priority"] = -2
          }
        },
        {
          id = 24,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -1872,
          y = 2689.02,
          width = 300,
          height = 300,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 25,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -1872,
          y = 2160,
          width = 300,
          height = 300,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 27,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -2064,
          y = 2480,
          width = 150,
          height = 150,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 29,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -2160,
          y = 2192,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -48, y = -384 },
            { x = 880, y = -384 },
            { x = 880, y = -336 },
            { x = 144, y = -336 },
            { x = 16, y = -224 },
            { x = 16, y = 864 },
            { x = -48, y = 848 }
          },
          properties = {}
        },
        {
          id = 33,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -2208,
          y = 3040,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 48 },
            { x = 64, y = 32 },
            { x = 64, y = 16 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0,
            ["render_priority"] = -2
          }
        },
        {
          id = 34,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -2144,
          y = 3072,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = 16 },
            { x = -64, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 35,
          name = "Different Sizes",
          type = "Hitbox",
          shape = "polygon",
          x = -2448,
          y = 3100.41,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -3.62323, y = 3.58556 },
            { x = 1004.38, y = 3.58556 },
            { x = 1004.38, y = -1052.41 },
            { x = 972.377, y = -1084.41 },
            { x = 1180.38, y = -1084.41 },
            { x = 1180.38, y = 163.586 },
            { x = -3.62323, y = 163.586 }
          },
          properties = {}
        },
        {
          id = 36,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -1475.62,
          y = 2016,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 1088 },
            { x = 32, y = 1088 },
            { x = 32, y = 32 }
          },
          properties = {}
        },
        {
          id = 37,
          name = "Horizontal Practice",
          type = "Hitbox",
          shape = "polygon",
          x = -880,
          y = 3453.29,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -3.62323, y = 3.58556 },
            { x = 224.103, y = 2.71242 },
            { x = 224.103, y = 34.7124 },
            { x = 1472.1, y = 34.7124 },
            { x = 1472.1, y = 2.71242 },
            { x = 1664.1, y = 2.71242 },
            { x = 1664.1, y = 162.712 },
            { x = -3.62323, y = 163.586 }
          },
          properties = {}
        },
        {
          id = 39,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -512,
          y = 3136,
          width = 250,
          height = 250,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 42,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -224,
          y = 3136,
          width = 250,
          height = 250,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 45,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 48,
          y = 3136,
          width = 250,
          height = 250,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 46,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 320,
          y = 3136,
          width = 250,
          height = 250,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 47,
          name = "",
          type = "DeceleratorSurface",
          shape = "polygon",
          x = -655.897,
          y = 3456,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 1248, y = 32 },
            { x = 1248, y = 0 }
          },
          properties = {}
        },
        {
          id = 48,
          name = "",
          type = "",
          shape = "polygon",
          x = -832,
          y = 2400,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -128, y = 128 },
            { x = 2560, y = 128 },
            { x = 2560, y = 256 },
            { x = -128, y = 272 }
          },
          properties = {}
        },
        {
          id = 50,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -432,
          y = 2384,
          width = 200,
          height = 200,
          rotation = 0,
          visible = true,
          properties = {
            ["indicator_always_visible"] = true
          }
        },
        {
          id = 51,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -432,
          y = 2064,
          width = 200,
          height = 200,
          rotation = 0,
          visible = true,
          properties = {
            ["indicator_always_visible"] = true
          }
        },
        {
          id = 64,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -112,
          y = 2112,
          width = 200,
          height = 200,
          rotation = 0,
          visible = true,
          properties = {
            ["indicator_always_visible"] = true
          }
        },
        {
          id = 66,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -432,
          y = 1728,
          width = 200,
          height = 200,
          rotation = 0,
          visible = true,
          properties = {
            ["indicator_always_visible"] = true
          }
        },
        {
          id = 68,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -192,
          y = 1632,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 48.0896 },
            { x = 22.6956, y = -32 },
            { x = 48, y = 48.0896 },
            { x = 48, y = 800 },
            { x = 0, y = 800 }
          },
          properties = {
            ["unjumpable"] = true
          }
        },
        {
          id = 69,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 80,
          y = 1920,
          width = 200,
          height = 200,
          rotation = 0,
          visible = true,
          properties = {
            ["indicator_always_visible"] = true
          }
        },
        {
          id = 70,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 272,
          y = 1728,
          width = 200,
          height = 200,
          rotation = 0,
          visible = true,
          properties = {
            ["indicator_always_visible"] = true
          }
        },
        {
          id = 71,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 528,
          y = 1712,
          width = 200,
          height = 200,
          rotation = 0,
          visible = true,
          properties = {
            ["indicator_always_visible"] = true
          }
        },
        {
          id = 72,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 784,
          y = 1712,
          width = 200,
          height = 200,
          rotation = 0,
          visible = true,
          properties = {
            ["indicator_always_visible"] = true
          }
        },
        {
          id = 73,
          name = "",
          type = "",
          shape = "polygon",
          x = 1024,
          y = 1888,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 48 },
            { x = 224, y = 48 },
            { x = 224, y = 0 }
          },
          properties = {}
        },
        {
          id = 77,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = -352,
          y = 2016,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 583.211, y = -349.832 },
            { x = 1376, y = -352 },
            { x = 1376, y = -384 },
            { x = 583.211, y = -381.832 }
          },
          properties = {}
        },
        {
          id = 78,
          name = "",
          type = "Coin",
          shape = "point",
          x = -128,
          y = 2128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 79,
          name = "",
          type = "DeceleratorSurface",
          shape = "polygon",
          x = -656,
          y = 3072,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 1248, y = 32 },
            { x = 1248, y = 0 }
          },
          properties = {}
        },
        {
          id = 80,
          name = "Horizontal Practice",
          type = "Hitbox",
          shape = "polygon",
          x = -896,
          y = 2944,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -3.62323, y = 3.58556 },
            { x = 1664.1, y = 2.71242 },
            { x = 1664, y = 160 },
            { x = 1488, y = 160 },
            { x = 1488, y = 128 },
            { x = 240, y = 128 },
            { x = 240, y = 160 },
            { x = 0, y = 160 }
          },
          properties = {}
        },
        {
          id = 82,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = -677.768,
          y = 3336.25,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
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
