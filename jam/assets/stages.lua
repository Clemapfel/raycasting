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
  nextobjectid = 1311,
  properties = {},
  tilesets = {},
  layers = {
    {
      type = "imagelayer",
      image = "../../assets/tilesets/debug_tileset_16x16/tile.png",
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
          name = "jump_introduction",
          type = "Stage",
          shape = "rectangle",
          x = -320,
          y = -224,
          width = 800,
          height = 800,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "First Jumps",
            ["priority"] = -3
          }
        },
        {
          id = 1296,
          name = "",
          type = "Contour",
          shape = "polygon",
          x = 448,
          y = -192,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = 16, y = -16 },
            { x = 16, y = 80 },
            { x = -96, y = 80 },
            { x = -177.985, y = 128 },
            { x = -218.726, y = 341.681 },
            { x = -197.453, y = 429.514 },
            { x = -48, y = 432 },
            { x = -48, y = 512 },
            { x = -224, y = 512 },
            { x = -400, y = 416 },
            { x = -473.813, y = 416 },
            { x = -544, y = 384 },
            { x = -544, y = 544 },
            { x = -496, y = 752 },
            { x = -752, y = 752 },
            { x = -752, y = 160 },
            { x = -288.228, y = 364.398 },
            { x = -228.727, y = 338.454 },
            { x = -188.391, y = 127.82 },
            { x = -272, y = 80 },
            { x = -752, y = 80 },
            { x = -752, y = -16 }
          },
          properties = {
            ["winding"] = false
          }
        },
        {
          id = 1300,
          name = "stage_02",
          type = "Stage",
          shape = "rectangle",
          x = 688,
          y = -224,
          width = 800,
          height = 1200,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "Liquidity"
          }
        },
        {
          id = 1301,
          name = "temp_07",
          type = "Stage",
          shape = "rectangle",
          x = -129.12,
          y = -1677.07,
          width = 800,
          height = 800,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "temp #1"
          }
        },
        {
          id = 1302,
          name = "temp_06",
          type = "Stage",
          shape = "rectangle",
          x = 973.75,
          y = -1502.87,
          width = 800,
          height = 800,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "temp #2"
          }
        },
        {
          id = 1303,
          name = "temp_05",
          type = "Stage",
          shape = "rectangle",
          x = 2121.77,
          y = -574.137,
          width = 800,
          height = 800,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "temp #3"
          }
        },
        {
          id = 1304,
          name = "temp_04",
          type = "Stage",
          shape = "rectangle",
          x = 2050.19,
          y = 639.311,
          width = 800,
          height = 800,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "temp #4"
          }
        },
        {
          id = 1305,
          name = "temp_03",
          type = "Stage",
          shape = "rectangle",
          x = 14.6473,
          y = 1177.81,
          width = 800,
          height = 800,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "temp #5"
          }
        },
        {
          id = 1306,
          name = "temp_02",
          type = "Stage",
          shape = "rectangle",
          x = -1573.94,
          y = 445.45,
          width = 800,
          height = 800,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "temp #6"
          }
        },
        {
          id = 1307,
          name = "temp_01",
          type = "Stage",
          shape = "rectangle",
          x = -1590.09,
          y = -986.968,
          width = 800,
          height = 800,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["name"] = "temp #7"
          }
        },
        {
          id = 1308,
          name = "",
          type = "Contour",
          shape = "polygon",
          x = 912,
          y = 96,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = -64, y = -16 },
            { x = -64, y = 192 },
            { x = 384, y = 0 },
            { x = 240, y = -128 },
            { x = 176, y = 16 }
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
      objects = {
        {
          id = 1297,
          name = "",
          type = "Contour",
          shape = "polygon",
          x = -80,
          y = 224,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polygon = {
            { x = -32, y = -32 },
            { x = -80, y = 48 },
            { x = -128, y = 48 },
            { x = -176, y = -32 },
            { x = -192, y = -32 },
            { x = -192, y = 128 },
            { x = -16, y = 128 },
            { x = -16, y = -32 }
          },
          properties = {
            ["winding"] = false
          }
        },
        {
          id = 1299,
          name = "",
          type = "Spawn",
          shape = "point",
          x = 61.3759,
          y = -138.638,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["radius"] = 60
          }
        },
        {
          id = 1309,
          name = "",
          type = "Spawn",
          shape = "point",
          x = 984.043,
          y = 78.0142,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
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
