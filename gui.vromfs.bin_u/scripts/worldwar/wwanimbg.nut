local { createBgData } = require("scripts/loading/loadingBgData.nut")
local { GUI } = require("scripts/utils/configs.nut")
local { animBgLoad } = require("scripts/loading/animBg.nut")

const WW_BG_PATH = "config/worldwar_bg/"

local function wwAnimBgLoad(name) {
  local wwBg = ::buildTableFromBlk(GUI.get()?.worldwar_bg)
  local fullPath = (name ?? "") == ""
    ? "" : wwBg?[name]
    ? $"{WW_BG_PATH}{name}.blk" : ""
  if (fullPath != "")
    return animBgLoad(fullPath)

  local curBgData = createBgData()
  foreach(n in wwBg)// Need to set random weight in config for random image getting when no active map
    curBgData.list[$"{WW_BG_PATH}{n}.blk"] <- ::math.rnd() % 10
  return animBgLoad("", null, curBgData)
}

return wwAnimBgLoad

