local function anyfn(...) return ({} :: any) end
it = it or anyfn
expect = expect or anyfn
describe = describe or anyfn

return function()
    local XSignal = require(script.Parent)

    describe("XSignal.new", function()
        it("should construct", function()
            expect(function()
                XSignal.new()
            end).never.to.throw()
        end)

        it("should reject non-function types as first arg", function()
            expect(function()
                XSignal.new(1)
            end).to.throw()
        end)

        it("should accept a function as first arg", function()
            expect(function()
                XSignal.new(function() end)
            end).never.to.throw()
        end)

        it("should accept a validator function", function()
            expect(function()
                XSignal.new(function(X, Y)
                    assert(typeof(X) == "number" and (Y == nil or typeof(Y) == "string"), "Type mismatch")
                end)
            end).never.to.throw()
        end)
    end)
    
    describe("XSignal.fromExtension", function()
        it("should accept a list of XSignals", function()
            expect(function()
                XSignal.fromExtension({XSignal.new(), XSignal.new()})
            end).never.to.throw()
        end)

        it("should accept a list of other signal types", function()
            local Bindable1 = Instance.new("BindableEvent")
            local Bindable2 = Instance.new("BindableEvent")
            expect(function()
                XSignal.fromExtension({Bindable1.Event, Bindable2.Event})
            end).never.to.throw()
        end)

        it("should pass through the value of fired XSignals", function()
            local Signal1 = XSignal.new()
            local Signal2 = XSignal.new()
            local Extended = XSignal.fromExtension({Signal1, Signal2})
            local Results = {}

            Extended:Connect(function(Value)
                table.insert(Results, Value)
            end)

            Signal1:Fire(1)
            Signal2:Fire(2)
            expect(Results[1]).to.equal(1)
            expect(Results[2]).to.equal(2)
        end)

        it("should pass through the value of fired other signals", function()
            local Signal1 = Instance.new("BindableEvent")
            local Signal2 = Instance.new("BindableEvent")
            local Extended = XSignal.fromExtension({Signal1.Event, Signal2.Event})
            local Results = {}

            Extended:Connect(function(Value)
                table.insert(Results, Value)
            end)

            Signal1:Fire(1)
            Signal2:Fire(2, 3)
            task.wait() -- Roblox signals can be deferred.
            expect(Results[1]).to.equal(1)
            expect(Results[2]).to.be.a("table")
            expect(Results[2][1]).to.equal(2)
            expect(Results[2][2]).to.equal(3)
        end)

        it("should pass through the value of fired other signals (or variadic for multiple)", function()
            local Signal = Instance.new("BindableEvent")
            local Result

            XSignal.fromExtension({Signal.Event}):Connect(function(Value)
                Result = Value
            end)

            Signal:Fire(1)
            task.wait()
            expect(Result).to.equal(1)
            Signal:Fire(2, 3)
            task.wait()
            expect(Result).to.be.a("table")
            expect(#Result).to.equal(2)
            expect(Result[1]).to.equal(2)
            expect(Result[2]).to.equal(3)
        end)
    end)

    describe("XSignal:Connect", function()
        it("should throw when not given a function", function()
            expect(function()
                XSignal.new():Connect(1)
            end).to.throw()

            expect(function()
                XSignal.new():Connect("S")
            end).to.throw()
        end)

        it("should accept a callback", function()
            expect(function()
                XSignal.new():Connect(function() end)
            end).never.to.throw()
        end)

        it("should accept a thread", function()
            expect(function()
                XSignal.new():Connect(coroutine.running())
            end).never.to.throw()
        end)

        it("should not fire a disconnected connection", function()
            local Test = XSignal.new()
            local DidFire = false
            local Connection = Test:Connect(function()
                DidFire = true
            end)
            Connection:Disconnect()
            Test:Fire()
            expect(DidFire).to.equal(false)
        end)

        it("should accept a callback wrapper as a second argument", function()
            XSignal.new():Connect(function() end, XSignal.FastDirect)
        end)

        it("should run in the same thread with direct callback", function()
            local Test = XSignal.new()
            local Found
            local Current = coroutine.running()
            Test:Connect(function()
                Found = coroutine.running()
            end, XSignal.FastDirect)
            Test:Fire(1)
            expect(Found).to.equal(Current)
        end)
    end)

    describe("XSignal:Fire", function()
        it("should fire with nil", function()
            local Test = XSignal.new()
            local GotValue
            Test:Connect(function(Value)
                GotValue = Value
            end)
            expect(GotValue).to.equal(nil)
            Test:Fire()
            expect(GotValue).to.equal(nil)
        end)

        it("should fire with a value", function()
            local Test = XSignal.new()
            local GotValue
            Test:Connect(function(Value)
                GotValue = Value
            end)
            expect(GotValue).to.equal(nil)
            Test:Fire(1)
            expect(GotValue).to.equal(1)
        end)

        it("should fire with a table", function()
            local Test = XSignal.new()
            local Temp = {}
            local GotValue
            Test:Connect(function(Value)
                GotValue = Value
            end)
            expect(GotValue).to.equal(nil)
            Test:Fire(Temp)
            expect(GotValue).to.equal(Temp)
        end)

        it("should only fire with one value", function()
            local Test = XSignal.new()
            local GotX, GotY
            Test:Connect(function(X, Y)
                GotX = X
                GotY = Y
            end)
            Test:Fire(1, 2)
            expect(GotX).to.equal(1)
            expect(GotY).to.equal(nil)
        end)

        it("should fire multiple times for multiple connection", function()
            local Test = XSignal.new()
            local Value1, Value2
            Test:Connect(function(X)
                Value1 = X
            end)
            Test:Connect(function(Y)
                Value2 = Y
            end)
            Test:Fire(1)
            expect(Value1).to.equal(1)
            expect(Value2).to.equal(1)
            Test:Fire(2)
            expect(Value1).to.equal(2)
            expect(Value2).to.equal(2)
        end)

        it("should resume suspended coroutines, passing the value", function()
            local Test = XSignal.new()
            task.defer(Test.Fire, Test, 1)
            Test:Connect(coroutine.running())
            local Value1 = coroutine.yield()
            expect(Value1).to.equal(1)
            task.defer(Test.Fire, Test, 2)
            local Value2 = coroutine.yield()
            expect(Value2).to.equal(2)
        end)
    end)

    describe("XSignal:Wait", function()
        it("should accept number & boolean as optional args", function() 
            local Test = XSignal.new()
            Test:Wait(0)
            expect(function()
                Test:Wait(0, true)
            end).to.throw()
        end)

        it("should timeout but return nil if no error is desired", function()
            local Test = XSignal.new()
            local Value = Test:Wait(0)
            expect(Value).to.equal(nil)
        end)

        it("should timeout and throw if an error is desired", function()
            local Test = XSignal.new()
            expect(function()
                Test:Wait(0, true)
            end).to.throw()
        end)

        it("should return the values passed when firing", function()
            local Test = XSignal.new()
            task.defer(Test.Fire, Test, 1)
            local Value = Test:Wait()
            expect(Value).to.equal(1)
            task.defer(Test.Fire, Test, 2)
            Value = Test:Wait()
            expect(Value).to.equal(2)
        end)
    end)

    describe("XSignal:Once", function()
        it("should accept a callback", function()
            local Test = XSignal.new()
            expect(function()
                Test:Once(function() end)
            end).never.to.throw()
        end)

        it("should accept a thread", function()
            local Test = XSignal.new()
            expect(function()
                Test:Once(coroutine.running())
            end).never.to.throw()
        end)

        it("should only fire once & return the passed values", function()
            local Test = XSignal.new()
            local Value
            Test:Once(function(Result)
                Value = Result
            end)
            Test:Fire(1)
            expect(Value).to.equal(1)
            Test:Fire(2)
            expect(Value).to.equal(1)
        end)

        it("should return the connection & allow disconnection", function()
            local Test = XSignal.new()
            local DidFire = false
            local Connection = Test:Once(function()
                DidFire = true
            end)
            Connection:Disconnect()
            Test:Fire()
            expect(DidFire).to.equal(false)
        end)

        it("should resume a thread once", function()
            local Test = XSignal.new()
            task.defer(Test.Fire, Test, 1)
            Test:Once(coroutine.running())
            expect(coroutine.yield()).to.equal(1)
        end)
    end)

    describe("XSignal:Map", function()
        it("should accept a function", function()
            local Test = XSignal.new()
            expect(function()
                Test:Map(function() end)
            end).never.to.throw()
        end)

        it("should create a new XSignal that listens to the original XSignal values and maps them", function()
            local Test = XSignal.new()
            local Results = {}
            local Mapped = Test:Map(function(Value)
                return Value + 1
            end)
            expect(Mapped).never.to.equal(Test)
            Mapped:Connect(function(Value)
                table.insert(Results, Value)
            end)
            Test:Fire(1)
            Test:Fire(2)
            expect(Results[1]).to.equal(2)
            expect(Results[2]).to.equal(3)
        end)

        it("should allow chaining of mapping functions", function()
            local Test = XSignal.new()
            local Results = {}
            local Mapped = Test:Map(function(Value)
                return Value + 1
            end):Map(function(Value)
                return Value * 2
            end):Map(function(Value)
                return Value ^ 2
            end)
            expect(Mapped).never.to.equal(Test)
            Mapped:Connect(function(Value)
                table.insert(Results, Value)
            end)
            Test:Fire(1)
            Test:Fire(2)
            expect(Results[1]).to.equal(16)
            expect(Results[2]).to.equal(36)
        end)
    end)

    describe("XSignal:CollectN", function()
        it("should collect the first n values", function()
            local Test = XSignal.new()
            local Results

            task.spawn(function()
                Results = Test:CollectN(2)
            end)

            Test:Fire(1)
            Test:Fire(2)
            Test:Fire(3)

            expect(#Results).to.equal(2)
            expect(Results[1]).to.equal(1)
            expect(Results[2]).to.equal(2)
        end)

        it("should return current results if it times out", function()
            local Test = XSignal.new()
            local Results

            task.spawn(function()
                Results = Test:CollectN(2, 0.1)
            end)

            Test:Fire(1)
            task.wait(0.1)
            expect(#Results).to.equal(1)
            expect(Results[1]).to.equal(1)
        end)

        it("should throw an error if it times out and timeout error is desired", function()
            local Test = XSignal.new()

            expect(function()
                Test:CollectN(2, 0.1, true)
            end).to.throw()
        end)
    end)

    describe("XSignal:CollectFirst", function()
        it("should collect the first value which satisfies a condition", function()
            local Test = XSignal.new()
            local Result

            task.spawn(function()
                Result = Test:CollectFirst(function(Value)
                    return Value > 10
                end)
            end)

            for Count = 1, 15 do
                Test:Fire(Count)
            end

            expect(Result).to.be.a("number")
            expect(Result).to.equal(11)
        end)

        it("should return nil if it times out", function()
            local Test = XSignal.new()
            local Result
            local DidFinish = false

            task.spawn(function()
                Result = Test:CollectFirst(function(Value)
                    return Value > 10
                end, 0.1)
                DidFinish = true
            end)
            task.wait(0.1)
            expect(Result).to.equal(nil)
            expect(DidFinish).to.equal(true)
        end)

        it("should throw an error if it times out and timeout error is desired", function()
            expect(function()
                XSignal.new():CollectFirst(function() return false end, 0.1, true)
            end).to.throw()
        end)
    end)

    describe("XSignal:Destroy", function()
        it("should disconnect all connections", function()
            local Test = XSignal.new()
            local DidFire = false
            local Connection = Test:Connect(function()
                DidFire = true
            end)
            Test:Destroy()
            expect(Connection.Connected).to.equal(false)
            Test:Fire()
            expect(DidFire).to.equal(false)
        end)

        it("should terminate all waiting threads", function()
            local Test = XSignal.new()
            local Thread = task.spawn(function()
                Test:Wait(math.huge)
            end)

            expect(coroutine.status(Thread)).to.equal("suspended")
            Test:Destroy()
            expect(coroutine.status(Thread)).to.equal("dead")
        end)
    end)

    describe("XSignal.AwaitFirst", function()
        it("should return nil on timeout", function()
            local Value = XSignal.AwaitFirst({XSignal.new()}, 0.1) 
            expect(Value).to.equal(nil)
        end)

        it("should throw an error on timeout if desired", function()
            expect(function()
                XSignal.AwaitFirst({XSignal.new()}, 0.1, true)
            end).to.throw()
        end)

        it("should accept a list of signals as first arg & reject non-signals", function()
            expect(function()
                local Test1 = XSignal.new()
                local Test2 = XSignal.new()
                local Test3 = XSignal.new()
                XSignal.AwaitFirst({Test1, Test2, Test3}, 0.1)
            end).never.to.throw()

            expect(function()
                XSignal.AwaitFirst({workspace.ChildAdded}, 0.1)
            end).never.to.throw()
        end)

        it("should immediately return nil if the signal list is empty", function()
            expect(XSignal.AwaitFirst({})).to.equal(nil)
        end)

        it("should return tables of arguments on variadic non-signals if args > 1", function()
            local Signal = Instance.new("BindableEvent")
            task.defer(function()
                Signal:Fire(1, 2, 3)
            end)
            local Value = XSignal.AwaitFirst({Signal.Event}, 0.1)
            expect(Value).to.be.a("table")
            expect(#Value).to.equal(3)
            expect(Value[1]).to.equal(1)
            expect(Value[2]).to.equal(2)
            expect(Value[3]).to.equal(3)

            task.defer(function()
                Signal:Fire(1)
            end)

            Value = XSignal.AwaitFirst({Signal.Event}, 0.1)
            expect(Value).to.be.a("number")
            expect(Value).to.equal(1)
        end)

        it("should return the first value on a single signal", function()
            local Signals = {}
            local FirstValue

            for _ = 1, 100 do
                table.insert(Signals, XSignal.new())
            end

            task.defer(function()
                local RandomGen = Random.new()

                for Count = 1, 100 do
                    local Value = RandomGen:NextInteger(1, 1000000)

                    if (not FirstValue) then
                        FirstValue = Value
                    end

                    Signals[RandomGen:NextInteger(1, 100)]:Fire(Value)
                end
            end)

            expect(XSignal.AwaitFirst(Signals, 0.1)).to.equal(FirstValue)
        end)
    end)

    describe("XSignal.AwaitAll", function()
        it("should return an empty table on timeout", function()
            local Result = XSignal.AwaitAll({XSignal.new()}, 0.1)
            expect(Result).to.be.a("table")
            expect(next(Result)).to.equal(nil)
        end)

        it("should throw an error on timeout if desired", function()
            expect(function()
                XSignal.AwaitAll({XSignal.new()}, 0.1, true)
            end).to.throw()
        end)

        it("should accept a list of signals as first arg & reject non-signals", function()
            expect(function()
                local Test1 = XSignal.new()
                local Test2 = XSignal.new()
                local Test3 = XSignal.new()
                XSignal.AwaitAll({Test1, Test2, Test3}, 0.1)
            end).never.to.throw()

            expect(function()
                XSignal.AwaitAll({workspace.ChildAdded}, 0.1)
            end).never.to.throw()
        end)

        it("should immediately return nil if the signal list is empty", function()
            expect(XSignal.AwaitAll({})).to.equal(nil)
        end)

        it("should return tables of arguments on variadic non-signals if args > 1", function()
            local Signal1 = Instance.new("BindableEvent")
            local Signal2 = Instance.new("BindableEvent")

            task.defer(function()
                Signal1:Fire(1, 2, 3)
                Signal2:Fire(4)
            end)

            local Values = XSignal.AwaitAll({Signal1.Event, Signal2.Event}, 0.1)
            expect(Values).to.be.a("table")
            expect(#Values).to.equal(2)
            expect(Values[1]).to.be.a("table")
            expect(Values[1][1]).to.equal(1)
            expect(Values[1][2]).to.equal(2)
            expect(Values[1][3]).to.equal(3)
            expect(Values[2]).to.be.a("number")
            expect(Values[2]).to.equal(4)
        end)

        it("should accept & return all values of XSignals", function()
            local Signal1 = XSignal.new()
            local Signal2 = XSignal.new()

            task.defer(function()
                Signal1:Fire(1)
                Signal2:Fire(2)
                Signal1:Fire(3)
                Signal2:Fire(4)
            end)

            local Values = XSignal.AwaitAll({Signal1, Signal2}, 0.1)
            expect(Values).to.be.a("table")
            expect(#Values).to.equal(2)
            expect(Values[1]).to.equal(1)
            expect(Values[2]).to.equal(2)
        end)
    end)
end