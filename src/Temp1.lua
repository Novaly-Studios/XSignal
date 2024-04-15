local WaitUntilFullParams = TypeGuard.Params(TypeGuard.Function(), TypeGuard.Number():Optional(), TypeGuard.Boolean():Optional())
--- Yields the current coroutine until the XSignal is fired and the predicate returns true, returning all data passed when the XSignal was fired.
function XSignal:WaitUntilFull(Predicate, Timeout, ThrowErrorOnTimeout)
    WaitUntilFullParams(Predicate, Timeout, ThrowErrorOnTimeout)
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

        if (Predicate(...)) then
            task.spawn(ActiveCoroutine)
        end
    end)

    if (Result ~= nil and Predicate(unpack(Result))) then
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

--- Yields the current coroutine until the XSignal is fired and the predicate returns true, returning the first argument passed when the XSignal was fired.
function XSignal:WaitUntil(Predicate, Timeout, ThrowErrorOnTimeout)
    WaitUntilFullParams(Predicate, Timeout, ThrowErrorOnTimeout)
    return self:WaitUntilFull(Predicate, Timeout, ThrowErrorOnTimeout)[1]
end