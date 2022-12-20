//checked for explicitness
#no-root-fallback
#explicit-this

let { DBGLEVEL } = require("dagor.system")
let { register_command } = require("console")
let { console_print, dlog } = require("%globalScripts/logs.nut")
let { get_time_msec } = require("dagor.time")

// warning disable: -file:forbidden-function

//for easy debug function timers
//start(profile = false) - at function start
//                           if profile it will start profiler too (finished with the same level pop)
//                           but it will decrease performance
//show(msg)              - in function middle to show top timer diff in console (ms)
//stop(msg)              - at function end. to show top timer diff in console and remove it

local printText = DBGLEVEL > 0 ? dlog : console_print

let sqProfiler = require_optional("dagor.profiler")
local profileIdx = -1
let timers = []

let function show(msg = "show") {
  if (timers.len())
    printText($"dbg_timer: {msg}: {get_time_msec() - timers.top()}")
  else
    printText($"dbg_timer: not found timer for {msg}")
}

let function start(profile = false) {
  if (profile && profileIdx < 0) {
    profileIdx = timers.len() + 1
    if (sqProfiler)
      sqProfiler.start();
  }
  timers.append(get_time_msec())
}

let function stop(profilerFileName = null) {
  if (profileIdx >= timers.len()) {
    if (sqProfiler) {
      if (profilerFileName == null)
        sqProfiler.stop()
      else
        sqProfiler.stop_and_save_to_file(profilerFileName)
      profileIdx = -1
    }
  }
  show("stop")
  if (timers.len())
    timers.pop()
}

let stopToFile = @() stop("profile.csv")

let function toggleProfile() {
  if (profileIdx < 0) {
    printText("scriptProfiler START")
    start(true)
    return
  }

  stopToFile()
  printText("scriptProfiler STOP")
}

let function registerConsoleCommand(prefix) {
  register_command(@() start(), $"debug.{prefix}_timer.start")
  register_command(@() start(true), $"debug.{prefix}_timer.start_profile")
  register_command(@() stop(), $"debug.{prefix}_timer.stop")
  register_command(stopToFile, $"debug.{prefix}_timer.stopToFile")
  register_command(toggleProfile, $"debug.{prefix}_timer.toggle_profile")
}

return {
  start
  stop
  stopToFile
  show
  toggleProfile
  registerConsoleCommand
}
