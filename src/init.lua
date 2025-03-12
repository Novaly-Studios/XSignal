local PureXSignal = require(script.PureXSignal)
export type PureXSignal<T> = PureXSignal.XSignal<T>

local XSignal = require(script.XSignal)
export type XSignal<T...> = XSignal.XSignal<T...>

return table.freeze({
    PureXSignal = PureXSignal;
    XSignal = XSignal;
})