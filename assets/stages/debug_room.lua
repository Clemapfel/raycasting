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
  nextobjectid = 1290,
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
      name = "background",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = -17.997,
      offsety = 363.117,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 1221,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 128,
          y = 64,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 16, y = 32 },
            { x = 16, y = 528 },
            { x = 32, y = 544 },
            { x = 320, y = 544 },
            { x = 368, y = 544 },
            { x = 384, y = 528 },
            { x = 384, y = 448 },
            { x = 368, y = 448 },
            { x = 368, y = 512 },
            { x = 352, y = 528 },
            { x = 48, y = 528 },
            { x = 32, y = 512 },
            { x = 32, y = 32 },
            { x = 48, y = 0 }
          },
          properties = {
            ["path"] = { id = 1222 }
          }
        },
        {
          id = 1222,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 152.141,
          y = 56.5709,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1224 }
          }
        },
        {
          id = 1224,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 152.013,
          y = 586.654,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1225 }
          }
        },
        {
          id = 1225,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 169.016,
          y = 601.789,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1226 }
          }
        },
        {
          id = 1226,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 487.689,
          y = 601.209,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1227 }
          }
        },
        {
          id = 1227,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 503.256,
          y = 585.758,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1228 }
          }
        },
        {
          id = 1228,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 504.103,
          y = 536.585,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 0 }
          }
        },
        {
          id = 1229,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 496,
          y = 512,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 16, y = 32 },
            { x = 16, y = 0 }
          },
          properties = {
            ["axis_x"] = 0,
            ["axis_y"] = 1,
            ["is_visible"] = false
          }
        },
        {
          id = 1201,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 80,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 272, y = 528 },
            { x = 288, y = 512 },
            { x = 416, y = 512 },
            { x = 432, y = 496 },
            { x = 432, y = 416 },
            { x = 464, y = 416 },
            { x = 496, y = 448 },
            { x = 512, y = 448 },
            { x = 512, y = 464 },
            { x = 688, y = 464 },
            { x = 704, y = 560 },
            { x = 304, y = 560 },
            { x = 304, y = 736 },
            { x = -64, y = 736 },
            { x = -64, y = 752 },
            { x = -96, y = 752 },
            { x = -96, y = 720 },
            { x = -80, y = 704 },
            { x = 32, y = 704 },
            { x = 256, y = 704 },
            { x = 272, y = 688 },
            { x = 272, y = 636.587 }
          },
          properties = {}
        },
        {
          id = 1202,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 224,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 16, y = 0 },
            { x = -16, y = -32 },
            { x = -48, y = -32 },
            { x = -64, y = 0 },
            { x = -64, y = 464 },
            { x = -64, y = 480 },
            { x = -48, y = 496 },
            { x = 208, y = 496 },
            { x = 256, y = 496 },
            { x = 272, y = 480 },
            { x = 272, y = 448 },
            { x = 272, y = 416 },
            { x = 240, y = 416 },
            { x = 208, y = 448 },
            { x = 192, y = 448 },
            { x = 192, y = 464 },
            { x = -32, y = 464 },
            { x = -32, y = 0 }
          },
          properties = {}
        },
        {
          id = 1231,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -96,
          y = 1104,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 16 },
            { x = 0, y = 240 },
            { x = 704, y = 240 },
            { x = 704, y = 128 },
            { x = 352, y = -32 }
          },
          properties = {
            ["why"] = 12351.21
          }
        },
        {
          id = 1232,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 80,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = -16, y = 0 },
            { x = 16, y = -32 },
            { x = 48, y = -32 },
            { x = 64, y = 0 },
            { x = 64, y = 496 },
            { x = 80, y = 512 },
            { x = 240, y = 512 },
            { x = 256, y = 528 },
            { x = 256, y = 672 },
            { x = 240, y = 688 },
            { x = -96, y = 688 },
            { x = -112, y = 704 },
            { x = -112, y = 752 },
            { x = -144, y = 752 },
            { x = -144, y = 656 },
            { x = 224, y = 656 },
            { x = 224, y = 560 },
            { x = 32, y = 560 },
            { x = 32, y = 0 }
          },
          properties = {}
        },
        {
          id = 1233,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 259.236,
          y = 643.817,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 60.7642, y = -35.8169 },
            { x = 108.764, y = -35.8169 },
            { x = 92.7642, y = -19.8169 },
            { x = 92.7642, y = 140.183 },
            { x = 76.7642, y = 156.183 },
            { x = -259.236, y = 156.183 },
            { x = -275.236, y = 172.183 },
            { x = -275.236, y = 204.183 },
            { x = -291.236, y = 204.183 },
            { x = -291.236, y = 156.183 },
            { x = -275.236, y = 140.183 },
            { x = 60.7642, y = 140.183 },
            { x = 76.7642, y = 124.183 },
            { x = 76.7642, y = -19.8169 }
          },
          properties = {
            ["path"] = { id = 1234 }
          }
        },
        {
          id = 1234,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 344.032,
          y = 616.771,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1235 }
          }
        },
        {
          id = 1235,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 343.857,
          y = 780.881,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1236 }
          }
        },
        {
          id = 1236,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 327.739,
          y = 792.823,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1237 }
          }
        },
        {
          id = 1237,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = -8.37583,
          y = 791.821,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1238 }
          }
        },
        {
          id = 1238,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = -24,
          y = 811.169,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1239 }
          }
        },
        {
          id = 1239,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = -24,
          y = 840.278,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 0 }
          }
        },
        {
          id = 1240,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = -144,
          y = 848,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 128 },
            { x = -16, y = 144 },
            { x = -16, y = 224 },
            { x = 0, y = 240 },
            { x = 0, y = 256 },
            { x = 400, y = 208 },
            { x = 768, y = 368 },
            { x = 800, y = 368 },
            { x = 944.963, y = 298.744 },
            { x = 944, y = 320 },
            { x = 800, y = 384 },
            { x = 768, y = 432 },
            { x = 768, y = 480 },
            { x = 752, y = 496 },
            { x = 752, y = 384 },
            { x = 400, y = 224 },
            { x = 48, y = 272 },
            { x = 48, y = 288 },
            { x = -96, y = 288 },
            { x = -96, y = -32 },
            { x = 0, y = -32 }
          },
          properties = {}
        },
        {
          id = 1241,
          name = "",
          type = "Portal",
          shape = "point",
          x = 624,
          y = 1344,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["other"] = { id = 1242 },
            ["target"] = { id = 1243 }
          }
        },
        {
          id = 1242,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = 1488,
          y = 1344,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 1243,
          name = "",
          type = "Portal",
          shape = "point",
          x = -144,
          y = 992,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["other"] = { id = 1244 },
            ["target"] = { id = 0 }
          }
        },
        {
          id = 1244,
          name = "",
          type = "PortalNode",
          shape = "point",
          x = -144,
          y = 1072,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 1245,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -144,
          y = 1008,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = -32 },
            { x = -16, y = -16 },
            { x = -16, y = 64 },
            { x = 0, y = 80 }
          },
          properties = {}
        },
        {
          id = 1246,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = -32,
          y = 816,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = 32 },
            { x = 16, y = 32 },
            { x = 16, y = 0 }
          },
          properties = {
            ["axis_y"] = 1,
            ["is_visible"] = false
          }
        },
        {
          id = 1247,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = 2208,
          y = 1104,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 144 },
            { x = 0, y = 240 },
            { x = -704, y = 240 },
            { x = -704, y = 144 }
          },
          properties = {}
        },
        {
          id = 1249,
          name = "",
          type = "SlipperyHitbox",
          shape = "polygon",
          x = 1504,
          y = 1136,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 112 },
            { x = 0, y = 208 },
            { x = -16, y = 208 },
            { x = -16, y = 96 },
            { x = 704, y = 96 },
            { x = 704, y = 112 }
          },
          properties = {}
        },
        {
          id = 1264,
          name = "",
          type = "BouncePad",
          shape = "ellipse",
          x = 425.339,
          y = 398.639,
          width = 160,
          height = 160,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 1267,
          name = "",
          type = "AirDashNode",
          shape = "ellipse",
          x = 658.425,
          y = 330.828,
          width = 160,
          height = 160,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 1285,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 1344,
          y = 1040,
          width = 0,
          height = 0,
          rotation = -22,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 1.997, y = -11.117 },
            { x = 288, y = 272 },
            { x = 784, y = 272 },
            { x = 432, y = -16 }
          },
          properties = {
            ["path"] = { id = 1288 }
          }
        },
        {
          id = 1286,
          name = "",
          type = "BoostFieldNodesB",
          shape = "point",
          x = 1632,
          y = 864,
          width = 0,
          height = 0,
          rotation = -22,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 1288,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 1536,
          y = 1008,
          width = 0,
          height = 0,
          rotation = -22,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 1289 }
          }
        },
        {
          id = 1289,
          name = "",
          type = "BoostFieldPathNode",
          shape = "point",
          x = 1920,
          y = 1312,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["next"] = { id = 0 }
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
          id = 1199,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -48,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 160, y = 0 },
            { x = 160, y = 560 },
            { x = 112, y = 560 },
            { x = 111.328, y = 64 },
            { x = -64, y = 64 },
            { x = -64, y = -320 },
            { x = 384, y = -320 },
            { x = 384, y = 64 },
            { x = 368, y = 64 },
            { x = 368, y = 448 },
            { x = 464, y = 448 },
            { x = 464, y = 464 },
            { x = 240, y = 464 },
            { x = 240, y = 0 },
            { x = 320, y = 0 },
            { x = 320, y = -256 },
            { x = 0, y = -256 },
            { x = 0, y = 0 }
          },
          properties = {}
        },
        {
          id = 1200,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = 379.42,
          y = 1420.04,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 1230,
          name = "",
          type = "AcceleratorSurface",
          shape = "polygon",
          x = 336,
          y = 160,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = -16, y = 0 },
            { x = -16, y = 384 },
            { x = 16, y = 384 },
            { x = 0, y = 368 }
          },
          properties = {}
        },
        {
          id = 1270,
          name = "",
          type = "BoostField",
          shape = "polygon",
          x = 544,
          y = 1456,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 0, y = -448 },
            { x = 160, y = -448 },
            { x = 160, y = 0 }
          },
          properties = {
            ["axis_y"] = -1
          }
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
