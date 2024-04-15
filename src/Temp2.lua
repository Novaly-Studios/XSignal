describe("XSignal.WaitUntilFull", function()
    it("should accept a predicate function as a first argument & reject non-functions", function()
        local Test = XSignal.new()

        expect(function()
            Test:WaitUntilFull()
        end).to.throw()

        expect(function()
            Test:WaitUntilFull(1)
        end).to.throw()

        expect(function()
            Test:WaitUntilFull(function() end, 0.1)
        end).never.to.throw()
    end)

    it("should accept a timeout number as second argument & reject non-numbers", function()
        local Test = XSignal.new()

        expect(function()
            Test:WaitUntilFull(function() end)
        end).to.throw()

        expect(function()
            Test:WaitUntilFull(function() end, "1")
        end).to.throw()

        expect(function()
            Test:WaitUntilFull(function() end, 0.1)
        end).never.to.throw()
    end)

    it("should accept a boolean as third argument & reject non-booleans", function()
        local Test = XSignal.new()

        expect(function()
            Test:WaitUntilFull(function() end, 0.1)
        end).to.throw()

        expect(function()
            Test:WaitUntilFull(function() end, 0.1, "1")
        end).to.throw()

        expect(function()
            Test:WaitUntilFull(function() end, 0.1, true)
        end).never.to.throw()
    end)
end)