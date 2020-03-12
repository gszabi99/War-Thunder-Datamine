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
      ::clog($"dbg_timer: {msg}: {::dagor.getCurTime() - timers.top()}")
    else
      ::clog($"dbg_timer: not found timer for {msg}")
  }

  function stop(msg = "stop")
  {
    if (profileIdx >= timers.len())
    {
      if (sqProfiler)
        sqProfiler.stop();
      profileIdx = -1
    }
    show(msg)
    if (timers.len())
      timers.pop()
  }
}