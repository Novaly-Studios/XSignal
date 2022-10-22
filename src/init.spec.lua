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
                XSignal.new(nil, function(X, Y)
                    assert(typeof(X) == "number" and (Y == nil or typeof(Y) == "string"), "Type mismatch")
                end)
            end).never.to.throw()
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

    describe("XSignal.Connect(ImmediateFire)", function()
        it("should immediately fire for new connections using callback (in order)", function()
            local Test = XSignal.new(function(Callback)
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
            local Test = XSignal.new(nil, function(X, Y)
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

        it("should return immediately with ImmediateFire", function()
            local TestObject = {}
            local Test = XSignal.new(function(Callback)
                Callback(3210, TestObject)
            end)

            local Primitive, Object = Test:Wait(0.1, true)
            expect(Primitive).to.equal(3210)
            expect(Object).to.equal(TestObject)
        end)
    end)

    describe("XSignal.WaitNoTimeout", function()
        it("should yield until the XSignal is fired", function()
            local Test = XSignal.new()

            task.delay(0.1, function()
                Test:Fire()
            end)

            Test:WaitNoTimeout()
        end)

        it("should return the data passed to the XSignal", function()
            local Test = XSignal.new()
            local TestObject = {}

            task.defer(function()
                Test:Fire(1, TestObject)
            end)

            local Primitive, Object = Test:WaitNoTimeout()
            expect(Primitive).to.equal(1)
            expect(Object).to.equal(TestObject)
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
    end)

    describe("XSignal.Extend", function()
        it("should throw when no XSignals to extend are passed", function()
            expect(function()
                XSignal.Extend()
            end).to.throw()

            expect(function()
                XSignal.Extend({})
            end).to.throw()
        end)

        it("should create a new XSignal which replicates firing from a single XSignal", function()
            local TestObject = {}
            local SubSignal = XSignal.new()
            local Test = XSignal.Extend({SubSignal})

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

            local Test = XSignal.Extend({SubSignal1, SubSignal2})

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

    describe("XSignal.AwaitAll", function()
        it("should throw for incorrect args", function()
            expect(function()
                XSignal.AwaitAll()
            end).to.throw()

            expect(function()
                XSignal.AwaitAll({})
            end).to.throw()

            expect(function()
                XSignal.AwaitAll({XSignal.new()}, "")
            end).to.throw()

            expect(function()
                XSignal.AwaitAll({XSignal.new()}, 0.1, "")
            end).to.throw()
        end)

        it("should timeout and pass a blank array if no error is desired", function()
            expect(next(XSignal.AwaitAll({XSignal.new()}, 0.1))).to.equal(nil)
        end)

        it("should timeout and throw if an error is desired", function()
            expect(function()
                XSignal.AwaitAll({XSignal.new()}, 0.1, true)
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

            XSignal.AwaitAll({Signal1, Signal2})
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

            local Results = XSignal.AwaitAll({Signal1, Signal2})
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

    describe("XSignal.AwaitAllFirstArg", function()
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

            local Results = XSignal.AwaitAllFirstArg({Signal1, Signal2})
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
end