local dagor_sys = require("dagor.system")
local {gui_scene} = require("daRg")
local {Watched} = require("frp")
local console = require("console")
local log = require("log.nut")()
local conprint = log.console_print

local clearTimer = @(v) gui_scene.clearTimer(v)
local setInterval = @(time, v) gui_scene.setInterval(time, v)

local mkWatched = @(id, val) persist(id, @() Watched(val))

local function registerScriptProfiler(prefix) {
  if (dagor_sys.DBGLEVEL > 0) {
    local profiler = require("dagor.profiler")
    local profiler_reset = profiler.reset_values
    local profiler_dump = profiler.dump
    local profiler_get_total_time = profiler.get_total_time
    local isProfileOn = mkWatched("isProfileOn", false)
    local isSpikesProfileOn = mkWatched("isSpikesProfileOn", false)
    local spikesThresholdMs = mkWatched("spikesThresholdMs", 10)

    local function toggleProfiler(newVal = null, fileName = null) {
      local ret
      if (newVal == isProfileOn.value)
        ret = "already"
      isProfileOn(!isProfileOn.value)
      if (isProfileOn.value)
        ret = "on"
      else
        ret = "off"
      if (ret=="on"){
        conprint(ret)
        profiler.start()
        return ret
      }
      if (ret=="off")
        if (fileName == null)
          profiler.stop()
        else {
          profiler.stop_and_save_to_file(fileName)
          ret = $"{ret} (saved to file {fileName})"
        }
      conprint(ret)
      return ret
    }
    local function profileSpikes(){
      if (profiler_get_total_time() > spikesThresholdMs.value*1000)
        profiler_dump()
      profiler_reset()
    }
    local function toggleSpikesProfiler(){
      isSpikesProfileOn(!isSpikesProfileOn.value)
      if (isSpikesProfileOn.value){
        conprint("starting spikes profiler with threshold {0}ms".subst(spikesThresholdMs.value))
        clearTimer(profileSpikes)
        profiler_reset()
        profiler.start()
        setInterval(0.005, profileSpikes)
      }
      else{
        conprint("stopping spikes profiler")
        clearTimer(profileSpikes)
      }
    }
    local function setSpikesThreshold(val){
      spikesThresholdMs(val.tofloat())
      conprint("set spikes threshold to {0} ms".subst(spikesThresholdMs.value))
    }

    local fileName = $"profile_{prefix}.csv"
    console.register_command(@() toggleProfiler(true), $"{prefix}.profiler.start")
    console.register_command(@() toggleProfiler(false), $"{prefix}.profiler.stop")
    console.register_command(@() toggleProfiler(false, fileName), $"{prefix}.profiler.stopWithFile")
    console.register_command(@() toggleProfiler(null), $"{prefix}.profiler.toggle")
    console.register_command(@() toggleProfiler(null, fileName), $"{prefix}.profiler.toggleWithFile")
    console.register_command(toggleSpikesProfiler, $"{prefix}.profiler.spikes")
    console.register_command(setSpikesThreshold, $"{prefix}.profiler.spikesMsValue")
    console.register_command(@(threshold) profiler.detect_slow_calls(threshold), $"{prefix}.profiler.detect_slow_calls")
  }
}

return registerScriptProfiler
