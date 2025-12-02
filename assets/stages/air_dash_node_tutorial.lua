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
  nextobjectid = 28,
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
          x = -2674.13,
          y = 436.54,
          width = 554.03,
          height = 925.136,
          rotation = 0,
          visible = true,
          properties = {
            ["type"] = "AIR_DASH"
          }
        },
        {
          id = 23,
          name = "Different Sizes",
          type = "Hitbox",
          shape = "polygon",
          x = -2476.38,
          y = 3788.41,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 973.237, y = 0 },
            { x = 972.377, y = -1148.41 },
            { x = 1180.38, y = -1148.41 },
            { x = 1168, y = 160 },
            { x = 0, y = 160 }
          },
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
            { x = 1200, y = 672 },
            { x = 0, y = 672 }
          },
          properties = {}
        },
        {
          id = 2,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -2345.69,
          y = 1452.37,
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
          x = -1888,
          y = 3377.02,
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
          x = -1888,
          y = 2800,
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
          x = -2080,
          y = 3168,
          width = 150,
          height = 150,
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
