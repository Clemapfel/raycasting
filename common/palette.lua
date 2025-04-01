require "common.color"

rt.Palette = {
    TRUE_WHITE = rt.RGBA(1, 1, 1, 1),
    TRUE_BLACK = rt.RGBA(0, 0, 0, 1),
    TRUE_RED = rt.RGBA(1, 0, 0, 1),
    TRUE_GREEN = rt.RGBA(0, 1, 0, 1),
    TRUE_BLUE = rt.RGBA(0, 0, 1, 1),
    TRUE_CYAN = rt.RGBA(0, 1, 1, 1),
    TRUE_YELLOW = rt.RGBA(1, 1, 0, 1),
    TRUE_MAGENTA = rt.RGBA(1, 0, 1, 1)
}

do -- load from image
    local image = love.image.newImageData("assets/palette.png")
    local row_to_prefix = {
        [1] = "GREEN",
        [2] = "MINT",
        [3] = "AQUAMARINE",
        [4] = "BLUE",
        [5] = "PURPLE",
        [6] = "LILAC",
        [7] = "PINK",
        [8] = "RED",
        [9] = "CINNABAR",
        [10] = "YELLOW",
        [11] = "ORANGE",
        [12] = "SKIN",
        [13] = "GRAY"
    }

    local last_gray = -1 * math.huge
    for row_i = 1, image:getHeight() do
        local prefix = row_to_prefix[row_i]
        if prefix ~= nil then
            for col_i = 1, image:getWidth() do
                local color = rt.RGBA(image:getPixel(col_i - 1, row_i - 1))
                if color.a ~= 0 then
                    color.a = 1
                    rt.Palette[prefix .. "_" .. col_i] = color

                    if prefix == "GRAY" then
                        last_gray = math.max(last_gray, col_i)
                    end
                end
            end
        end
    end

    rt.Palette.WHITE = rt.Palette.GRAY_1
    rt.Palette.BLACK = rt.Palette["GRAY_" .. last_gray]

    rt.Palette.GREEN = rt.Palette.GREEN_3
    rt.Palette.MINT = rt.Palette.MINT_2
    rt.Palette.RED = rt.Palette.CINNABAR_4
    rt.Palette.AQUAMARINE = rt.Palette.AQUAMARINE_2
    rt.Palette.BLUE = rt.Palette.BLUE_4
    rt.Palette.PURPLE = rt.Palette.PURPLE_3
    rt.Palette.LILAC = rt.Palette.LILAC_3
    rt.Palette.PINK = rt.Palette.PINK_4
    rt.Palette.RED = rt.Palette.RED_3
    rt.Palette.CINNABAR = rt.Palette.CINNABAR_4
    rt.Palette.YELLOW = rt.Palette.YELLOW_3
    rt.Palette.ORANGE = rt.Palette.ORANGE_3
    rt.Palette.BROWN = rt.Palette.ORANGE_8
    rt.Palette.LIGHT_SKIN = rt.Palette.SKIN_2
    rt.Palette.DARK_SKIN = rt.Palette.SKIN_7
    rt.Palette.GRAY = rt.Palette.GRAY_4

    -- ui
    rt.Palette.BACKGROUND = rt.Palette.GRAY_9
    rt.Palette.BACKGROUND_OUTLINE = rt.Palette.BLACK

    rt.Palette.BASE = rt.Palette.GRAY_6
    rt.Palette.BASE_OUTLINE = rt.Palette.BLACK

    rt.Palette.FOREGROUND = rt.Palette.GRAY_1
    rt.Palette.FOREGROUND_OUTLINE = rt.Palette.GRAY_5

    rt.Palette.SELECTION = rt.Palette.YELLOW_4
    rt.Palette.SELECTION_OUTLINE = rt.Palette.ORANGE_1

    -- battle
    rt.Palette.ALLY = rt.Palette.BLUE_1
    rt.Palette.ENEMY = rt.Palette.RED_3
    rt.Palette.SELF = rt.Palette.PURPLE_1
    rt.Palette.ATTACK = rt.Palette.ENEMY
    rt.Palette.DEFENSE = rt.Palette.ALLY
    rt.Palette.SPEED = rt.Palette.MINT_2
    rt.Palette.HP = rt.Palette.PURPLE_1

    rt.Palette.COLOR_A = rt.Palette.GRAY_1
    rt.Palette.COLOR_B = rt.Palette.GRAY_7

    -- overworld
    rt.Palette.STICKY = rt.Palette.FOREGROUND
end

setmetatable(rt.Palette, {
    __index = function(self, key)
        rt.error("In rt.Palette. trying to access color `" .. key .. "`, but it does not exist")
        return nil
    end
})
