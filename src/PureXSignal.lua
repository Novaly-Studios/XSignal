--!nonstrict
--!optimize 2
--!native

-- Allows easy command bar paste:
if (not script and Instance) then
    script = game:GetService("ReplicatedFirst").XSignal.PureXSignal
end

export type Connection = {
    Disconnect: (() -> ());
    Connected: boolean;
}

local function ConnectionDisconnect(self, Signal)
    if (not self.Connected) then
        return
    end

    local Temp = Signal._HeadConnection
    if (not Temp) then
        return
    end

    if (Temp == self) then
        Signal._HeadConnection = self._Next
    else
        while (Temp._Next ~= self) do
            Temp = Temp._Next
        end

        Temp._Next = self._Next
    end

    ---------------------------------------------

    if (Signal._HeadConnection == nil) then
        local OnConnectionsEmpty = Signal._OnConnectionsEmpty
        if (OnConnectionsEmpty) then
            OnConnectionsEmpty()
        end
    end

    self.Connected = false
end

local function ConnectionReconnect(self, Signal)
    if (self.Connected) then
        return
    end

    local Head = Signal._HeadConnection
    self.Connected = true

    if (Head) then
        self._Next = Head
        Signal._HeadConnection = self
        return
    end

    Signal._HeadConnection = self

    local OnConnectionsPresent = Signal._OnConnectionsPresent
    if (OnConnectionsPresent) then
        OnConnectionsPresent()
    end
end

local function CreateConnection(SignalObject): Connection
    return {
        Disconnect = function(self)
            ConnectionDisconnect(self, SignalObject)
        end;
        Connected = false;
        _Next = false;
    }
end

local TypeGuard = require(script.Parent.Parent:WaitForChild("TypeGuard"))

local AsyncModule = script.Parent:FindFirstChild("Async")
    local Async = AsyncModule and require(AsyncModule :: any) or nil
        local ThreadSpawn = Async and Async.Spawn or task.spawn
        local ThreadCancel = Async and Async.Cancel or task.cancel

local DEFAULT_WAIT_TIMEOUT_SECONDS = 240
local ERR_WAIT_TIMEOUT = "Wait call timed out (time elapsed: %d)"
local TIMEOUT_OBJECT = table.freeze({})

local function TimeoutFunction(ActiveCoroutine, Pass)
    task.spawn(ActiveCoroutine, Pass or TIMEOUT_OBJECT)
end

local function SpawnerCall(Callback)
    return function(Value)
        ThreadSpawn(Callback, Value)
    end
end

local function DirectCall(Callback)
    return Callback
end

local function ProtectedDirectCall(Callback)
    return function(Value)
        local Success, Result = pcall(Callback, Value)

        if (Success) then
            return
        end

        task.spawn(error, Result)
    end
end

local Function = TypeGuard.Function()
local MinimalSignalTypeChecker = TypeGuard.Or(
    TypeGuard.RBXScriptSignal(),
    TypeGuard.Object({
        Connect = Function;
        Once = Function;
        Wait = Function;
        Fire = Function;
    })
)

type Callback<T> = ((T?) -> ())

export type XSignal<T> = {
    DisconnectAll: ((self: XSignal<T>) -> ());
    CollectUntil: ((self: XSignal<T>, Predicate: ((T) -> (boolean)), Inclusive: boolean?, Timeout: number?, ErrorOnTimeout: boolean?) -> (T?));
    CollectFirst: ((self: XSignal<T>, Predicate: ((T) -> (boolean)), Timeout: number?, ErrorOnTimeout: boolean?) -> (T?));
    CollectN: ((self: XSignal<T>, Amount: number, Timeout: number?, ErrorOnTimeout: boolean?) -> ({T}));
    Destroy: ((self: XSignal<T>) -> ());
    Connect: ((self: XSignal<T>, Handler: Callback<T>, Wrapper: ((Callback<T>) -> (Callback<T>))?) -> (Connection)) &
             ((self: XSignal<T>, Handler: thread) -> (Connection));
    Once: ((self: XSignal<T>, Handler: Callback<T>, Wrapper: ((Callback<T>) -> (Callback<T>))?) -> (Connection)) &
          ((self: XSignal<T>, Handler: thread) -> (Connection));
    Wait: ((self: XSignal<T>, Timeout: number?, ErrorOnTimeout: boolean?) -> (T));
    Fire: ((self: XSignal<T>, Value: T?) -> ());
    Map: (<O>(self: XSignal<T>, Processor: ((T) -> (O))) -> XSignal<O>);
}

type MinimalSignal<T...> = RBXScriptSignal<T...> | {
    Connect: ((MinimalSignal<T...>, ((T...) -> ())) -> (RBXScriptConnection | Connection));
    Once: ((MinimalSignal<T...>, ((T...) -> ())) -> (RBXScriptConnection | Connection));
    Fire: ((MinimalSignal<T...>, T...) -> ());
    Wait: ((MinimalSignal<T...>) -> (T...));
}


--- @class XSignal
--- E(X)tended Signal class: adds additional memory leak prevention features & useful utilities to the Signal pattern.
--- Optimizes for Fire speed rather than Connect speed.
local XSignal = {}
XSignal._IsXSignal = true
XSignal.FastDirect = DirectCall
XSignal.Direct = ProtectedDirectCall
XSignal.__index = XSignal

local function IsXSignal(Value)
    return (type(Value) == "table" and Value._IsXSignal)
end

local NewParams = TypeGuard.Params(TypeGuard.Optional(Function))
--- Constructs a new XSignal.
local function new<T>(Validator: ((T) -> ())?): XSignal<T>
    NewParams(Validator)

    local self = setmetatable({
        _HeadConnection = false;
        _Validator = Validator;
    }, XSignal)

    return self
end
XSignal.new = new

local ConnectParams = TypeGuard.Params(
    TypeGuard.Or(Function, TypeGuard.Thread()),
    TypeGuard.Optional(Function)
)
--- Creates a new connection object given a callback function, which is called when the XSignal is fired.
--- Second argument accepts an optional wrapper function to wrap the callback; by default it is just task.spawn.
local function Connect(self, Callback, Wrapper)
    ConnectParams(Callback, Wrapper)

    if (type(Callback) == "thread") then
        local NewConnection = CreateConnection(self)
        NewConnection._Thread = Callback
        ConnectionReconnect(NewConnection, self)
        return NewConnection
    end

    local NewConnection = CreateConnection(self)
    NewConnection._Callback = (Wrapper or SpawnerCall)(Callback)
    ConnectionReconnect(NewConnection, self)
    return NewConnection
end
XSignal.Connect = Connect

--- Fires the XSignal, calling all connected callbacks.
local function Fire(self, Value)
    debug.profilebegin("XS.F")

    local Head = self._HeadConnection
    if (not Head) then
        debug.profileend()
        return
    end

    -- Validate input.
    local Validator = self._Validator
    if (Validator) then
        Validator(Value)
    end

    -- Apply transformation to the value if any exists.
    local Mapper = self._Map
    if (Mapper) then
        Value = Mapper(Value)
    end

    -- Activate all callbacks or threads waiting.
    while (Head) do
        local Callback = Head._Callback

        if (Callback) then
            Callback(Value)
        else
            local Thread = Head._Thread

            if (coroutine.status(Thread) == "suspended") then
                task.spawn(Thread, Value)
            end
        end

        Head = Head._Next
    end

    debug.profileend()
end
XSignal.Fire = Fire

local FromExtensionParams = TypeGuard.Params(
    TypeGuard.Or(
        TypeGuard.Array(MinimalSignalTypeChecker):MinLength(1),
        MinimalSignalTypeChecker
    )
)
--- Watches multiple other Signal objects and replicates firing through any of them.
local function fromExtension<T>(Signals: {MinimalSignal<T>} | MinimalSignal<T>, Validator): XSignal<T | {T}>
    FromExtensionParams(Signals)

    if (not (Signals :: {})[1]) then
        Signals = {Signals}
    end

    local NewSignal = new(Validator)
    local ConnectionCount = #Signals
    local ConnectionsList = table.create(ConnectionCount)

    -- Unhook provided signals on object destruction.
    NewSignal._OnConnectionsEmpty = function()
        local Remove = table.create(ConnectionCount)

        for Index, SubConnection in ConnectionsList do
            SubConnection:Disconnect()
            table.insert(Remove, Index)
        end

        for _, Index in Remove do
            ConnectionsList[Index] = nil
        end
    end

    -- Hook into all provided signals.
    local function DefaultHook(...)
        NewSignal:Fire(select("#", ...) == 1 and (...) or {...})
    end

    local function XSignalHook(Value)
        Fire(NewSignal, Value)
    end

    NewSignal._OnConnectionsPresent = function()
        for Index, SubSignal in (Signals :: {MinimalSignal<any>}) do
            if (ConnectionsList[Index]) then
                error(`Connection already created in slot {Index}`)
            end

            ConnectionsList[Index] = IsXSignal(SubSignal) and
                                        SubSignal:Connect(XSignalHook, DirectCall) or -- XSignal -> no threads required for propagation, faster.
                                        SubSignal:Connect(DefaultHook) -- Other signal -> spawns thread for propagation, slower.
        end
    end

    return NewSignal
end
XSignal.fromExtension = fromExtension

local OnceParams = TypeGuard.Params(
    TypeGuard.Or(Function, TypeGuard.Thread()),
    TypeGuard.Optional(Function)
)
--- Connects the XSignal once and then disconnects.
local function Once(self, Callback, Wrapper)
    OnceParams(Callback, Wrapper)

    if (type(Callback) == "thread") then
        local NewConnection = Connect(self, Callback)

        Once(self, function()
            NewConnection:Disconnect()
        end)

        return NewConnection
    end

    local NewConnection

    NewConnection = Connect(self, function(Value)
        NewConnection:Disconnect()
        Callback(Value)
    end, Wrapper)

    return NewConnection
end
XSignal.Once = Once

local MapParams = TypeGuard.Params(Function)
--- Returns a new XSignal, extending the original, which processes all Fire calls of the original,
--- transforming its arguments using the provided processor function.
local function Map(self, Processor)
    MapParams(Processor)

    local New = fromExtension({self})
    New._Map = Processor
    return New
end
XSignal.Map = Map

local WaitParams = TypeGuard.Params(
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Yields the current coroutine until the XSignal is fired, returning all data passed when the XSignal was fired.
local function Wait(self, Timeout, ThrowErrorOnTimeout)
    WaitParams(Timeout, ThrowErrorOnTimeout)
    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local ActiveCoroutine = coroutine.running()
    local TimeoutThread = (Timeout ~= math.huge and task.delay(Timeout, TimeoutFunction, ActiveCoroutine) or nil)
    Once(self, ActiveCoroutine)

    local Result = coroutine.yield()
    if (TimeoutThread and coroutine.status(TimeoutThread) == "suspended") then
        task.cancel(TimeoutThread)
    end

    local DidTimeout = (Result == TIMEOUT_OBJECT)
    if (DidTimeout) then
        if (ThrowErrorOnTimeout) then
            error(ERR_WAIT_TIMEOUT:format(Timeout))
        end

        return nil
    end

    return Result
end
XSignal.Wait = Wait

--- Collects the firing of the XSignal until the predicate returns true, returning the first value that does.
local function CollectFirst(self, Predicate, Timeout, ThrowErrorOnTimeout)
    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local ActiveCoroutine = coroutine.running()
    local Temp = Connect(self, function(Value)
        if (not Predicate(Value)) then
            return
        end

        if (coroutine.status(ActiveCoroutine) == "suspended") then
            task.spawn(ActiveCoroutine, Value)
        end
    end, DirectCall)

    local TimeoutThread = (Timeout ~= math.huge and task.delay(Timeout, TimeoutFunction, ActiveCoroutine) or nil)
    local Result = coroutine.yield()
    Temp:Disconnect()

    if (TimeoutThread and coroutine.status(TimeoutThread) == "suspended") then
        task.cancel(TimeoutThread)
    end

    local DidTimeout = (Result == TIMEOUT_OBJECT)

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    elseif (DidTimeout) then
        return nil
    end

    return Result
end
XSignal.CollectFirst = CollectFirst

--- Collects the values fired through the XSignal until the predicate returns true, then returns those values.
--- By default, not inclusive of the last value. Also returns all collected values on timeout + no error.
local function CollectUntil(self, Predicate, Inclusive, Timeout, ThrowErrorOnTimeout)
    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local ActiveCoroutine = coroutine.running()
    local Results = {}
    local Temp = Connect(self, function(Value)
        if (not Predicate(Value)) then
            table.insert(Results, Value)
            return
        end

        if (Inclusive) then
            table.insert(Results, Value)
        end

        if (coroutine.status(ActiveCoroutine) == "suspended") then
            task.spawn(ActiveCoroutine)
        end
    end, DirectCall)

    local TimeoutThread = (Timeout ~= math.huge and task.delay(Timeout, TimeoutFunction, ActiveCoroutine) or nil)
    local Result = coroutine.yield()
    Temp:Disconnect()

    if (TimeoutThread and coroutine.status(TimeoutThread) == "suspended") then
        task.cancel(TimeoutThread)
    end

    local DidTimeout = (Result == TIMEOUT_OBJECT)
    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end
    return Results
end
XSignal.CollectUntil = CollectUntil

--- Yields the current coroutine until the XSignal is fired Count times, returning all data passed when the XSignal was fired.
--- Returns all collected values on timeout + no error.
local function CollectN(self, Count, Timeout, ThrowErrorOnTimeout)
    return CollectUntil(self, function()
        Count -= 1
        return (Count == 0)
    end, true, Timeout, ThrowErrorOnTimeout)
end
XSignal.CollectN = CollectN

--- Flushes all connections from the XSignal.
local function Destroy(self)
    local Head = self._HeadConnection

    while (Head) do
        -- Release all thread callbacks which are likely from Wait calls.
        local Thread = Head._Thread
        if (Thread) then
            ThreadCancel(Thread)
        end

        Head:Disconnect()
        Head = Head._Next
    end
end
XSignal.Destroy = Destroy
XSignal.DisconnectAll = Destroy

local AwaitFirstParams = TypeGuard.Params(
    TypeGuard.Array(MinimalSignalTypeChecker),
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Awaits the completion of the first signal object and returns its fired data.
type AwaitFirst = (
    (<T>(Signals: {XSignal<T>}, Timeout: number?, ThrowErrorOnTimeout: boolean?) -> (T?)) &
    (<T>(Signals: {MinimalSignal<T>}, Timeout: number?, ThrowErrorOnTimeout: boolean?) -> ({T} | T))
)
local function AwaitFirst(Signals, Timeout, ThrowErrorOnTimeout)
    AwaitFirstParams(Signals, Timeout, ThrowErrorOnTimeout)
    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local Count = #Signals
    if (Count == 0) then
        return nil
    end

    local ActiveCoroutine = coroutine.running()
    local Connections = table.create(Count)

    for Index, Signal in Signals do
        Connections[Index] = (
            IsXSignal(Signal) and
            Once(Signal, ActiveCoroutine) or -- XSignal -> internal resumes thread directly, faster.
            Signal:Once(function(...) -- Other signal -> capture varargs, creates intermediary thread to resume, slower.
                task.spawn(ActiveCoroutine, select("#", ...) == 1 and select(1, ...) or {...})
            end)
        )
    end

    local TimeoutThread = (Timeout ~= math.huge and task.delay(Timeout, TimeoutFunction, ActiveCoroutine) or nil)
    local Result = coroutine.yield()

    if (TimeoutThread and coroutine.status(TimeoutThread) == "suspended") then
        task.cancel(TimeoutThread)
    end

    for _, Connection in Connections do
        Connection:Disconnect()
    end

    local DidTimeout = (Result == TIMEOUT_OBJECT)

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    elseif (DidTimeout) then
        return nil
    end

    return Result
end
XSignal.AwaitFirst = AwaitFirst :: AwaitFirst

local AwaitAllParams = TypeGuard.Params(
    TypeGuard.Array(MinimalSignalTypeChecker),
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Awaits the completion of all Signal objects and returns their fired data in sub-arrays (for multiple arguments).
--- Return order is maintained for the Signals passed in.
type AwaitAll = (
    (<T>(Signals: {XSignal<T>}, Timeout: number?, ThrowErrorOnTimeout: boolean?) -> ({T})) &
    (<T>(Signals: {MinimalSignal<T>}, Timeout: number?, ThrowErrorOnTimeout: boolean?) -> ({{T} | T}))
)
local function AwaitAll(Signals, Timeout, ThrowErrorOnTimeout)
    AwaitAllParams(Signals, Timeout, ThrowErrorOnTimeout)
    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local Count = #Signals
    if (Count == 0) then
        return nil
    end

    local Results = table.create(Count)
    local Connections = table.create(Count)
    local ActiveCoroutine = coroutine.running()

    for Index, Signal in Signals do
        Connections[Index] = (
            IsXSignal(Signal) and
            Once(Signal, function(Value) -- XSignal -> capture single value, in-thread, faster.
                Results[Index] = Value

                if (Count == 1) then
                    if (coroutine.status(ActiveCoroutine) == "suspended") then
                        task.spawn(ActiveCoroutine)
                    end

                    return
                end

                Count -= 1
            end, DirectCall) or
            Signal:Once(function(...) -- Other signal -> capture varargs, thread-per-call, slower.
                Results[Index] = select("#", ...) == 1 and select(1, ...) or {...}

                if (Count == 1) then
                    if (coroutine.status(ActiveCoroutine) == "suspended") then
                        task.spawn(ActiveCoroutine)
                    end

                    return
                end

                Count -= 1
            end)
        )
    end

    local TimeoutThread = (Timeout ~= math.huge and task.delay(Timeout, TimeoutFunction, ActiveCoroutine) or nil)
    local Result = coroutine.yield()

    if (TimeoutThread and coroutine.status(TimeoutThread) == "suspended") then
        task.cancel(TimeoutThread)
    end

    for _, Connection in Connections do
        Connection:Disconnect()
    end

    if ((Result == TIMEOUT_OBJECT) and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return Results
end
XSignal.AwaitAll = AwaitAll :: AwaitAll

return XSignal