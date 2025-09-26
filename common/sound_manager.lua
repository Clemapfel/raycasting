--- @class rt.SoundManager

local _messages = {}
for message_id in range(
    "instantiate",
    "play",
    "set_volume"
) do
    _messages[message_id] = message_id
end