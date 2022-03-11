local { DBGLEVEL } = require("dagor.system")

// warning disable: -file:forbidden-function

// Profiler usage:
// console commands:
// "sq.script_profile_start"
// "sq.script_profile_stop"
// And see profile.txt for results.

//for easy debug function timers
//::dbg_timer.start(profile = false) - at function start
//                                     if profile it will start profiler too (finished with the same level pop)
//                                     but it will decrease performance
//::dbg_timer.show(msg)              - in function middle to show top timer diff in console (ms)
//::dbg_timer.stop(msg)              - at function end. to show top timer diff in console and remove it

local printText = DBGLEVEL > 0 ? ::dlog : ::dagor.console_print

::dbg_timer <- {
  timers = []
  profileIdx = -1

  sqProfiler = require_optional("dagor.profiler")

  function start(profile = false)
  {
    if (profile && profileIdx < 0)
    {
      profileIdx = timers.len() + 1
      if (sqProfiler)
        sqProfiler.start();
    }
    timers.append(::dagor.getCurTime())
  }

  function show(msg = "show")
  {
    if (timers.len())
      printText($"dbg_timer: {msg}: {::dagor.getCurTime() - timers.top()}")
    else
      printText($"dbg_timer: not found timer for {msg}")
  }

  function stop(msg = "stop", profilerFileName = null)
  {
    if (profileIdx >= timers.len())
    {
      if (sqProfiler)
        if (profilerFileName == null)
          sqProfiler.stop()
        else
          sqProfiler.stop_and_save_to_file(profilerFileName)
      profileIdx = -1
    }
    show(msg)
    if (timers.len())
      timers.pop()
  }

  stopToFile = @(msg = "stop") stop(msg, "profile.csv")
}
