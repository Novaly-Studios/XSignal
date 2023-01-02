# XSignal

E(X)tended signal is an API implementing Roblox's default Signal pattern, with some useful additions to help prevent memory leaks and manage multiple Signals. This should be compatible with any other Signal library too.

## Usage Examples (additional features vs regular Signals)

### 1: Wait timeouts with and without error throwing

```lua
local Test = XSignal.new() :: XSignal<number>
local Result = Test:Wait(2) --> nil
local SomethingElse = Test:Wait(2, true) -- Throws error due to timeout
```

### 2: Extension and "immediate fire" mode

```lua
-- fromExtension wraps a generic Signal or a list of generic Signals and funnels invocations directly to the new constructed XSignal
local PlayerExists = XSignal.fromExtension(Players.PlayerAdded, nil, function(Callback)
    for _, Player in Players:GetPlayers() do
        Callback(Player)
    end
end)

PlayerExists:Connect(function(Player)
    -- This will fire for all existing players as soon as Connect is called, as well as when a player joins
    -- ...
end)

-- fromExtension also supports passing a list
XSignal.fromExtension({ game:GetService("Workspace").ChildAdded, game:GetService("Players").PlayerAdded })
```

### 3: Data Validation

```lua
local Test = XSignal.new(function(X, Y)
    assert(typeof(X) == "number" and (Y == nil or typeof(Y) == "string"), "Type mismatch")
end)

Test:Fire(1, "") -- Accept
Test:Fire(2) -- Accept
Test:Fire() -- Reject
Test:Fire("") -- Reject

-- Same as above but with TypeGuard: https://github.com/Novaly-Studios/TypeGuard
local Another = XSignal.new(TypeGuard.Params(TypeGuard.Number(), TypeGuard.String():Optional())) :: XSignal<number, string?>
```

### 4: Waiting for the first of a list of Signals to fire

```lua
local Test1 = XSignal.new()
local Test2 = XSignal.new()
local Test3 = Players.PlayerAdded

task.delay(0.1, function()
    Test1:Fire("Test1 fired", "Something else")
end)

print(XSignal.AwaitFirst({Test1, Test2, Test3}))
--> Test1 fired    Something else

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
print(XSignal.AwaitAll({Test1, Test2, Test3})) -- Extracts only first arg
--> {"Test1 fired", "Test3 fired", "Test2 fired"}

task.delay(0.1, FireThem)
print(XSignal.AwaitAllFull({Test1, Test2, Test3}))
--> {{"Test1 fired"}, {"Test3 fired"}, {"Test2 fired", "Another arg"}}

 -- Optional timeout & error on timeout args
XSignal.AwaitAllFull({Test1, Test2, Test3}, 10, true)
XSignal.AwaitAll({Test1, Test2, Test3}, 10, true)
```

### 6: Collecting first x fires

```lua
local Test = XSignal.new()

task.delay(0.1, function()
    Test:Fire("Test1 fired")
    Test:Fire("Test2 fired")
    Test:Fire("Test3 fired")
end)

print(Test:Collect(2))
--> {"Test1 fired", "Test2 fired"}

task.spawn(function()
    task.wait()
    Test:Fire("Test1 fired")
    task.wait()
    Test:Fire("Test2 fired")
end)

print(Test:CollectFull(2))
--> {{"Test1 fired"}, {"Test2 fired"}}
```