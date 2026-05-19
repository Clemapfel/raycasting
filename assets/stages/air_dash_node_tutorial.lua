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
  nextobjectid = 113,
  properties = {
    ["background_id"] = "\"nebula\""
  },
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
      objects = {}
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
          id = 95,
          name = "",
          type = "Wall",
          shape = "polygon",
          x = -1392,
          y = 832,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 688, y = 0 },
            { x = 688, y = -640 },
            { x = 1152, y = -640 },
            { x = 1152, y = -1520 },
            { x = 1760, y = -1520 },
            { x = 1760, y = -1696 },
            { x = 656, y = -1696 },
            { x = -512, y = 416 },
            { x = 0, y = 416 }
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
          id = 89,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -543.516,
          y = 142.387,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 91,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -1647.08,
          y = 1248,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -256, y = 0 },
            { x = 256.238, y = 0 },
            { x = 255.076, y = -416 },
            { x = 480, y = -416 },
            { x = 479.076, y = 144 },
            { x = -256.924, y = 144 }
          },
          properties = {}
        },
        {
          id = 92,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -1392,
          y = 928,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = -96 },
            { x = -16, y = -96 },
            { x = -16, y = 304 },
            { x = -32, y = 320 },
            { x = 0, y = 320 }
          },
          properties = {}
        },
        {
          id = 93,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -1584,
          y = 960,
          width = 224,
          height = 224,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 96,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -864,
          y = 512,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 160, y = -320 },
            { x = 144, y = -320 },
            { x = 144, y = 304 },
            { x = 128, y = 320 },
            { x = 160, y = 320 }
          },
          properties = {}
        },
        {
          id = 97,
          name = "",
          type = "",
          shape = "polygon",
          x = -1184,
          y = 832,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 560 },
            { x = 848, y = 544 },
            { x = 848, y = -640 },
            { x = 480, y = -640 },
            { x = 480, y = 0 }
          },
          properties = {}
        },
        {
          id = 100,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -944,
          y = 528,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 105,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -1088,
          y = 192,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["direction"] = { id = 106 }
          }
        },
        {
          id = 106,
          name = "",
          type = "AirDashNodeDirection",
          shape = "point",
          x = -919.674,
          y = 148.515,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 108,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = -1344,
          y = 832,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = -32 },
            { x = 192, y = -32 },
            { x = 208, y = 0 }
          },
          properties = {}
        },
        {
          id = 109,
          name = "",
          type = "",
          shape = "polygon",
          x = -352,
          y = 192,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 1184 },
            { x = 720, y = 1184 },
            { x = 720, y = -880 },
            { x = 112, y = -880 },
            { x = 112, y = 0 }
          },
          properties = {}
        },
        {
          id = 110,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -444.384,
          y = -54.9578,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 111,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -448,
          y = -320,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        },
        {
          id = 112,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = -448,
          y = -608,
          width = 176,
          height = 176,
          rotation = 0,
          visible = true,
          properties = {
            ["angle"] = 0,
            ["axis_y"] = -1
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 6,
      name = "front",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {}
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
