return {
  version = "1.10",
  luaversion = "5.1",
  tiledversion = "1.11.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 32,
  height = 32,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 7,
  nextobjectid = 138,
  properties = {},
  tilesets = {
    {
      name = "debug_tileset",
      firstgid = 1,
      filename = "../tilesets/debug_tileset.tsx",
      exportfilename = "../tilesets/debug_tileset.lua"
    }
  },
  layers = {
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 32,
      height = 32,
      id = 3,
      name = "base",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      chunks = {}
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 5,
      name = "walls",
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
          id = 2,
          name = "",
          type = "PlayerSpawn",
          shape = "point",
          x = -384,
          y = 352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 22,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 327.687,
          y = 901.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -1088, y = 0 },
            { x = 4416, y = 0 },
            { x = 4800, y = 32 },
            { x = 5984, y = 32 },
            { x = 5984, y = 160 },
            { x = -1088, y = 160 }
          },
          properties = {}
        },
        {
          id = 40,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 256,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 96 },
            { x = 32, y = 64 },
            { x = 32, y = 32 }
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
          x = 864,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 96 },
            { x = -32, y = 64 },
            { x = -32, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 42,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 640,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -384, y = 0 },
            { x = -352, y = 32 },
            { x = -352, y = 64 },
            { x = -384, y = 96 },
            { x = 224, y = 96 },
            { x = 192, y = 64 },
            { x = 192, y = 32 },
            { x = 224, y = 0 }
          },
          properties = {}
        },
        {
          id = 43,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1248,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 96 },
            { x = 32, y = 64 },
            { x = 32, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 44,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1888,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 96 },
            { x = -32, y = 64 },
            { x = -32, y = 32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 45,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1664,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -416, y = 0 },
            { x = -384, y = 32 },
            { x = -384, y = 64 },
            { x = -416, y = 96 },
            { x = 224, y = 96 },
            { x = 192, y = 64 },
            { x = 192, y = 32 },
            { x = 224, y = 0 }
          },
          properties = {}
        },
        {
          id = 46,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 32,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 96 },
            { x = -32, y = 64 },
            { x = -32, y = 32 },
            { x = 0, y = 0 }
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
          x = -512,
          y = 736,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 0 },
            { x = -32, y = 0 },
            { x = -32, y = 160 },
            { x = 544, y = 160 },
            { x = 512, y = 128 },
            { x = 512, y = 96 },
            { x = 544, y = 64 },
            { x = 288, y = 64 },
            { x = 192, y = 32 },
            { x = 96, y = 32 }
          },
          properties = {}
        },
        {
          id = 55,
          name = "",
          type = "Checkpoint",
          shape = "point",
          x = 1568,
          y = 160,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 56,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2983.69,
          y = 741.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 0 },
            { x = -32, y = -128 },
            { x = 32, y = -128 },
            { x = 0, y = -96 },
            { x = 0, y = -32 }
          },
          properties = {}
        },
        {
          id = 57,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3015.69,
          y = 613.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = 32 },
            { x = -32, y = 96 },
            { x = -64, y = 128 },
            { x = 0, y = 128 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 62,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3800.5,
          y = 354.665,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 18.2362, y = -3.55658 },
            { x = 18.2362, y = -131.557 },
            { x = -109.764, y = -131.557 },
            { x = -45.7638, y = -99.5566 },
            { x = -45.7638, y = -3.55658 }
          },
          properties = {}
        },
        {
          id = 63,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3768.5,
          y = 226.665,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -77.7638, y = -3.55658 },
            { x = -13.7638, y = 28.4434 },
            { x = -13.7638, y = 220.443 },
            { x = -45.7638, y = 220.443 }
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
          x = 3755.64,
          y = 415.407,
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
          properties = {}
        },
        {
          id = 69,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3175.69,
          y = 549.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -64 },
            { x = 32, y = -64 },
            { x = 32, y = 0 }
          },
          properties = {}
        },
        {
          id = 70,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3175.69,
          y = 485.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 64, y = -32 },
            { x = 64, y = 96 },
            { x = 0, y = 64 },
            { x = 32, y = 64 },
            { x = 32, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 71,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3015.69,
          y = 421.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -64 },
            { x = -32, y = -64 },
            { x = -32, y = 0 }
          },
          properties = {}
        },
        {
          id = 72,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3015.69,
          y = 357.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = -32 },
            { x = -64, y = 96 },
            { x = 0, y = 64 },
            { x = -32, y = 64 },
            { x = -32, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 73,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3207.69,
          y = 356.735,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 192, y = 0 },
            { x = 192, y = -32 },
            { x = 0, y = -32 }
          },
          properties = {}
        },
        {
          id = 74,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3207.69,
          y = 356.735,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 32, y = 32 },
            { x = 224, y = 32 },
            { x = 256, y = 32 },
            { x = 544, y = 160 },
            { x = 576, y = 160 },
            { x = 224, y = 0 },
            { x = 192, y = -32 },
            { x = 192, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 76,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3751.69,
          y = 516.735,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 134.993, y = 0 },
            { x = 171.56, y = 0 },
            { x = 192, y = 0 },
            { x = 192, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 77,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3591.69,
          y = 263.799,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 355.053, y = 23.3097 },
            { x = 387.053, y = 23.3097 },
            { x = 1022.13, y = 354.511 },
            { x = 1050.77, y = 368.144 },
            { x = 1080.35, y = 372.622 },
            { x = 1110.07, y = 366.007 },
            { x = 1134.15, y = 355.891 },
            { x = 1159.98, y = 335.655 },
            { x = 1149.94, y = 327.077 },
            { x = 1130.13, y = 342.913 },
            { x = 1106.21, y = 353.067 },
            { x = 1080.33, y = 358.989 },
            { x = 1055.45, y = 354.533 },
            { x = 1027.05, y = 343.31 },
            { x = 355.053, y = -40.6903 }
          },
          properties = {
            ["friction"] = -5,
            ["slippery"] = true
          }
        },
        {
          id = 78,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3882.74,
          y = 223.108,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = 32, y = 64 },
            { x = 64, y = 64 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 80,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 5255.69,
          y = 250.058,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 104.584, y = 43.8052 },
            { x = 104.584, y = 587.805 },
            { x = 72.5844, y = 587.805 },
            { x = 72.5844, y = 75.8052 },
            { x = -55.4156, y = 11.8052 },
            { x = -87.4156, y = -20.1948 },
            { x = -23.4156, y = -20.1948 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 82,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 5310.07,
          y = 261.863,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 224, y = 0 },
            { x = 96, y = 64 },
            { x = 96, y = 576 },
            { x = 64, y = 576 },
            { x = 64, y = 32 },
            { x = 160, y = 0 },
            { x = 192, y = -32 },
            { x = 256, y = -32 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 83,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 5296.27,
          y = 837.863,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = 224, y = 64 },
            { x = 224, y = 96 },
            { x = -32, y = 96 },
            { x = -32, y = 0 }
          },
          properties = {}
        },
        {
          id = 84,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 5328.27,
          y = 837.863,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = 0 },
            { x = -64, y = 96 },
            { x = -192, y = 96 },
            { x = 0, y = -96 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 86,
          name = "",
          type = "CameraBounds",
          shape = "rectangle",
          x = -1090.67,
          y = -576,
          width = 6210.67,
          height = 1532.78,
          rotation = 0,
          visible = false,
          properties = {}
        },
        {
          id = 90,
          name = "",
          type = "Checkpoint",
          shape = "point",
          x = 3763.33,
          y = 133.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["body"] = { id = 91 }
          }
        },
        {
          id = 91,
          name = "",
          type = "CheckpointBody",
          shape = "rectangle",
          x = 3691.02,
          y = 149.211,
          width = 257.271,
          height = 73.5061,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 92,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 3911.69,
          y = 517.635,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 0 },
            { x = 64, y = -32 },
            { x = 64, y = 64 },
            { x = -128, y = 64 },
            { x = -160, y = 32 },
            { x = 32, y = 32 },
            { x = 32, y = 0 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 93,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -544,
          y = 832,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 64 },
            { x = -64, y = 64 },
            { x = -64, y = -1408 },
            { x = 0, y = -1408 },
            { x = 0, y = -1280 },
            { x = -32, y = -1248 },
            { x = -32, y = -1216 },
            { x = 0, y = -1184 },
            { x = 0, y = -1152 },
            { x = -32, y = -1120 },
            { x = -32, y = -1056 },
            { x = 0, y = -1024 },
            { x = 0, y = -960 },
            { x = -32, y = -928 },
            { x = -32, y = -864 },
            { x = 0, y = -832 },
            { x = 0, y = -768 },
            { x = -32, y = -736 },
            { x = -32, y = -224 },
            { x = 0, y = -192 },
            { x = 0, y = -128 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 94,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -544,
          y = 64,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = 32 },
            { x = -32, y = 544 },
            { x = 0, y = 576 }
          },
          properties = {}
        },
        {
          id = 95,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -544,
          y = 0,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = -32 },
            { x = -32, y = -96 },
            { x = 0, y = -128 }
          },
          properties = {}
        },
        {
          id = 97,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -544,
          y = -192,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = -32 },
            { x = -32, y = -96 },
            { x = 0, y = -128 }
          },
          properties = {}
        },
        {
          id = 98,
          name = "",
          type = "",
          shape = "polygon",
          x = -544,
          y = -352,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -32, y = -32 },
            { x = 32, y = -32 },
            { x = 32, y = 0 }
          },
          properties = {}
        },
        {
          id = 106,
          name = "",
          type = "OneWayPlatform",
          shape = "rectangle",
          x = -266.895,
          y = 561.949,
          width = 276.69,
          height = 9.79432,
          rotation = 20,
          visible = true,
          properties = {}
        },
        {
          id = 107,
          name = "",
          type = "",
          shape = "polygon",
          x = 2016,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 160, y = 0 },
            { x = 448, y = 0 },
            { x = 768, y = 0 },
            { x = 768, y = 96 },
            { x = 0, y = 96 },
            { x = 32, y = 64 },
            { x = 32, y = 32 }
          },
          properties = {}
        },
        {
          id = 115,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2208,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 0 },
            { x = -32, y = -64 },
            { x = 0, y = -96 },
            { x = -32, y = -128 },
            { x = -32, y = -192 },
            { x = 0, y = -224 },
            { x = -32, y = -256 },
            { x = -32, y = -319.828 },
            { x = 0, y = -352 },
            { x = -32, y = -384 },
            { x = -32, y = -448 },
            { x = 32, y = -448 },
            { x = 64, y = -480 },
            { x = 96, y = -480 },
            { x = 128, y = -416 },
            { x = 64, y = -416 },
            { x = 64, y = -256 },
            { x = 32, y = -224 },
            { x = 32, y = -224 },
            { x = 64, y = -192 },
            { x = 64, y = -128 },
            { x = 32, y = -96 },
            { x = 64, y = -64 },
            { x = 64, y = 0 }
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
          x = 2374.97,
          y = 384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 121.031, y = -256 },
            { x = 249.031, y = -256 },
            { x = 311.068, y = -156.741 },
            { x = 291.306, y = -110.403 },
            { x = 343.437, y = -104.949 },
            { x = 409.031, y = 0 },
            { x = 409.031, y = 256 },
            { x = 377.031, y = 288 },
            { x = 409.031, y = 256 },
            { x = 377.031, y = 288 },
            { x = 345.031, y = 256 },
            { x = 346.69, y = 0 },
            { x = 89.0306, y = 0 },
            { x = 88.9029, y = 68.2143 },
            { x = 25.0306, y = 64 },
            { x = 25.0306, y = 0 },
            { x = -32, y = 0 }
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
          x = 2016,
          y = 800,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 96 },
            { x = 32, y = 64 },
            { x = 32, y = 32 }
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
          x = 2176,
          y = 416,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = 32, y = 32 }
          },
          properties = {}
        },
        {
          id = 122,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2176,
          y = 544,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = 32, y = 32 }
          },
          properties = {}
        },
        {
          id = 123,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2176,
          y = 672,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = 32, y = 32 }
          },
          properties = {}
        },
        {
          id = 124,
          name = "",
          type = "",
          shape = "polygon",
          x = 2208,
          y = 320,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -32, y = 0 },
            { x = -32, y = 32 },
            { x = 32, y = 32 },
            { x = 64, y = 0 }
          },
          properties = {}
        },
        {
          id = 125,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2687.06,
          y = 228.347,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 30.8003, y = 50.9798 },
            { x = -20.1795, y = 45.1383 }
          },
          properties = {}
        },
        {
          id = 126,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2784,
          y = 640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = -32, y = 96 },
            { x = -64, y = 96 },
            { x = -64, y = 0 },
            { x = -32, y = 32 }
          },
          properties = {}
        },
        {
          id = 129,
          name = "",
          type = "Checkpoint",
          shape = "point",
          x = 2337.87,
          y = 397.613,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 130,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2400,
          y = 384,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 32, y = 96 },
            { x = 0, y = 128 },
            { x = 0, y = 224.058 },
            { x = 32, y = 256 },
            { x = 0, y = 288 },
            { x = 0, y = 416 },
            { x = 64, y = 416 },
            { x = 64, y = 96 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 131,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2400,
          y = 480,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 32, y = 0 },
            { x = 64, y = 0 },
            { x = 63.8723, y = -23.4108 },
            { x = 2.79949, y = -17.916 },
            { x = 0.127706, y = -11.6619 }
          },
          properties = {}
        },
        {
          id = 132,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2283.13,
          y = 548.708,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -10.3896, y = -4.73179 },
            { x = -10.3896, y = 59.2682 },
            { x = -42.3896, y = 27.2682 }
          },
          properties = {}
        },
        {
          id = 135,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2282.7,
          y = 676.563,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -10.7048, y = -4.56326 },
            { x = -10.7048, y = 59.4367 },
            { x = -42.3896, y = 27.2682 }
          },
          properties = {}
        },
        {
          id = 137,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2400,
          y = 608,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = 32, y = 32 }
          },
          properties = {}
        }
      }
    }
  }
}
