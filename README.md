# XSignal

E(X)tended signal is an API implementing Roblox's default Signal pattern, wiht some useful additions to help prevent memory leaks and manage multiple Signals. This should be compatible with any other Signal library too.

## Usage Examples (additional features vs regular Signals)

### 1: Wait timeouts with and without error throwing

```lua
local Test = XSignal.new() :: XSignal<number>
local Result = Test:Wait(2) --> nil
local SomethingElse = Test:Wait(2, true) -- Throws error due to timeout
```

### 2: Extension and "immediate fire" mode

```lua
-- Extend wraps a generic Signal or a list of generic Signals and funnels invocations directly to the new constructed XSignal
local PlayerExists = XSignal.Extend(Players.PlayerAdded, function(Callback)
    for _, Player in Players:GetPlayers() do
        Callback(Player)
    end
end)

PlayerExists:Connect(function(Player)
    -- This will fire for all existing players as soon as Connect is called, as well as when a player joins
    -- ...
end)

-- Extend also supports passing a list
XSignal.Extend({ game:GetService("Workspace").ChildAdded, game:GetService("Players").PlayerAdded })
```

### 3: Data Validation

```lua
local Test = XSignal.new(nil, function(X, Y)
    assert(typeof(X) == "number" and (Y == nil or typeof(Y) == "string"), "Type mismatch")
end)

Test:Fire(1, "") -- Accept
Test:Fire(2) -- Accept
Test:Fire() -- Reject
Test:Fire("") -- Reject

-- Same as above but with TypeGuard: https://github.com/Novaly-Studios/TypeGuard
local Another = XSignal.new(nil, TypeGuard.Params(TypeGuard.Number(), TypeGuard.String():Optional())) :: XSignal<number, string?>
```

### 4: Waiting for the first of a list of Signals to fire

```lua
local Test1 = XSignal.new()
local Test2 = XSignal.new()
local Test3 = Players.PlayerAdded

task.delay(0.1, function()
    Test1:Fire("Test1 fired")
end)

print(XSignal.AwaitFirst({Test1, Test2, Test3}))
--> Test1 fired

XSignal.AwaitFirst({Test1, Test2, Test3}, 10, true) -- Optional timeout & error on timeout args
```

### 5: Waiting for all Signals in a list to fire

```lua
local Test1 = XSignal.new()
local Test2 = XSignal.new()
local Test3 = XSignal.new()

local function FireThem()
    Test1:Fire("Test1 fired")
    Test3:Fire("Test3 fired")
    Test2:Fire("Test2 fired", "Another arg")
end

task.delay(0.1, FireThem)
print(XSignal.AwaitAll({Test1, Test2, Test3}))
--> {{"Test1 fired"}, {"Test3 fired"}, {"Test2 fired", "Another arg"}}

task.delay(0.1, FireThem)
print(XSignal.AwaitAllFirstArg({Test1, Test2, Test3}))
--> {"Test1 fired", "Test3 fired", "Test2 fired"}

XSignal.AwaitAll({Test1, Test2, Test3}, 10, true) -- Optional timeout & error on timeout args
XSignal.AwaitAllFirstArg({Test1, Test2, Test3}, 10, true)
```