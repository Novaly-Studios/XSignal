export type Connection = {
    Connected: boolean,

    Disconnect: ((Connection) -> ()),
    Reconnect: ((Connection) -> ()),
}

local function BLANK_FUNCTION() end

local Connection = {}
Connection.__index = Connection

function Connection.new()
    return setmetatable({
        Connected = false;

        _DisconnectCallback = BLANK_FUNCTION;
        _ReconnectCallback = BLANK_FUNCTION;
    }, Connection)
end

function Connection:Disconnect()
    if (not self.Connected) then
        return
    end

    self.Connected = false
    self._DisconnectCallback()
end

function Connection:Reconnect()
    if (self.Connected) then
        return
    end

    self.Connected = true
    self._ReconnectCallback()
end

return Connection