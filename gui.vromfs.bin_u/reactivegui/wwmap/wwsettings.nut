from "%rGui/globals/ui_library.nut" import *
let DataBlock = require("DataBlock")

let WW_SETTINGS_BLK_FILENAME = "worldWar/worldwar.blk";
local isMapSettingsLoaded = false
let mapSettingsBlk = DataBlock()
let settingsCache = {}

function initWWSettings() {
  if (isMapSettingsLoaded)
    return true
  isMapSettingsLoaded = mapSettingsBlk.tryLoad(WW_SETTINGS_BLK_FILENAME)
  return isMapSettingsLoaded
}

let getMapsDirName = @() mapSettingsBlk?["mapsDirName"]

function getSettings(param) {
  if(!isMapSettingsLoaded)
    return null

  if(!(param in settingsCache))
    settingsCache[param] <- mapSettingsBlk.guiMap[param]
  return settingsCache[param]
}

function getSettingsArray(param) {
  if(!isMapSettingsLoaded)
    return null

  if(!(param in settingsCache))
    settingsCache[param] <- mapSettingsBlk.guiMap % param
  return settingsCache[param]
}

return {
  getSettings
  getSettingsArray
  getMapsDirName
  initWWSettings
}
