# XSignal

E(X)tended signal is an API implementing Roblox's default Signal pattern, with some useful additions to help prevent memory leaks and manage multiple Signals. This should be compatible with any other Signal library. Only single args are supported for type system limitations, good practice, and performance reasons.

## Usage Examples (additional features vs regular Signals)

### 1: Wait timeouts with and without error throwing

```lua
local Test = XSignal.new() :: XSignal<number>
local Result = Test:Wait(2) --> nil
local SomethingElse = Test:Wait(2, true) -- Throws error due to timeout.
```

### 2: Signal extension

```lua
-- fromExtension wraps a Signal or XSignal, or a list of generic Signals or XSignals, and funnels invocations directly to the new constructed XSignal.
XSignal.fromExtension({Workspace.ChildAdded, Players.PlayerAdded}):Connect(function(Item)
    if (Item:IsA("BasePart")) then
        print("New part")
        return
    end

    print("New player")
end)

-- Warning: packs variadics from other signal types into a table.
XSignal.fromExtension({MarketplaceService.PromptProductPurchaseFinished}):Connect(function(Args)
    local UserId = Args[1]
    local ProductId = Args[2]
    local IsPurchased = Args[3]
end)
```

### 3: Data Validation

```lua
local Test = XSignal.new(function(Value)
    assert(
        (typeof(Value) == "number" and Value > 0 and Value < 10) or
        (typeof(Value) == "string") or
        (Value == nil),
        "Type mismatch"
    )
end)

Test:Fire(1) -- Accept
Test:Fire(2) -- Accept
Test:Fire(11) -- Reject
Test:Fire() -- Reject
Test:Fire("") -- Reject

-- Same as above but with TypeGuard: https://github.com/Novaly-Studios/TypeGuard
local Another = XSignal.new(TypeGuard.Params(TypeGuard.Number(0, 10):Or(TypeGuard.String()):Optional())) :: XSignal<(number | string)?>
```

### 4: Waiting for the first of a list of Signals to fire

```lua
local Test1 = XSignal.new()
local Test2 = XSignal.new()
local Test3 = Players.PlayerAdded

task.delay(0.1, function()
    Test2:Fire("Test2 fired")
    Test1:Fire("Test1 fired")
end)

print(XSignal.AwaitFirst({Test1, Test2, Test3}))
--> Test2 fired

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
    Test2:Fire("Test2 fired")
end

task.delay(0.1, FireThem)
print(XSignal.AwaitAll({Test1, Test2, Test3}))
--> {"Test1 fired", "Test2 fired", "Test3 fired"}
-- Maintains order of the input signals.

-- Optional timeout & error on timeout args.
XSignal.AwaitAll({Test1, Test2, Test3}, 10, true)
```

### 6: Collecting values

```lua
-- Collect first 2 values.
local Test = XSignal.new()

task.delay(0.1, function()
    Test:Fire("Test1 fired")
    Test:Fire("Test2 fired")
    Test:Fire("Test3 fired")
end)

local Result = Test:CollectN(2) -- Timeout & error on timeout args also supported.
print(Result) --> {"Test1 fired", "Test2 fired"}

-- Yield & collect first value which meets a condition.
local Test = XSignal.new()
local Result

task.spawn(function()
    Result = Test:CollectFirst(function(Value)
        return Value > 10
    end) -- Timeout & error on timeout args also supported.
end)

for Count = 1, 15 do
    Test:Fire(Count)
end

print(Result) --> 11
```

### 7: Fast / threadless connection & firing

```lua
-- Sometimes if we know a function won't yield, we can use a threadless connection.
-- Activates in the same coroutine. Be cautious.
local Test = XSignal.new()
Test:Connect(function(Value)
    print(Value)
end, XSignal.FastDirect)
Test:Fire(1)

-- Protected call version.
local Test = XSignal.new()
Test:Connect(function(Value)
    if (math.random() > 0.5) then
        error("Fail")
    end

    print(Value)
end, XSignal.Direct)
Test:Fire(1)
```

### 8: Mapping values between signals

```lua
local Test = XSignal.new()
local Stage1 = Test:Map(function(Value)
    return Value * 2
end)
local Stage2 = Stage1:Map(function(Value)
    return Value + 1
end)
Stage2:Connect(function(Value)
    print("Final", Value)
end)
Test:Fire(4) --> Final 9
```
