local { get_time_msec } = require("dagor.time")
local { log } = require("log.nut")()

local timers = []

local start = @() timers.append(get_time_msec())

local show = @(msg = "show", printFunc = log) timers.len() > 0
  ? printFunc($"dbg_timer: {msg}: {get_time_msec() - timers.top()}")
  : printFunc($"dbg_timer: not found timer for {msg}")

local function stop(msg = "stop", printFunc = log) {
  show(msg, printFunc)
  if (timers.len())
    timers.pop()
}

local timerFunc = @(func, msg = "func time", printFunc = log) function(...) {
  start()
  local res = func.acall([this].extend(vargv))
  stop(msg, printFunc)
  return res
}

return {
  timerStart = start
  timerShow = show
  timerStop = stop
  timerFunc = timerFunc
}