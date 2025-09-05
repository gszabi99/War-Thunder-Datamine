from "%scripts/dagui_library.nut" import *

let { platformId } = require("%sqstd/platform.nut")
let { regexp } = require("string")
let DataBlock  = require("DataBlock")
let { isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")





let stdPresetPathPrefix = "config/hotkeys/hotkey."
let presetFileNameExtention = ".blk"
let versionRegExp = regexp(@"_ver(\d+)$")
let versionDigits = regexp(@"\d+$")

let nullPreset = {
  id       = "",
  version  = -1,
  name     = "",
  fileName = ""
}

local presetsListCached = null




function handleVersion(preset) {
  preset.name = preset.id
  preset.version = 0

  let versionMatch = versionRegExp.search(preset.name)
  if (versionMatch) {
    let versionSubstring = preset.name.slice(versionMatch.begin)
    preset.version = versionSubstring.slice(versionDigits.search(versionSubstring).begin).tointeger()
    preset.name = preset.name.slice(0, versionMatch.begin)
  }
}

let getNullControlsPresetInfo = @() clone nullPreset







function getControlsPresetsList() {
  if (presetsListCached == null) {
    let blk = DataBlock()
    blk.load("config/hotkeys/list.blk")
    local platform = isPlatformSteamDeck ? "steamdeck" : platformId
    presetsListCached = (blk?[platform] != null)
      ? blk[platform] % "preset"
      : blk % "preset"
  }
  let result = [].extend(presetsListCached)
  return result
}




function getControlsPresetFilename(presetName) {
  return "".concat(stdPresetPathPrefix, presetName, ".blk")
}




function parseControlsPresetFileName(presetFileName) {
  let preset = getNullControlsPresetInfo()

  if (presetFileName.len() < stdPresetPathPrefix.len())
    return preset

  preset.fileName = presetFileName
  preset.id = presetFileName.slice(stdPresetPathPrefix.len()).slice(0, -1 * presetFileNameExtention.len())

  handleVersion(preset)

  return preset
}





function parseControlsPresetName(presetName) {
  let preset = getNullControlsPresetInfo()

  if (presetName == "")
    return preset

  preset.fileName = getControlsPresetFilename(presetName)
  preset.id = presetName

  handleVersion(preset)

  return preset
}

function getHighestVersionControlsPreset(preset) {
  let controlsPresetsList = getControlsPresetsList()
  local highestVersionPreset = preset
  foreach (value in controlsPresetsList) {
    let presetInList = parseControlsPresetName(value)

    if (presetInList.name != preset.name)
      continue

    if (highestVersionPreset.version < presetInList.version)
      highestVersionPreset = presetInList
  }

  return highestVersionPreset
}

return {
  getNullControlsPresetInfo
  getControlsPresetsList
  getControlsPresetFilename
  parseControlsPresetFileName
  parseControlsPresetName
  getHighestVersionControlsPreset
}
