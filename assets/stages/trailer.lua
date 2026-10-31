return {
  version = "1.10",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 32,
  height = 32,
  tilewidth = 16,
  tileheight = 16,
  nextlayerid = 9,
  nextobjectid = 1308,
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
      type = "objectgroup",
      draworder = "topdown",
      id = 8,
      name = "aux",
      class = "",
      visible = false,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 1306,
          name = "",
          type = "CameraFit",
          shape = "polygon",
          x = -128,
          y = 160,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 64, y = 0 },
            { x = 1008, y = 0 },
            { x = 1008, y = -608 },
            { x = 64, y = -608 }
          },
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 7,
      name = "background",
      class = "",
      visible = false,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 1304,
          name = "",
          type = "Wall",
          shape = "polygon",
          x = -64,
          y = -128,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 288 },
            { x = 944, y = 288 },
            { x = 944, y = -448 },
            { x = 624, y = -448 }
          },
          properties = {
            ["type"] = "SPHERES"
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
      name = "base",
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
          id = 1295,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -64,
          y = 16,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = -128, y = 0 },
            { x = 144, y = 0 },
            { x = 144, y = 240 },
            { x = -128, y = 240 }
          },
          properties = {}
        },
        {
          id = 1296,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -312.096,
          y = -54.3443,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 1297,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 336,
          y = -208,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 32, y = 0 },
            { x = 64, y = 0 },
            { x = 64, y = 80 },
            { x = 48, y = 80 },
            { x = 49.7592, y = 16 },
            { x = 32, y = 16 }
          },
          properties = {}
        },
        {
          id = 1298,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 96,
          y = 144,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 112 },
            { x = 0, y = -128 },
            { x = 0, y = -144 },
            { x = -288, y = -144 },
            { x = -288, y = -128 },
            { x = -16, y = -128 },
            { x = -16, y = 112 }
          },
          properties = {}
        },
        {
          id = 1299,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 624,
          y = 160,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 96 },
            { x = 0, y = -416 },
            { x = 464, y = -416 },
            { x = 464, y = 96 }
          },
          properties = {}
        },
        {
          id = 1300,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 624,
          y = 160,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 96 },
            { x = -16, y = 96 },
            { x = -16, y = -432 },
            { x = 464, y = -432 },
            { x = 464, y = -416 },
            { x = 0, y = -416 }
          },
          properties = {}
        },
        {
          id = 1301,
          name = "",
          type = "KillPlane",
          shape = "polygon",
          x = 96,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 512, y = 0 },
            { x = 512, y = 160 },
            { x = 0, y = 160 }
          },
          properties = {}
        },
        {
          id = 1307,
          name = "",
          type = "Hitboxnd",
          shape = "polygon",
          x = 336,
          y = -192,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 32, y = 0 },
            { x = 32, y = 64 },
            { x = 48, y = 64 },
            { x = 48, y = 0 }
          },
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 6,
      name = "foreground",
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
      chunks = {}
    }
  }
}
