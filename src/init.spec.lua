return function()
    local Signal = require(script.Parent)

    describe("Signal.new", function()
        it("should construct", function()
            expect(function()
                Signal.new()
            end).never.to.throw()
        end)

        it("should reject non-function types as first arg", function()
            expect(function()
                Signal.new(1)
            end).to.throw()
        end)

        it("should accept a function as first arg", function()
            expect(function()
                Signal.new(function() end)
            end).never.to.throw()
        end)
    end)

    describe("Signal.Connect", function()
        it("should throw when not given a function", function()
            expect(function()
                Signal.new():Connect(1)
            end).to.throw()
        end)

        it("should accept a callback", function()
            expect(function()
                Signal.new():Connect(function() end)
            end).never.to.throw()
        end)

        it("should accept multiple callbacks", function()
            expect(function()
                local Test = Signal.new()
                Test:Connect(function() end)
                Test:Connect(function() end)
                Test:Connect(function() end)
            end).never.to.throw()
        end)

        it("should allow disconnection", function()
            local Test = Signal.new()

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

    describe("Signal.Connect(ImmediateFire)", function()
        it("should immediately fire for new connections using callback (in order)", function()
            local Test = Signal.new(function(Callback)
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

    describe("Signal.Fire", function()
        it("should execute a connection", function()
            local Test = Signal.new()
            local FiredCount = 0

            Test:Connect(function()
                FiredCount += 1
            end)

            expect(FiredCount).to.equal(0)
            Test:Fire()
            expect(FiredCount).to.equal(1)
        end)

        it("should execute multiple connections", function()
            local Test = Signal.new()
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
            local Test = Signal.new()
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
            local Test = Signal.new()

            Test:Connect(function(X, Y, Z)
                expect(X).to.equal(1)
                expect(Y).to.equal("s")
                expect(Z).to.equal(true)
            end)

            Test:Fire(1, "s", true)
        end)

        it("should pass objects", function()
            local Test = Signal.new()
            local Pass1 = {}
            local Pass2 = {}

            Test:Connect(function(X, Y)
                expect(X).to.equal(Pass1)
                expect(Y).to.equal(Pass2)
            end)

            Test:Fire(Pass1, Pass2)
        end)

        it("should not execute disconnected connections", function()
            local Test = Signal.new()
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
    end)

    describe("Signal.Wait", function()
        it("should yield until the signal is fired", function()
            local Test = Signal.new()

            task.delay(0.1, function()
                Test:Fire()
            end)

            Test:Wait()
        end)

        it("should timeout and pass nil if no error is desired", function()
            local Test = Signal.new()
            expect(Test:Wait(0.1)).to.equal(nil)
        end)

        it("should timeout and throw if an error is desired", function()
            local Test = Signal.new()

            expect(pcall(function()
                Test:Wait(0.1, true)
            end)).to.equal(false)
        end)

        it("should return the data passed to the Signal", function()
            local Test = Signal.new()
            local TestObject = {}

            task.defer(function()
                Test:Fire(1, TestObject)
            end)

            local Primitive, Object = Test:Wait()
            expect(Primitive).to.equal(1)
            expect(Object).to.equal(TestObject)
        end)
    end)

    describe("Signal.DisconnectAll", function()
        it("should wipe all connections", function()
            local Test = Signal.new()
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

    describe("Signal.Extend", function()
        it("should throw when no Signals to extend are passed", function()
            expect(function()
                Signal.Extend()
            end).to.throw()

            expect(function()
                Signal.Extend({})
            end).to.throw()
        end)

        it("should create a new Signal which replicates firing from a single Signal", function()
            local TestObject = {}
            local SubSignal = Signal.new()
            local Test = Signal.Extend({SubSignal})

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

        it("should create a new Signal which replicates firing from multiple Signals", function()
            local TestObject1 = {}
            local TestObject2 = {}

            local SubSignal1 = Signal.new()
            local SubSignal2 = Signal.new()

            local Test = Signal.Extend({SubSignal1, SubSignal2})

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

    describe("Signal.AwaitFirst", function()
        it("should throw for incorrect args", function()
            expect(function()
                Signal.AwaitFirst()
            end).to.throw()

            expect(function()
                Signal.AwaitFirst({})
            end).to.throw()

            expect(function()
                Signal.AwaitFirst({Signal.new()}, "")
            end).to.throw()

            expect(function()
                Signal.AwaitFirst({Signal.new()}, 0.1, "")
            end).to.throw()
        end)

        it("should timeout and pass nil if no error is desired", function()
            expect(Signal.AwaitFirst({Signal.new()}, 0.1)).to.equal(nil)
        end)

        it("should timeout and throw if an error is desired", function()
            expect(function()
                Signal.AwaitFirst({Signal.new()}, 0.1, true)
            end).to.throw()
        end)

        it("should resume a coroutine with the first Signal to fire", function()
            local Signal1 = Signal.new()
            local Signal2 = Signal.new()

            task.delay(0.1, function()
                Signal1:Fire()
            end)

            Signal.AwaitFirst({Signal1, Signal2})

            task.delay(0.1, function()
                Signal2:Fire()
            end)

            Signal.AwaitFirst({Signal1, Signal2})
        end)

        it("should return the standard 'Wait' data passed from the wrapped Signal", function()
            local TestObject = {}
            local Signal1 = Signal.new()
            local Signal2 = Signal.new()

            task.delay(0.1, function()
                Signal1:Fire(1, TestObject)
            end)

            local X, Y = Signal.AwaitFirst({Signal1, Signal2})
            expect(X).to.equal(1)
            expect(Y).to.equal(TestObject)
        end)
    end)

    describe("Signal.AwaitAll", function()
        it("should throw for incorrect args", function()
            expect(function()
                Signal.AwaitAll()
            end).to.throw()

            expect(function()
                Signal.AwaitAll({})
            end).to.throw()

            expect(function()
                Signal.AwaitAll({Signal.new()}, "")
            end).to.throw()

            expect(function()
                Signal.AwaitAll({Signal.new()}, 0.1, "")
            end).to.throw()
        end)

        it("should timeout and pass a blank array if no error is desired", function()
            expect(next(Signal.AwaitAll({Signal.new()}, 0.1))).to.equal(nil)
        end)

        it("should timeout and throw if an error is desired", function()
            expect(function()
                Signal.AwaitAll({Signal.new()}, 0.1, true)
            end).to.throw()
        end)

        it("should await all Signals, not just one", function()
            local Signal1 = Signal.new()
            local Signal2 = Signal.new()
            local Running = coroutine.running()

            task.delay(0.1, function()
                Signal1:Fire()
                expect(coroutine.status(Running)).to.equal("suspended")

                task.wait(0.1)
                Signal2:Fire()
            end)

            Signal.AwaitAll({Signal1, Signal2})
        end)

        it("should return the standard 'Wait' data passed from the wrapped Signals, in a two-dimensional array format, in the order they were passed into the function", function()
            local TestObject = {}
            local Signal1 = Signal.new()
            local Signal2 = Signal.new()
            local Running = coroutine.running()

            task.delay(0.1, function()
                Signal1:Fire(1, TestObject)
                expect(coroutine.status(Running)).to.equal("suspended")

                task.wait(0.1)
                Signal2:Fire(2, TestObject)
            end)

            local Results = Signal.AwaitAll({Signal1, Signal2})
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

    describe("Signal.AwaitAllFirstArg", function()
        it("should return the standard 'Wait' data passed from the wrapped Signals, in a one-dimensional array format, in the order they were passed into the function", function()
            local TestObject = {}
            local Signal1 = Signal.new()
            local Signal2 = Signal.new()
            local Running = coroutine.running()

            task.delay(0.1, function()
                Signal1:Fire(1, TestObject)
                expect(coroutine.status(Running)).to.equal("suspended")

                task.wait(0.1)
                Signal2:Fire(2, TestObject)
            end)

            local Results = Signal.AwaitAllFirstArg({Signal1, Signal2})
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