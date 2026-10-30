from "%appGlobals/clientState/localProfile.nut" import saveLocalSharedSettings, loadLocalSharedSettings, loadLocalAccountSettings
from "%scripts/options/systemOptions.nut" import canShowGpuBenchmark
from "%scripts/clientState/clientStates.nut" import getFromSettingsBlk
from "gpuBenchmark" import getGpuName
from "%scripts/dagui_library.nut" import *

const GPU_BENCHMARK_SEEN_SAVE_ID = "gpuBenchmark/seen"
const GPU_BENCHMARK_GPU_SAVE_ID = "gpuBenchmark/gpuName"

let skipGpuBenchmark = getFromSettingsBlk("debug/skipGpuBenchmark", false)

function needShowGpuBenchmark() {
  if (skipGpuBenchmark || !canShowGpuBenchmark())
    return false

  let currentGpuName = getGpuName()
  let systemGpuName = loadLocalSharedSettings(GPU_BENCHMARK_GPU_SAVE_ID, null)
  let lastSeenGpuName = systemGpuName ?? loadLocalAccountSettings(GPU_BENCHMARK_GPU_SAVE_ID)

  let gpuChanged = (currentGpuName != lastSeenGpuName)
  if (systemGpuName == null && !gpuChanged)
    saveLocalSharedSettings(GPU_BENCHMARK_GPU_SAVE_ID, currentGpuName)

  if (gpuChanged)
    return true

  local alreadySeenOnSystem = loadLocalSharedSettings(GPU_BENCHMARK_SEEN_SAVE_ID, null)
  if (alreadySeenOnSystem == null) {
    let alreadySeenOnAccount = loadLocalAccountSettings(GPU_BENCHMARK_SEEN_SAVE_ID)
    alreadySeenOnSystem = alreadySeenOnAccount
    saveLocalSharedSettings(GPU_BENCHMARK_SEEN_SAVE_ID, alreadySeenOnSystem)
  }

  return !alreadySeenOnSystem
}

return freeze({
  needShowGpuBenchmark
  GPU_BENCHMARK_SEEN_SAVE_ID
  GPU_BENCHMARK_GPU_SAVE_ID
})