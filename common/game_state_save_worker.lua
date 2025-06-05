require "common.common"
require "love.filesystem"
require "love.math"

local main_to_worker, worker_to_main, MessageType = ...

local save_dir = "/chroma_drift/saves"
local watchdog_path = save_dir .. "/" .. "watchdog"

-- check if save_dir exist, otherwise create it
-- check if watchdog exists, otherwise create it
-- check if watchdog is valid, other recreate it
-- for all save files, check if they match watchdog sha

-- load everything as strings, only write to disc once everything is validated
