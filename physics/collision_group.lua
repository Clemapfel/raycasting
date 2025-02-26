--- @class b2.CollisionGroup
--- @brief only objects in the same group collide
b2.CollisionGroup = meta.enum("CollisionGroup", {
    NONE = -1,
    ALL = 0,
    GROUP_01 = bit.lshift(1, 0),
    GROUP_02 = bit.lshift(1, 1),
    GROUP_03 = bit.lshift(1, 2),
    GROUP_04 = bit.lshift(1, 3),
    GROUP_05 = bit.lshift(1, 4),
    GROUP_06 = bit.lshift(1, 5),
    GROUP_07 = bit.lshift(1, 6),
    GROUP_08 = bit.lshift(1, 7),
    GROUP_09 = bit.lshift(1, 8),
    GROUP_10 = bit.lshift(1, 9),
    GROUP_11 = bit.lshift(1, 10),
    GROUP_12 = bit.lshift(1, 11),
    GROUP_13 = bit.lshift(1, 12),
    GROUP_14 = bit.lshift(1, 13),
    GROUP_15 = bit.lshift(1, 14),
    GROUP_16 = bit.lshift(1, 15)
})