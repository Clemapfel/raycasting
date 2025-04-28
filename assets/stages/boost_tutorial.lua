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
  nextobjectid = 327,
  properties = {
    ["title"] = "Boosting"
  },
  tilesets = {
    {
      name = "debug_tileset",
      firstgid = 1,
      filename = "../tilesets/debug_tileset.tsx",
      exportfilename = "../tilesets/debug_tileset.lua"
    },
    {
      name = "debug_tileset_objects",
      firstgid = 70,
      filename = "../tilesets/debug_tileset_objects.tsx",
      exportfilename = "../tilesets/debug_tileset_objects.lua"
    }
  },
  layers = {
    {
      type = "imagelayer",
      image = "../tilesets/debug_tileset_16x16/tile.png",
      id = 2,
      name = "Image Layer 1",
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
      id = 3,
      name = "Object Layer 1",
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
          name = "",
          type = "PlayerSpawn",
          shape = "point",
          x = 355.707,
          y = 2313.54,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -256,
          y = 0,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 224, y = 0 },
            { x = 240, y = 16 },
            { x = 224, y = 32 },
            { x = 0, y = 32 },
            { x = -32, y = 32 },
            { x = -32, y = 0 },
            { x = -32, y = -336 },
            { x = -64, y = -336 },
            { x = -32, y = -304 },
            { x = -32, y = -352 },
            { x = -32, y = -368 },
            { x = 16, y = -368 },
            { x = 0, y = -352 },
            { x = -16, y = -352 },
            { x = -16, y = 0 }
          },
          properties = {}
        },
        {
          id = 6,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -272,
          y = -256,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -96 },
            { x = 16, y = -96 },
            { x = 16, y = 256 },
            { x = 0, y = 256 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 7,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 224,
          y = 0,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -256, y = 0 },
            { x = -240, y = 16 },
            { x = -256, y = 32 },
            { x = 336, y = 32 },
            { x = 352, y = 16 },
            { x = 336, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 8,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 256,
          y = -64,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -208, y = 0 },
            { x = -208, y = 64 },
            { x = 256, y = 64 },
            { x = 272, y = 32 },
            { x = 256, y = 0 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0,
            ["velocity"] = 3
          }
        },
        {
          id = 10,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 256,
          y = -64,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -224, y = 0 },
            { x = -256, y = 0 },
            { x = -256, y = -16 },
            { x = -240, y = -32 },
            { x = -240, y = -288 },
            { x = -256, y = -304 },
            { x = -288, y = -304 },
            { x = -304, y = -320 },
            { x = -256, y = -320 },
            { x = -224, y = -320 },
            { x = -224, y = -304 },
            { x = 0, y = -304 },
            { x = 0, y = -16 },
            { x = -224, y = -16 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 12,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 560,
          y = 0,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 16 },
            { x = 0, y = 32 },
            { x = 112, y = 32 },
            { x = 112, y = 0 }
          },
          properties = {}
        },
        {
          id = 13,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 752,
          y = 0,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = -176 },
            { x = -80, y = -384 },
            { x = -64, y = -368 },
            { x = -64, y = 0 },
            { x = -80, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 14,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 496.799,
          y = -208.745,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -208.799, y = -175.255 },
            { x = -208.799, y = -191.255 },
            { x = -192.799, y = -223.255 },
            { x = -192.799, y = -175.255 },
            { x = 32, y = -175.255 },
            { x = 31.2007, y = -158.509 },
            { x = -224, y = -160 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 15,
          name = "",
          type = "Coin",
          shape = "point",
          x = -111.693,
          y = -82.9247,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 16,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = -752,
          y = 48,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -224 },
            { x = 272, y = -224 },
            { x = 368, y = -16 },
            { x = 1424, y = -16 },
            { x = 1424, y = 48 },
            { x = 0, y = 48 }
          },
          properties = {}
        },
        {
          id = 17,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 752,
          y = -80,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = 48 },
            { x = -112, y = 32 },
            { x = -144, y = 48 },
            { x = -144, y = -96 },
            { x = -112, y = -112 },
            { x = -80, y = -96 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 19,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 16,
          y = -208,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -176 },
            { x = -128, y = -176 },
            { x = -144, y = -192 },
            { x = -128, y = -208 },
            { x = 0, y = -208 }
          },
          properties = {
            ["axis_x"] = -1,
            ["axis_y"] = 0
          }
        },
        {
          id = 20,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -464,
          y = -256,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = -176 },
            { x = 144, y = -176 },
            { x = 144, y = 272 },
            { x = 112, y = 272 },
            { x = 80, y = 272 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 21,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 0,
          y = -368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 288 },
            { x = 16, y = 272 },
            { x = 16, y = 16 },
            { x = 0, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 23,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 560,
          y = -384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 320 },
            { x = -16, y = 304 },
            { x = -16, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 25,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -240,
          y = -368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = -16, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 28,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 256,
          y = -208,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -224, y = -176 },
            { x = -32, y = -176 },
            { x = -32, y = -224 },
            { x = -16, y = -192 },
            { x = -16, y = -176 },
            { x = 0, y = -160 },
            { x = -224, y = -160 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 29,
          name = "",
          type = "Coin",
          shape = "point",
          x = 263.59,
          y = -229.461,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 31,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 256,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -224, y = -176 },
            { x = 0, y = -176 },
            { x = 0, y = -160 },
            { x = -224, y = -160 }
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
          x = 496,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -224, y = -176 },
            { x = 32, y = -175.255 },
            { x = 31.2007, y = -158.509 },
            { x = -224, y = -160 }
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
          x = 256,
          y = -64,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 272, y = -304 },
            { x = 272, y = -320 },
            { x = 304, y = -320 },
            { x = 288, y = -304.784 },
            { x = 288, y = -18.4808 },
            { x = 304, y = 0 },
            { x = 272, y = 0 },
            { x = 272, y = -16 },
            { x = 16, y = -16 },
            { x = 16, y = -304 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 36,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 240,
          y = -400,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = -32 },
            { x = 0, y = -48 },
            { x = 48, y = -48 },
            { x = 64, y = -32 },
            { x = 48, y = 0 },
            { x = 48, y = 336 },
            { x = 0, y = 336 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 40,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -320,
          y = -336,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 32 },
            { x = 16, y = 368 },
            { x = 32, y = 368 },
            { x = 32, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 41,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 832,
          y = -384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 240 },
            { x = 0, y = -288 },
            { x = 80, y = -288 },
            { x = 80, y = 240 }
          },
          properties = {
            ["axis_x"] = -1,
            ["axis_y"] = 0
          }
        },
        {
          id = 42,
          name = "",
          type = "Coin",
          shape = "point",
          x = 871.977,
          y = -423.022,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 43,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 768,
          y = -416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 256 },
            { x = 32, y = 272 },
            { x = 64, y = 256 },
            { x = 64, y = 0 },
            { x = 32, y = 16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 44,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 912,
          y = -416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 272 },
            { x = 32, y = 256 },
            { x = 64, y = 272 },
            { x = 64, y = 32 },
            { x = 32, y = 16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 46,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 672,
          y = -384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 96, y = 0 },
            { x = 96, y = 240 },
            { x = 80, y = 240 },
            { x = 80, y = 320 },
            { x = 320, y = 320 },
            { x = 320, y = 240 },
            { x = 304, y = 240 },
            { x = 304, y = 0 },
            { x = 368, y = 0 },
            { x = 400, y = 0 },
            { x = 400, y = 240 },
            { x = 384, y = 240 },
            { x = 384, y = 320 },
            { x = 624, y = 320 },
            { x = 624, y = 240 },
            { x = 608, y = 240 },
            { x = 608, y = 112 },
            { x = 640, y = 112 },
            { x = 640, y = 320 },
            { x = 640, y = 336 },
            { x = 16, y = 336 },
            { x = 16, y = 16 }
          },
          properties = {}
        },
        {
          id = 47,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 768,
          y = -128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 16 },
            { x = 48, y = 32 },
            { x = 70.4546, y = 39.1494 },
            { x = 96.2568, y = 43.6351 },
            { x = 112.257, y = 43.6351 },
            { x = 136.236, y = 39.388 },
            { x = 160, y = 32 },
            { x = 192, y = 16 },
            { x = 208, y = 0 },
            { x = 208, y = -16 },
            { x = 224, y = -16 },
            { x = 224, y = 64 },
            { x = 0, y = 64 },
            { x = -16, y = 64 },
            { x = -16, y = -16 },
            { x = 0, y = -16 }
          },
          properties = {
            ["friction"] = -1,
            ["slippery"] = true
          }
        },
        {
          id = 49,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 961.856,
          y = -553.115,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -13.3078, y = -21.079 },
            { x = -1.85637, y = -38.8848 },
            { x = 14.5397, y = -60.3386 },
            { x = 37.9235, y = -71.1938 },
            { x = 66.6043, y = -77.3957 },
            { x = 96.9157, y = -79.1346 },
            { x = 115.907, y = -74.7913 },
            { x = 136.522, y = -68.2805 },
            { x = 154.14, y = -49.399 },
            { x = 174.144, y = -6.88482 },
            { x = 174.144, y = 393.115 },
            { x = 270.144, y = 393.115 },
            { x = 272, y = 0 },
            { x = 270.144, y = -102.885 },
            { x = 318.144, y = -102.885 },
            { x = 318.144, y = -118.885 },
            { x = 270.144, y = -118.885 },
            { x = -49.8564, y = -118.885 },
            { x = -49.8564, y = 121.115 },
            { x = -34.1365, y = 121.115 },
            { x = -26.3405, y = 121.115 },
            { x = -20.8326, y = 117.808 },
            { x = -17.8564, y = 112.97 },
            { x = -17.8564, y = 41.1152 },
            { x = -17.8564, y = 9.11518 }
          },
          properties = {
            ["friction"] = -1,
            ["slippery"] = true
          }
        },
        {
          id = 50,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 912,
          y = -416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 224 },
            { x = 16, y = 192 },
            { x = 32, y = 144 },
            { x = 32, y = 8.19793 },
            { x = 30.5251, y = 1.47487 },
            { x = 23.0688, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 53,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1072,
          y = -480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 256 },
            { x = 32, y = 272 },
            { x = 64, y = 256 },
            { x = 64, y = 0 },
            { x = 32, y = 16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 54,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1072,
          y = -128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 16 },
            { x = 48, y = 32 },
            { x = 70.4546, y = 39.1494 },
            { x = 96.2568, y = 43.6351 },
            { x = 112.257, y = 43.6351 },
            { x = 136.236, y = 39.388 },
            { x = 160, y = 32 },
            { x = 192, y = 16 },
            { x = 208, y = 0 },
            { x = 208, y = -16 },
            { x = 224, y = -16 },
            { x = 224, y = 64 },
            { x = -16, y = 64 },
            { x = -16, y = -16 },
            { x = 0, y = -16 }
          },
          properties = {
            ["friction"] = -1,
            ["slippery"] = true
          }
        },
        {
          id = 56,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1232,
          y = -672,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 16 },
            { x = 0, y = 144 },
            { x = 48, y = 144 },
            { x = 48, y = 16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 58,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1249.36,
          y = -366.31,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -1.36, y = 62.31 },
            { x = -17.3626, y = 94.3097 },
            { x = -17.3626, y = -1.69029 },
            { x = -1.36257, y = -33.6903 }
          },
          properties = {}
        },
        {
          id = 59,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1264,
          y = -384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -16 },
            { x = 0, y = 80 },
            { x = 16, y = 112 },
            { x = 48, y = 112 },
            { x = 48, y = 64 },
            { x = 144, y = 64 },
            { x = 144, y = 32 },
            { x = 224, y = 32 },
            { x = 224, y = 16 },
            { x = 80, y = 16 },
            { x = 16, y = 16 }
          },
          properties = {}
        },
        {
          id = 62,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2928,
          y = -2096,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 224 },
            { x = 0, y = 272 },
            { x = 336, y = 272 },
            { x = 208, y = 224 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 64,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3504,
          y = -1808,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -240, y = 0 },
            { x = -368, y = 48 },
            { x = -240, y = 48 },
            { x = -208, y = 16 },
            { x = -48, y = 16 },
            { x = -48, y = 0 },
            { x = -192, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 65,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3504,
          y = -1824,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -240, y = 0 },
            { x = -368, y = -48 },
            { x = -240, y = -48 },
            { x = -208, y = -16 },
            { x = -48, y = -16 },
            { x = -48, y = 0 },
            { x = -192, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 66,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2976,
          y = -2048,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -80, y = 224 },
            { x = -80, y = 240 },
            { x = -80, y = 288 },
            { x = -48, y = 288 },
            { x = -48, y = 240 },
            { x = 576, y = 240 },
            { x = 576, y = 224 },
            { x = -48, y = 224 },
            { x = -48, y = 176 },
            { x = -80, y = 176 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0,
            ["velocity"] = 10
          }
        },
        {
          id = 67,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 5127.59,
          y = -1140.62,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 25.2085, y = -29.0867 },
            { x = 161.57, y = -61.4644 },
            { x = 288.647, y = -109.807 },
            { x = 504.413, y = -187.381 },
            { x = 655.215, y = -231.966 },
            { x = 840.413, y = -267.381 },
            { x = 959.368, y = -290.192 },
            { x = 1064.41, y = -299.381 },
            { x = 1138.27, y = -286.47 },
            { x = 1192.41, y = -251.381 },
            { x = 1224.41, y = -187.381 },
            { x = 1192.41, y = -203.381 },
            { x = 1128.41, y = -219.381 },
            { x = 1032.41, y = -203.381 },
            { x = 968.413, y = -139.381 },
            { x = 955.764, y = -46.9816 },
            { x = 1056, y = 352 },
            { x = 24.4127, y = 356.619 },
            { x = -327.587, y = 356.619 },
            { x = -875.492, y = 356.619 },
            { x = -1472.65, y = 356.619 },
            { x = -1847.59, y = 356.619 },
            { x = -1847.59, y = -11.3809 },
            { x = -1467.91, y = -11.3809 },
            { x = -894.45, y = -11.3809 },
            { x = -327.587, y = -11.3809 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1,
            ["velocity"] = 1.5
          }
        },
        {
          id = 69,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3264,
          y = -1728,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 0, y = 1280 },
            { x = -32, y = 1280 },
            { x = -32, y = -32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 70,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3504,
          y = -1904,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -240, y = 0 },
            { x = -656, y = -192 },
            { x = -896, y = -192 },
            { x = -896, y = -48 },
            { x = -608, y = 80 },
            { x = -608, y = 32 },
            { x = -240, y = 32 }
          },
          properties = {}
        },
        {
          id = 71,
          name = "",
          type = "Coin",
          shape = "point",
          x = 2912,
          y = -1728,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 72,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 6176,
          y = -448,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = -336 },
            { x = -2896, y = -352 },
            { x = -3536, y = 144 },
            { x = 16, y = 144 }
          },
          properties = {}
        },
        {
          id = 78,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1424,
          y = -992,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 208 },
            { x = 64, y = 208 },
            { x = 64, y = 32 },
            { x = 32, y = 16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 81,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1456,
          y = -400,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 160 },
            { x = 64, y = 160 },
            { x = 64, y = 32 },
            { x = 32, y = 32 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 82,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1488,
          y = -368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 16 },
            { x = 0, y = 208 },
            { x = 32, y = 208 },
            { x = 32, y = 16 },
            { x = 96, y = 16 },
            { x = 96, y = -1344 },
            { x = 112, y = -1328 },
            { x = 112, y = 240 },
            { x = -80, y = 240 },
            { x = -80, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 83,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1520,
          y = -672,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 208 },
            { x = 64, y = 208 },
            { x = 64, y = 32 },
            { x = 32, y = 16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 84,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1520,
          y = -1344,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 208 },
            { x = 64, y = 208 },
            { x = 64, y = 32 },
            { x = 32, y = 16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 85,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1424,
          y = -1664,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 208 },
            { x = 64, y = 208 },
            { x = 64, y = 32 },
            { x = 32, y = 16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 87,
          name = "",
          type = "Coin",
          shape = "point",
          x = 1503.91,
          y = -176.837,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 88,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1392,
          y = -384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = -32 },
            { x = 32, y = -32 },
            { x = 32, y = -1440 },
            { x = 320, y = -1440 },
            { x = 352, y = -1424 },
            { x = 464, y = -1424 },
            { x = 480, y = -1456 },
            { x = 528, y = -1664 },
            { x = 672, y = -1664 },
            { x = 752, y = -1472 },
            { x = 880, y = -1424 },
            { x = 880, y = -1456 },
            { x = 896, y = -1472 },
            { x = 896, y = -1728 },
            { x = 352, y = -1728 },
            { x = 352, y = -1456 },
            { x = 224, y = -1456 },
            { x = 32, y = -1456 },
            { x = 16, y = -1456 },
            { x = 16, y = -1440 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 90,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1520,
          y = -368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 64, y = 16 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 92,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1600,
          y = -128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = -1216 },
            { x = 304, y = -1216 },
            { x = 304, y = -1232 },
            { x = 272, y = -1264 },
            { x = 288, y = -1264 },
            { x = 288, y = -1312 },
            { x = 304, y = -1312 },
            { x = 304, y = -1328 },
            { x = 288, y = -1344 },
            { x = 256, y = -1344 },
            { x = 256, y = -1520 },
            { x = 224, y = -1520 },
            { x = 192, y = -1568 },
            { x = 32, y = -1568 },
            { x = 0, y = -1568 },
            { x = 0, y = -1536 }
          },
          properties = {}
        },
        {
          id = 93,
          name = "",
          type = "Coin",
          shape = "point",
          x = 1360,
          y = -496,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 94,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1280,
          y = -672,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 144 },
            { x = 112, y = 144 },
            { x = 112, y = 256 },
            { x = 128, y = 256 },
            { x = 128, y = 0 },
            { x = 128, y = -1168 },
            { x = 464, y = -1168 },
            { x = 464, y = -1184 },
            { x = 464, y = -1440 },
            { x = 128, y = -1184 },
            { x = 112, y = -1184 },
            { x = 112, y = 0 }
          },
          properties = {}
        },
        {
          id = 95,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1462.06,
          y = -1826.73,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -38.0612, y = 2.72707 },
            { x = -38.0612, y = 66.7271 },
            { x = 121.939, y = 66.7271 },
            { x = 137.939, y = 34.7271 },
            { x = 121.939, y = 2.72707 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0
          }
        },
        {
          id = 97,
          name = "",
          type = "Coin",
          shape = "point",
          x = -48.9584,
          y = -66.2949,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 123,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -768,
          y = 544,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 96 },
            { x = 224, y = 96 },
            { x = 208, y = 112 },
            { x = 208, y = 144 },
            { x = 224, y = 160 },
            { x = 432, y = 160 },
            { x = 448, y = 144 },
            { x = 464, y = 128 },
            { x = 464, y = -64 },
            { x = 448, y = -80 },
            { x = 448, y = -96 },
            { x = 576, y = -96 },
            { x = 576, y = -80 },
            { x = 560, y = -64 },
            { x = 560, y = 80 },
            { x = 576, y = 96 },
            { x = 656, y = 96 },
            { x = 640, y = 112 },
            { x = 640, y = 144 },
            { x = 656, y = 160 },
            { x = 800, y = 160 },
            { x = 1312, y = 160 },
            { x = 1312, y = 144 },
            { x = 1328, y = 128 },
            { x = 1328, y = -208 },
            { x = 1312, y = -224 },
            { x = 1568, y = -224 },
            { x = 1648, y = -224 },
            { x = 1648, y = 96 },
            { x = 2080, y = 96 },
            { x = 2080, y = -224 },
            { x = 2192, y = -224 },
            { x = 2192, y = 176 },
            { x = 2000, y = 176 },
            { x = 1840, y = 176 },
            { x = 1680, y = 176 },
            { x = 1552, y = 176 },
            { x = 976, y = 176 },
            { x = 576, y = 176 },
            { x = 447.819, y = 176 },
            { x = 0, y = 176 }
          },
          properties = {}
        },
        {
          id = 124,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = -768,
          y = 832,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 3638.09, y = 0 },
            { x = 3638.09, y = 160 },
            { x = 42.3033, y = 160 }
          },
          properties = {}
        },
        {
          id = 134,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -432,
          y = 704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = -64 },
            { x = 0, y = -176 },
            { x = 16, y = -64 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 135,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 544,
          y = 320,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 368 },
            { x = 16, y = 352 },
            { x = 16, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 137,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -224,
          y = 432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 32 },
            { x = 32, y = 208 },
            { x = 16, y = 192 },
            { x = 16, y = 48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 142,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 336,
          y = 528,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -48, y = 112 },
            { x = 0, y = -160 },
            { x = 48, y = 112 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 145,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -48,
          y = 640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 15.1081 },
            { x = 80, y = 32 },
            { x = 16, y = 32 },
            { x = 16, y = 14.5594 },
            { x = 32, y = 0 },
            { x = 64.46, y = 0 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 146,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 112,
          y = 640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = 80, y = 0 },
            { x = 96, y = 16 },
            { x = 96, y = 32 },
            { x = 0, y = 32 },
            { x = 0, y = 15.1081 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 147,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 288,
          y = 640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -0.587293, y = 0 },
            { x = 96, y = 0 },
            { x = 112.393, y = 14.5594 },
            { x = 112.393, y = 32 },
            { x = -16, y = 32 },
            { x = -16, y = 14.5594 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 148,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -480,
          y = 640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 0 },
            { x = 80, y = 16 },
            { x = 80, y = 32 },
            { x = 16, y = 32 },
            { x = 16, y = 15.938 },
            { x = 32, y = 0 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 149,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 0,
          y = 704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = -64 },
            { x = 0, y = -176 },
            { x = 16, y = -64 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 151,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -320,
          y = 432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 256 },
            { x = 16, y = 240 },
            { x = 16, y = 48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 153,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 160,
          y = 608,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 32 },
            { x = 0, y = -160 },
            { x = 32, y = 32 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 155,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -576,
          y = 624,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 16 },
            { x = 32, y = 80 },
            { x = 16, y = 64 },
            { x = 16, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 156,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -144,
          y = 624,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 16 },
            { x = 32, y = 80 },
            { x = 16, y = 64 },
            { x = 16, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 157,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1312,
          y = 448,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -128 },
            { x = -80, y = -128 },
            { x = -78.4455, y = -15.3947 },
            { x = -83.8935, y = -14.7893 },
            { x = -78.4455, y = 0.343826 },
            { x = -79.5666, y = 105.534 },
            { x = -85.9982, y = 98.3273 },
            { x = -80, y = 112 },
            { x = -80, y = 192 },
            { x = 0, y = 192 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 158,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -784,
          y = -2448,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -304, y = 80 },
            { x = 1056, y = 80 },
            { x = 1056, y = 32 },
            { x = 1072, y = 16 },
            { x = 816, y = 16 },
            { x = 752, y = -48 },
            { x = 752, y = -160 },
            { x = 576, y = -160 },
            { x = 496, y = -160 },
            { x = 480, y = -160 },
            { x = 496, y = -144 },
            { x = 494.964, y = -64 },
            { x = 272, y = -64 },
            { x = 256, y = -64 },
            { x = 272, y = -48 },
            { x = 272, y = 0 },
            { x = -160, y = 0 },
            { x = -160, y = -288 },
            { x = -144, y = -304 },
            { x = -304, y = -304 }
          },
          properties = {}
        },
        {
          id = 160,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -528,
          y = -2512,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 16 },
            { x = 16, y = 64 },
            { x = 0, y = 64 }
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
          x = -944,
          y = -2752,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 16 },
            { x = 16, y = 0 },
            { x = 16, y = 304 },
            { x = 0, y = 304 }
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
          x = -304,
          y = -2512,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = -80 },
            { x = 0, y = -96 }
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
          x = -32,
          y = -2608,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 112 },
            { x = 64, y = 176 },
            { x = 176, y = 176 }
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
          x = 2208,
          y = -2736,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -336, y = 128 },
            { x = -278.266, y = 128 },
            { x = -128, y = 128 },
            { x = -144, y = 144 },
            { x = -320, y = 144 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 165,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1792,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 80, y = -80 },
            { x = 80, y = -16 },
            { x = 64, y = 0 }
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
          x = 2080,
          y = -2608,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 144, y = 192 },
            { x = 0, y = 192 }
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
          x = 2416,
          y = -2656,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 112, y = 0 },
            { x = 128, y = 16 },
            { x = 128, y = 240 },
            { x = 112, y = 240 },
            { x = 112, y = 32 },
            { x = 96, y = 16 },
            { x = 16, y = 16 }
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
          x = 560,
          y = -2448,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 976, y = 80 },
            { x = 3776, y = 80 },
            { x = 3776, y = 32 },
            { x = 2640, y = 32 },
            { x = 2592, y = 16 },
            { x = 2592, y = -16 },
            { x = 2576, y = 0 },
            { x = 2560, y = -16 },
            { x = 2560, y = -240 },
            { x = 2416, y = -240 },
            { x = 2416, y = -176 },
            { x = 2432, y = -160 },
            { x = 2432, y = -112 },
            { x = 2416, y = -97.7583 },
            { x = 2416, y = -48 },
            { x = 2432, y = -31.3251 },
            { x = 2432, y = 32 },
            { x = 1968, y = 32 },
            { x = 1968, y = -176 },
            { x = 1952, y = -192 },
            { x = 1872, y = -192 },
            { x = 1856, y = -208 },
            { x = 1856, y = 32 },
            { x = 1520, y = 32 },
            { x = 1520, y = -160 },
            { x = 1504, y = -144 },
            { x = 1328, y = -144 },
            { x = 1312, y = -160 },
            { x = 1312, y = -160 },
            { x = 1312, y = 0 },
            { x = 1296, y = 16 },
            { x = 1232, y = 16 },
            { x = 976, y = 16 },
            { x = 960, y = 16 },
            { x = 976, y = 32 }
          },
          properties = {}
        },
        {
          id = 170,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 80,
          y = -2368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1494.03, y = 0 },
            { x = 1494.03, y = 96 },
            { x = 0, y = 96 }
          },
          properties = {}
        },
        {
          id = 171,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 464,
          y = -2368,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = 16, y = -48 },
            { x = 0, y = -64 },
            { x = 96, y = -64 },
            { x = 128, y = -80 },
            { x = 144, y = -64 },
            { x = 128, y = -48 },
            { x = 336, y = -48 },
            { x = 368, y = -64 },
            { x = 432, y = -64 },
            { x = 448, y = -64 },
            { x = 432, y = -48 },
            { x = 432, y = 0 }
          },
          properties = {}
        },
        {
          id = 172,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 288,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = -16, y = 64 },
            { x = -16, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 174,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 480,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 16 },
            { x = 0, y = 64 },
            { x = -16, y = 64 },
            { x = -16, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 175,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 608,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = -16 },
            { x = 16, y = -16 },
            { x = 192, y = -16 },
            { x = 224, y = 0 },
            { x = 192, y = 16 },
            { x = -16, y = 16 },
            { x = 0, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 176,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1344,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -96, y = 0 },
            { x = -112, y = 16 },
            { x = -112, y = 64 },
            { x = -96, y = 64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 177,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1168,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 16 },
            { x = 16, y = 64 },
            { x = 64, y = 64 },
            { x = 64, y = 16 },
            { x = 80, y = 0 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 178,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1168,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 16 },
            { x = 16, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 179,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 912,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 16 },
            { x = -16, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 180,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1520,
          y = -2432,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 16 },
            { x = 16, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 181,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2928,
          y = -2496,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 48, y = 0 },
            { x = 48, y = 80 },
            { x = 64, y = 80 },
            { x = 64, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 182,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2928,
          y = -2624,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 48, y = 0 },
            { x = 48, y = 80 },
            { x = 64, y = 64 },
            { x = 64, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 183,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2928,
          y = -2704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 48, y = -16 },
            { x = 224, y = -16 },
            { x = 224, y = 0 },
            { x = 224, y = 240 },
            { x = 208, y = 256 },
            { x = 192, y = 240 },
            { x = 192, y = 16 },
            { x = 48, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 185,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3392,
          y = -2656,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 0 },
            { x = 80, y = 32 },
            { x = 64, y = 32 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 186,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3392,
          y = -2656,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 0 },
            { x = 48, y = -32 },
            { x = 48, y = 64 },
            { x = 80, y = 32 },
            { x = 64, y = 32 },
            { x = 64, y = 0 }
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
          x = 3520,
          y = -2768,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 0 },
            { x = 80, y = 32 },
            { x = 64, y = 32 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 190,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3520,
          y = -2544,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 0 },
            { x = 80, y = 32 },
            { x = 64, y = 32 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 191,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3504,
          y = -2544,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 0 },
            { x = 112, y = -32 },
            { x = 112, y = 64 },
            { x = 80, y = 32 },
            { x = 96, y = 32 },
            { x = 96, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 192,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3504,
          y = -2768,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 0 },
            { x = 112, y = -32 },
            { x = 112, y = 64 },
            { x = 80, y = 32 },
            { x = 96, y = 32 },
            { x = 96, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 193,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3360,
          y = -2864,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 0 },
            { x = 80, y = 48 },
            { x = 64, y = 48 },
            { x = 64, y = 16 },
            { x = 32, y = 16 },
            { x = 16, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 194,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3296,
          y = -2864,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 80, y = 0 },
            { x = 80, y = 32 },
            { x = 112, y = 32 },
            { x = 112, y = 48 },
            { x = 128, y = 48 },
            { x = 128, y = 16 },
            { x = 96, y = 16 }
          },
          properties = {}
        },
        {
          id = 196,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3584,
          y = -2896,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 144, y = 480 },
            { x = 225.06, y = 479.321 },
            { x = 224, y = 416 },
            { x = 224, y = 288.442 },
            { x = 240, y = 288.442 },
            { x = 240, y = 224 },
            { x = 224, y = 224.442 },
            { x = 224, y = 48 },
            { x = 240, y = 48 },
            { x = 240, y = -16 },
            { x = 224, y = -16 },
            { x = 224, y = -80 },
            { x = 240, y = -80 },
            { x = 240, y = -96 },
            { x = 240, y = -112 },
            { x = 112, y = -112 },
            { x = 96, y = -96 },
            { x = 96, y = -48 },
            { x = 112, y = -32 },
            { x = 144, y = -32 }
          },
          properties = {}
        },
        {
          id = 197,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3584,
          y = -2928,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 128, y = 0 },
            { x = 128, y = 512 },
            { x = 144, y = 512 },
            { x = 144, y = 0 }
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
          x = 3680,
          y = -2992,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -32 },
            { x = 144, y = -32 },
            { x = 160, y = -32 },
            { x = 160, y = -16 },
            { x = 144, y = 0 },
            { x = 144, y = -16 },
            { x = 16, y = -16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 199,
          name = "",
          type = "Coin",
          shape = "point",
          x = -302.771,
          y = -355.137,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 200,
          name = "",
          type = "Coin",
          shape = "point",
          x = -208,
          y = -112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 203,
          name = "",
          type = "Coin",
          shape = "point",
          x = 98.018,
          y = -2510.66,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 204,
          name = "",
          type = "Coin",
          shape = "point",
          x = -168.274,
          y = -2623.99,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 205,
          name = "",
          type = "Coin",
          shape = "point",
          x = -421.073,
          y = -2543.99,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 207,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -768,
          y = -1312,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 240, y = 0 },
            { x = 240, y = 112 },
            { x = 0, y = 112 }
          },
          properties = {}
        },
        {
          id = 210,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1968,
          y = -1648,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = 0 },
            { x = 16, y = 0 },
            { x = 16, y = -208 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 213,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2080,
          y = -1824,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = -32 },
            { x = -96, y = -32 },
            { x = -96, y = 176 },
            { x = -128, y = 176 },
            { x = -128, y = 352 },
            { x = -160, y = 352 },
            { x = -176, y = 368 },
            { x = -176, y = 384 },
            { x = -160, y = 384 },
            { x = -160, y = 432 },
            { x = -144, y = 432 },
            { x = -176, y = 464 },
            { x = -176, y = 480 },
            { x = -16, y = 480 }
          },
          properties = {}
        },
        {
          id = 215,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1856,
          y = -1648,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 96, y = 0 },
            { x = 96, y = 176 },
            { x = 0, y = 176 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 216,
          name = "",
          type = "Coin",
          shape = "point",
          x = 1904,
          y = -1472,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 217,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1984,
          y = -1824,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 80, y = -32 },
            { x = 80, y = 336 },
            { x = 288, y = 336 },
            { x = 96, y = -48 },
            { x = 0, y = -48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 221,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2304,
          y = -1504,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 16 },
            { x = 64, y = 16 },
            { x = 64, y = 288 },
            { x = -32, y = 288 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 222,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1888,
          y = -1440,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 0 },
            { x = 32, y = 48 },
            { x = 48, y = 48 },
            { x = 16, y = 80 },
            { x = -16, y = 48 },
            { x = 0, y = 48 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 223,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2464,
          y = -1824,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 176, y = -16 },
            { x = 176, y = 464 },
            { x = 80, y = 464 },
            { x = 80, y = 336 },
            { x = -96, y = 336 },
            { x = 48, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 225,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2144,
          y = -2048,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 464, y = -48 },
            { x = 464, y = 96 },
            { x = 400, y = 96 },
            { x = 320, y = 192 },
            { x = 224, y = 240 },
            { x = 224, y = 208 },
            { x = 208, y = 208 },
            { x = 208, y = -48 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 226,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2272,
          y = -1488,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0.474544, y = 272 },
            { x = 96.4745, y = 272 },
            { x = 96, y = 0 },
            { x = 272, y = 0 },
            { x = 272, y = 224 },
            { x = 95.8295, y = 352 },
            { x = 0, y = 352 },
            { x = -208, y = 224 },
            { x = -208, y = 0 }
          },
          properties = {}
        },
        {
          id = 229,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2304,
          y = -1904,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 48 },
            { x = 0, y = 64 },
            { x = -16, y = 80 },
            { x = -16, y = 96 },
            { x = -32, y = 96 },
            { x = -32, y = 64 },
            { x = -16, y = 48 },
            { x = -16, y = -128 },
            { x = 48, y = -128 },
            { x = 48, y = 48 },
            { x = 64, y = 64 },
            { x = 64, y = 96 },
            { x = 48, y = 96 },
            { x = 48, y = 80 },
            { x = 32, y = 64 },
            { x = 32, y = 48 },
            { x = 32, y = -112 },
            { x = 0, y = -112 }
          },
          properties = {}
        },
        {
          id = 230,
          name = "",
          type = "Coin",
          shape = "point",
          x = 2320,
          y = -1984,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 231,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1856,
          y = -1648,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = -48 },
            { x = -64, y = -48 },
            { x = -32, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 232,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1792,
          y = -1712,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 0 },
            { x = -208, y = 0 },
            { x = -192, y = 16 },
            { x = 32, y = 16 }
          },
          properties = {}
        },
        {
          id = 238,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2784,
          y = -1536,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 144, y = 304 },
            { x = 144, y = -224 },
            { x = 448, y = -224 },
            { x = 448, y = -192 },
            { x = 176, y = -144 },
            { x = 176, y = 304 },
            { x = 176, y = 336 },
            { x = -144, y = 336 },
            { x = -144, y = 304 },
            { x = -144, y = -304 },
            { x = -112, y = -304 },
            { x = -48, y = -304 },
            { x = -64, y = -288 },
            { x = -112, y = -287.962 },
            { x = -112, y = 304 }
          },
          properties = {}
        },
        {
          id = 240,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2640,
          y = -1792,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = -16 },
            { x = 64, y = 336 },
            { x = 32, y = 336 },
            { x = 32, y = -16 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 241,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2704,
          y = -1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 272 },
            { x = 64, y = 336 },
            { x = 32, y = 336 },
            { x = 32, y = 272 },
            { x = 32, y = 240 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 246,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2640,
          y = -1600,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 272 },
            { x = 32, y = 240 },
            { x = 224, y = 240 },
            { x = 224, y = 272 }
          },
          properties = {
            ["axis_x"] = -1,
            ["axis_y"] = 0
          }
        },
        {
          id = 247,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2640,
          y = -1504,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 272 },
            { x = 64, y = 240 },
            { x = 128, y = 240 },
            { x = 128, y = 272 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0
          }
        },
        {
          id = 248,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2640,
          y = -1584,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 352 },
            { x = 32, y = 224 },
            { x = 64, y = 256 },
            { x = 64, y = 320 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1
          }
        },
        {
          id = 249,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2736,
          y = -1584,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 352 },
            { x = 64, y = 256 },
            { x = 32, y = 256 },
            { x = 32, y = 320 },
            { x = 32, y = 352 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 251,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2704,
          y = -1696.77,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 272 },
            { x = 32, y = 240.766 },
            { x = 192, y = 240 },
            { x = 192, y = 272 }
          },
          properties = {
            ["axis_x"] = -1,
            ["axis_y"] = 0
          }
        },
        {
          id = 252,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2512,
          y = -1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 160, y = 272 },
            { x = 160, y = 240 },
            { x = 224, y = 240 },
            { x = 224, y = 272 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0
          }
        },
        {
          id = 253,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2704,
          y = -1504.46,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 96, y = 272.458 },
            { x = 96, y = 240.458 },
            { x = 160, y = 240.458 },
            { x = 192, y = 240.458 },
            { x = 192, y = 272 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0
          }
        },
        {
          id = 258,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2608,
          y = -1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 272 },
            { x = 128, y = 272 },
            { x = 128, y = 336 },
            { x = 64, y = 336 }
          },
          properties = {
            ["filter"] = 15
          }
        },
        {
          id = 260,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2704,
          y = -1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 272 },
            { x = 160, y = 272 },
            { x = 160, y = 336 },
            { x = 64, y = 336 }
          },
          properties = {
            ["filter"] = 15
          }
        },
        {
          id = 261,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2640,
          y = -1600,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 272 },
            { x = 128, y = 272 },
            { x = 128, y = 336 },
            { x = 64, y = 336 }
          },
          properties = {
            ["filter"] = 15
          }
        },
        {
          id = 262,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2736,
          y = -1600,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 272 },
            { x = 128, y = 272 },
            { x = 128, y = 336 },
            { x = 64, y = 336 }
          },
          properties = {
            ["filter"] = 15
          }
        },
        {
          id = 264,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2832,
          y = -1600,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 272 },
            { x = 64, y = 272 },
            { x = 64, y = 336 },
            { x = 32, y = 336 }
          },
          properties = {
            ["filter"] = 15
          }
        },
        {
          id = 266,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2928,
          y = -1664,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 336 },
            { x = 0, y = 432 },
            { x = -32, y = 432 },
            { x = -32, y = 336 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 268,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2896,
          y = -1792,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 400 },
            { x = 0, y = 464 },
            { x = -32, y = 464 },
            { x = -32, y = 400 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 270,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2928,
          y = -1824,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 64 },
            { x = 0, y = 432 },
            { x = -32, y = 432 },
            { x = -32, y = 64 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 275,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2896,
          y = -1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 304 },
            { x = 32, y = 304 },
            { x = 32, y = 336 },
            { x = 0, y = 336 }
          },
          properties = {
            ["filter"] = 15
          }
        },
        {
          id = 276,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2896,
          y = -1600,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 272 },
            { x = 0, y = 240 },
            { x = 32, y = 240 },
            { x = 32, y = 272 }
          },
          properties = {
            ["axis_x"] = -1,
            ["axis_y"] = 0
          }
        },
        {
          id = 277,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2768,
          y = -1664,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 96, y = 272 },
            { x = 96, y = 240.458 },
            { x = 128, y = 240 },
            { x = 128, y = 272 }
          },
          properties = {
            ["axis_x"] = 1,
            ["axis_y"] = 0
          }
        },
        {
          id = 279,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2848,
          y = -1808,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -144, y = 352 },
            { x = -112, y = 352 },
            { x = 48, y = 352 },
            { x = 48, y = 48 },
            { x = 16, y = 48 },
            { x = 16, y = 320 },
            { x = -112, y = 320 },
            { x = -112, y = 48 },
            { x = -144, y = 48 }
          },
          properties = {
            ["filter"] = 15
          }
        },
        {
          id = 280,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2896,
          y = -1808,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 48 },
            { x = -192, y = 48 },
            { x = -192, y = 0 }
          },
          properties = {}
        },
        {
          id = 281,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 2928,
          y = -1760,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -48 },
            { x = 336, y = -48 },
            { x = 208, y = 0 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 282,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3872,
          y = -2896,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 160, y = 480 },
            { x = 240, y = 480 },
            { x = 240, y = -112 },
            { x = 144, y = -112 },
            { x = 144, y = -96 },
            { x = 160, y = -96 },
            { x = 160, y = -80 },
            { x = 144, y = -80 },
            { x = 144, y = -16 },
            { x = 160, y = -16 },
            { x = 160, y = 112 },
            { x = 144, y = 112 },
            { x = 144, y = 176 },
            { x = 160, y = 176 },
            { x = 160, y = 320 },
            { x = 144, y = 320 },
            { x = 144, y = 384 },
            { x = 160, y = 384 }
          },
          properties = {}
        },
        {
          id = 283,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3952,
          y = -2992,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 144, y = -32 },
            { x = 144, y = -16 },
            { x = 62.6679, y = -16 },
            { x = 64, y = 0 },
            { x = 80, y = 0 },
            { x = 80, y = 16 },
            { x = 64, y = 16 },
            { x = 64, y = 16 },
            { x = 32, y = -16 },
            { x = 32, y = -32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 284,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4423.24,
          y = -3182.51,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 272 },
            { x = 16, y = 288 },
            { x = 32, y = 272 },
            { x = 32, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 285,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4491.84,
          y = -2690.9,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 16, y = 96 },
            { x = 32, y = 80 },
            { x = 32, y = 0 },
            { x = 16, y = -16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 286,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4134.58,
          y = -2613.04,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 80 },
            { x = 16, y = 96 },
            { x = 32, y = 80 },
            { x = 32, y = 0 },
            { x = 16, y = -16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 290,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3952,
          y = -2480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 64, y = 32 },
            { x = 64, y = -32 },
            { x = 80, y = -32 },
            { x = 80, y = 64 },
            { x = 32, y = 64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 292,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3824,
          y = -2944,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 96 },
            { x = -16, y = 96 },
            { x = -16, y = 272 },
            { x = 0, y = 272 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 293,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3824,
          y = -2720,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 112 },
            { x = -16, y = 112 },
            { x = -16, y = 304 },
            { x = 32, y = 304 },
            { x = 0, y = 272 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 294,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4032,
          y = -2768,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 48 },
            { x = -16, y = 48 },
            { x = -16, y = 192 },
            { x = 0, y = 192 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 295,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4032,
          y = -3024,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 112 },
            { x = -16, y = 112 },
            { x = -16, y = 240 },
            { x = 0, y = 240 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 296,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -449.9,
          y = 1283.81,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 1.89976, y = -19.8138 },
            { x = 1.89976, y = 204.186 },
            { x = -366.1, y = 204.186 },
            { x = -366.1, y = 268.186 },
            { x = 64, y = 272 },
            { x = 65.8998, y = -19.8138 }
          },
          properties = {}
        },
        {
          id = 297,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -720,
          y = 1488,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -96, y = -256 },
            { x = -96, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 300,
          name = "",
          type = "Hook",
          shape = "point",
          x = -548.192,
          y = 1473.4,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 301,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -464,
          y = 1264,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -16 },
            { x = 0, y = 224 },
            { x = 16, y = 224 },
            { x = 16, y = 0 },
            { x = 80, y = 0 },
            { x = 96, y = -16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 302,
          name = "",
          type = "Coin",
          shape = "point",
          x = -208,
          y = -304,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 303,
          name = "",
          type = "Coin",
          shape = "point",
          x = -208,
          y = -240,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 304,
          name = "",
          type = "Coin",
          shape = "point",
          x = -208,
          y = -272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 305,
          name = "",
          type = "Coin",
          shape = "point",
          x = -208,
          y = -208,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 306,
          name = "",
          type = "Coin",
          shape = "point",
          x = -208,
          y = -176,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 307,
          name = "",
          type = "Coin",
          shape = "point",
          x = -208,
          y = -144,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 308,
          name = "",
          type = "Coin",
          shape = "point",
          x = -208,
          y = -80,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 309,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -800,
          y = 1680,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 240 },
            { x = 800, y = 240 },
            { x = 800, y = 16 },
            { x = 736, y = 80 },
            { x = 695.848, y = 87.043 },
            { x = 712.402, y = 103.598 },
            { x = 640, y = 176 },
            { x = 624, y = 160 },
            { x = 608, y = 176 },
            { x = 336, y = 176 },
            { x = 336, y = 192 },
            { x = 240, y = 192 },
            { x = 239.71, y = 176 },
            { x = 64, y = 176 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 315,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = -816,
          y = 1648,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 288 },
            { x = 832, y = 288 },
            { x = 832, y = -96 },
            { x = 880, y = -96 },
            { x = 880, y = 336 },
            { x = -48, y = 336 },
            { x = -48, y = -16 },
            { x = 0, y = -16 }
          },
          properties = {}
        },
        {
          id = 317,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = -736,
          y = 1680,
          width = 16,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 318,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = -560,
          y = 1856,
          width = 96,
          height = 16,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 319,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = -512,
          y = 1776,
          width = 144,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 320,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = -103.336,
          y = 1767.37,
          width = 22.9256,
          height = 102.621,
          rotation = 45,
          visible = true,
          properties = {}
        },
        {
          id = 321,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = -656,
          y = 1792,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 322,
          name = "",
          type = "BouncePad",
          shape = "rectangle",
          x = -592,
          y = 1728,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 324,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -800,
          y = 2320,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 80 },
            { x = 1136, y = 80 },
            { x = 1136, y = 16 },
            { x = 720, y = -224 },
            { x = 720, y = -144 },
            { x = 704, y = -80 },
            { x = 640, y = 0 },
            { x = 480, y = 16 },
            { x = 448, y = -16 },
            { x = 384, y = -32 },
            { x = 336, y = 16 },
            { x = 304, y = 16 },
            { x = 256, y = 0 },
            { x = 208, y = 16 },
            { x = 176, y = 16 },
            { x = 144, y = 0 },
            { x = 112, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {}
        },
        {
          id = 325,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 336,
          y = 2320,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 80 },
            { x = 1136, y = 80 },
            { x = 1136, y = 16 },
            { x = 720, y = -224 },
            { x = 720, y = -144 },
            { x = 704, y = -80 },
            { x = 640, y = 0 },
            { x = 480, y = 16 },
            { x = 448, y = -16 },
            { x = 384, y = -32 },
            { x = 336, y = 16 },
            { x = 304, y = 16 },
            { x = 256, y = 0 },
            { x = 208, y = 16 },
            { x = 176, y = 16 },
            { x = 144, y = 0 },
            { x = 112, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 326,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = -816,
          y = 2224,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 208 },
            { x = 2304, y = 192 },
            { x = 2304, y = -80 },
            { x = 2400, y = -80 },
            { x = 2400, y = 304 },
            { x = -112, y = 288 },
            { x = -96, y = -112 }
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
      name = "Tile Layer 1",
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
      chunks = {
        {
          x = 224, y = -192, width = 16, height = 16,
          data = "eJxjYBgcwH2gHTAKRsEIBAD6SABI"
        },
        {
          x = -32, y = -96, width = 16, height = 16,
          data = "eJxjYBgF+IDbQDtgFIwCGgIAzUAARw=="
        },
        {
          x = -32, y = 96, width = 16, height = 16,
          data = "eJxjYBgFo2AUYANuA+0AOgAAQlgARw=="
        }
      }
    }
  }
}
