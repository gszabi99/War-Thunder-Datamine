from "%rGui/globals/ui_library.nut" import *

let { BlkFileName } = require("%rGui/planeState/planeToolsState.nut")
let DataBlock = require("DataBlock")
let { hsdSettingsUpd }  = require("%rGui/planeCockpit/hsd.nut")
let { devicesSettingUpd } = require("%rGui/planeCockpit/digitalDevices.nut")
let { rwrSettingUpd } = require("%rGui/planeRwr.nut")
let { radarSettingsUpd } = require("%rGui/radar.nut")
let { mfdRwrSettingsUpd } = require("%rGui/tws.nut")
let { ilsSettingsUpd } = require("%rGui/planeIls.nut")
let { hmdSettingsUpd } = require("%rGui/planeHmd.nut")
let { mfdCameraSettingUpd } = require("%rGui/planeMfdCamera.nut")
let { customPageSettingsUpd } = require("%rGui/planeCockpit/customPageBuilder.nut")

function updateSettings(blk_name) {
  if (blk_name == "")
    return
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{blk_name}.blk"
  if (!blk.tryLoad(fileName))
    return

  ilsSettingsUpd(blk)
  hmdSettingsUpd(blk)
  mfdCameraSettingUpd(blk)
  let cockpitBlk = blk.getBlockByName("cockpit")
  if (!cockpitBlk)
    return
  let devicesBlk = cockpitBlk.getBlockByName("digitalDevices")
  if (devicesBlk)
    devicesSettingUpd(devicesBlk)
  let mfdBlk = cockpitBlk.getBlockByName("multifunctionDisplays")
  if (!mfdBlk)
    return

  rwrSettingUpd(mfdBlk, blk.getStr("rwrIndicator", ""))
  for (local i = 0; i < mfdBlk.blockCount(); ++i) {
    let displayBlk = mfdBlk.getBlock(i)
    for (local j = 0; j < displayBlk.blockCount(); ++j) {
      let pageBlk = displayBlk.getBlock(j)
      let typeStr = pageBlk.getStr("type", "")
      if (typeStr == "hsd")
        hsdSettingsUpd(pageBlk)
      else if (typeStr == "radar" || typeStr == "radar_b_round")
        radarSettingsUpd(pageBlk)
      else if (typeStr == "rwr")
        mfdRwrSettingsUpd(pageBlk)
      else if (typeStr == "custom")
        customPageSettingsUpd(pageBlk)
    }
  }
}

BlkFileName.subscribe(updateSettings)