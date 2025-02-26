rt.settings.selection_state = {
    unselected_opacity = 0.6,
}

--- @class rt.SelectionState
rt.SelectionState = meta.enum("SelectionState", {
    SELECTED = 1,
    ACTIVE = 1,
    INACTIVE = 0,
    UNSELECTED = -1
})