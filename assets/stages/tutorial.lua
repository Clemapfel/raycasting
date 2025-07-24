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
  nextlayerid = 5,
  nextobjectid = 808,
  properties = {
    ["title"] = "Not a Tutorial"
  },
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
        },
        {
          x = 144, y = 160, width = 16, height = 16,
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
            0, 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
          }
        },
        {
          x = 80, y = 240, width = 16, height = 16,
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
            0, 0, 0, 0, 0, 0, 0, 0, 0, 75, 0, 0, 0, 0, 0, 0,
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
          type = "Hitbox",
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
          type = "Hitbox",
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
          type = "Hitbox",
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
          x = -1854.11,
          y = 866.468,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["value"] = 12321312.123
          }
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
            { x = -533.33, y = 0 },
            { x = 1386.67, y = 0 },
            { x = 1386.67, y = 48 },
            { x = -533.333, y = 47.3023 }
          },
          properties = {}
        },
        {
          id = 178,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = 3081.58,
          y = 2395.15,
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
          type = "Hitbox",
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
          type = "Hitbox",
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
            { x = 0, y = -192 },
            { x = 16, y = -192 },
            { x = 32, y = -208 },
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
          id = 196,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3072,
          y = 960,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 48 },
            { x = 0, y = 240 },
            { x = 32, y = 240 },
            { x = 32, y = 48 }
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
            { x = 0, y = 16 },
            { x = 0, y = 160 },
            { x = 48, y = 160 },
            { x = 48, y = 16 },
            { x = 32, y = 32 },
            { x = 16, y = 32 }
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
          y = 1177.85,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 22.1538 },
            { x = 0, y = 166.154 },
            { x = 32, y = 166.154 },
            { x = 32, y = 22.1538 }
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
          type = "Hitbox",
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
        },
        {
          id = 202,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2688,
          y = 1200,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 48, y = 0 },
            { x = 32, y = 16 },
            { x = 16, y = 16 }
          },
          properties = {}
        },
        {
          id = 203,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2400,
          y = 896,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 48, y = 0 },
            { x = 32, y = 16 },
            { x = 16, y = 16 }
          },
          properties = {}
        },
        {
          id = 204,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 1840,
          y = 1408,
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
          id = 209,
          name = "",
          type = "BubbleField",
          shape = "ellipse",
          x = 346.814,
          y = 3043.07,
          width = 514.478,
          height = 519.592,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 550,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 1296,
          y = 848,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 336, y = 0 },
            { x = 336, y = -464 },
            { x = -48, y = -448 }
          },
          properties = {}
        },
        {
          id = 551,
          name = "",
          type = "Checkpoint",
          shape = "point",
          x = 1805.4,
          y = 2859.66,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 553,
          name = "",
          type = "Goal",
          shape = "point",
          x = 2507.04,
          y = 2806.84,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 554,
          name = "",
          type = "Checkpoint",
          shape = "point",
          x = 2080,
          y = 2800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 557,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = -320,
          y = 3136.3,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -1040, y = 0 },
            { x = -922.877, y = -115.332 },
            { x = -872.41, y = -40.121 },
            { x = -738.042, y = 5.42734 },
            { x = -538.514, y = 8.00006 },
            { x = -451.948, y = -260.088 },
            { x = -432.902, y = -146.256 },
            { x = -348.051, y = -35.0778 },
            { x = 336, y = 0 },
            { x = 336, y = 64 },
            { x = -1040, y = 64 }
          },
          properties = {}
        },
        {
          id = 558,
          name = "",
          type = "Coin",
          shape = "point",
          x = 1949.67,
          y = 2887.4,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 559,
          name = "",
          type = "Coin",
          shape = "point",
          x = 2032.95,
          y = 2702.75,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 560,
          name = "",
          type = "Coin",
          shape = "point",
          x = 2197.68,
          y = 2851.19,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 564,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 1872,
          y = 2640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 48, y = 272 },
            { x = 528, y = 272 },
            { x = 528, y = 0 }
          },
          properties = {}
        },
        {
          id = 566,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 3520,
          y = 3392,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -80 },
            { x = 0, y = 48 },
            { x = 144, y = 48 },
            { x = 144, y = -80 }
          },
          properties = {}
        },
        {
          id = 567,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 3792,
          y = 3328,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -16 },
            { x = 0, y = 160 },
            { x = 256, y = 160 },
            { x = 256, y = -16 }
          },
          properties = {}
        },
        {
          id = 568,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 1024,
          y = 3552,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 3648, y = 0 },
            { x = 3648, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 569,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 4160,
          y = 3392,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -80 },
            { x = 0, y = 48 },
            { x = 144, y = 48 },
            { x = 144, y = -80 }
          },
          properties = {}
        },
        {
          id = 571,
          name = "Bubble",
          type = "Hitbox",
          shape = "polygon",
          x = 992,
          y = 3872,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 218, y = 80 },
            { x = 224, y = 752 },
            { x = 304, y = 752 },
            { x = 304, y = 0 }
          },
          properties = {}
        },
        {
          id = 572,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 1328,
          y = 4208,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -80 },
            { x = 0, y = 416 },
            { x = 64, y = 368 },
            { x = 80, y = 368 },
            { x = 145.376, y = 416 },
            { x = 145.376, y = 272 },
            { x = 176, y = 272 },
            { x = 192, y = 256 },
            { x = 224, y = 256 },
            { x = 336, y = 96 },
            { x = 368, y = 96 },
            { x = 368, y = -336 },
            { x = 384, y = -336 },
            { x = 384, y = -400 },
            { x = 304, y = -400 },
            { x = 304, y = 32 },
            { x = 192, y = 192 },
            { x = 145.376, y = 192 },
            { x = 144, y = -80 },
            { x = 80, y = -128 },
            { x = 64, y = -128 }
          },
          properties = {}
        },
        {
          id = 573,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 832,
          y = 4624,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1536, y = 0 },
            { x = 1536, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 574,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1504,
          y = 4384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 16, y = 16 },
            { x = 128, y = -144 },
            { x = 112, y = -144 },
            { x = 112, y = -736 },
            { x = -80, y = -736 },
            { x = -80, y = -640 },
            { x = -16, y = -624 },
            { x = -16, y = -592 },
            { x = 0, y = -592 },
            { x = 0, y = -512 }
          },
          properties = {}
        },
        {
          id = 575,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1552,
          y = 4496,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 160, y = -192 },
            { x = 160, y = -624 },
            { x = 208, y = -624 },
            { x = 208, y = 128 },
            { x = -48, y = 128 },
            { x = -48, y = -17.879 },
            { x = -32, y = -32 },
            { x = 0, y = -32 },
            { x = 112, y = -192 }
          },
          properties = {}
        },
        {
          id = 576,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1312,
          y = 4624,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -752 },
            { x = -16, y = -752 },
            { x = -16, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 577,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1504,
          y = 4624,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -224 },
            { x = 0, y = -832 },
            { x = -16, y = -832 },
            { x = -16, y = -224 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 578,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1488,
          y = 4480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 144 },
            { x = 16, y = 144 },
            { x = 16, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 579,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1696,
          y = 4304,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = 16, y = -432 },
            { x = 0, y = -432 },
            { x = 0, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 580,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1632,
          y = 4304,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -64 },
            { x = 0, y = -656 },
            { x = -16, y = -656 },
            { x = -16, y = -64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 582,
          name = "Bubble",
          type = "Hitbox",
          shape = "polygon",
          x = 848,
          y = 5472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 432, y = 80 },
            { x = 432, y = 0 }
          },
          properties = {}
        },
        {
          id = 583,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 848,
          y = 5552,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 3216, y = -16 },
            { x = 3216, y = 48 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 584,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 1392,
          y = 3408,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -176 },
            { x = 464, y = -176 },
            { x = 464, y = 0 }
          },
          properties = {}
        },
        {
          id = 585,
          name = "Bubble",
          type = "Hitbox",
          shape = "polygon",
          x = 3632,
          y = 5456,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 432, y = 80 },
            { x = 432, y = 0 }
          },
          properties = {}
        },
        {
          id = 586,
          name = "Bubble",
          type = "Hitbox",
          shape = "polygon",
          x = 1024,
          y = 3472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 16 },
            { x = 16, y = 80 },
            { x = 272, y = 80 },
            { x = 272, y = 16 }
          },
          properties = {}
        },
        {
          id = 589,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 2288,
          y = 3360,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = -16 },
            { x = 176, y = -80 },
            { x = 336, y = -80 },
            { x = 464, y = 0 },
            { x = 592, y = 0 },
            { x = 720, y = -80 },
            { x = 864, y = -80 },
            { x = 864, y = 0 },
            { x = 720, y = 0 },
            { x = 592, y = 80 },
            { x = 464, y = 80 },
            { x = 336, y = 0 },
            { x = 176, y = 0 },
            { x = 80, y = 64 },
            { x = 80, y = 112 },
            { x = -32, y = 112 },
            { x = -32, y = -16 }
          },
          properties = {}
        },
        {
          id = 590,
          name = "",
          type = "Checkpoint",
          shape = "point",
          x = 4528,
          y = 3360,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 592,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1040,
          y = 3552,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = -16, y = -80 },
            { x = 272, y = -80 },
            { x = 272, y = 0 },
            { x = 256, y = 0 },
            { x = 256, y = -64 },
            { x = 0, y = -64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 593,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1920,
          y = 3472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 16 },
            { x = 16, y = 80 },
            { x = 272, y = 80 },
            { x = 272, y = 16 }
          },
          properties = {}
        },
        {
          id = 594,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1936,
          y = 3552,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = -16, y = -80 },
            { x = 272, y = -80 },
            { x = 272, y = 0 },
            { x = 256, y = 0 },
            { x = 256, y = -64 },
            { x = 0, y = -64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 595,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3184,
          y = 3472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 16 },
            { x = 16, y = 80 },
            { x = 272, y = 80 },
            { x = 272, y = 16 }
          },
          properties = {}
        },
        {
          id = 596,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3200,
          y = 3552,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = -16, y = -80 },
            { x = 272, y = -80 },
            { x = 272, y = 0 },
            { x = 256, y = 0 },
            { x = 256, y = -64 },
            { x = 0, y = -64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 597,
          name = "s",
          type = "Hitbox",
          shape = "polygon",
          x = 4384,
          y = 3472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 16 },
            { x = 16, y = 80 },
            { x = 272, y = 80 },
            { x = 272, y = 16 }
          },
          properties = {}
        },
        {
          id = 598,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4400,
          y = 3552,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = -16, y = -80 },
            { x = 272, y = -80 },
            { x = 272, y = 0 },
            { x = 256, y = 0 },
            { x = 256, y = -64 },
            { x = 0, y = -64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 599,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4400,
          y = 3312,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = -144 },
            { x = 0, y = -144 },
            { x = 0, y = -80 },
            { x = 256, y = -80 },
            { x = 256, y = -144 },
            { x = 272, y = -144 },
            { x = 272, y = -64 },
            { x = -16, y = -64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 600,
          name = "s",
          type = "Hitbox",
          shape = "polygon",
          x = 4384,
          y = 3152,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 16 },
            { x = 16, y = 80 },
            { x = 272, y = 80 },
            { x = 272, y = 16 }
          },
          properties = {}
        },
        {
          id = 604,
          name = "Toast",
          type = "BubbleField",
          shape = "polygon",
          x = 27.8677,
          y = -89.9494,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 8.63513, y = -6.04459 },
            { x = 34.5405, y = -18.9973 },
            { x = 74.2621, y = -29.3594 },
            { x = 122.619, y = -34.5405 },
            { x = 157.159, y = -35.404 },
            { x = 193.427, y = -33.677 },
            { x = 228.831, y = -30.2229 },
            { x = 246.965, y = -26.7689 },
            { x = 269.416, y = -19.8608 },
            { x = 282.369, y = -8.63513 },
            { x = 291.004, y = 6.04459 },
            { x = 293.594, y = 18.1338 },
            { x = 296.185, y = 38.8581 },
            { x = 297.912, y = 70.8081 },
            { x = 298.775, y = 90.6688 },
            { x = 298.775, y = 113.12 },
            { x = 298.775, y = 133.844 },
            { x = 297.912, y = 157.159 },
            { x = 296.185, y = 179.611 },
            { x = 296.185, y = 195.154 },
            { x = 295.321, y = 217.605 },
            { x = 294.458, y = 263.293 },
            { x = 292.731, y = 273.655 },
            { x = 287.55, y = 280.563 },
            { x = 278.051, y = 285.744 },
            { x = 256.463, y = 285.744 },
            { x = 225.377, y = 289.198 },
            { x = 196.017, y = 290.925 },
            { x = 160.613, y = 296.106 },
            { x = 133.844, y = 300.424 },
            { x = 110.53, y = 302.151 },
            { x = 85.4878, y = 303.014 },
            { x = 58.7189, y = 301.287 },
            { x = 37.1311, y = 296.97 },
            { x = 23.3148, y = 290.062 },
            { x = 12.9527, y = 277.109 },
            { x = 12.0892, y = 257.248 },
            { x = 9.49864, y = 210.697 },
            { x = 3.45405, y = 184.792 },
            { x = -1.72703, y = 153.705 },
            { x = -3.45405, y = 120.892 },
            { x = -5.18108, y = 86.3513 },
            { x = -6.04459, y = 59.5824 },
            { x = -6.04459, y = 37.1311 },
            { x = -5.18108, y = 12.0892 }
          },
          properties = {
            ["print"] = "\"yes\"ss"
          }
        },
        {
          id = 605,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 1360,
          y = 5280,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 160 },
            { x = 304, y = 160 },
            { x = 304, y = 0 }
          },
          properties = {}
        },
        {
          id = 607,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1616,
          y = 5264,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = 64 },
            { x = -16, y = 112 },
            { x = 48, y = 48 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = -1
          }
        },
        {
          id = 608,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = 1952,
          y = 5280,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 160 },
            { x = 304, y = 160 },
            { x = 304, y = 0 }
          },
          properties = {}
        },
        {
          id = 609,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2208,
          y = 5264,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = 64 },
            { x = -16, y = 112 },
            { x = 48, y = 48 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = -1
          }
        },
        {
          id = 610,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -352,
          y = 1344,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 80, y = 0 },
            { x = 80, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 615,
          name = "",
          type = "AcceleratorSurface",
          shape = "polygon",
          x = -352,
          y = 1344,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -48, y = -32 },
            { x = -96, y = -160 },
            { x = -148.692, y = -1247.78 },
            { x = -131.737, y = -1309.41 },
            { x = -86.8362, y = -1371.49 },
            { x = -11.0294, y = -1412.86 },
            { x = 96.4197, y = -1445.48 },
            { x = 214.051, y = -1475.07 },
            { x = 365.329, y = -1503.16 },
            { x = 423.135, y = -1546.69 },
            { x = -368, y = -1504 },
            { x = -208, y = 240 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 619,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2176.05,
          y = 1004.37,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 3.62598 },
            { x = -32.0506, y = 3.62598 },
            { x = -32.0506, y = -12.374 },
            { x = -0.0506176, y = -12.374 }
          },
          properties = {}
        },
        {
          id = 620,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 1184,
          y = 2832,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 80, y = 32 },
            { x = 128, y = -16 },
            { x = 0, y = -32 }
          },
          properties = {}
        },
        {
          id = 621,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 1392,
          y = 2896,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 48 },
            { x = 144, y = 32 },
            { x = 144, y = -16 }
          },
          properties = {}
        },
        {
          id = 622,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 2256,
          y = 1312,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 384, y = 0 },
            { x = 384, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 625,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -32,
          y = 1232,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 240, y = 0 },
            { x = 224, y = -64 },
            { x = 240, y = -64 },
            { x = 272, y = -64 },
            { x = 544, y = -64 },
            { x = 544, y = 32 },
            { x = -32, y = 32 },
            { x = -32, y = -224 },
            { x = 544, y = -224 },
            { x = 544, y = -112 },
            { x = 272, y = -112 },
            { x = 240, y = -112 },
            { x = 224, y = -112 },
            { x = 240, y = -192 },
            { x = 0, y = -192 }
          },
          properties = {}
        },
        {
          id = 626,
          name = "",
          type = "AcceleratorSurface",
          shape = "polygon",
          x = 340.441,
          y = 601.862,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = -16, y = 16 },
            { x = 0, y = 16 },
            { x = 311.131, y = 16.3856 },
            { x = 580.673, y = 136.564 },
            { x = 696.868, y = 70.9285 },
            { x = 691.654, y = 47.5077 },
            { x = 688.75, y = -88.0679 },
            { x = 713.591, y = -195.3 },
            { x = 688.237, y = -175.096 },
            { x = 673.88, y = -147.922 },
            { x = 670.931, y = -100.955 },
            { x = 669.448, y = -71.7674 },
            { x = 669.966, y = -31.9579 },
            { x = 668.891, y = 1.20895 },
            { x = 668.732, y = 41.4705 },
            { x = 663.599, y = 64.7055 },
            { x = 651.2, y = 80.2136 },
            { x = 638.198, y = 89.4186 },
            { x = 623.947, y = 94.3516 },
            { x = 604.908, y = 94.5051 },
            { x = 586.812, y = 93.2928 },
            { x = 572.639, y = 90.6384 },
            { x = 554.363, y = 82.557 },
            { x = 548.816, y = 72.6945 },
            { x = 547.87, y = 54.0478 },
            { x = 549.975, y = 38.0283 },
            { x = 550.721, y = 20.9258 },
            { x = 551.265, y = 1.35767 },
            { x = 548.811, y = -17.1695 },
            { x = 543.54, y = -31.0046 },
            { x = 534.546, y = -37.2125 },
            { x = 524.932, y = -33.9356 },
            { x = 515.076, y = -23.7101 },
            { x = 500.528, y = -5.61124 },
            { x = 487.168, y = 11.0756 },
            { x = 474.723, y = 24.4406 },
            { x = 463.961, y = 33.5664 },
            { x = 454.982, y = 35.901 },
            { x = 444.406, y = 34.1659 },
            { x = 436.759, y = 27.0478 },
            { x = 430.948, y = 11.9958 },
            { x = 425.516, y = -3.76559 },
            { x = 416.977, y = -18.9728 },
            { x = 407.795, y = -31.5147 },
            { x = 396.732, y = -41.5263 },
            { x = 382.436, y = -47.1215 },
            { x = 362.67, y = -44.875 },
            { x = 347.056, y = -36.4347 },
            { x = 332.901, y = -23.4366 },
            { x = 319.028, y = -9.60013 },
            { x = 304, y = 0 }
          },
          properties = {}
        },
        {
          id = 627,
          name = "",
          type = "AcceleratorSurface",
          shape = "polygon",
          x = 340.441,
          y = 569.862,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = 16, y = 16 },
            { x = 304, y = 16 },
            { x = 331.104, y = -8.10176 },
            { x = 349.554, y = -21.1878 },
            { x = 368.329, y = -27.0951 },
            { x = 384.52, y = -27.1888 },
            { x = 403.263, y = -19.1166 },
            { x = 416.908, y = -6.07881 },
            { x = 427.354, y = 9.10219 },
            { x = 436.64, y = 27.3388 },
            { x = 443.126, y = 40.4319 },
            { x = 445.618, y = 48.2521 },
            { x = 452.393, y = 53.1521 },
            { x = 460.846, y = 51.8044 },
            { x = 468.221, y = 47.0301 },
            { x = 475.702, y = 37.0932 },
            { x = 483.603, y = 28.1598 },
            { x = 501.707, y = -4.86056 },
            { x = 521.06, y = -25.5453 },
            { x = 534.564, y = -28.5112 },
            { x = 550.01, y = -21.3932 },
            { x = 559.713, y = -1.96892 },
            { x = 563.377, y = 28.1854 },
            { x = 563.79, y = 61.8161 },
            { x = 560.53, y = 88.6874 },
            { x = 565.095, y = 101.479 },
            { x = 578.014, y = 109.656 },
            { x = 595.018, y = 113.259 },
            { x = 610.146, y = 114.486 },
            { x = 624.501, y = 112.033 },
            { x = 637.272, y = 107.599 },
            { x = 645.594, y = 99.0027 },
            { x = 654.056, y = 83.12 },
            { x = 656.897, y = 66.7259 },
            { x = 656.975, y = 35.1069 },
            { x = 655.673, y = -24.035 },
            { x = 654.868, y = -44.695 },
            { x = 655.006, y = -69.583 },
            { x = 655.219, y = -116.493 },
            { x = 652.461, y = -131.784 },
            { x = 644.228, y = -142.802 },
            { x = 629.288, y = -146.875 },
            { x = 600.084, y = -144.091 },
            { x = 567.378, y = -139.309 },
            { x = 536.866, y = -133.983 },
            { x = 496.516, y = -125.077 },
            { x = 447.313, y = -108.84 },
            { x = 402.915, y = -87.7836 },
            { x = 364.388, y = -62.032 },
            { x = 304, y = 0 }
          },
          properties = {}
        },
        {
          id = 628,
          name = "",
          type = "Coin",
          shape = "point",
          x = 376.097,
          y = 264.539,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 634,
          name = "",
          type = "",
          shape = "polygon",
          x = -1408,
          y = 2400,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 256, y = 0 },
            { x = 256, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 635,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -32,
          y = 1152,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 137.002, y = 77.8133 },
            { x = 89.0015, y = 13.8133 },
            { x = 37.7046, y = 14.0498 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 641,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = -994.573,
          y = 2967.44,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 130.573, y = 8.56445 },
            { x = 130.573, y = -39.4355 },
            { x = -29.4274, y = -39.4355 }
          },
          properties = {}
        },
        {
          id = 642,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = -1210.31,
          y = 2944.37,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 99.0502, y = -35.2782 },
            { x = -2.7137, y = -119.403 }
          },
          properties = {}
        },
        {
          id = 643,
          name = "",
          type = "BubbleField",
          shape = "polygon",
          x = -848.033,
          y = 2766.62,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 274.084, y = 55.6309 },
            { x = 363.636, y = 180.461 },
            { x = 576.662, y = 151.967 },
            { x = 466.757, y = -177.748 },
            { x = 135.685, y = -255.088 },
            { x = -124.83, y = -225.237 },
            { x = -135.685, y = -97.6934 }
          },
          properties = {}
        },
        {
          id = 645,
          name = "",
          type = "AcceleratorSurface",
          shape = "polygon",
          x = -1408,
          y = 2400,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -48, y = -16 },
            { x = -80, y = -48 },
            { x = -105.052, y = -103.817 },
            { x = -112, y = -160 },
            { x = -112, y = -208 },
            { x = -109.922, y = -301.942 },
            { x = -76.4589, y = -389.982 },
            { x = -6.07815, y = -447.641 },
            { x = 48.2119, y = -478.743 },
            { x = 121.059, y = -482.885 },
            { x = 196.903, y = -482.885 },
            { x = 258.718, y = -464.822 },
            { x = 300.55, y = -422.052 },
            { x = 337.554, y = -340.55 },
            { x = 346.785, y = -276.142 },
            { x = 345.267, y = -203.788 },
            { x = 347.592, y = -107.909 },
            { x = 353.918, y = -22.376 },
            { x = 351.098, y = 44.8985 },
            { x = 349.917, y = 125.604 },
            { x = 344.349, y = 195.878 },
            { x = 311.782, y = 252.379 },
            { x = 265.06, y = 277.586 },
            { x = 203.869, y = 295.79 },
            { x = 98.5386, y = 306.27 },
            { x = -24.2376, y = 299.491 },
            { x = -118.659, y = 262.776 },
            { x = -177.983, y = 232.192 },
            { x = -225.778, y = 203.92 },
            { x = -274.737, y = 163.039 },
            { x = -305.792, y = 114.607 },
            { x = -312.458, y = 23.4047 },
            { x = -319.988, y = -74.0623 },
            { x = -322.781, y = -183.161 },
            { x = -320.493, y = -281.925 },
            { x = -316.584, y = -393.528 },
            { x = -307.802, y = -482.733 },
            { x = -300.16, y = -615.914 },
            { x = -293.704, y = -707.243 },
            { x = -268.301, y = -783.792 },
            { x = -248.129, y = -836.594 },
            { x = -218.444, y = -882.16 },
            { x = -196.406, y = -915.989 },
            { x = -95.8122, y = -982.875 },
            { x = 11.1074, y = -982.01 },
            { x = 110.482, y = -946.197 },
            { x = 193.988, y = -893.845 },
            { x = 283.115, y = -805.786 },
            { x = 417.033, y = -690.707 },
            { x = 566.474, y = -542.997 },
            { x = 601.711, y = -499.967 },
            { x = 614.618, y = -442.043 },
            { x = 628.906, y = -339.85 },
            { x = 624.399, y = -75.6923 },
            { x = 593.978, y = 323.915 },
            { x = 557.111, y = 498.873 },
            { x = 645.811, y = 508.935 },
            { x = 700.608, y = 125.123 },
            { x = 717.98, y = -465.493 },
            { x = 350.568, y = -1057.94 },
            { x = -4.93466, y = -1155.63 },
            { x = -312.496, y = -923.349 },
            { x = -505.132, y = -715.363 },
            { x = -428.095, y = 129.294 },
            { x = -131.769, y = 658.594 },
            { x = 473.825, y = 497.927 },
            { x = 537.099, y = -345.228 },
            { x = 528.137, y = -433.58 },
            { x = 478.347, y = -523.424 },
            { x = 357.453, y = -654.775 },
            { x = 197.791, y = -803.736 },
            { x = 124.879, y = -870.344 },
            { x = 39.7056, y = -909.693 },
            { x = -40.9467, y = -916.122 },
            { x = -118.766, y = -893.02 },
            { x = -157.773, y = -861.29 },
            { x = -179.477, y = -818.995 },
            { x = -211.576, y = -761.275 },
            { x = -235.966, y = -696.838 },
            { x = -252.954, y = -618.849 },
            { x = -264.014, y = -488.112 },
            { x = -262.142, y = -387.364 },
            { x = -261.253, y = -279.283 },
            { x = -262.053, y = -176.845 },
            { x = -243.363, y = -70.6286 },
            { x = -210.163, y = 21.4396 },
            { x = -176, y = 64 },
            { x = 0, y = 64 },
            { x = 21.8818, y = 3.42152 }
          },
          properties = {}
        },
        {
          id = 654,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 624,
          y = 160,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 656,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 637.178,
          y = 228.909,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 657,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 649.571,
          y = 104.25,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 658,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 687.926,
          y = 66.5988,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 664,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 432,
          y = 192,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = -16 },
            { x = 80.5735, y = -16.3423 },
            { x = 32, y = 32 },
            { x = 16, y = 32 },
            { x = 5.75512, y = 12.9935 }
          },
          properties = {}
        },
        {
          id = 665,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 432.941,
          y = 143.981,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 16 },
            { x = 80.7718, y = 16.0542 },
            { x = 32, y = -64 },
            { x = 16, y = -64 },
            { x = 4.75562, y = -16.7416 }
          },
          properties = {}
        },
        {
          id = 700,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 750.195,
          y = 49.8054,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 701,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 827.237,
          y = 77.821,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 702,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 866.148,
          y = 119.844,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 703,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 880.934,
          y = 183.658,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 704,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 846.693,
          y = 238.911,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 705,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1968,
          y = -96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 80 },
            { x = 96, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 706,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1645.22,
          y = -19.2485,
          width = 0,
          height = 0,
          rotation = 327.865,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 80 },
            { x = 96, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 707,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1731.09,
          y = -123.361,
          width = 0,
          height = 0,
          rotation = 45.587,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 80 },
            { x = 96, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 708,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1752.82,
          y = 58.8662,
          width = 0,
          height = 0,
          rotation = 14.6684,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 80 },
            { x = 96, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 710,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2032,
          y = -16,
          width = 0,
          height = 0,
          rotation = 14.6684,
          visible = true,
          polygon = {
            { x = 85.7862, y = 12.6055 },
            { x = -110.946, y = 144.814 },
            { x = -2.59591, y = 116.453 },
            { x = 101.048, y = 43.765 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 712,
          name = "",
          type = "",
          shape = "polygon",
          x = 1792.42,
          y = -64.6084,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -31.3812, y = 49.3793 },
            { x = -22.6129, y = 53.5327 },
            { x = 9.69126, y = 5.99935 }
          },
          properties = {}
        },
        {
          id = 713,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1840,
          y = -80,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 80, y = 0 },
            { x = 80, y = -80 },
            { x = 0, y = -80 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 714,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1946.95,
          y = -154.384,
          width = 0,
          height = 0,
          rotation = 54,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 80 },
            { x = 96, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 715,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 704,
          y = 256,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 80, y = 32 },
            { x = 80, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 716,
          name = "",
          type = "DoubleJumpTether",
          shape = "point",
          x = 610.164,
          y = 282.657,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 718,
          name = "",
          type = "Coin",
          shape = "point",
          x = 187.783,
          y = 1068.42,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 720,
          name = "",
          type = "Coin",
          shape = "point",
          x = 71.2281,
          y = 1070.58,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 745,
          name = "",
          type = "Coin",
          shape = "point",
          x = 256.667,
          y = 998,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 746,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 368,
          y = 864,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = 64 },
            { x = 256, y = 112 },
            { x = 128, y = -80 }
          },
          properties = {}
        },
        {
          id = 747,
          name = "",
          type = "CameraBounds",
          shape = "rectangle",
          x = -329.628,
          y = 628.593,
          width = 1034.88,
          height = 636.259,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 749,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -1712,
          y = 928,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -544, y = -432 },
            { x = -464, y = -432 },
            { x = -464, y = 0 },
            { x = 608, y = 0 },
            { x = 614.101, y = -432 },
            { x = 688, y = -432 },
            { x = 688, y = 80 },
            { x = -544, y = 80 }
          },
          properties = {}
        },
        {
          id = 751,
          name = "",
          type = "NPC",
          shape = "polygon",
          x = -1713.1,
          y = 911.473,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0.916577, y = -7.14237 },
            { x = -28.306, y = -36.7862 },
            { x = -40.1363, y = -72.9149 },
            { x = -43.0332, y = -122.442 },
            { x = -36.3544, y = -156.521 },
            { x = -16.0195, y = -192.788 },
            { x = 8.93325, y = -226.343 },
            { x = 40.8104, y = -253.079 },
            { x = 66.0011, y = -268.904 },
            { x = 99.6874, y = -280.953 },
            { x = 144.712, y = -287.864 },
            { x = 191.316, y = -292.331 },
            { x = 247.939, y = -291.214 },
            { x = 302.359, y = -285.431 },
            { x = 344.74, y = -275.402 },
            { x = 385.782, y = -255.766 },
            { x = 423.885, y = -227.217 },
            { x = 447.513, y = -191.337 },
            { x = 461.879, y = -156.11 },
            { x = 470.489, y = -114.825 },
            { x = 466.265, y = -67.9998 },
            { x = 448.188, y = -38.7983 },
            { x = 420.092, y = -10.703 },
            { x = 382.632, y = 6.68937 },
            { x = 350.523, y = 16.0545 },
            { x = 49.986, y = 13.8212 }
          },
          properties = {}
        },
        {
          id = 752,
          name = "",
          type = "",
          shape = "polygon",
          x = -1744,
          y = -176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = 0 },
            { x = 0, y = 64 },
            { x = 0, y = 288 },
            { x = -176, y = 288 },
            { x = -176, y = 0 },
            { x = -240, y = 0 },
            { x = -240, y = -240 },
            { x = -288, y = -240 },
            { x = -288, y = 64 },
            { x = -240, y = 66.6656 },
            { x = -240, y = 352 },
            { x = 1008, y = 352 },
            { x = 1008, y = 288 },
            { x = 64, y = 288 },
            { x = 64, y = 22.4759 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 766,
          name = "",
          type = "",
          shape = "polygon",
          x = -1504,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 112, y = -112 },
            { x = 256, y = -112 },
            { x = 304, y = 0 }
          },
          properties = {}
        },
        {
          id = 784,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1952,
          y = -288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = false,
            ["other"] = { id = 785 },
            ["target"] = { id = 786 }
          }
        },
        {
          id = 785,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1952,
          y = -176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 786,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1728,
          y = -288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = true,
            ["other"] = { id = 787 },
            ["target"] = { id = 784 }
          }
        },
        {
          id = 787,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1728,
          y = -176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 788,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1920,
          y = 0,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = false,
            ["other"] = { id = 789 },
            ["target"] = { id = 790 }
          }
        },
        {
          id = 789,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1920,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 790,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1680,
          y = 0,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = false,
            ["other"] = { id = 791 },
            ["target"] = { id = 788 }
          }
        },
        {
          id = 791,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1680,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 792,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1408,
          y = 16,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = true,
            ["other"] = { id = 793 },
            ["target"] = { id = 794 }
          }
        },
        {
          id = 793,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1488,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 794,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1238.11,
          y = 17.2024,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = false,
            ["other"] = { id = 795 },
            ["target"] = { id = 792 }
          }
        },
        {
          id = 795,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1204.44,
          y = 99.1434,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 796,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1376,
          y = -368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = true,
            ["other"] = { id = 797 },
            ["target"] = { id = 798 }
          }
        },
        {
          id = 797,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1296,
          y = -368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 798,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1376,
          y = -96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = false,
            ["other"] = { id = 799 },
            ["target"] = { id = 796 }
          }
        },
        {
          id = 799,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1280,
          y = -96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 800,
          name = "",
          type = "Portal",
          shape = "point",
          x = -944,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = false,
            ["other"] = { id = 801 },
            ["target"] = { id = 802 }
          }
        },
        {
          id = 801,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -864,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 802,
          name = "",
          type = "Portal",
          shape = "point",
          x = -1120,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["left_or_right"] = false,
            ["other"] = { id = 803 },
            ["target"] = { id = 800 }
          }
        },
        {
          id = 803,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -1040,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 804,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -1606.06,
          y = -318.182,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -9.93939, y = 190.182 },
            { x = 102.061, y = 206.182 },
            { x = 118.061, y = -1.81818 }
          },
          properties = {}
        },
        {
          id = 805,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = -2116.15,
          y = 283.498,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -8.12477, y = -1.79775 },
            { x = -46.9562, y = 67.0803 },
            { x = -6.70803, y = 155.962 },
            { x = 150.931, y = 134.161 },
            { x = 216.334, y = 88.8814 },
            { x = 261.613, y = 30.1861 },
            { x = 187.825, y = -26.8321 },
            { x = 89.9212, y = -32.97 }
          },
          properties = {}
        },
        {
          id = 806,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = -1741.01,
          y = 337.906,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -28.1881, y = 10.1477 },
            { x = -24.8055, y = 66.5238 },
            { x = -56.3761, y = 113.88 },
            { x = -186.041, y = 134.175 },
            { x = -54.1211, y = 128.538 },
            { x = -31.5706, y = 138.685 },
            { x = 43.9734, y = 130.793 },
            { x = 111.625, y = 117.262 },
            { x = 173.963, y = 83.872 },
            { x = 198.444, y = 10.1477 },
            { x = 153.343, y = -19.1679 },
            { x = 101.477, y = -30.4431 },
            { x = 95.8394, y = 31.5706 },
            { x = 85.6917, y = 55.2486 },
            { x = 56.3761, y = 76.6716 },
            { x = 7.89266, y = 75.544 },
            { x = 19.1679, y = 33.8257 }
          },
          properties = {}
        }
      }
    }
  }
}
