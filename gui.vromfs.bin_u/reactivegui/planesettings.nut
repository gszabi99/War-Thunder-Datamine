import "DataBlock" as DataBlock
from "%rGui/planeState/planeToolsState.nut" import BlkFileName
from "%rGui/planeCockpit/instrumentsPage/hsd.nut" import hsdSettingsUpd
from "%rGui/planeCockpit/instrumentsPage/digitalDevices.nut" import devicesSettingUpd
from "%rGui/planeRwr.nut" import rwrSettingUpd
from "%rGui/radar.nut" import radarSettingsUpd
from "%rGui/tws.nut" import mfdRwrSettingsUpd
from "%rGui/planeIls.nut" import ilsSettingsUpd
from "%rGui/planeHmd.nut" import hmdSettingsUpd
from "%rGui/planeMfdCamera.nut" import mfdCameraSettingUpd
from "%rGui/planeCockpit/customPageBuilder.nut" import customPageSettingsUpd
from "%rGui/globalState.nut" import isInFlight
from "%rGui/hudState.nut" import unitType
from "%rGui/hudUnitType.nut" import isAirUnitType
from "blkLoad" import tryLoadBlk
from "%rGui/globals/ui_library.nut" import *



function gatherPageBlksToUpdateSettings(mfdBlk) {
  let blksToSet = {}
  let customPagesBlks = []
  for (local i = 0; i < mfdBlk.blockCount(); ++i) {
    let displayBlk = mfdBlk.getBlock(i)
    for (local j = 0; j < displayBlk.blockCount(); ++j) {
      let pageBlk = displayBlk.getBlock(j)
      let typeStr = pageBlk.getStr("type", "")
      if (typeStr == "custom")
        customPagesBlks.append(pageBlk)
      else
        blksToSet[typeStr] <- pageBlk
    }
  }
  return { blksToSet, customPagesBlks }
}

function updateSettings(blk_name) {
  if (blk_name == "")
    return
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{blk_name}.blk"
  if (!tryLoadBlk(blk, fileName))
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

  let { blksToSet, customPagesBlks } = gatherPageBlksToUpdateSettings(mfdBlk)
  foreach(typeStr, pageBlk in blksToSet) {
    if (typeStr == "hsd")
      hsdSettingsUpd(pageBlk)
    else if (typeStr == "radar" || typeStr == "radar_b_round")
      radarSettingsUpd(pageBlk, blk.getBool("chinaLang", false))
    else if (typeStr == "rwr")
      mfdRwrSettingsUpd(pageBlk)
  }
  let isChina = blk.getBool("chinaLang", false)
  foreach(pageBlk in customPagesBlks) {
    if (isChina && !pageBlk.paramExists("chinaLang"))
      pageBlk.setBool("chinaLang", true)
    customPageSettingsUpd(pageBlk)
  }
}
let unitBlkNameInFlight = keepref(Computed(@() isInFlight.get() && isAirUnitType(unitType.get()) ? BlkFileName.get() : ""))
unitBlkNameInFlight.subscribe(updateSettings)
