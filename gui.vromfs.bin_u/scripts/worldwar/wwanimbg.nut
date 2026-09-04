from "dagor.random" import rnd
from "%sqstd/datablock.nut" import convertBlk
from "%sqstd/underscore.nut" import isDataBlock
from "%scripts/dagui_library.nut" import *

let { createBgData } = require("%scripts/loading/loadingBgData.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")

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
  foreach (n in wwBg) 
    curBgData.list[$"{WW_BG_PATH}{n}.blk"] <- rnd() % 10
  return animBgLoad("", null, curBgData)
}

return wwAnimBgLoad
