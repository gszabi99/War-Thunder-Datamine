let DataBlock = require("DataBlock")
let { wwGetOperationMapName } = require("worldwar")

let WW_SETTINGS_BLK_FILENAME = "worldWar/worldwar.blk";
local isMapSettingsLoaded = false
let mapSettingsBlk = DataBlock()
let settingsCache = {}

function initWWSettings() {
  isMapSettingsLoaded = mapSettingsBlk.tryLoad(WW_SETTINGS_BLK_FILENAME)
}

function getMapsDirName() {
  if(!isMapSettingsLoaded)
    initWWSettings()
  return mapSettingsBlk?["mapsDirName"]
}

function getSettings(param) {
  if(!isMapSettingsLoaded)
    initWWSettings()

  if(!(param in settingsCache)) {
    let mapName = wwGetOperationMapName()
    settingsCache[param] <- mapSettingsBlk.guiMap?.overrideByMapName[mapName][param] ?? mapSettingsBlk.guiMap[param]
  }
  return settingsCache[param]
}

function getSettingsArray(param) {
  if(!isMapSettingsLoaded)
    initWWSettings()

  if(!(param in settingsCache))
    settingsCache[param] <- mapSettingsBlk.guiMap % param
  return settingsCache[param]
}

return {
  getSettings
  getSettingsArray
  getMapsDirName
  clearSettingsCache = @() settingsCache.clear()
}