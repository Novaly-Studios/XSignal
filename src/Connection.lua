export type Connection = {
    Connected: boolean,

    Disconnect: ((Connection) -> ()),
    Reconnect: ((Connection) -> ()),
}

local Connection = {}
Connection.__index = Connection

function Connection.new(SignalObject, Callback)
    return setmetatable({
        Connected = false;
        Callback = Callback;

        _Signal = SignalObject;
        _Next = nil;
    }, Connection)
end

function Connection:Disconnect()
    if (not self.Connected) then
        return
    end

    local SignalRef = self._Signal
    local Temp = SignalRef._HeadConnection

    if (Temp == nil) then
        return
    end

    if (Temp == self) then
        SignalRef._HeadConnection = self._Next
    else
        while (Temp._Next ~= self) do
            Temp = Temp._Next
        end

        Temp._Next = self._Next
    end

    ---------------------------------------------

    SignalRef._ConnectionCount -= 1

    if (SignalRef._ConnectionCount == 0) then
        SignalRef._HeadConnection = nil
        SignalRef._OnConnectionsEmpty()
    end

    self.Connected = false
end

function Connection:Reconnect()
    if (self.Connected) then
        return
    end

    local SignalRef = self._Signal
    local Head = SignalRef._HeadConnection

    if (Head) then
        self._Next = Head
        SignalRef._HeadConnection = self
    else
        SignalRef._HeadConnection = self
    end

    ---------------------------------------------

    SignalRef._ConnectionCount += 1

    if (SignalRef._ConnectionCount == 1) then
        SignalRef._OnConnectionsPresent()
    end

    self.Connected = true
end

return Connection