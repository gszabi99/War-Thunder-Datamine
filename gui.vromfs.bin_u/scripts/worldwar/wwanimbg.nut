local { eachParam } = require("std/datablock.nut")
local { createBgData } = require("scripts/loading/loadingBgData.nut")

local getBgFullPath = @(name) (name ?? "") != "" ? $"config/worldwar_bg/{name}.blk" : ""

local function loadBgData()
{
  local res = createBgData()
  local blk = ::configs.GUI.get()?.worldwar_bg
  if (blk)// Need to set random weight in config for random image getting when no active map
    eachParam(blk, @(inst) res.list[getBgFullPath(inst)] <- ::math.rnd() % 10)

  return res
}

return {
  getBgFullPath
  loadBgData
}
