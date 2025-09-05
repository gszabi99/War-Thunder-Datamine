from "%scripts/dagui_library.nut" import *

let blkUtil = require("%scripts/utils/datablockConverter.nut")
let applyRendererSettingsChange = require("%scripts/clientState/applyRendererSettingsChange.nut")
let { is_hfr_supported } = require("graphicsOptions")
let { get_settings_blk } = require("blkGetters")
let { platformAlias, platformId } = require("%sqstd/platform.nut")
let { console_save_user_config } = require("consoleUserConfig")


let vDefaultSyncModeNames = [ "thirty", "sixty", "unlimited" ]
let vHfrSyncModeNames = [ "fourty", "sixty", "hundred_twenty", "unlimited" ]

let allLfrModes = {
  xbox = { thirty    = { video = { vsync = true  freqLevel = 0 } },
           sixty     = { video = { vsync = true  freqLevel = 2 } },
           unlimited = { video = { vsync = false freqLevel = 4 } } }
  ps4  = { thirty    = { video = { vsync = true  frameSkip = 1 } },
           sixty     = { video = { vsync = true  frameSkip = 0 } },
           unlimited = { video = { vsync = false frameSkip = 0 } } }
  ps5  = { thirty    = { video = { vsync = true  freqLevel = 0 } },
           sixty     = { video = { vsync = true  freqLevel = 1 } },
           unlimited = { video = { vsync = false freqLevel = 4 } } }
}

let allHfrModes = {
  xbox = { fourty         = { video = { vsync = true  freqLevel = 1 } },
           sixty          = { video = { vsync = true  freqLevel = 2 } },
           hundred_twenty = { video = { vsync = true  freqLevel = 3 } },
           unlimited      = { video = { vsync = false freqLevel = 4 } } }
  ps5  = { fourty         = { video = { vsync = true  freqLevel = 0 } },
           sixty          = { video = { vsync = true  freqLevel = 1 } },
           hundred_twenty = { video = { vsync = true  freqLevel = 2 } },
           unlimited      = { video = { vsync = false freqLevel = 4 } } }
}

let getModes = @(all) all?[platformId] ?? all?[platformAlias] ?? []
let lfrModes = getModes(allLfrModes)
let hfrModes = getModes(allHfrModes)

function canSetVSyncMode() {
  let modes = is_hfr_supported() ? allHfrModes : allLfrModes
  return (platformId in modes) || (platformAlias in modes)
}

function getAvailableVSyncModes() {
  return is_hfr_supported() ? vHfrSyncModeNames : vDefaultSyncModeNames
}


function getVSyncModeIdx(fromFreqLevel = false) {
  let settings = get_settings_blk()
  let modeNames = getAvailableVSyncModes()

  if (!fromFreqLevel) {
    let modeName = settings?["vsync_mode"]
    if (modeNames.contains(modeName))
      return modeNames.indexof(modeName)
  }

  let video = settings?.video
  if (video) {
    let modes = is_hfr_supported() ? hfrModes : lfrModes
    return modeNames.findindex(@(name) modes[name].video.vsync == video.vsync && modes[name].video?.freqLevel == video?.freqLevel) ?? 0
  }

  return modeNames.indexof("sixty");
}


function setVSyncMode(modeIdx) {
  if (getVSyncModeIdx() == modeIdx)
    return

  let modeName = getAvailableVSyncModes()[modeIdx]
  let cfg = blkUtil.dataToBlk(is_hfr_supported() ? hfrModes[modeName] : lfrModes[modeName])
  cfg["vsync_mode"] = modeName

  console_save_user_config(cfg)
  applyRendererSettingsChange()
}


return {
  canSetVSyncMode
  getAvailableVSyncModes
  getVSyncMode = getVSyncModeIdx
  setVSyncMode
}
