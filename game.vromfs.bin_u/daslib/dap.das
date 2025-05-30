options gen2
options rtti
options no_aot
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module dap shared

require daslib/json
require daslib/json_boost
require daslib/strings_boost



struct InitializeRequestArguments {}

def InitializeRequestArguments(data : JsonValue?) {
    return InitializeRequestArguments()
}



struct DisconnectArguments {
    restart : bool
    terminateDebuggee : bool
    suspendDebuggee : bool
}

def DisconnectArguments(data : JsonValue?) {
    return DisconnectArguments(restart = job(data, "restart"),
                                 terminateDebuggee = job(data, "terminateDebuggee"),
                                 suspendDebuggee = job(data, "suspendDebuggee")
            )
}



struct Capabilities {
    supportsConfigurationDoneRequest : bool
    supportsRestartRequest : bool
    supportTerminateDebuggee : bool
    supportsTerminateRequest : bool
    supportsExceptionOptions : bool
    supportsExceptionFilterOptions : bool
    supportsDelayedStackTraceLoading : bool
    supportsDataBreakpoints : bool
}




struct DataBreakpoint {
    dataId : string
    accessType : string
    condition : string
    hitCondition : string
    description : string
    enabled : bool
}

def DataBreakpoint(data : JsonValue?) {
    return DataBreakpoint(dataId = jos(data, "dataId"),
                            accessType = jos(data, "accessType"),
                            condition = jos(data, "condition"),
                            hitCondition = jos(data, "hitCondition"),
                            description = jos(data, "description"),
                            enabled = job(data, "enabled", true)
            )
}


struct SetDataBreakpointsArguments {
    breakpoints : array<DataBreakpoint>
}

def SetDataBreakpointsArguments(data : JsonValue?) {
    var res <- SetDataBreakpointsArguments()
    var breakpoints = joj(data, "breakpoints")
    if (breakpoints != null) {
        for (it in breakpoints.value as _array) {
            res.breakpoints |> emplace(DataBreakpoint(it))
        }
    }
    return <- res
}


struct DataBreakpointInfoArguments {
    variablesReference : double
    name : string
}

def DataBreakpointInfoArguments(data : JsonValue?) {
    return DataBreakpointInfoArguments(
                variablesReference = jon(data, "variablesReference"),
                name = jos(data, "name")
            )
}

struct DataBreakpointInfoResponse {
    dataId : string
    description : string
    
}



struct SourceBreakpoint {
    line : double
}

def SourceBreakpoint(data : JsonValue?) {
    return SourceBreakpoint(line = jon(data, "line"))
}


struct Source {
    name : string
    path : string
}

def Source(data : JsonValue?) {
    return Source(name = jos(data, "name"), path = jos(data, "path"))
}



struct SetBreakpointsArguments {
    source : Source
    breakpoints : array<SourceBreakpoint>
    sourceModified : bool
}

def SetBreakpointsArguments(data : JsonValue?) {
    var res <- SetBreakpointsArguments(source = Source(joj(data, "source")),
                                         sourceModified = job(data, "sourceModified"))
    var breakpoints = joj(data, "breakpoints")
    if (breakpoints != null) {
        for (it in breakpoints.value as _array) {
            res.breakpoints |> emplace(SourceBreakpoint(it))
        }
    }
    return <- res
}



struct Breakpoint {
    id : double
    verified : bool
    source : Source
    line : double
    message : string
}


struct SetBreakpointsResponse {
    breakpoints : array<Breakpoint>
}




struct Thread {
    id : double
    name : string
}



struct ThreadsResponseBody {
    threads : array<Thread>
}



struct StackTraceArguments {
    threadId : double
    startFrame : double
    levels : double
}

def StackTraceArguments(data : JsonValue?) {
    return <- StackTraceArguments(threadId = jon(data, "threadId"), startFrame = jon(data, "startFrame"), levels = jon(data, "levels"))
}

struct StackFrame {
    id : double
    name : string
    source : Source
    line : double
    column : double
}

struct StackTraceResponseBody {
    stackFrames : array<StackFrame>
    totalFrames : double
}



struct ScopesArguments {
    frameId : double
}

def ScopesArguments(data : JsonValue?) {
    return <- ScopesArguments(frameId = jon(data, "frameId"))
}



struct Scope {
    name : string
    variablesReference : double
}


struct ScopesResponseBody {
    scopes : array<Scope>
}



struct VariablesArguments {
    variablesReference : double
    start : double
    count : double
}

def VariablesArguments(data : JsonValue?) {
    return <- VariablesArguments(
        variablesReference = jon(data, "variablesReference"),
        start = jon(data, "start", -1lf),
        count = jon(data, "count", -1lf)
    )
}



struct Variable {
    name : string
    value : string
    variablesReference : double
    @rename _type : string
    indexedVariables : double
}

struct VariablesResponseBody {
    variables : array<Variable>
}


def JV(data : Variable) {
    let valStr = unescape(data.value)
    return JV({
        "name" => JV(data.name),
        "value" => JV(valStr),
        "variablesReference" => JV(data.variablesReference),
        "indexedVariables" => data.indexedVariables > 0lf ? JV(data.indexedVariables) : JVNull(),
        "type" => JV(data._type)
    })
}


struct OutputEventBody {
    category : string
    output : string
}



struct ContinueArguments {
    threadId : double
}

def ContinueArguments(data : JsonValue?) {
    return <- ContinueArguments(threadId = jon(data, "threadId"))
}



struct PauseArguments {
    threadId : double
}

def PauseArguments(data : JsonValue?) {
    return <- PauseArguments(threadId = jon(data, "threadId"))
}



struct StepInArguments {
    threadId : double
}

def StepInArguments(data : JsonValue?) {
    return <- StepInArguments(threadId = jon(data, "threadId"))
}



struct NextArguments {
    threadId : double
}

def NextArguments(data : JsonValue?) {
    return <- NextArguments(threadId = jon(data, "threadId"))
}



struct StepOutArguments {
    threadId : double
}

def StepOutArguments(data : JsonValue?) {
    return <- StepOutArguments(threadId = jon(data, "threadId"))
}



struct EvaluateArguments {
    expression : string
    frameId : double
    context : string
}

def EvaluateArguments(data : JsonValue?) {
    return <- EvaluateArguments(frameId = jon(data, "frameId"), expression = jos(data, "expression"), context = jos(data, "context"))
}


struct EvaluateResponse {
    result : string
    @rename _type : string
    variablesReference : double
    indexedVariables : double
}

def JV(data : EvaluateResponse) {
    return JV({
        "result" => JV(data.result),
        "variablesReference" => JV(data.variablesReference),
        "indexedVariables" => data.indexedVariables > 0lf ? JV(data.indexedVariables) : JVNull(),
        "type" => JV(data._type)
    })
}



struct BreakpointEvent {
    reason : string 
    breakpoint : Breakpoint
}


struct ThreadEvent {
    reason : string 
    threadId : double
}


def joj(val : JsonValue?; id : string) : JsonValue? {
    var res : JsonValue? = null
    if (val == null || !(val is _object)) {
        return res
    }
    get(val as _object, id) <| $(v) {
        res = unsafe(reinterpret<JsonValue?> v)
    }
    return res
}

def jon(val : JsonValue?; id : string; defVal = 0lf) : double {
    var res = defVal
    if (val == null || !(val is _object)) {
        return res
    }
    get(val.value as _object, id) <| $(v) {
        if (v.value is _number) {
            res = v.value as _number
        }
    }
    return res
}

def j_s(val : JsonValue?; defVal = "") : string {
    return val?.value ?as _string ?? defVal
}

def jos(val : JsonValue?; id : string; defVal = "") : string {
    var res = defVal
    if (val == null || !(val is _object)) {
        return res
    }
    get(val.value as _object, id) <| $(v) {
        if (v.value is _string) {
            res = v.value as _string
        }
    }
    return res
}

def job(val : JsonValue?; id : string; defVal = false) : bool {
    var res = defVal
    if (val == null || !(val is _object)) {
        return res
    }
    get(val.value as _object, id) <| $(v) {
        if (v.value is _bool) {
            res = v.value as _bool
        }
    }
    return res
}
