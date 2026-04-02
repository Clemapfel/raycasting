rt.settings.selection_state = {
    unselected_opacity = 0.6,
}

--- @enum rt.SelectionState
rt.SelectionState = {
    SELECTED = 1,
    ACTIVE = 1,
    INACTIVE = 0,
    UNSELECTED = -1
}
rt.SelectionState = meta.enum("SelectionState", rt.SelectionState)