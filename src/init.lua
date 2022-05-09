--!nonstrict
local Connection = require(script.Connection)

local function BLANK_FUNCTION() end

local DEFAULT_AWAIT_FIRST_TIMEOUT_SECONDS = 30
local DEFAULT_AWAIT_ALL_TIMEOUT_SECONDS = 30
local DEFAULT_WAIT_TIMEOUT_SECONDS = 30

local ERR_CONNECTION_ALREADY_CREATED = "Connection already created in slot %d"
local INVALID_ARGUMENT = "Invalid argument #%d (%s expected, got %s)"
local ERR_WAIT_TIMEOUT = "Wait call timed out (time elapsed: %d)"
local ERR_NO_SIGNALS = "No Signals passed"

local TYPE_FUNCTION = "function"
local TYPE_BOOLEAN = "boolean"
local TYPE_NUMBER = "number"
local TYPE_TABLE = "table"

type Signal<T...> = {
    Connect: ((Signal<T...>, ((T...) -> ())) -> (Connection.Connection)),
    Wait: ((Signal<T...>, number?, boolean?) -> (T...)),
    Fire: ((Signal<T...>, T...) -> ())
}

local function CheckType(PassedArg: any, ArgNumber: number, ExpectedType: string)
    local GotType = typeof(PassedArg)
    assert(GotType == ExpectedType, INVALID_ARGUMENT:format(ArgNumber, ExpectedType, GotType))
end

local Signal = {}
Signal.__index = Signal

function Signal.new(ImmediateFire)
    if (ImmediateFire) then
        CheckType(ImmediateFire, 1, TYPE_FUNCTION)
    end

    local self = setmetatable({
        _ConnectionCount = 0;

        _HeadConnection = nil;

        _ImmediateFire = ImmediateFire;
        _OnConnectionsEmpty = BLANK_FUNCTION;
        _OnConnectionsPresent = BLANK_FUNCTION;
    }, Signal)

    self.Event = self -- Easy to port BindableEvents over in existing codebases

    return self
end

--- Creates a new connection object given a callback function, which is called when the Signal is fired.
function Signal:Connect(Callback)
    CheckType(Callback, 1, TYPE_FUNCTION)

    local NewConnection = Connection.new(self, Callback)
    NewConnection:Reconnect()

    local ImmediateFire = self._ImmediateFire

    if (ImmediateFire) then
        ImmediateFire(function(...)
            task.spawn(Callback, ...)
        end)
    end

    return NewConnection
end
Signal.connect = Signal.Connect

--- Fires the Signal, calling all connected callbacks in their own coroutine.
function Signal:Fire(...)
    debug.profilebegin("Signal.Fire")

    -- Resume all of the connections
    local Head = self._HeadConnection

    while (Head) do
        task.spawn(Head.Callback, ...)
        Head = Head._Next
    end

    debug.profileend()
end
Signal.fire = Signal.Fire

--- Yields the current coroutine until the Signal is fired, returning all data passed when the Signal was fired.
function Signal:Wait(Timeout, ThrowErrorOnTimeout)
    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS
    CheckType(Timeout, 1, TYPE_NUMBER)

    if (ThrowErrorOnTimeout) then
        CheckType(ThrowErrorOnTimeout, 2, TYPE_BOOLEAN)
    end

    local ActiveCoroutine = coroutine.running()
    local Temp; Temp = self:Connect(function(...)
        task.spawn(ActiveCoroutine, ...)
        Temp:Disconnect()
    end)

    local DidTimeout = false
    local DidResume = false

    task.delay(Timeout, function()
        -- Could time out at a later point, so once we resume we know it is only yielding for this & can reject in future
        if (DidResume) then
            return
        end

        DidTimeout = true
        Temp:Disconnect() -- Safe for coroutine.close to be called
        task.spawn(ActiveCoroutine, nil)
    end)

    local Result = {coroutine.yield()}
    DidResume = true

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return unpack(Result)
end
Signal.wait = Signal.Wait

--- Flushes all connections from the Signal.
function Signal:Destroy()
    self._HeadConnection = nil
    self._ConnectionCount = 0
    self._OnConnectionsEmpty()
end
Signal.destroy = Signal.Destroy
Signal.DisconnectAll = Signal.Destroy
Signal.disconnectAll = Signal.Destroy

--- Awaits the completion of the first Signal object and returns its fired data.
function Signal.AwaitFirst(Signals: {Signal<any>}, Timeout: number?, ThrowErrorOnTimeout: boolean?): ...any
    Timeout = Timeout or DEFAULT_AWAIT_FIRST_TIMEOUT_SECONDS
    CheckType(Timeout, 2, TYPE_NUMBER)
    CheckType(Signals, 1, TYPE_TABLE)
    assert(#Signals > 0, ERR_NO_SIGNALS)

    if (ThrowErrorOnTimeout) then
        CheckType(ThrowErrorOnTimeout, 3, TYPE_BOOLEAN)
    end

    local ActiveCoroutine = coroutine.running()
    local Connections = table.create(#Signals)

    for Index, Value in ipairs(Signals) do
        Connections[Index] = Value:Connect(function(...)
            task.spawn(ActiveCoroutine, ...)
        end)
    end

    local DidTimeout = false
    local DidResume = false

    task.delay(Timeout, function()
        if (DidResume) then
            return
        end

        DidTimeout = true

        for _, SubConnection in ipairs(Connections) do
            SubConnection:Disconnect()
        end

        task.spawn(ActiveCoroutine)
    end)

    local Result = {coroutine.yield()}
    DidResume = true

    for _, SubConnection in ipairs(Connections) do
        SubConnection:Disconnect()
    end

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return unpack(Result)
end
Signal.awaitFirst = Signal.AwaitFirst

--- Awaits the completion of all Signal objects and returns their fired data in sub-arrays (for multiple arguments).
--- Return order is maintained for the Signals passed in.
function Signal.AwaitAll(Signals: {Signal<any>}, Timeout: number?, ThrowErrorOnTimeout: boolean?): {{any}}
    Timeout = Timeout or DEFAULT_AWAIT_ALL_TIMEOUT_SECONDS
    CheckType(Timeout, 2, TYPE_NUMBER)
    CheckType(Signals, 1, TYPE_TABLE)
    assert(#Signals > 0, ERR_NO_SIGNALS)

    if (ThrowErrorOnTimeout) then
        CheckType(ThrowErrorOnTimeout, 3, TYPE_BOOLEAN)
    end

    local TargetCount = #Signals
    local Result = table.create(TargetCount)
    local Connections = table.create(TargetCount)
    local ActiveCoroutine = coroutine.running()
    local Count = 0

    local DidTimeout = false
    local DidResume = false

    task.delay(Timeout, function()
        if (DidResume) then
            return
        end

        DidTimeout = true

        for _, SubConnection in ipairs(Connections) do
            SubConnection:Disconnect()
        end

        task.spawn(ActiveCoroutine)
    end)

    for Index, Value in ipairs(Signals) do
        local TempConnection; TempConnection = Value:Connect(function(...)
            TempConnection:Disconnect()
            Result[Index] = {...}
            Count += 1

            if (Count == TargetCount) then
                task.spawn(ActiveCoroutine)
            end
        end)

        table.insert(Connections, TempConnection)
    end

    coroutine.yield()
    DidResume = true

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return Result
end
Signal.awaitAll = Signal.AwaitAll

--- Awaits the completion of all Signal objects and returns the first item of each of their arguments in an array.
--- Return order is maintained for the Signals passed in.
function Signal.AwaitAllFirstArg(Signals: {Signal<any>}, Timeout: number?, ThrowErrorOnTimeout: boolean?): {any}
    local Result = Signal.AwaitAll(Signals, Timeout, ThrowErrorOnTimeout)
    local Reformatted = table.create(#Result)

    for Index, Value in pairs(Result) do
        Reformatted[Index] = Value[1]
    end

    return Reformatted
end
Signal.awaitAllFirstArg = Signal.AwaitAllFirstArg

--- Watches multiple other Signal objects and replicates firing through any of them.
function Signal.Extend(Signals: {Signal<any>}, ...)
    CheckType(Signals, 1, TYPE_TABLE)
    assert(#Signals > 0, ERR_NO_SIGNALS)

    local NewSignal = Signal.new(...)
    local ConnectionsList = table.create(#Signals)

    -- Unhook provided signals on object destruction
    NewSignal._OnConnectionsEmpty = function()
        for Index, SubConnection in ipairs(ConnectionsList) do
            SubConnection:Disconnect()
            ConnectionsList[Index] = nil
        end
    end

    -- Hook into all provided signals
    NewSignal._OnConnectionsPresent = function()
        for Index, SubSignal in ipairs(Signals) do
            assert(ConnectionsList[Index] == nil, ERR_CONNECTION_ALREADY_CREATED:format(Index))

            ConnectionsList[Index] = SubSignal:Connect(function(...)
                NewSignal:Fire(...)
            end)
        end
    end

    return NewSignal
end
Signal.extend = Signal.Extend

return Signal