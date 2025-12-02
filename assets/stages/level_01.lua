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
  nextlayerid = 3,
  nextobjectid = 11,
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
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
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
          id = 1,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -128,
          y = 32,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -368, y = 16 },
            { x = 304, y = 16 },
            { x = 304, y = 0 },
            { x = 384, y = 0 },
            { x = 384, y = 160 },
            { x = -432, y = 160 },
            { x = -432, y = -304 },
            { x = -288, y = -304 },
            { x = -288, y = -256 },
            { x = -368, y = -256 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 2,
          name = "Spawn",
          type = "PlayerSpawn",
          shape = "point",
          x = -154.581,
          y = -81.4765,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -771.656,
          y = 76.334,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 163.308, y = 0 },
            { x = 163.308, y = 160 },
            { x = 0, y = 160 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 4,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -128,
          y = 32,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 304, y = -25.5313 },
            { x = 310.752, y = -33.8209 },
            { x = 319.634, y = -38.291 },
            { x = 336, y = -44.0185 },
            { x = 384, y = -46.3902 },
            { x = 448, y = -46.3902 },
            { x = 453.501, y = -46.7791 },
            { x = 463.292, y = -51.2491 },
            { x = 470.109, y = -58.7264 },
            { x = 480, y = -64 },
            { x = 560, y = -64 },
            { x = 560, y = 0 },
            { x = 304, y = 0 }
          },
          properties = {
            ["friction"] = 0.5,
            ["slippery"] = true
          }
        },
        {
          id = 5,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -128,
          y = 32,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 384, y = -64 },
            { x = 336, y = -64 },
            { x = 319.958, y = -65.8227 },
            { x = 311.034, y = -71.9956 },
            { x = 304, y = -80 },
            { x = 304, y = -134.365 },
            { x = 304, y = -192 },
            { x = 256, y = -240 },
            { x = 464, y = -240 },
            { x = 470.762, y = -159.54 },
            { x = 469.315, y = -96.6499 },
            { x = 469.156, y = -89.2869 },
            { x = 464, y = -80 },
            { x = 456.899, y = -70.3204 },
            { x = 448, y = -65.1419 },
            { x = 436.694, y = -64 }
          },
          properties = {
            ["slippery"] = true
          }
        },
        {
          id = 6,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -272,
          y = -208,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 336, y = 0 },
            { x = 336, y = -48 },
            { x = 544, y = -48 },
            { x = 544, y = 0 }
          },
          properties = {}
        },
        {
          id = 7,
          name = "",
          type = "Hitbox",
          shape = "polygon",
          x = -368,
          y = -128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -96, y = -48 },
            { x = -96, y = 144 },
            { x = -96, y = 160 },
            { x = 64, y = 160 },
            { x = 544, y = 160 },
            { x = 544, y = 176 },
            { x = 64, y = 176 },
            { x = -128, y = 176 },
            { x = -128, y = -96 },
            { x = -48, y = -96 }
          },
          properties = {
            ["slippery"] = false
          }
        },
        {
          id = 8,
          name = "",
          type = "BouncePad",
          shape = "polygon",
          x = -464,
          y = 32,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 0, y = 0 },
            { x = 96, y = 0 },
            { x = 128, y = 0 },
            { x = 96, y = -32 },
            { x = 0, y = -32 }
          },
          properties = {}
        },
        {
          id = 9,
          name = "",
          type = "Coin",
          shape = "point",
          x = -412.572,
          y = -168.229,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 10,
          name = "",
          type = "NPC",
          shape = "polygon",
          x = -223.208,
          y = 23.5131,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = 2.29248, y = 1.25747 },
            { x = -7.26877, y = -6.38499 },
            { x = -13.2234, y = -14.7945 },
            { x = -15.2638, y = -26.7397 },
            { x = -14.0422, y = -39.5292 },
            { x = -11.8628, y = -51.0744 },
            { x = -7.72457, y = -59.6267 },
            { x = -2.89058, y = -67.1575 },
            { x = 2.91502, y = -73.8584 },
            { x = 10.1099, y = -80.6587 },
            { x = 18.33, y = -85.8224 },
            { x = 32.5291, y = -91.6781 },
            { x = 47.221, y = -93.9332 },
            { x = 62.4284, y = -95.3908 },
            { x = 80.9051, y = -95.0261 },
            { x = 98.6634, y = -93.1394 },
            { x = 112.493, y = -89.8667 },
            { x = 125.573, y = -84.6553 },
            { x = 138.318, y = -74.1435 },
            { x = 146.029, y = -62.4352 },
            { x = 150.716, y = -50.9403 },
            { x = 152.885, y = -35.5446 },
            { x = 153.274, y = -22.501 },
            { x = 150.236, y = -13.059 },
            { x = 142.852, y = -5.46371 },
            { x = 135.087, y = -1.10043 },
            { x = 124.857, y = 2.18281 },
            { x = 114.379, y = 5.23876 },
            { x = 16.2686, y = 5.32201 }
          },
          properties = {
            ["dialog_id"] = "debug_dialog"
          }
        }
      }
    }
  }
}
