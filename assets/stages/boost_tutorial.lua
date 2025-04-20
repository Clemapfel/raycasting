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
  nextobjectid = 158,
  properties = {
    ["title"] = "Boosting"
  },
  tilesets = {},
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
          x = -170.939,
          y = -57.6327,
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
            { x = -80, y = -384 },
            { x = -64, y = -368 },
            { x = -64, y = -160 },
            { x = -64, y = -144 },
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
          x = -304,
          y = -352,
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
            { x = 224, y = 48 },
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
            { x = 224, y = 48 },
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
            { x = -1.36257, y = 62.3097 },
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
          id = 60,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1568,
          y = -1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 64, y = 16 },
            { x = 384, y = 16 },
            { x = 384, y = 64 },
            { x = 960, y = 64 },
            { x = 960, y = 96 },
            { x = 384, y = 96 },
            { x = 64, y = 96 },
            { x = 48, y = 96 },
            { x = 48, y = 32 },
            { x = 16, y = 32 }
          },
          properties = {}
        },
        {
          id = 61,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1952,
          y = -1712,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 0, y = 80 },
            { x = 448, y = 80 },
            { x = 576, y = 32 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 62,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1952,
          y = -1968,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 224 },
            { x = 0, y = 272 },
            { x = 576, y = 272 },
            { x = 448, y = 224 }
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
          x = 2528,
          y = -1680,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -128, y = 48 },
            { x = 0, y = 48 },
            { x = 32, y = 16 },
            { x = 192, y = 16 },
            { x = 192, y = 0 },
            { x = 48, y = 0 }
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
          x = 2528,
          y = -1696,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -128, y = -48 },
            { x = 0, y = -48 },
            { x = 32, y = -16 },
            { x = 192, y = -16 },
            { x = 192, y = 0 },
            { x = 48, y = 0 }
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
          x = 2160,
          y = -1920,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 272, y = 224 },
            { x = 272, y = 240 },
            { x = 576, y = 240 },
            { x = 576, y = 224 }
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
          x = 4359.59,
          y = -1012.62,
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
          x = 2496,
          y = -1600,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 1280 },
            { x = -32, y = 1280 },
            { x = -32, y = 0 }
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
          x = 2528,
          y = -1776,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -416, y = -192 },
            { x = -912, y = -192 },
            { x = -1136, y = -192 },
            { x = -1136, y = -48 },
            { x = -1136, y = 112 },
            { x = -1104, y = 112 },
            { x = -1104, y = -48 },
            { x = -912, y = -48 },
            { x = -368, y = -48 },
            { x = -288, y = -16 },
            { x = -288, y = 0 },
            { x = -576, y = 0 },
            { x = -576, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 71,
          name = "",
          type = "Coin",
          shape = "point",
          x = 2192,
          y = -1792,
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
          x = 5408,
          y = -320,
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
          id = 75,
          name = "",
          type = "Coin",
          shape = "point",
          x = 5524.1,
          y = -1193.93,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
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
            { x = 96, y = -1296 },
            { x = 112, y = -1296 },
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
            { x = 32, y = -1280 },
            { x = 16, y = -1280 }
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
            { x = 16, y = -1536 },
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
            { x = 128, y = -992 },
            { x = 112, y = -992 },
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
          x = -34.9332,
          y = -243.013,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 115,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 5424,
          y = -656,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 352, y = 608 },
            { x = 0, y = 608 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 116,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 6643.69,
          y = -1693.19,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -1200, y = 2704 },
            { x = 336, y = 1472 }
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
          x = 5680,
          y = -752,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 96, y = 0 },
            { x = 96, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {}
        },
        {
          id = 118,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 4993.41,
          y = 496.703,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -676.923, y = -720.879 },
            { x = 1020.13, y = 1412.4 },
            { x = 0, y = 608 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 119,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 7037.36,
          y = -48.3516,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -1200, y = 2704 },
            { x = 336, y = 1472 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 121,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 5440,
          y = 1008,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 592, y = -1312 },
            { x = 464, y = -1360 },
            { x = -96, y = -64 }
          },
          properties = {
            ["axis"] = { id = 122 }
          }
        },
        {
          id = 122,
          name = "",
          type = "BoostFieldAxis",
          shape = "point",
          x = 5380.22,
          y = 1032.97,
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
          id = 125,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -308.547,
          y = 1277.02,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 112 },
            { x = 0, y = -176 },
            { x = 32, y = 112 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 128,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -100.547,
          y = 1277.02,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 112 },
            { x = 0, y = -176 },
            { x = 32, y = 112 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 129,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 123.453,
          y = 1277.02,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 112 },
            { x = 0, y = -176 },
            { x = 32, y = 112 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
        },
        {
          id = 130,
          name = "",
          type = "",
          shape = "polygon",
          x = 363.453,
          y = 1117.02,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 96 },
            { x = 208, y = 96 },
            { x = 208, y = 176 },
            { x = 0, y = 176 }
          },
          properties = {}
        },
        {
          id = 132,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 317.51,
          y = 1237.01,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 45.943, y = 40.0094 },
            { x = 29.943, y = -7.99056 },
            { x = -18.057, y = -103.991 },
            { x = 45.943, y = -23.9906 }
          },
          properties = {
            ["slippery"] = true,
            ["unjumpable"] = true
          }
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
        }
      }
    }
  }
}
