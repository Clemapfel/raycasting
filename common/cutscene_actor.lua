--- @class rt.CutsceneActor
rt.CutsceneActor = meta.abstract_class("CutsceneActor", nil, {
    --- () -> x : Number, y : Number
    get_position = meta.Function,

    --- (x : Number, y : Number) -> Nil
    set_position = meta.Function,

    --- () -> Union<String, Number>
    get_name = meta.Function,

    --- () -> Union<String Number>
    get_id = meta.Function,

    --- () -> rt.AABB
    get_bounds = meta.Function,

    --- () -> vx : Number, vy : Number
    get_velocity = meta.Function,

    --- (vx: Number, vy : Number) -> Nil
    set_velocity = meta.Function,

    --- () -> radians : Number
    get_rotation = meta.Function,

    --- (radians : Number) -> Nil
    set_rotation = meta.Function,

    --- (state : Union<String, Number>) -> nil
    set_state = meta.Function,

    --- (delta : Number) -> Nil
    update = meta.Function,

    --- () -> Nil
    draw = meta.Function
})

