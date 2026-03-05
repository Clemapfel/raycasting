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
  nextobjectid = 327,
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
          id = 288,
          name = "",
          type = "ControlIndicatorTrigger",
          shape = "polygon",
          x = -240,
          y = -1040,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 496 },
            { x = 720, y = 496 },
            { x = 720, y = 0 }
          },
          properties = {
            ["type"] = "HOLD_DOWN_TO_ACCELERATE"
          }
        },
        {
          id = 290,
          name = "",
          type = "CameraFit",
          shape = "polygon",
          x = -368,
          y = -1152,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 32 },
            { x = 960, y = 32 },
            { x = 960, y = 720 },
            { x = 0, y = 720 }
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
          id = 287,
          name = "",
          type = "Wall",
          shape = "polygon",
          x = -368,
          y = -1088,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 576 },
            { x = 960, y = 576 },
            { x = 960, y = -16 },
            { x = 0, y = -16 }
          },
          properties = {
            ["opacity"] = 0.85,
            ["type"] = "flat"
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 6,
      name = "hitbox",
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
          id = 260,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -266.524,
          y = -41.8781,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 261,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 336,
          y = -576,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -592, y = 0 },
            { x = -592, y = -208 },
            { x = -704, y = -208 },
            { x = -704, y = 144 },
            { x = 256, y = 144 },
            { x = 256, y = -336 },
            { x = 128, y = -336 },
            { x = 144, y = -320 },
            { x = 144, y = 0 },
            { x = 32, y = 0 },
            { x = 32, y = 32 },
            { x = -160, y = 32 },
            { x = -160, y = 0 },
            { x = -288, y = 0 },
            { x = -288, y = 32 },
            { x = -480, y = 32 },
            { x = -480, y = 0 }
          },
          properties = {}
        },
        {
          id = 262,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 176,
          y = -560,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -304, y = -16 },
            { x = -144, y = -16 },
            { x = -144, y = 16 },
            { x = -304, y = 16 }
          },
          properties = {}
        },
        {
          id = 263,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 352,
          y = -576,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -160, y = 0 },
            { x = -160, y = 32 },
            { x = 0, y = 32 },
            { x = 0, y = 0 }
          },
          properties = {}
        },
        {
          id = 264,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 464,
          y = -576,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -112, y = -16 },
            { x = -48, y = -32 },
            { x = 0, y = -32 },
            { x = 0, y = -336 },
            { x = 16, y = -320 },
            { x = 16, y = 0 },
            { x = -96, y = 0 },
            { x = -96, y = 32 },
            { x = -112, y = 32 }
          },
          properties = {}
        },
        {
          id = 265,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 96,
          y = -592,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -64, y = 0 },
            { x = 16, y = -16 },
            { x = 96, y = 0 },
            { x = 96, y = 48 },
            { x = 80, y = 48 },
            { x = 80, y = 16 },
            { x = -48, y = 16 },
            { x = -48, y = 48 },
            { x = -64, y = 48 }
          },
          properties = {}
        },
        {
          id = 275,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 544,
          y = -1040,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 48, y = 0 },
            { x = -784, y = 0 },
            { x = -784, y = 112 },
            { x = -800, y = 112 },
            { x = -912, y = 112 },
            { x = -912, y = 96 },
            { x = -800, y = 96 },
            { x = -800, y = -16 },
            { x = 48, y = -16 }
          },
          properties = {}
        },
        {
          id = 276,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -368,
          y = -1056,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 112 },
            { x = 112, y = 112 },
            { x = 112, y = 0 },
            { x = 960, y = 0 },
            { x = 960, y = -192 },
            { x = 0, y = -192 }
          },
          properties = {}
        },
        {
          id = 286,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -240,
          y = -576,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 112, y = -16 },
            { x = 48, y = -32 },
            { x = 0, y = -32 },
            { x = 5.68434e-14, y = -208 },
            { x = -16, y = -208 },
            { x = -16, y = 0 },
            { x = 96, y = 0 },
            { x = 96, y = 32 },
            { x = 112, y = 32 }
          },
          properties = {}
        },
        {
          id = 305,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 1536,
          y = -640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 0, y = 32 },
            { x = -16, y = 48 },
            { x = -256, y = 48 },
            { x = -256, y = -496 },
            { x = -272, y = -496 },
            { x = -272, y = 64 },
            { x = 0, y = 64 },
            { x = 0, y = 112 },
            { x = -336, y = 112 },
            { x = -336, y = -272 },
            { x = -304, y = -272 },
            { x = -304, y = -496 },
            { x = -320, y = -496 },
            { x = -320, y = -304 },
            { x = -352, y = -272 },
            { x = -352, y = 112 },
            { x = -336, y = 128 },
            { x = 0, y = 128 },
            { x = 16, y = 112 },
            { x = 16, y = -32 }
          },
          properties = {}
        },
        {
          id = 306,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 1584,
          y = -640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -16, y = 128 },
            { x = -32, y = 144 },
            { x = -400, y = 144 },
            { x = -416, y = 128 },
            { x = -416, y = -272 },
            { x = -448, y = -304 },
            { x = -464, y = -304 },
            { x = -464, y = -272 },
            { x = -432, y = -272 },
            { x = -432, y = 160 },
            { x = 0, y = 160 },
            { x = 0, y = 64 },
            { x = 272, y = 64 },
            { x = 272, y = -480 },
            { x = 256, y = -480 },
            { x = 256, y = 48 },
            { x = 16, y = 48 },
            { x = 0, y = 32 },
            { x = 0, y = -32 },
            { x = -16, y = -32 }
          },
          properties = {}
        },
        {
          id = 307,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1152,
          y = -912,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = 16, y = 384 },
            { x = 32, y = 384 },
            { x = 32, y = 0 },
            { x = 64, y = -32 },
            { x = -16, y = -32 }
          },
          properties = {
            ["axis_y"] = 1,
            ["has_outline"] = false,
            ["hue"] = "player",
            ["velocity"] = 1
          }
        },
        {
          id = 308,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1152,
          y = -512,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = 16, y = -16 },
            { x = 32, y = -16 },
            { x = 48, y = 0 },
            { x = 384, y = 0 },
            { x = 384, y = 16 },
            { x = 32, y = 16 }
          },
          properties = {
            ["axis_x"] = 1,
            ["has_outline"] = false,
            ["hue"] = "player",
            ["velocity"] = 1
          }
        },
        {
          id = 309,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1552,
          y = -640,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = 0, y = 112 },
            { x = -16, y = 128 },
            { x = -16, y = 144 },
            { x = 0, y = 144 },
            { x = 16, y = 128 },
            { x = 16, y = -32 }
          },
          properties = {
            ["axis_y"] = -1,
            ["has_outline"] = false,
            ["hue"] = "player",
            ["velocity"] = 1
          }
        },
        {
          id = 311,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1536,
          y = -576,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -272, y = 0 },
            { x = -272, y = -560 },
            { x = -304, y = -560 },
            { x = -304, y = -336 },
            { x = -336, y = -336 },
            { x = -336, y = 48 },
            { x = 0, y = 48 }
          },
          properties = {}
        },
        {
          id = 312,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 1152,
          y = -912,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -64, y = 0 },
            { x = -64, y = 480 },
            { x = 880, y = 480 },
            { x = 880, y = -208 },
            { x = 704, y = -208 },
            { x = 704, y = 336 },
            { x = 432, y = 336 },
            { x = 432, y = 432 },
            { x = 0, y = 432 }
          },
          properties = {}
        },
        {
          id = 316,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 1584,
          y = -672,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = 16, y = 80 },
            { x = 80, y = 80 }
          },
          properties = {}
        },
        {
          id = 317,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = 1536,
          y = -672,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 64 },
            { x = -16, y = 80 },
            { x = -80, y = 80 }
          },
          properties = {}
        },
        {
          id = 318,
          name = "",
          type = "",
          shape = "polygon",
          x = -320,
          y = 32,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 128, y = 32 },
            { x = 128, y = 0 }
          },
          properties = {}
        },
        {
          id = 319,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -352,
          y = 144,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 1168, y = 0 },
            { x = 1168, y = 32 },
            { x = 0, y = 32 }
          },
          properties = {}
        },
        {
          id = 320,
          name = "",
          type = "",
          shape = "polygon",
          x = 64,
          y = 32,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 128, y = 32 },
            { x = 128, y = 0 }
          },
          properties = {}
        },
        {
          id = 321,
          name = "",
          type = "OneWayPlatform",
          shape = "point",
          x = 816,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = "player",
            ["other"] = { id = 323 }
          }
        },
        {
          id = 323,
          name = "",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -368,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["hue"] = "player"
          }
        },
        {
          id = 324,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -352,
          y = 112,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 1168, y = 32 },
            { x = 1168, y = 0 }
          },
          properties = {
            ["axis_x"] = -1,
            ["hue"] = "player"
          }
        },
        {
          id = 326,
          name = "",
          type = "Wall",
          shape = "polygon",
          x = -368,
          y = -144,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 320 },
            { x = 1184, y = 320 },
            { x = 1184, y = -32 },
            { x = 0, y = -32 }
          },
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
      name = "front",
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
          id = 271,
          name = "",
          type = "OneWayPlatform",
          shape = "point",
          x = -240,
          y = -928,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["other"] = { id = 272 }
          }
        },
        {
          id = 272,
          name = "",
          type = "OneWayPlatformNode",
          shape = "point",
          x = -240,
          y = -784,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 279,
          name = "Flies",
          type = "Fireflies",
          shape = "point",
          x = 112,
          y = -704,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["count"] = "3"
          }
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
