from "%scripts/dagui_library.nut" import *

let { rnd } = require("dagor.random")
let { createBgData } = require("%scripts/loading/loadingBgData.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isDataBlock } = require("%sqstd/underscore.nut")

const WW_BG_PATH = "worldwar_bg/"

function wwAnimBgLoad(name) {
  let worldwar_bg = GUI.get()?.worldwar_bg
  let wwBg = isDataBlock(worldwar_bg) ? convertBlk(worldwar_bg) : {}
  let fullPath = (name ?? "") == ""
    ? "" : wwBg?[name]
    ? $"{WW_BG_PATH}{name}.blk" : ""
  if (fullPath != "")
    return animBgLoad(fullPath)

  let curBgData = createBgData()
  foreach (n in wwBg) // Need to set random weight in config for random image getting when no active map
    curBgData.list[$"{WW_BG_PATH}{n}.blk"] <- rnd() % 10
  return animBgLoad("", null, curBgData)
}

return wwAnimBgLoad

