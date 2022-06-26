local Connection = require(script.Connection)
local TypeGuard = require(script.Parent:WaitForChild("TypeGuard"))

local function BLANK_FUNCTION() end

local CHECK_TYPES = true

local DEFAULT_AWAIT_FIRST_TIMEOUT_SECONDS = 60
local DEFAULT_AWAIT_ALL_TIMEOUT_SECONDS = 60
local DEFAULT_WAIT_TIMEOUT_SECONDS = 60

local ERR_CONNECTION_ALREADY_CREATED = "Connection already created in slot %d"
local ERR_WAIT_TIMEOUT = "Wait call timed out (time elapsed: %d)"

local EMPTY_TABLE = {}

local GenericSignalTypeChecker = TypeGuard.Object({
    Connect = TypeGuard.Function();
    Wait = TypeGuard.Function();
    Fire = TypeGuard.Function();
}):Or(TypeGuard.RBXScriptSignal())

export type XSignal<T...> = {
    WaitNoTimeout: ((XSignal<T...>) -> (T...));
    Connect: ((XSignal<T...>, ((T...) -> ())) -> (Connection.Connection));
    Once: ((XSignal<T...>, ((T...) -> ())) -> (Connection.Connection));
    Fire: ((XSignal<T...>, T...) -> ());
    Wait: ((XSignal<T...>, number?, boolean?) -> (T...));
}

type GenericConnection = RBXScriptConnection | {
    Disconnect: (GenericConnection) -> ();
}
type GenericSignal = RBXScriptSignal | {
    Connect: (GenericSignal, any...) -> GenericConnection;
    Wait: (GenericSignal, any...) -> any...;
    Fire: (GenericSignal, any...) -> ();
}

local XSignal = {}
XSignal.__index = XSignal

local NewParams = TypeGuard.Params(TypeGuard.Function():Optional())
--- Constructs a new XSignal.
function XSignal.new(ImmediateFire: () -> (...any))
    if (CHECK_TYPES) then
        NewParams(ImmediateFire)
    end

    local self = setmetatable({
        _ConnectionCount = 0;

        _HeadConnection = nil;
        _ImmediateFire = ImmediateFire;

        _OnConnectionsEmpty = BLANK_FUNCTION;
        _OnConnectionsPresent = BLANK_FUNCTION;
    }, XSignal)

    self.Event = self -- Easy to port BindableEvents over in existing codebases

    return self
end

local ConnectParams = TypeGuard.Params(TypeGuard.Function():Optional())
--- Creates a new connection object given a callback function, which is called when the XSignal is fired.
function XSignal:Connect(Callback)
    if (CHECK_TYPES) then
        ConnectParams(Callback)
    end

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
XSignal.connect = XSignal.Connect

local OnceParams = TypeGuard.Params(TypeGuard.Function():Optional())
--- Connects the XSignal once and then disconnects
function XSignal:Once(Callback)
    if (CHECK_TYPES) then
        OnceParams(Callback)
    end

    local NewConnection; NewConnection = self:Connect(function(...)
        NewConnection:Disconnect()
        Callback(...)
    end)

    return NewConnection
end

--- Fires the XSignal, calling all connected callbacks in their own coroutine.
function XSignal:Fire(...)
    debug.profilebegin("XSignal.Fire")

    -- Resume all of the connections
    local Head = self._HeadConnection

    while (Head) do
        task.spawn(Head.Callback, ...)
        Head = Head._Next
    end

    debug.profileend()
end
XSignal.fire = XSignal.Fire

local WaitParams = TypeGuard.Params(TypeGuard.Number():Optional(), TypeGuard.Boolean():Optional())
--- Yields the current coroutine until the XSignal is fired, returning all data passed when the XSignal was fired.
function XSignal:Wait(Timeout, ThrowErrorOnTimeout)
    if (CHECK_TYPES) then
        WaitParams(Timeout, ThrowErrorOnTimeout)
    end

    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local ActiveCoroutine = coroutine.running()
    local Temp; Temp = self:Connect(function(...)
        -- Could return immediately from ImmediateFire, which would cause coroutine library error, so we check here
        local Args = {...}

        if (self._ImmediateFire) then

            task.defer(function()
                task.spawn(ActiveCoroutine, Args)
                Temp:Disconnect()
            end)

            return
        end

        task.spawn(ActiveCoroutine, Args)
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
        task.spawn(ActiveCoroutine, EMPTY_TABLE)
    end)

    local Result = coroutine.yield()
    DidResume = true

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return unpack(Result)
end
XSignal.wait = XSignal.Wait

-- Yields the XSignal indefinitely until it fires
function XSignal:WaitNoTimeout()
    local ActiveCoroutine = coroutine.running()
    local Temp; Temp = self:Connect(function(...)
        local Args = {...}

        if (self._ImmediateFire) then

            task.defer(function()
                task.spawn(ActiveCoroutine, Args)
                Temp:Disconnect()
            end)

            return
        end

        task.spawn(ActiveCoroutine, Args)
        Temp:Disconnect()
    end)

    return unpack(coroutine.yield())
end
XSignal.waitNoTimeout = XSignal.WaitNoTimeout

--- Flushes all connections from the Signal.
function XSignal:Destroy()
    self._HeadConnection = nil
    self._ConnectionCount = 0
    self._OnConnectionsEmpty()
end
XSignal.destroy = XSignal.Destroy
XSignal.DisconnectAll = XSignal.Destroy
XSignal.disconnectAll = XSignal.Destroy

local AwaitLikeParams = TypeGuard.Params(TypeGuard.Array(GenericSignalTypeChecker):MinLength(1), TypeGuard.Number():Optional(), TypeGuard.Boolean():Optional())
--- Awaits the completion of the first XSignal object and returns its fired data.
function XSignal.AwaitFirst(Signals: {GenericSignal}, Timeout: number?, ThrowErrorOnTimeout: boolean?): ...any
    if (CHECK_TYPES) then
        AwaitLikeParams(Signals, Timeout, ThrowErrorOnTimeout)
    end

    Timeout = Timeout or DEFAULT_AWAIT_FIRST_TIMEOUT_SECONDS

    local ActiveCoroutine = coroutine.running()
    local Connections = table.create(#Signals)

    for Index, Value in Signals do
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

        for _, SubConnection in Connections do
            SubConnection:Disconnect()
        end

        task.spawn(ActiveCoroutine)
    end)

    local Result = {coroutine.yield()}
    DidResume = true

    for _, SubConnection in Connections do
        SubConnection:Disconnect()
    end

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return unpack(Result)
end
XSignal.awaitFirst = XSignal.AwaitFirst

--- Awaits the completion of all Signal objects and returns their fired data in sub-arrays (for multiple arguments).
--- Return order is maintained for the Signals passed in.
function XSignal.AwaitAll(Signals: {GenericSignal}, Timeout: number?, ThrowErrorOnTimeout: boolean?): {{any}}
    if (CHECK_TYPES) then
        AwaitLikeParams(Signals, Timeout, ThrowErrorOnTimeout)
    end

    Timeout = Timeout or DEFAULT_AWAIT_ALL_TIMEOUT_SECONDS

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

        for _, SubConnection in Connections do
            SubConnection:Disconnect()
        end

        task.spawn(ActiveCoroutine)
    end)

    for Index, Value in Signals do
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
XSignal.awaitAll = XSignal.AwaitAll

--- Awaits the completion of all Signal objects and returns the first item of each of their arguments in an array.
--- Return order is maintained for the Signals passed in.
function XSignal.AwaitAllFirstArg(Signals: {GenericSignal}, Timeout: number?, ThrowErrorOnTimeout: boolean?): {any}
    if (CHECK_TYPES) then
        AwaitLikeParams(Signals, Timeout, ThrowErrorOnTimeout)
    end

    local Result = XSignal.AwaitAll(Signals, Timeout, ThrowErrorOnTimeout)
    local Reformatted = table.create(#Result)

    for Index, Value in Result do
        Reformatted[Index] = Value[1]
    end

    return Reformatted
end
XSignal.awaitAllFirstArg = XSignal.AwaitAllFirstArg

local ExtendParams = TypeGuard.Params(TypeGuard.Array(GenericSignalTypeChecker):MinLength(1))
--- Watches multiple other Signal objects and replicates firing through any of them.
function XSignal.Extend(Signals: {GenericSignal}, ...)
    if (CHECK_TYPES) then
        ExtendParams(Signals)
    end

    local NewSignal = XSignal.new(...)
    local ConnectionsList = table.create(#Signals)

    -- Unhook provided signals on object destruction
    NewSignal._OnConnectionsEmpty = function()
        for Index, SubConnection in ConnectionsList do
            SubConnection:Disconnect()
            ConnectionsList[Index] = nil
        end
    end

    -- Hook into all provided signals
    NewSignal._OnConnectionsPresent = function()
        for Index, SubSignal in Signals do
            assert(ConnectionsList[Index] == nil, ERR_CONNECTION_ALREADY_CREATED:format(Index))

            ConnectionsList[Index] = SubSignal:Connect(function(...)
                NewSignal:Fire(...)
            end)
        end
    end

    return NewSignal
end
XSignal.extend = XSignal.Extend

return XSignal