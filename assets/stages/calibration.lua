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
  nextobjectid = 120,
  properties = {},
  tilesets = {
    {
      name = "debug_tileset_16x16",
      firstgid = 1,
      filename = "../tilesets/debug_tileset_16x16.tsx",
      exportfilename = "../tilesets/debug_tileset_16x16.lua"
    }
  },
  layers = {
    {
      type = "imagelayer",
      image = "../tilesets/debug_tileset_16x16/tile.png",
      id = 4,
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
          id = 8,
          name = "",
          type = "PlayerSpawn",
          shape = "point",
          x = 38.9563,
          y = 233.003,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 15,
          name = "",
          type = "OneWayPlatform",
          shape = "rectangle",
          x = 96,
          y = 144,
          width = 80,
          height = 16,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 23,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 16,
          y = 16,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 256 },
            { x = 304, y = 256 },
            { x = 304, y = 288 },
            { x = -16, y = 288 },
            { x = -16, y = 0 }
          },
          properties = {}
        },
        {
          id = 31,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 320,
          y = 272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -112 },
            { x = 16, y = -112 },
            { x = 16, y = -128 },
            { x = 0, y = -128 },
            { x = 0, y = -224.33 },
            { x = 16, y = -224 },
            { x = 16, y = -240 },
            { x = 0, y = -240 },
            { x = 0, y = -336 },
            { x = 32, y = -336 },
            { x = 32, y = -240 },
            { x = 16, y = -240 },
            { x = 16, y = -224 },
            { x = 32, y = -224 },
            { x = 32, y = -128 },
            { x = 16, y = -128 },
            { x = 16, y = -112 },
            { x = 32, y = -112 },
            { x = 32, y = -8.00223 },
            { x = 0, y = -16 },
            { x = 0, y = -32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 32,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 320,
          y = 32,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 32, y = 16 },
            { x = 32, y = 0 }
          },
          properties = {}
        },
        {
          id = 33,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 320,
          y = 144,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 16 },
            { x = 32, y = 16 },
            { x = 32, y = 0 }
          },
          properties = {}
        },
        {
          id = 34,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 352,
          y = 272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 352, y = 0 },
            { x = 336, y = 16 },
            { x = 352, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 35,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1216,
          y = 272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -96, y = 0 },
            { x = -80, y = 16 },
            { x = -96, y = 32 },
            { x = 128, y = 32 },
            { x = 1856, y = 32 },
            { x = 1929.88, y = -34.7927 },
            { x = 1888, y = -16 },
            { x = 1872.38, y = -9.63642 },
            { x = 1861.46, y = -5.51646 },
            { x = 1852.14, y = -3.09327 },
            { x = 1841.26, y = -2.22663 },
            { x = 1827.99, y = -0.984511 },
            { x = 1814.87, y = -0.736871 },
            { x = 1789.98, y = 0 },
            { x = 1755.68, y = 0 },
            { x = -96, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 36,
          name = "",
          type = "PlayerSpawn",
          shape = "point",
          x = 1448.98,
          y = 52.8987,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 37,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1120,
          y = 272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 16, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 38,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 704,
          y = 272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = -16, y = 16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 39,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 320,
          y = 272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 0 },
            { x = 32, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 40,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 800,
          y = 272,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 224, y = 0 },
            { x = 224, y = 16 },
            { x = 0, y = 16 }
          },
          properties = {}
        },
        {
          id = 41,
          name = "Linear Motor",
          type = "LinearMotor",
          shape = "point",
          x = 912,
          y = 336,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["cycle"] = 2,
            ["lower"] = { id = 43 },
            ["target"] = { id = 40 },
            ["upper"] = { id = 44 }
          }
        },
        {
          id = 42,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 0,
          y = 304,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1712, y = 0 },
            { x = 1712, y = 64 },
            { x = 0, y = 64 }
          },
          properties = {}
        },
        {
          id = 43,
          name = "",
          type = "LinearMotorTarget",
          shape = "point",
          x = 912,
          y = 288,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 44,
          name = "",
          type = "LinearMotorTarget",
          shape = "point",
          x = 912,
          y = 240,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 54,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 512,
          y = 192,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 512, y = 0 },
            { x = 512, y = -16 },
            { x = 0, y = -16 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 97,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1648,
          y = 240,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -288, y = 0 },
            { x = -416, y = 0 },
            { x = -416, y = -384 },
            { x = -288, y = -384 }
          },
          properties = {
            ["axis"] = { id = 98 }
          }
        },
        {
          id = 98,
          name = "",
          type = "BoostFieldAxis",
          shape = "point",
          x = 1296,
          y = -128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 100,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1520,
          y = -400,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -283.391, y = 258.288 },
            { x = -411.391, y = 258.288 },
            { x = -416, y = -384 },
            { x = -288, y = -384 }
          },
          properties = {
            ["axis"] = { id = 101 }
          }
        },
        {
          id = 101,
          name = "",
          type = "BoostFieldAxis",
          shape = "point",
          x = 1168,
          y = -816,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 102,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1648,
          y = -992,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -288, y = 208 },
            { x = -416, y = 208 },
            { x = -416, y = -384 },
            { x = -288, y = -384 }
          },
          properties = {
            ["axis"] = { id = 103 }
          }
        },
        {
          id = 103,
          name = "",
          type = "BoostFieldAxis",
          shape = "point",
          x = 1296,
          y = -1408,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 104,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1136,
          y = -800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 976 },
            { x = -64, y = 976 },
            { x = -64, y = -96 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 105,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1424,
          y = -1408,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 1584 },
            { x = -64, y = 1584 },
            { x = -64, y = -3.86363 },
            { x = 0, y = -96 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 106,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 60.4411,
          y = -3285.48,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 3141.2, y = 0 },
            { x = 3141.2, y = 1701.48 },
            { x = 0, y = 1701.48 }
          },
          properties = {
            ["axis"] = { id = 107 }
          }
        },
        {
          id = 107,
          name = "",
          type = "BoostFieldAxis",
          shape = "point",
          x = 1616,
          y = -3872,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 117,
          name = "",
          type = "Coin",
          shape = "point",
          x = 954.935,
          y = 144.451,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 118,
          name = "",
          type = "Coin",
          shape = "point",
          x = 777.614,
          y = 134.071,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 119,
          name = "",
          type = "Coin",
          shape = "point",
          x = 639.218,
          y = 140.126,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
