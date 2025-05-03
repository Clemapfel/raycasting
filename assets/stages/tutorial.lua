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
  nextobjectid = 76,
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
          id = 3,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = 1149.04,
          y = -458.469,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 4,
          name = "",
          type = "",
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
          type = "",
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
          x = 14.9849,
          y = 1424,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 576, y = 0 },
            { x = 576, y = -336 },
            { x = 80, y = -336 },
            { x = 80, y = -368 },
            { x = 672, y = -368 },
            { x = 672, y = -336 },
            { x = 672, y = 0 },
            { x = 672, y = 80 },
            { x = 0, y = 80 }
          },
          properties = {}
        },
        {
          id = 44,
          name = "",
          type = "",
          shape = "polygon",
          x = 478.985,
          y = 1296,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = 0 },
            { x = -592, y = 0 },
            { x = -592, y = -432 },
            { x = -496, y = -432 },
            { x = -496, y = -32 },
            { x = -16, y = -32 }
          },
          properties = {}
        },
        {
          id = 45,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 590.985,
          y = 1248,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = -112 },
            { x = -160, y = -160 },
            { x = 0, y = -160 }
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
          x = 462.985,
          y = 1264,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 16, y = 32 },
            { x = 16, y = -16 },
            { x = -480, y = -16 },
            { x = -480, y = 0 }
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
          x = 574.985,
          y = 1520,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = -96 },
            { x = -80, y = -96 },
            { x = 16, y = -144 }
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
          x = 94.9849,
          y = 1088,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = -16, y = -48 },
            { x = 592, y = -48 },
            { x = 592, y = -32 },
            { x = 0, y = -32 }
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
          x = -16,
          y = 960,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 64, y = -80 },
            { x = 414.985, y = -80 },
            { x = 414.985, y = -160 },
            { x = 0, y = -160 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 52,
          name = "",
          type = "",
          shape = "polygon",
          x = 662.993,
          y = 816,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 105.007, y = 96 },
            { x = 105.007, y = -48 },
            { x = 9.00677, y = -48 },
            { x = 9.00677, y = -192 },
            { x = -6.99323, y = -192 },
            { x = -6.99323, y = -48 },
            { x = -6.99323, y = -32 },
            { x = 25.0068, y = -30.8418 },
            { x = 25.0068, y = 80 },
            { x = -6.99323, y = 80 },
            { x = -6.99323, y = 96 },
            { x = -6.99323, y = 224 },
            { x = 9.00677, y = 224 },
            { x = 9.00677, y = 96 }
          },
          properties = {}
        },
        {
          id = 53,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 656,
          y = 816,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 0, y = 80 },
            { x = 16, y = 80 },
            { x = 16, y = -32 }
          },
          properties = {
            ["slippery"] = true
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
          width = 1280,
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
          x = 2848,
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
          x = 2992,
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
          x = 3212.92,
          y = -608,
          width = 368,
          height = 81.3066,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 73,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 3312,
          y = -640,
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
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        }
      }
    }
  }
}
