
ow.RayMaterial = meta.enum("RayMaterial", {
    ABSORPTIVE = b2.CollisionGroup.GROUP_01,   -- player: can't pass, ray: can't pass
    REFLECTIVE = b2.CollisionGroup.GROUP_02,   -- player: can't pass, ray: reflects
    TRANSMISSIVE = b2.CollisionGroup.GROUP_03, -- player: can't pass, ray: pass
    FILTRATIVE = b2.CollisionGroup.GROUP_04,   -- player: pass,       ray: can't pass

    RECEIVER = b2.CollisionGroup.GROUP_05, -- per-shape markers
    TELEPORTER = b2.CollisionGroup.GROUP_06,
    BEAM_SPLITTER = b2.CollisionGroup.GROUP_07
})
