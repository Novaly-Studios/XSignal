export type Connection = {
    Connected: boolean,

    Disconnect: ((Connection) -> ()),
    Reconnect: ((Connection) -> ()),
}

local Connection = {}
Connection.__index = Connection

function Connection.new(Callback, Signal)
    return setmetatable({
        Connected = false;
        Callback = Callback;

        _Signal = Signal;
    }, Connection)
end

function Connection:Disconnect()
    if (not self.Connected) then
        return
    end

    local SignalRef = self._Signal
    local Before = self._Previous
    local After = self._Next

    if (Before) then
        -- Before ~= nil -> there is something before this connection
        -- so remove this connection from the chain by pointing previous node's next to next node
        Before._Next = After
    else
        -- Before == nil -> is _FirstConnection
        -- so replace FirstConnection with the connection after this
        SignalRef._FirstConnection = After
    end

    if (After) then
        -- After ~= nil -> there is something after this connection
        -- so remove this connection from the chain by pointing next node's previous to previous node
        After._Previous = Before
    else
        -- After == nil -> is _LastConnection
        -- so replace _LastConnection with the connection before this
        SignalRef._LastConnection = Before
    end

    ---------------------------------------------

    SignalRef._ConnectionCount -= 1

    if (SignalRef._ConnectionCount == 0) then
        SignalRef._FirstConnection = nil
        SignalRef._OnConnectionsEmpty()
    end

    self.Connected = false
end

function Connection:Reconnect()
    if (self.Connected) then
        return
    end

    local SignalRef = self._Signal
    local LastConnection = SignalRef._LastConnection
    self._Previous = LastConnection

    if (LastConnection) then
        LastConnection._Next = self
    end

    if (not SignalRef._FirstConnection) then
        SignalRef._FirstConnection = self
    end

    SignalRef._LastConnection = self

    ---------------------------------------------

    SignalRef._ConnectionCount += 1

    if (SignalRef._ConnectionCount == 1) then
        SignalRef._OnConnectionsPresent()
    end

    self.Connected = true
end

return Connection