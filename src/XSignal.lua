--!nonstrict
--!optimize 2
--!native

-- Allows easy command bar paste:
if (not script and Instance) then
    script = game:GetService("ReplicatedFirst").XSignal.XSignal
end

local TypeGuard = require(script.Parent.Parent:WaitForChild("TypeGuard"))

local function EmptyFunction() end

local DEFAULT_WAIT_TIMEOUT_SECONDS = 240
local ERR_CONNECTION_ALREADY_CREATED = "Connection already created in slot %d"
local ERR_WAIT_TIMEOUT = "Wait call timed out (time elapsed: %d)"

local GenericMinimalSignalTypeChecker = TypeGuard.Or(
    TypeGuard.RBXScriptSignal(),
    TypeGuard.Object({
        Connect = TypeGuard.Function();
        Wait = TypeGuard.Function();
        Fire = TypeGuard.Function();
    })
)

type XSignal_WaitIndefinite<T...> = ((XSignal<T...>) -> (T...));
type XSignal_CollectFull<T...> = ((XSignal<T...>, number, number?, boolean?) -> ({{any}}));
type XSignal_Destroy<T...> = ((XSignal<T...>) -> ());
type XSignal_Collect<T...> = ((XSignal<T...>, number, number?, boolean?) -> ({any}));
type XSignal_Connect<T...> = ((XSignal<T...>, (T...) -> ()) -> (Connection));
type XSignal_Once<T...> = ((XSignal<T...>, (T...) -> ()) -> (Connection));
type XSignal_Fire<T...> = ((XSignal<T...>, T...) -> ());
type XSignal_Wait<T...> = ((XSignal<T...>, number?, boolean?) -> (T...));

export type XSignal<T...> = {
    WaitIndefinite: XSignal_WaitIndefinite<T...>;
    DisconnectAll: XSignal_Destroy<T...>;
    CollectFull: XSignal_CollectFull<T...>;
    Destroy: XSignal_Destroy<T...>;
    Collect: XSignal_Collect<T...>;
    Connect: XSignal_Connect<T...>;
    Once: XSignal_Once<T...>;
    Fire: XSignal_Fire<T...>;
    Wait: XSignal_Wait<T...>;
}
type GenericConnection = RBXScriptConnection | {
    Disconnect: (GenericConnection) -> ();
}
type GenericMinimalSignal<T...> = RBXScriptSignal<T...> | {
    Connect: (((T...) -> ()) -> (Connection));
    Fire: ((T...) -> ());
    Wait: ((number?, boolean?) -> (T...));
}

type Connection = {
    Connected: boolean,

    Disconnect: (() -> ()),
    Reconnect: (() -> ()),
}

local Connection = {}
Connection.__index = Connection

function Connection.new(SignalObject, Callback)
    return setmetatable({
        Connected = false;
        Callback = Callback;

        _Signal = SignalObject;
        _Next = nil;

        OnDisconnect = nil;
    }, Connection)
end

function Connection:Disconnect()
    if (not self.Connected) then
        return
    end

    local SignalRef = self._Signal
    local Temp = SignalRef._HeadConnection

    if (not Temp) then
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
        SignalRef._HeadConnection = false
        SignalRef._OnConnectionsEmpty()
    end

    self.Connected = false

    local OnDisconnect = self.OnDisconnect

    if (OnDisconnect) then
        OnDisconnect()
    end
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

--- @class XSignal
--- E(X)tended Signal class: adds additional memory leak prevention features & useful utilities to the Signal pattern.
local XSignal = {}
XSignal.__index = XSignal

local NewParams = TypeGuard.Params(
    TypeGuard.Optional(TypeGuard.Function())
)
--- Constructs a new XSignal.
function XSignal.new<T...>(Validator: ((T...) -> ())?): XSignal<T...>
    NewParams(Validator)

    local self = setmetatable({
        _ConnectionCount = 0;

        _Validator = Validator;
        _HeadConnection = false;

        _OnConnectionsEmpty = EmptyFunction;
        _OnConnectionsPresent = EmptyFunction;

        Event = false;
    }, XSignal)

    self.Event = self -- This makes it easy to port BindableEvents over in existing codebases

    return self
end

local FromExtensionParams = TypeGuard.Params(
    TypeGuard.Or(
        TypeGuard.Array(GenericMinimalSignalTypeChecker):MinLength(1),
        GenericMinimalSignalTypeChecker
    )
)
--- Watches multiple other Signal objects and replicates firing through any of them.
function XSignal.fromExtension(Signals: {GenericMinimalSignal<any>} | GenericMinimalSignal<any>, ...): XSignal<any>
    FromExtensionParams(Signals)

    if (not (Signals :: {})[1]) then
        Signals = {Signals}
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
        for Index, SubSignal in (Signals :: {GenericMinimalSignal<any>}) do
            assert(ConnectionsList[Index] == nil, ERR_CONNECTION_ALREADY_CREATED:format(Index))

            ConnectionsList[Index] = SubSignal:Connect(function(...)
                NewSignal:Fire(...)
            end)
        end
    end

    return NewSignal
end

local ConnectParams = TypeGuard.Params(
    TypeGuard.Optional(TypeGuard.Function())
)
--- Creates a new connection object given a callback function, which is called when the XSignal is fired.
function XSignal:Connect(Callback)
    ConnectParams(Callback)

    local NewConnection = Connection.new(self, Callback)
    NewConnection:Reconnect()
    return NewConnection
end

local OnceParams = TypeGuard.Params(
    TypeGuard.Optional(TypeGuard.Function())
)
--- Connects the XSignal once and then disconnects
function XSignal:Once(Callback)
    OnceParams(Callback)

    local GotSomeValue

    local NewConnection; NewConnection = self:Connect(function(...)
        if (GotSomeValue) then
            return
        end

        GotSomeValue = true

        if (NewConnection) then
            NewConnection:Disconnect()
        end

        Callback(...)
    end)

    if (GotSomeValue) then
        NewConnection:Disconnect()
    end

    return NewConnection
end

--- Fires the XSignal, calling all connected callbacks in their own coroutine.
function XSignal:Fire(...)
    debug.profilebegin("XSignal.Fire")

    local Validator = self._Validator

    if (Validator) then
        Validator(...)
    end

    -- Resume all of the connections
    local Head = self._HeadConnection

    while (Head) do
        task.spawn(Head.Callback, ...)
        Head = Head._Next
    end

    debug.profileend()
end

local WaitParams = TypeGuard.Params(
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Yields the current coroutine until the XSignal is fired, returning all data passed when the XSignal was fired.
function XSignal:Wait(Timeout, ThrowErrorOnTimeout)
    WaitParams(Timeout, ThrowErrorOnTimeout)

    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local DidYield = false
    local DidResume = false
    local DidTimeout = false

    local Result
    local ActiveCoroutine = coroutine.running()

    local Temp = self:Connect(function(...)
        Result = {...}

        if (not DidYield or DidTimeout) then
            return
        end

        task.spawn(ActiveCoroutine)
    end)

    if (Result ~= nil) then
        Temp:Disconnect()
        return unpack(Result)
    end

    if (Timeout ~= math.huge) then
        task.delay(Timeout, function()
            -- Could time out at a later point, so once we resume we know it is only yielding for this & can reject in future
            if (DidResume) then
                return
            end

            Result = {}
            DidTimeout = true
            task.spawn(ActiveCoroutine)
        end)
    end

    DidYield = true
    coroutine.yield()
    Temp:Disconnect()
    DidResume = true

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return unpack(Result)
end

local CollectFull = TypeGuard.Params(
    TypeGuard.Number(),
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Yields the current coroutine until the XSignal is fired "Count" times, returning all data passed when the XSignal was fired.
function XSignal:CollectFull(Count, Timeout, ThrowErrorOnTimeout)
    CollectFull(Count, Timeout, ThrowErrorOnTimeout)

    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local Results = table.create(Count)
    local ActiveCoroutine = coroutine.running()

    local DidYield = false
    local DidResume = false
    local DidTimeout = false

    local Temp; Temp = self:Connect(function(...)
        if (not DidResume and Count > 0) then
            Count -= 1
            table.insert(Results, {...})
        end

        if (Count == 0 and DidYield and not DidResume) then
            task.spawn(ActiveCoroutine)
        end
    end)

    task.delay(Timeout, function()
        -- Could time out at a later point, so once we resume we know it is only yielding for this & can reject in future
        if (DidResume) then
            return
        end

        DidTimeout = true
        task.spawn(ActiveCoroutine)
    end)

    DidYield = true

    if (Count > 0) then
        coroutine.yield()
    end

    DidResume = true
    Temp:Disconnect()

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return Results
end

local Collect = TypeGuard.Params(
    TypeGuard.Number(),
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Yields the current coroutine until the XSignal is fired "Count" times, returning the first argument passed when the XSignal was fired.
function XSignal:Collect(Count, Timeout, ThrowErrorOnTimeout)
    Collect(Count, Timeout, ThrowErrorOnTimeout)

    local Results = table.create(Count)

    for Index, Value in self:CollectFull(Count, Timeout, ThrowErrorOnTimeout) do
        Results[Index] = Value[1]
    end

    return Results
end

-- Yields the XSignal indefinitely until it fires. Not recommended unless absolutely necessary.
function XSignal:WaitIndefinite()
    return self:Wait(math.huge)
end

--- Flushes all connections from the XSignal.
function XSignal:Destroy()
    local Head = self._HeadConnection

    while (Head) do
        Head:Disconnect()
        Head = Head._Next
    end
end
XSignal.DisconnectAll = XSignal.Destroy

local AwaitFirstParams = TypeGuard.Params(
    TypeGuard.Array(GenericMinimalSignalTypeChecker):MinLength(1),
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Awaits the completion of the first XSignal object and returns its fired data.
function XSignal.AwaitFirst(Signals: {GenericMinimalSignal<any>}, Timeout: number?, ThrowErrorOnTimeout: boolean?): ...any
    AwaitFirstParams(Signals, Timeout, ThrowErrorOnTimeout)

    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local ActiveCoroutine = coroutine.running()
    local Connections = table.create(#Signals)

    local DidYield = false
    local DidResume = false
    local DidTimeout = false

    local GotValue

    for Index, Signal in Signals do
        Connections[Index] = Signal:Connect(function(...)
            if (GotValue == nil) then
                GotValue = {...}
            end

            if (DidYield and not DidResume) then
                task.spawn(ActiveCoroutine)
            end
        end)

        if (GotValue) then
            break
        end
    end

    task.delay(Timeout, function()
        if (DidResume) then
            return
        end

        GotValue = {}
        DidTimeout = true
        task.spawn(ActiveCoroutine)
    end)

    DidYield = true

    if (not GotValue) then
        coroutine.yield()
    end

    DidResume = true

    for _, Connection in Connections do
        Connection:Disconnect()
    end

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return unpack(GotValue)
end

local AwaitAllFullParams = TypeGuard.Params(
    TypeGuard.Array(GenericMinimalSignalTypeChecker):MinLength(1),
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Awaits the completion of all Signal objects and returns their fired data in sub-arrays (for multiple arguments).
--- Return order is maintained for the Signals passed in.
function XSignal.AwaitAllFull(Signals: {GenericMinimalSignal<any>}, Timeout: number?, ThrowErrorOnTimeout: boolean?): {{any}}
    AwaitAllFullParams(Signals, Timeout, ThrowErrorOnTimeout)

    Timeout = Timeout or DEFAULT_WAIT_TIMEOUT_SECONDS

    local TargetCount = #Signals

    local Count = 0
    local Results = table.create(TargetCount)
    local Connections = table.create(TargetCount)
    local ActiveCoroutine = coroutine.running()

    local DidYield = false
    local DidResume = false
    local DidTimeout = false

    for Index, Signal in Signals do
        local Collected = false

        Connections[Index] = Signal:Connect(function(...)
            if (Collected) then
                return
            end

            Collected = true

            Count += 1
            Results[Index] = {...}

            if (Count == TargetCount and DidYield and not DidResume) then
                task.spawn(ActiveCoroutine)
            end
        end)
    end

    task.delay(Timeout, function()
        if (DidResume) then
            return
        end

        DidTimeout = true
        task.spawn(ActiveCoroutine)
    end)

    DidYield = true
    coroutine.yield()
    DidResume = true

    for _, Connection in Connections do
        Connection:Disconnect()
    end

    if (DidTimeout and ThrowErrorOnTimeout) then
        error(ERR_WAIT_TIMEOUT:format(Timeout))
    end

    return Results
end

local AwaitAllParams = TypeGuard.Params(
    TypeGuard.Array(GenericMinimalSignalTypeChecker):MinLength(1),
    TypeGuard.Optional(TypeGuard.Number()),
    TypeGuard.Optional(TypeGuard.Boolean())
)
--- Awaits the completion of all Signal objects and returns the first item of each of their arguments in an array.
--- Return order is maintained for the Signals passed in.
function XSignal.AwaitAll(Signals: {GenericMinimalSignal<any>}, Timeout: number?, ThrowErrorOnTimeout: boolean?): {any}
    AwaitAllParams(Signals, Timeout, ThrowErrorOnTimeout)

    local Result = XSignal.AwaitAllFull(Signals, Timeout, ThrowErrorOnTimeout)
    local Reformatted = table.create(#Result)

    for Index, Value in Result do
        Reformatted[Index] = Value[1]
    end

    return Reformatted
end

return XSignal