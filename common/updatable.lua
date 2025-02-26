--- @class rt.Updatable
rt.Updatable = meta.abstrat_class("Updatable")

--- @brief abstract method, must be override
function rt.Updatable:update(delta)
    rt.error("In " .. meta.typeof(self) .. ":update(): abstract method called")
end