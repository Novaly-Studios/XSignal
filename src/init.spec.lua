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
        it("should throw when no XSignals to extend are passed", function()
            expect(function()
                XSignal.fromExtension()
            end).to.throw()

            expect(function()
                XSignal.fromExtension({})
            end).to.throw()
        end)

        it("should create a new XSignal which replicates firing from a single XSignal", function()
            local TestObject = {}
            local SubSignal = XSignal.new()
            local Test = XSignal.fromExtension({SubSignal})

            local Data

            Test:Connect(function(...)
                Data = {...}
            end)

            SubSignal:Fire(1, TestObject)

            expect(Data).to.be.ok()
            expect(Data).to.be.a("table")
            expect(Data[1]).to.equal(1)
            expect(Data[2]).to.equal(TestObject)
        end)

        it("should create a new XSignal which replicates firing from multiple XSignals", function()
            local TestObject1 = {}
            local TestObject2 = {}

            local SubSignal1 = XSignal.new()
            local SubSignal2 = XSignal.new()

            local Test = XSignal.fromExtension({SubSignal1, SubSignal2})

            local Data

            Test:Connect(function(...)
                Data = {...}
            end)

            SubSignal1:Fire(1, TestObject1)
            expect(Data).to.be.ok()
            expect(Data).to.be.a("table")
            expect(Data[1]).to.equal(1)
            expect(Data[2]).to.equal(TestObject1)

            SubSignal1:Fire(2, TestObject2)
            expect(Data).to.be.ok()
            expect(Data).to.be.a("table")
            expect(Data[1]).to.equal(2)
            expect(Data[2]).to.equal(TestObject2)
        end)
    end)

    describe("XSignal.Connect", function()
        it("should throw when not given a function", function()
            expect(function()
                XSignal.new():Connect(1)
            end).to.throw()
        end)

        it("should accept a callback", function()
            expect(function()
                XSignal.new():Connect(function() end)
            end).never.to.throw()
        end)

        it("should accept multiple callbacks", function()
            expect(function()
                local Test = XSignal.new()
                Test:Connect(function() end)
                Test:Connect(function() end)
                Test:Connect(function() end)
            end).never.to.throw()
        end)

        it("should allow disconnection", function()
            local Test = XSignal.new()

            local X = Test:Connect(function() end)
            local Y = Test:Connect(function() end)
            local Z = Test:Connect(function() end)

            expect(X.Disconnect).to.be.a("function")
            expect(Y.Disconnect).to.be.a("function")
            expect(Z.Disconnect).to.be.a("function")

            expect(function()
                X:Disconnect()
                Y:Disconnect()
                Z:Disconnect()
            end).never.to.throw()
        end)
    end)

    -- TODO: check Validator works for Immediates
    describe("XSignal.Connect + Immediate", function()
        it("should immediately fire for new connections using callback (in order)", function()
            local Test = XSignal.new(nil, function(Callback)
                Callback(1, 2)
                Callback(3, 4)
                Callback(5, 6)
            end)

            local Results = {}

            Test:Connect(function(Num1, Num2)
                table.insert(Results, Num1)
                table.insert(Results, Num2)
            end)

            expect(table.concat(Results)).to.equal("123456")
        end)

        it("should not fire disconnected connections for immediates with delays", function()
            local Test = XSignal.new(nil, function(Callback)
                Callback(1, 2)
                task.wait(0.1)
                Callback(3, 4)
            end)

            local Results = {}

            local X = Test:Connect(function(Num1, Num2)
                table.insert(Results, Num1)
                table.insert(Results, Num2)
            end)

            X:Disconnect()

            expect(table.concat(Results)).to.equal("12")
            task.wait(0.1)
            expect(table.concat(Results)).to.equal("12")
        end)

        it("should apply a validator to immediates", function()
            local Test = XSignal.new(function(X, Y)
                assert(typeof(X) == "number" and typeof(Y) == "number", "Type mismatch")
            end, function(Callback)
                Callback(1, "H")
            end)

            local Results = {}

            Test:Connect(function(Num1, Num2)
                table.insert(Results, Num1)
                table.insert(Results, Num2)
            end)

            expect(table.concat(Results)).to.equal("")
        end)
    end)

    describe("XSignal.Once", function()
        it("should reject incorrect type args", function()
            expect(function()
                XSignal.new():Once(1)
            end).to.throw()
        end)

        it("should accept correct arg type", function()
            expect(function()
                XSignal.new():Once(function() end)
            end).never.to.throw()
        end)

        it("should only fire once & return the passed values", function()
            local Test = XSignal.new()

            local Count = 0
            local GotX, GotY

            Test:Once(function(X, Y)
                Count += 1
                GotX = X
                GotY = Y
            end)

            expect(Count).to.equal(0)
            expect(GotX).to.equal(nil)
            expect(GotY).to.equal(nil)
            Test:Fire(10, 20)
            expect(Count).to.equal(1)
            expect(GotX).to.equal(10)
            expect(GotY).to.equal(20)
            Test:Fire(30, 40)
            expect(Count).to.equal(1)
            expect(GotX).to.equal(10)
            expect(GotY).to.equal(20)
        end)

        it("should return a connection & allow disconnection", function()
            local Test = XSignal.new()

            local Count = 0

            local Connection = Test:Once(function()
                Count += 1
            end)
            expect(Connection).to.be.ok()
            Connection:Disconnect()
            expect(Count).to.equal(0)
            Test:Fire()
            expect(Count).to.equal(0)
        end)
    end)

    describe("XSignal.Once + Immediate", function()
        it("should immediately fire, only once", function()
            local Test = XSignal.fromImmediate(function(Callback)
                Callback(1, 2)
                Callback(3, 4)
                Callback(5, 6)
            end)

            local Results = {}

            Test:Once(function(Num1, Num2)
                table.insert(Results, Num1)
                table.insert(Results, Num2)
            end)

            expect(#Results).to.equal(2)
            expect(Results[1]).to.be.a("number")
            expect(Results[1]).to.equal(1)
            expect(Results[2]).to.be.a("number")
            expect(Results[2]).to.equal(2)
        end)

        it("should fire with delays, only once", function()
            local Test = XSignal.fromImmediate(function(Callback)
                task.wait(0.1)
                Callback(1, 2)
                task.wait(0.1)
                Callback(3, 4)
                task.wait(0.1)
                Callback(5, 6)
            end)

            local Results = {}

            Test:Once(function(Num1, Num2)
                table.insert(Results, Num1)
                table.insert(Results, Num2)
            end)

            expect(#Results).to.equal(0)

            task.wait(0.1)

            expect(#Results).to.equal(2)
            expect(Results[1]).to.be.a("number")
            expect(Results[1]).to.equal(1)
            expect(Results[2]).to.be.a("number")
            expect(Results[2]).to.equal(2)

            task.wait(0.1)

            expect(#Results).to.equal(2)
        end)
    end)

    describe("XSignal.Fire", function()
        it("should execute a connection", function()
            local Test = XSignal.new()
            local FiredCount = 0

            Test:Connect(function()
                FiredCount += 1
            end)

            expect(FiredCount).to.equal(0)
            Test:Fire()
            expect(FiredCount).to.equal(1)
        end)

        it("should execute multiple connections", function()
            local Test = XSignal.new()
            local FiredCount = 0

            Test:Connect(function()
                FiredCount += 1
            end)

            Test:Connect(function()
                FiredCount += 1
            end)

            Test:Connect(function()
                FiredCount += 1
            end)

            expect(FiredCount).to.equal(0)
            Test:Fire()
            expect(FiredCount).to.equal(3)
        end)

        it("should execute multiple connections async", function()
            local Test = XSignal.new()
            local FiredCount = 0

            Test:Connect(function()
                task.wait(0.1)
                FiredCount += 1
            end)

            Test:Connect(function()
                task.wait(0.1)
                FiredCount += 1
            end)

            expect(FiredCount).to.equal(0)
            Test:Fire()
            expect(FiredCount).to.equal(0)
            task.wait(0.1)
            expect(FiredCount).to.equal(2)
        end)

        it("should pass primitive data types", function()
            local Test = XSignal.new()

            Test:Connect(function(X, Y, Z)
                expect(X).to.equal(1)
                expect(Y).to.equal("s")
                expect(Z).to.equal(true)
            end)

            Test:Fire(1, "s", true)
        end)

        it("should pass objects", function()
            local Test = XSignal.new()
            local Pass1 = {}
            local Pass2 = {}

            Test:Connect(function(X, Y)
                expect(X).to.equal(Pass1)
                expect(Y).to.equal(Pass2)
            end)

            Test:Fire(Pass1, Pass2)
        end)

        it("should not execute disconnected connections", function()
            local Test = XSignal.new()
            local RunCount = 0

            Test:Connect(function()
                RunCount += 1
            end)

            Test:Connect(function()
                RunCount += 1
            end)

            Test:Connect(function()
                RunCount += 1
            end):Disconnect()

            Test:Fire()
            expect(RunCount).to.equal(2)
        end)

        it("should execute the validator before firing & pass all params", function()
            local Test = XSignal.new(function(X, Y)
                assert(typeof(X) == "number" and (Y == nil or typeof(Y) == "string"), "Type mismatch")
            end)
            
            expect(function()
                Test:Fire(1, "") -- Accept
            end).never.to.throw()

            expect(function()
                Test:Fire(2) -- Accept
            end).never.to.throw()

            expect(function()
                Test:Fire() -- Reject
            end).to.throw()

            expect(function()
                Test:Fire("") -- Reject
            end).to.throw()
        end)
    end)

    describe("XSignal.Wait", function()
        it("should yield until the XSignal is fired", function()
            local Test = XSignal.new()

            task.delay(0.1, function()
                Test:Fire()
            end)

            Test:Wait()
        end)

        it("should timeout and pass nil if no error is desired", function()
            local Test = XSignal.new()
            expect(Test:Wait(0.1)).to.equal(nil)
        end)

        it("should timeout and throw if an error is desired", function()
            local Test = XSignal.new()

            expect(pcall(function()
                Test:Wait(0.1, true)
            end)).to.equal(false)
        end)

        it("should return the data passed to the XSignal", function()
            local Test = XSignal.new()
            local TestObject = {}

            task.defer(function()
                Test:Fire(1, TestObject)
            end)

            local Primitive, Object = Test:Wait()
            expect(Primitive).to.equal(1)
            expect(Object).to.equal(TestObject)
        end)

        it("should return immediately with Immediate", function()
            local TestObject = {}
            local Test = XSignal.new(nil, function(Callback)
                Callback(3210, TestObject)
            end)

            local Primitive, Object = Test:Wait(0.1, true)
            expect(Primitive).to.equal(3210)
            expect(Object).to.equal(TestObject)
        end)
    end)

    describe("XSignal.Wait + Immediate", function()
        it("should return immediately with Immediate", function()
            local TestObject = {}
            local Test = XSignal.fromImmediate(function(Callback)
                Callback(8, TestObject)
            end)

            local Primitive, Object = Test:Wait(0.1, true)
            expect(Primitive).to.equal(8)
            expect(Object).to.equal(TestObject)
        end)

        it("should timeout if the Immediate takes too long", function()
            local TestObject = {}
            local Test = XSignal.fromImmediate(function(Callback)
                task.wait(0.1)
                Callback(8, TestObject)
            end)

            local Primitive, Object = Test:Wait(0.01)
            expect(Primitive).to.equal(nil)
            expect(Object).to.equal(nil)
        end)
    end)

    describe("XSignal.WaitIndefinite", function()
        it("should yield until the XSignal is fired", function()
            local Test = XSignal.new()

            task.delay(0.1, function()
                Test:Fire()
            end)

            Test:WaitIndefinite()
        end)

        it("should return the data passed to the XSignal", function()
            local Test = XSignal.new()
            local TestObject = {}

            task.defer(function()
                Test:Fire(1, TestObject)
            end)

            local Primitive, Object = Test:WaitIndefinite()
            expect(Primitive).to.equal(1)
            expect(Object).to.equal(TestObject)
        end)
    end)

    describe("XSignal.CollectFull", function()
        it("should reject non-numbers as the Count param", function()
            local Test = XSignal.new()

            expect(function()
                Test:CollectFull("1")
            end).to.throw()

            expect(function()
                Test:CollectFull({})
            end).to.throw()

            expect(function()
                task.defer(function() Test:Fire() end)
                Test:CollectFull(1)
            end).never.to.throw()
        end)

        it("should return a table with a single item for Count = 1", function()
            local Test = XSignal.new()

            task.defer(function()
                Test:Fire(1)
            end)

            local Data = Test:CollectFull(1)
            expect(Data).to.be.a("table")
            expect(#Data).to.equal(1)
            expect(Data[1]).to.be.a("table")
            expect(Data[1][1]).to.be.a("number")
            expect(Data[1][1]).to.equal(1)
            expect(Data[2]).to.equal(nil)
        end)

        it("should return a table with three items for Count = 3", function()
            local Test = XSignal.new()

            task.defer(function()
                Test:Fire(1)
                Test:Fire(2)
                Test:Fire(3)
            end)

            local Data = Test:CollectFull(3)
            expect(Data).to.be.a("table")
            expect(#Data).to.equal(3)
            expect(Data[1]).to.be.a("table")
            expect(Data[1][1]).to.be.a("number")
            expect(Data[1][1]).to.equal(1)
            expect(Data[2]).to.be.a("table")
            expect(Data[2][1]).to.be.a("number")
            expect(Data[2][1]).to.equal(2)
            expect(Data[3]).to.be.a("table")
            expect(Data[3][1]).to.be.a("number")
            expect(Data[3][1]).to.equal(3)
            expect(Data[4]).to.equal(nil)
        end)

        it("should timeout and pass nil if no error is desired", function()
            local Test = XSignal.new()
            local Results = Test:CollectFull(3, 0.1)
            expect(Results).to.be.a("table")
            expect(#Results).to.equal(0)
        end)
    end)

    describe("XSignal.Collect", function()
        it("should reject non-numbers as the Count param", function()
            local Test = XSignal.new()

            expect(function()
                Test:Collect("1")
            end).to.throw()

            expect(function()
                Test:Collect({})
            end).to.throw()

            expect(function()
                task.defer(function() Test:Fire() end)
                Test:Collect(1)
            end).never.to.throw()
        end)

        it("should return a table with a single item for Count = 1", function()
            local Test = XSignal.new()

            task.defer(function()
                Test:Fire(1)
            end)

            local Data = Test:Collect(1)
            expect(Data).to.be.a("table")
            expect(#Data).to.equal(1)
            expect(Data[1]).to.be.a("number")
            expect(Data[1]).to.equal(1)
            expect(Data[2]).to.equal(nil)
        end)

        it("should return a table with three items for Count = 3", function()
            local Test = XSignal.new()

            task.defer(function()
                Test:Fire(1)
                Test:Fire(2)
                Test:Fire(3)
            end)

            local Data = Test:Collect(3)
            expect(Data).to.be.a("table")
            expect(#Data).to.equal(3)
            expect(Data[1]).to.be.a("number")
            expect(Data[1]).to.equal(1)
            expect(Data[2]).to.be.a("number")
            expect(Data[2]).to.equal(2)
            expect(Data[3]).to.be.a("number")
            expect(Data[3]).to.equal(3)
            expect(Data[4]).to.equal(nil)
        end)

        it("should timeout and pass nil if no error is desired", function()
            local Test = XSignal.new()
            local Results = Test:Collect(3, 0.1)
            expect(Results).to.be.a("table")
            expect(#Results).to.equal(0)
        end)
    end)

    describe("XSignal.CollectFull + Immediate", function()
        it("should immediately return a table with a single item for Count = 1", function()
            local Test = XSignal.fromImmediate(function(Callback)
                Callback(1)
            end)

            local Data = Test:CollectFull(1)
            expect(Data).to.be.a("table")
            expect(#Data).to.equal(1)
            expect(Data[1]).to.be.a("table")
            expect(Data[1][1]).to.be.a("number")
            expect(Data[1][1]).to.equal(1)
            expect(Data[2]).to.equal(nil)
        end)

        it("should immediately return a table with three items for Count = 3", function()
            local Test = XSignal.fromImmediate(function(Callback)
                Callback(1)
                Callback(2)
                Callback(3)
            end)

            local Data = Test:CollectFull(3)
            expect(Data).to.be.a("table")
            expect(#Data).to.equal(3)
            expect(Data[1]).to.be.a("table")
            expect(Data[1][1]).to.be.a("number")
            expect(Data[1][1]).to.equal(1)
            expect(Data[2]).to.be.a("table")
            expect(Data[2][1]).to.be.a("number")
            expect(Data[2][1]).to.equal(2)
            expect(Data[3]).to.be.a("table")
            expect(Data[3][1]).to.be.a("number")
            expect(Data[3][1]).to.equal(3)
            expect(Data[4]).to.equal(nil)
        end)

        it("should handle delays between items", function()
            local Test = XSignal.fromImmediate(function(Callback)
                Callback(1)
                task.wait(0.1)
                Callback(2)
                task.wait(0.1)
                Callback(3)
            end)

            local Data

            task.spawn(function()
                Data = Test:CollectFull(3)
            end)

            expect(Data).to.equal(nil)
            task.wait(0.3)

            expect(Data).to.be.a("table")
            expect(#Data).to.equal(3)
            expect(Data[1]).to.be.a("table")
            expect(Data[1][1]).to.be.a("number")
            expect(Data[1][1]).to.equal(1)
            expect(Data[2]).to.be.a("table")
            expect(Data[2][1]).to.be.a("number")
            expect(Data[2][1]).to.equal(2)
            expect(Data[3]).to.be.a("table")
            expect(Data[3][1]).to.be.a("number")
            expect(Data[3][1]).to.equal(3)
            expect(Data[4]).to.equal(nil)
        end)

        it("should only fill up the table until timeout is reached", function()
            local Test = XSignal.fromImmediate(function(Callback)
                Callback(1)
                task.wait(0.1)
                Callback(2)
                task.wait(0.1)
                Callback(3)
            end)

            local Data = Test:CollectFull(3, 0.15)
            expect(Data).to.be.a("table")
            expect(#Data).to.equal(2)
            expect(Data[1]).to.be.a("table")
            expect(Data[1][1]).to.be.a("number")
            expect(Data[1][1]).to.equal(1)
            expect(Data[2]).to.be.a("table")
            expect(Data[2][1]).to.be.a("number")
            expect(Data[2][1]).to.equal(2)
            expect(Data[3]).to.equal(nil)
        end)
    end)

    describe("XSignal.DisconnectAll", function()
        it("should wipe all connections", function()
            local Test = XSignal.new()
            local RunCount = 0

            Test:Connect(function()
                RunCount += 1
            end)

            Test:Connect(function()
                RunCount += 1
            end)

            Test:Connect(function()
                RunCount += 1
            end)

            expect(RunCount).to.equal(0)
            Test:DisconnectAll()
            Test:Fire()
            expect(RunCount).to.equal(0)
        end)

        it("should not error on multiple disconnections", function()
            local Test = XSignal.new()
            local X = Test:Connect(function() end)
            Test:DisconnectAll()

            expect(function()
                X:Disconnect()
            end).never.to.throw()
        end)

        it("should not reconnect the whole chain when Reconnect is called, and should set Connected = false", function()
            local Test = XSignal.new()
            local Count = 0

            local X = Test:Connect(function()
                Count += 1
            end)

            local Y = Test:Connect(function()
                Count += 1
            end)

            local Z = Test:Connect(function()
                Count += 1
            end)

            expect(Count).to.equal(0)
            Test:Fire()
            expect(Count).to.equal(3)
            Test:DisconnectAll()
            Test:Fire()
            expect(Count).to.equal(3)

            Count = 0
            X:Reconnect()
            Test:Fire()
            expect(Count).to.equal(1)

            Count = 0
            Z:Reconnect()
            Test:Fire()
            expect(Count).to.equal(2)

            Count = 0
            Y:Reconnect()
            Test:Fire()
            expect(Count).to.equal(3)
        end)
    end)

    describe("XSignal.AwaitFirst", function()
        it("should throw for incorrect args", function()
            expect(function()
                XSignal.AwaitFirst()
            end).to.throw()

            expect(function()
                XSignal.AwaitFirst({})
            end).to.throw()

            expect(function()
                XSignal.AwaitFirst({XSignal.new()}, "")
            end).to.throw()

            expect(function()
                XSignal.AwaitFirst({XSignal.new()}, 0.1, "")
            end).to.throw()
        end)

        it("should timeout and pass nil if no error is desired", function()
            expect(XSignal.AwaitFirst({XSignal.new()}, 0.1)).to.equal(nil)
        end)

        it("should timeout and throw if an error is desired", function()
            expect(function()
                XSignal.AwaitFirst({XSignal.new()}, 0.1, true)
            end).to.throw()
        end)

        it("should resume a coroutine with the first XSignal to fire", function()
            local Signal1 = XSignal.new()
            local Signal2 = XSignal.new()

            task.delay(0.1, function()
                Signal1:Fire()
            end)

            XSignal.AwaitFirst({Signal1, Signal2})

            task.delay(0.1, function()
                Signal2:Fire()
            end)

            XSignal.AwaitFirst({Signal1, Signal2})
        end)

        it("should return the standard 'Wait' data passed from the wrapped XSignal", function()
            local TestObject = {}
            local Signal1 = XSignal.new()
            local Signal2 = XSignal.new()

            task.delay(0.1, function()
                Signal1:Fire(1, TestObject)
            end)

            local X, Y = XSignal.AwaitFirst({Signal1, Signal2})
            expect(X).to.equal(1)
            expect(Y).to.equal(TestObject)
        end)
    end)

    describe("XSignal.AwaitFirst + Immediate", function()
        it("should await the first of three Immediate XSignals", function()
            local Signal1 = XSignal.fromImmediate(function(Return)
                Return(1)
            end)
            local Signal2 = XSignal.fromImmediate(function(Return)
                Return(2)
            end)
            local Signal3 = XSignal.fromImmediate(function(Return)
                Return(3)
            end)

            expect(XSignal.AwaitFirst({Signal1, Signal2, Signal3})).to.equal(1)
        end)

        it("should await and only return the first value of the first Immediate XSignal", function()
            local Signal1 = XSignal.fromImmediate(function(Return)
                Return(1)
                Return(2)
            end)
            local Signal2 = XSignal.fromImmediate(function(Return)
                Return(3)
                Return(4)
            end)

            expect(XSignal.AwaitFirst({Signal1, Signal2})).to.equal(1)
        end)

        it("should await with a timeout and return nil", function()
            local Signal1 = XSignal.fromImmediate(function(Return)
                task.wait(0.1)
                Return(1)
            end)
            local Signal2 = XSignal.fromImmediate(function(Return)
                task.wait(0.1)
                Return(2)
            end)

            expect(XSignal.AwaitFirst({Signal1, Signal2}, 0.05)).to.equal(nil)
        end)

        it("should handle yielding Immediate functions", function()
            local Signal1 = XSignal.fromImmediate(function(Return)
                task.wait(0.2)
                Return(1)
            end)
            local Signal2 = XSignal.fromImmediate(function(Return)
                task.wait(0.1)
                Return(2)
            end)

            expect(XSignal.AwaitFirst({Signal1, Signal2})).to.equal(2)
        end)
    end)

    describe("XSignal.AwaitAllFull", function()
        it("should throw for incorrect args", function()
            expect(function()
                XSignal.AwaitAllFull()
            end).to.throw()

            expect(function()
                XSignal.AwaitAllFull({})
            end).to.throw()

            expect(function()
                XSignal.AwaitAllFull({XSignal.new()}, "")
            end).to.throw()

            expect(function()
                XSignal.AwaitAllFull({XSignal.new()}, 0.1, "")
            end).to.throw()
        end)

        it("should timeout and pass a blank array if no error is desired", function()
            expect(next(XSignal.AwaitAllFull({XSignal.new()}, 0.1))).to.equal(nil)
        end)

        it("should timeout and throw if an error is desired", function()
            expect(function()
                XSignal.AwaitAllFull({XSignal.new()}, 0.1, true)
            end).to.throw()
        end)

        it("should await all XSignals, not just one", function()
            local Signal1 = XSignal.new()
            local Signal2 = XSignal.new()
            local Running = coroutine.running()

            task.delay(0.1, function()
                Signal1:Fire()
                expect(coroutine.status(Running)).to.equal("suspended")

                task.wait(0.1)
                Signal2:Fire()
            end)

            XSignal.AwaitAllFull({Signal1, Signal2})
        end)

        it("should return the standard 'Wait' data passed from the wrapped XSignals, in a two-dimensional array format, in the order they were passed into the function", function()
            local TestObject = {}
            local Signal1 = XSignal.new()
            local Signal2 = XSignal.new()
            local Running = coroutine.running()

            task.delay(0.1, function()
                Signal1:Fire(1, TestObject)
                expect(coroutine.status(Running)).to.equal("suspended")

                task.wait(0.1)
                Signal2:Fire(2, TestObject)
            end)

            local Results = XSignal.AwaitAllFull({Signal1, Signal2})
            expect(Results).to.be.ok()
            expect(Results).to.be.a("table")
            expect(Results[1]).to.be.ok()
            expect(Results[1]).to.be.a("table")
            expect(Results[1][1]).to.equal(1)
            expect(Results[1][2]).to.equal(TestObject)
            expect(Results[2]).to.be.ok()
            expect(Results[2]).to.be.a("table")
            expect(Results[2][1]).to.equal(2)
            expect(Results[2][2]).to.equal(TestObject)
        end)
    end)

    describe("XSignal.AwaitAll", function()
        it("should return the standard 'Wait' data passed from the wrapped XSignals, in a one-dimensional array format, in the order they were passed into the function", function()
            local TestObject = {}
            local Signal1 = XSignal.new()
            local Signal2 = XSignal.new()
            local Running = coroutine.running()

            task.delay(0.1, function()
                Signal1:Fire(1, TestObject)
                expect(coroutine.status(Running)).to.equal("suspended")

                task.wait(0.1)
                Signal2:Fire(2, TestObject)
            end)

            local Results = XSignal.AwaitAll({Signal1, Signal2})
            expect(Results).to.be.ok()
            expect(Results).to.be.a("table")
            expect(Results[1]).to.be.ok()
            expect(Results[1]).to.be.a("number")
            expect(Results[1]).to.equal(1)
            expect(Results[2]).to.be.ok()
            expect(Results[2]).to.be.a("number")
            expect(Results[2]).to.equal(2)
        end)
    end)

    describe("XSignal.AwaitAll + Immediate", function()
        it("should return with no delay given an Immediate function", function()
            local Signal1 = XSignal.fromImmediate(function(Return)
                Return(1)
            end)
            local Signal2 = XSignal.fromImmediate(function(Return)
                Return(2)
            end)

            local Result

            task.spawn(function()
                Result = XSignal.AwaitAll({Signal1, Signal2})
            end)

            expect(Result).to.be.ok()
            expect(Result).to.be.a("table")
            expect(Result[1]).to.be.ok()
            expect(Result[1]).to.be.a("number")
            expect(Result[1]).to.equal(1)
            expect(Result[2]).to.be.ok()
            expect(Result[2]).to.be.a("number")
            expect(Result[2]).to.equal(2)
        end)

        it("should return only the first value for multiple Immediate returns", function()
            local Signal1 = XSignal.fromImmediate(function(Return)
                Return(1)
                Return(2)
            end)
            local Signal2 = XSignal.fromImmediate(function(Return)
                Return(3)
                Return(4)
            end)

            local Result

            task.spawn(function()
                Result = XSignal.AwaitAll({Signal1, Signal2})
            end)

            expect(Result).to.be.ok()
            expect(Result).to.be.a("table")
            expect(Result[1]).to.be.ok()
            expect(Result[1]).to.be.a("number")
            expect(Result[1]).to.equal(1)
            expect(Result[2]).to.be.ok()
            expect(Result[2]).to.be.a("number")
            expect(Result[2]).to.equal(3)
        end)
    end)
end