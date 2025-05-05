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
  nextlayerid = 4,
  nextobjectid = 202,
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
      name = "bg",
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
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 32,
      height = 32,
      id = 1,
      name = "tiles",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      chunks = {
        {
          x = 288, y = 16, width = 16, height = 16,
          data = {
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 75,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
          }
        },
        {
          x = 16, y = 64, width = 16, height = 16,
          data = {
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
      name = "objects",
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
          id = 4,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -48,
          y = 224,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 416, y = 0 },
            { x = 416, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 5,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -45.9937,
          y = 228.841,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -256 },
            { x = -32, y = -256 },
            { x = -32, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 6,
          name = "Jump 01",
          type = "Hitbox",
          shape = "polygon",
          x = 432,
          y = 224,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 112, y = 0 },
            { x = 112, y = 64 },
            { x = 672, y = 64 },
            { x = 672, y = 0 },
            { x = 960, y = 0 },
            { x = 960, y = -64 },
            { x = 1248, y = -64 },
            { x = 1248, y = -128 },
            { x = 1744, y = -128 },
            { x = 1744, y = 64 },
            { x = 2464.13, y = 64 },
            { x = 2464, y = -80 },
            { x = 2864, y = -80 },
            { x = 2864, y = 64.6396 },
            { x = 3680, y = 64 },
            { x = 3680, y = -160 },
            { x = 4192, y = -160 },
            { x = 4192, y = 16 },
            { x = 5152, y = 16 },
            { x = 5152, y = -160 },
            { x = 5360, y = -160 },
            { x = 5360, y = 112 },
            { x = 5184, y = 112 },
            { x = 0, y = 112 },
            { x = 0, y = 32 },
            { x = -48, y = 32 },
            { x = -48, y = 0 }
          },
          properties = {}
        },
        {
          id = 7,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 544,
          y = 224,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 8,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 896,
          y = 224,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 192, y = 0 },
            { x = 192, y = 64 },
            { x = 208, y = 64 },
            { x = 208, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 9,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1264,
          y = 160,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 128, y = 0 },
            { x = 112, y = 0 },
            { x = 112, y = 64 },
            { x = 128, y = 64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 10,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1344,
          y = 240,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 320, y = -144 },
            { x = 320, y = -80 },
            { x = 336, y = -80 },
            { x = 336, y = -144 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 11,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1648,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 528, y = 0 },
            { x = 528, y = 192 },
            { x = 720, y = 192 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 12,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2688,
          y = 176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 64, y = 0 },
            { x = 64, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 15,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2896,
          y = 288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = 0 },
            { x = -32, y = -176 },
            { x = 416, y = -176 },
            { x = 576, y = 0 },
            { x = 400, y = 0 },
            { x = 400, y = -144 },
            { x = 0, y = -144 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 33,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3808,
          y = 192,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 0 },
            { x = 32, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 35,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3952,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 0 },
            { x = 32, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 36,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4144,
          y = 496,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = -208 },
            { x = -48, y = -208 },
            { x = -48, y = -432 },
            { x = -32, y = -432 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 37,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4640,
          y = 288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -48 },
            { x = -16, y = -48 },
            { x = -16, y = -224 },
            { x = 0, y = -224 },
            { x = 0, y = -144 },
            { x = 32, y = -144 },
            { x = 32, y = -128 },
            { x = 0, y = -128 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 40,
          name = "Sprint",
          type = "Hitbox",
          shape = "polygon",
          x = 4928,
          y = 80,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 336, y = 0 },
            { x = 336, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 41,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 5584,
          y = 288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -48 },
            { x = -16, y = -48 },
            { x = -16, y = -224 },
            { x = 0, y = -224 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 42,
          name = "",
          type = "Coin",
          shape = "point",
          x = 5272.58,
          y = 89.1503,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 43,
          name = "Walljump",
          type = "Hitbox",
          shape = "polygon",
          x = 158.985,
          y = 2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1.01513, y = 0 },
            { x = 577.015, y = 0 },
            { x = 578.03, y = -384 },
            { x = 82.0303, y = -384 },
            { x = 82.0303, y = -416 },
            { x = 674.03, y = -416 },
            { x = 674.03, y = -384 },
            { x = 673.015, y = 0 },
            { x = 673.015, y = 80 },
            { x = 1.01513, y = 80 }
          },
          properties = {}
        },
        {
          id = 44,
          name = "",
          type = "",
          shape = "polygon",
          x = 622.985,
          y = 2304,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -14.9849, y = 0 },
            { x = -590.985, y = 0 },
            { x = -590.985, y = -432 },
            { x = -494.985, y = -432 },
            { x = -494.985, y = -32 },
            { x = -14.9849, y = -32 }
          },
          properties = {}
        },
        {
          id = 45,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 734.985,
          y = 2256,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1.01513, y = 0 },
            { x = -61.9697, y = -160 },
            { x = -157.97, y = -208 },
            { x = 2.03025, y = -208 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 46,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 606.985,
          y = 2272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1.01513, y = 0 },
            { x = 1.01513, y = 32 },
            { x = 17.0151, y = 32 },
            { x = 17.0151, y = -16 },
            { x = -478.985, y = -16 },
            { x = -478.985, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 48,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 718.985,
          y = 2528,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 17.0151, y = -96 },
            { x = -78.9849, y = -96 },
            { x = 17.0151, y = -144 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 49,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 238.985,
          y = 2096,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 2.03025, y = -48 },
            { x = -13.9697, y = -48 },
            { x = -13.9697, y = -96 },
            { x = 594.03, y = -96 },
            { x = 594.03, y = -80 },
            { x = 2.03025, y = -80 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 50,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 128,
          y = 1936,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1.01513, y = 0 },
            { x = 65.0151, y = -80 },
            { x = 544, y = -80 },
            { x = 576, y = -48 },
            { x = 577.015, y = -160 },
            { x = 1.01513, y = -160 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 53,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1168,
          y = 1387.43,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -11.4286 },
            { x = 0, y = 100.571 },
            { x = 16, y = 100.571 },
            { x = 16, y = -11.4286 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 60,
          name = "",
          type = "",
          shape = "polygon",
          x = -80,
          y = -432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 784, y = 0 },
            { x = 784, y = -256 },
            { x = 800, y = -256 },
            { x = 803.097, y = 0 },
            { x = 1312, y = 0 },
            { x = 1312, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 61,
          name = "",
          type = "",
          shape = "polygon",
          x = 400,
          y = -480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -16 },
            { x = 0, y = -320 },
            { x = 624, y = -320 },
            { x = 624, y = 0 },
            { x = 608, y = 0 },
            { x = 608, y = -304 },
            { x = 16, y = -304 },
            { x = 16, y = -16 }
          },
          properties = {}
        },
        {
          id = 62,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 1008,
          y = -784,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 352 },
            { x = -592, y = 352 },
            { x = -592, y = 0 }
          },
          properties = {}
        },
        {
          id = 63,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 1024,
          y = -400,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 6122.31, y = 3.36817 },
            { x = 6122.31, y = 35.3682 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 65,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1488,
          y = -624,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 208, y = 0 },
            { x = 208, y = 144 },
            { x = 0, y = 144 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0
          }
        },
        {
          id = 66,
          name = "",
          type = "BubbleField",
          shape = "rectangle",
          x = 1488,
          y = -784,
          width = 784,
          height = 304,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 68,
          name = "",
          type = "BubbleField",
          shape = "rectangle",
          x = 2336,
          y = -784,
          width = 80,
          height = 304,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 69,
          name = "",
          type = "BubbleField",
          shape = "rectangle",
          x = 2480,
          y = -784,
          width = 80,
          height = 304,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 70,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 7040,
          y = -405.828,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 256, y = 0 },
            { x = 256, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 71,
          name = "",
          type = "Goal",
          shape = "rectangle",
          x = 7152,
          y = -1280,
          width = 32,
          height = 1242.17,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 72,
          name = "",
          type = "BubbleField",
          shape = "rectangle",
          x = 2640,
          y = -784,
          width = 992,
          height = 304,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 73,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2731.78,
          y = -979.853,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 160, y = 0 },
            { x = 160, y = 176 },
            { x = 0, y = 176 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0
          }
        },
        {
          id = 76,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 992,
          y = 1275.43,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -11.4286 },
            { x = 0, y = 100.571 },
            { x = 16, y = 100.571 },
            { x = 16, y = -11.4286 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 77,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1168,
          y = 1163.43,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -11.4286 },
            { x = 0, y = 100.571 },
            { x = 16, y = 100.571 },
            { x = 16, y = -11.4286 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 78,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 992,
          y = 1051.43,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -11.4286 },
            { x = 0, y = 100.571 },
            { x = 16, y = 100.571 },
            { x = 16, y = -11.4286 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 83,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1168,
          y = 1024,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 16 },
            { x = 0, y = 32 },
            { x = 416, y = 32 },
            { x = 416, y = -383.988 },
            { x = 592, y = -384 },
            { x = 592, y = -432 },
            { x = 352, y = -432 },
            { x = 352, y = 16 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 89,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 816,
          y = 1616,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1.01513, y = -64 },
            { x = 1.01513, y = 384 },
            { x = 17.0151, y = 384 },
            { x = 17.0151, y = -48 },
            { x = 352, y = -48 },
            { x = 352, y = -64 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 91,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 704,
          y = 1632,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -240 },
            { x = 1.01513, y = 256 },
            { x = 17.0151, y = 256 },
            { x = 16, y = -240 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 93,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 704,
          y = 1376,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 304, y = 16 },
            { x = 304, y = 16 },
            { x = 304, y = 0 },
            { x = 288, y = 0 },
            { x = 288, y = -112 },
            { x = 304, y = -112 },
            { x = 304, y = -224 },
            { x = 288, y = -224 },
            { x = 288, y = -336 },
            { x = 304, y = -336 },
            { x = 304, y = -432 },
            { x = 704, y = -432 },
            { x = 704, y = -878.102 },
            { x = 1056, y = -880 },
            { x = 1056, y = -944 },
            { x = 624, y = -944 },
            { x = 624, y = -512 },
            { x = 208, y = -512 },
            { x = 208, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 95,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1168,
          y = 1488,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -432 },
            { x = 0, y = -336 },
            { x = 16, y = -336 },
            { x = 16, y = -224 },
            { x = 0, y = -224 },
            { x = 0, y = -112 },
            { x = 16, y = -112 },
            { x = 16, y = 0 },
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 96, y = 80 },
            { x = 96, y = -432 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 98,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2384,
          y = 2000,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 112 },
            { x = 16, y = 112 },
            { x = 16, y = 0 }
          },
          properties = {}
        },
        {
          id = 99,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2704,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 208, y = 0 },
            { x = 208, y = 48 },
            { x = 0, y = 48 }
          },
          properties = {}
        },
        {
          id = 100,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2384,
          y = 2000,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 8.52091, y = -15.3023 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 101,
          name = "",
          type = "Coin",
          shape = "point",
          x = 2416,
          y = 2080,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 102,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2192,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = 48 },
            { x = 0, y = 48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 103,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2688,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = 48 },
            { x = 0, y = 48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 108,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3424,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 336, y = -416 },
            { x = 544, y = -416 },
            { x = 544, y = 48 },
            { x = 336, y = 48 }
          },
          properties = {}
        },
        {
          id = 111,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2912,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = 48 },
            { x = 0, y = 48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 112,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3408,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 336, y = -416 },
            { x = 352, y = -416 },
            { x = 352, y = 48 },
            { x = 336, y = 48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 113,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2384,
          y = 2112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 7.2836, y = 15.2747 },
            { x = 16, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 114,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3104,
          y = 2016,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 16, y = 80 },
            { x = 16, y = 0 }
          },
          properties = {}
        },
        {
          id = 115,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3104,
          y = 2016,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 8.52091, y = -15.3023 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 117,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3104,
          y = 2128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 7.2836, y = -16.7253 },
            { x = 16, y = -32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 118,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3312,
          y = 1904,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 16, y = 80 },
            { x = 16, y = 0 }
          },
          properties = {}
        },
        {
          id = 119,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3312,
          y = 1904,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 8.52091, y = -15.3023 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 120,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3312,
          y = 2016,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 7.2836, y = -16.7253 },
            { x = 16, y = -32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 121,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3520,
          y = 1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 16, y = 80 },
            { x = 16, y = 0 }
          },
          properties = {}
        },
        {
          id = 122,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3520,
          y = 1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 8.52091, y = -15.3023 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 123,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3520,
          y = 1824,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -48 },
            { x = 7.2836, y = -32.7253 },
            { x = 16, y = -48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 138,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3104,
          y = 1760,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 16, y = 80 },
            { x = 16, y = 0 }
          },
          properties = {}
        },
        {
          id = 139,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3104,
          y = 1760,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 8.52091, y = -15.3023 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 140,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3104,
          y = 1872,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 7.2836, y = -16.7253 },
            { x = 16, y = -32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 141,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3312,
          y = 1664,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 16, y = 80 },
            { x = 16, y = 0 }
          },
          properties = {}
        },
        {
          id = 142,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3312,
          y = 1664,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 8.52091, y = -15.3023 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 143,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3312,
          y = 1776,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 7.2836, y = -16.7253 },
            { x = 16, y = -32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 154,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = 2038.3,
          y = 1272.68,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 155,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1168,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = 112, y = -0.6977 },
            { x = 112, y = 47.3023 },
            { x = -80, y = 47.3023 }
          },
          properties = {}
        },
        {
          id = 156,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 1216,
          y = 2224,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -126.316, y = -0.6977 },
            { x = 2753.68, y = 0 },
            { x = 2753.68, y = 64 },
            { x = -126.316, y = 63.3023 }
          },
          properties = {}
        },
        {
          id = 157,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1552,
          y = 2000,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -80, y = 111.302 },
            { x = -64, y = 111.302 },
            { x = -64, y = -0.6977 }
          },
          properties = {}
        },
        {
          id = 158,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1872,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 112, y = 0 },
            { x = 320, y = 0 },
            { x = 320, y = 48 },
            { x = 112, y = 48 }
          },
          properties = {}
        },
        {
          id = 159,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1552,
          y = 2000,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -64, y = -0.6977 },
            { x = -71.4791, y = -16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 161,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1360,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -64, y = -0.6977 },
            { x = -64, y = 47.3023 },
            { x = -80, y = 47.3023 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 162,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1856,
          y = 2176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 112, y = 0 },
            { x = 128, y = 0 },
            { x = 128, y = 48 },
            { x = 112, y = 48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 163,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1552,
          y = 2112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -72.7164, y = 14.577 },
            { x = -64, y = -0.6977 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 164,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1696,
          y = 2000,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -80, y = 111.302 },
            { x = -64, y = 111.302 },
            { x = -64, y = -0.6977 }
          },
          properties = {}
        },
        {
          id = 165,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1696,
          y = 2000,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -64, y = -0.6977 },
            { x = -71.4791, y = -16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 166,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1696,
          y = 2112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -72.7164, y = 14.577 },
            { x = -64, y = -0.6977 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 167,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1840,
          y = 2000,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -80, y = 111.302 },
            { x = -64, y = 111.302 },
            { x = -64, y = -0.6977 }
          },
          properties = {}
        },
        {
          id = 168,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1840,
          y = 2000,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -64, y = -0.6977 },
            { x = -71.4791, y = -16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 169,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1840,
          y = 2112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -0.6977 },
            { x = -72.7164, y = 14.577 },
            { x = -64, y = -0.6977 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 171,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1573.33,
          y = 2944,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -533.333, y = -0.6977 },
            { x = 746.667, y = -0.6977 },
            { x = 746.667, y = 47.3023 },
            { x = -533.333, y = 47.3023 }
          },
          properties = {}
        },
        {
          id = 172,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 1040,
          y = 2992,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -384 },
            { x = -80, y = -384 },
            { x = -80, y = 112 },
            { x = 1392, y = 96 },
            { x = 1376, y = -384 },
            { x = 1280, y = -384 },
            { x = 1280, y = 0 }
          },
          properties = {}
        },
        {
          id = 173,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 1322.39,
          y = 2784.24,
          width = 0,
          height = 0,
          rotation = 139,
          visible = true,
          polygon = {
            { x = -60.0346, y = 11.7379 },
            { x = 75.3992, y = 2.26747 },
            { x = 70.3041, y = -113.812 },
            { x = -57.4297, y = -113.199 }
          },
          properties = {}
        },
        {
          id = 174,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 1520,
          y = 2800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 48, y = 64 },
            { x = 144, y = 48 },
            { x = 32, y = -160 },
            { x = 48, y = 0 }
          },
          properties = {}
        },
        {
          id = 175,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 1328,
          y = 2688,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 160, y = -32 },
            { x = 96, y = -96 },
            { x = 0, y = -80 }
          },
          properties = {}
        },
        {
          id = 178,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = 2304,
          y = 2368,
          width = 16,
          height = 575.087,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 180,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = 1040,
          y = 2368,
          width = 19.0575,
          height = 576,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 181,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 1184,
          y = 2724.86,
          width = 0,
          height = 0,
          rotation = 90,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 109.107, y = -12.123 },
            { x = 36.3691, y = -84.8611 }
          },
          properties = {}
        },
        {
          id = 182,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1952,
          y = 1312,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 160, y = 0 },
            { x = 160, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 184,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 1792,
          y = 1344,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1840, y = 0 },
            { x = 1840, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {}
        },
        {
          id = 185,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2112,
          y = 1312,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 64, y = 0 },
            { x = 64, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 186,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2176,
          y = 1248,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = 0 },
            { x = -32, y = -48 },
            { x = -32, y = -240 },
            { x = 0, y = -240 },
            { x = 0, y = -192 },
            { x = -16, y = -192 },
            { x = -16, y = -192 },
            { x = -16, y = -48 },
            { x = 0, y = -48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 187,
          name = "",
          type = "",
          shape = "polygon",
          x = 2176,
          y = 1200,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = -16, y = -144 },
            { x = 0, y = -144 }
          },
          properties = {}
        },
        {
          id = 188,
          name = "",
          type = "",
          shape = "polygon",
          x = 2416,
          y = 1008,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = -16, y = -64 },
            { x = 0, y = -64 }
          },
          properties = {
            ["unjumpable"] = true
          }
        },
        {
          id = 189,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2416,
          y = 1104,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = -96 },
            { x = 0, y = -96 },
            { x = 0, y = -160 },
            { x = -16, y = -160 },
            { x = -16, y = -192 },
            { x = -16, y = -208 },
            { x = 0, y = -208 },
            { x = 0, y = -192 },
            { x = 32, y = -192 },
            { x = 80, y = -112 },
            { x = 80, y = -96 },
            { x = 64, y = -96 },
            { x = 64, y = 16 },
            { x = -16, y = -80 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 190,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2416,
          y = 880,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 32, y = 32 },
            { x = 32, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {
            ["unjumpable"] = true
          }
        },
        {
          id = 191,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2480,
          y = 976,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 144 },
            { x = 16, y = 144 },
            { x = 16, y = 32 }
          },
          properties = {
            ["unjumpable"] = true
          }
        },
        {
          id = 192,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2688,
          y = 976,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 176 },
            { x = 32, y = 176 },
            { x = 32, y = 32 }
          },
          properties = {}
        },
        {
          id = 193,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2688,
          y = 976,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -128, y = -144 },
            { x = 160, y = -144 },
            { x = 160, y = -32 },
            { x = 32, y = 32 },
            { x = 0, y = 32 },
            { x = -128, y = -32 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 194,
          name = "",
          type = "",
          shape = "polygon",
          x = 2688,
          y = 1168,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 48 },
            { x = 48, y = 48 },
            { x = 48, y = 32 }
          },
          properties = {}
        },
        {
          id = 196,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3072,
          y = 976,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 160 },
            { x = 32, y = 160 },
            { x = 32, y = 32 }
          },
          properties = {}
        },
        {
          id = 197,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2688,
          y = 1184,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 160 },
            { x = 48, y = 160 },
            { x = 48, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 198,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3072,
          y = 1104,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 240 },
            { x = 32, y = 240 },
            { x = 32, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 199,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3072,
          y = 1008,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = -32 },
            { x = 32, y = 0 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 200,
          name = "",
          type = "",
          shape = "polygon",
          x = 3328,
          y = 1168,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 160, y = 32 },
            { x = 160, y = 48 },
            { x = 304, y = 48 },
            { x = 304, y = 32 }
          },
          properties = {}
        },
        {
          id = 201,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3328,
          y = 1184,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 160, y = 32 },
            { x = 160, y = 160 },
            { x = 304, y = 160 },
            { x = 304, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        }
      }
    }
  }
}
