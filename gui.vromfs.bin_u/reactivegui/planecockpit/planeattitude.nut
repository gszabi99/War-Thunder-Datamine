from "%rGui/globals/ui_library.nut" import *
let DataBlock = require("DataBlock")
let { BlkFileName } = require("%rGui/planeState/planeToolsState.nut")

function planeAttitude(pos, size) {
  local params = DataBlock()

  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  let fmBlk = DataBlock()
  fmBlk.tryLoad(fileName)

  let mfdBlk = fmBlk.getBlockByName("cockpit")?.getBlockByName("multifunctionDisplays")
  if (mfdBlk !=  null) {
    for (local i = 0; i < mfdBlk.blockCount(); ++i) {
      let displayBlk = mfdBlk.getBlock(i)
      for (local j = 0; j < displayBlk.blockCount(); ++j) {
        let pageBlk = displayBlk.getBlock(j)
        let typeStr = pageBlk.getStr("type", "")
        let pageName = pageBlk.getStr("pageName", "")
        if (typeStr == "custom" && pageName == "planeAttitude") {
          params = pageBlk
        }
      }
    }
  }

  return {
      rendObj = ROBJ_DAS_CANVAS
      pos
      size
      fontId = Fonts.hud
      script = load_das("%rGui/planeCockpit/planeAttitude.das")
      drawFunc = "draw"
      setupFunc = "setup"
      blk = clone params
  }
}

return planeAttitude