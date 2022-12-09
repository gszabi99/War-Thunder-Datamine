from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { regexp } = require("string")
let controlsPresetConfigPath = require("%scripts/controls/controlsPresetConfigPath.nut")
let { isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")

/**
 * Functions to work with controls presets
 */

let stdPresetPathPrefix = $"{controlsPresetConfigPath.value}config/hotkeys/hotkey."
let presetFileNameExtention = ".blk"
let versionRegExp = regexp(@"_ver(\d+)$")
let versionDigits = regexp(@"\d+$")

//Path in local settings BLK, where stored hidhest version number which was displayed
//to player.
//Append preset name to this path get version of preset.
let highestVersionSettingsPath = "controls_presets/highest_version_displayed"

/**
 * Slice version from name and fill version field.
 */
let function _handleVersion(preset)
{
  preset.name = preset.id
  preset.version = 0

  let versionMatch = versionRegExp.search(preset.name)
  if (versionMatch)
  {
    let versionSubstring = preset.name.slice(versionMatch.begin)
    preset.version = versionSubstring.slice(versionDigits.search(versionSubstring).begin).tointeger()
    preset.name = preset.name.slice(0, versionMatch.begin)
  }
}


::g_controls_presets <- {


  nullPreset = {
    id       = "",
    version  = -1,
    name     = "",
    fileName = ""
  }

  presetsListCached = null

  /**
   * Function compare current controls preset version and highest available.
   * Returns true if new version is available.
   * If custom preset used or user already been asked about last version returns false.
   */
  function isNewerControlsPresetVersionAvailable()
  {
    let currentPreset = this.getCurrentPresetInfo()
    if (currentPreset.name == "")
      return false

    let controlsPresetsList = this.getControlsPresetsList()
    let highestDisplayedVersion = this.getHighestDisplayedPresetVersion(currentPreset.name)

    foreach (value in controlsPresetsList)
    {
      let preset = this.parsePresetName(value)
      if (preset.name != currentPreset.name)
        continue

      if (preset.version > highestDisplayedVersion && preset.version > currentPreset.version)
        return true
    }

    return false
  }

  function getHighestDisplayedPresetVersion(presetName)
  {
    return ::load_local_account_settings(highestVersionSettingsPath + "/" + presetName, -1)
  }

  function setHighestDisplayedPresetVersion(presetName, version)
  {
    ::save_local_account_settings(highestVersionSettingsPath + "/" + presetName, version)
  }

  function getHighestVersionPreset(preset)
  {
    let controlsPresetsList = this.getControlsPresetsList()
    local highestVersionPreset = preset
    foreach (value in controlsPresetsList)
    {
      let presetInList = this.parsePresetName(value)

      if (presetInList.name != preset.name)
        continue

      if (highestVersionPreset.version < presetInList.version)
        highestVersionPreset = presetInList
    }

    return highestVersionPreset
  }

  function setHighestVersionOfCurrentPreset()
  {
    let currentPreset = this.getCurrentPresetInfo()
    if (currentPreset.name == "")
      return

    ::apply_joy_preset_xchange(this.getHighestVersionPreset(currentPreset).fileName)
    ::save_profile(false)
  }

  function rejectHighestVersionOfCurrentPreset()
  {
    let currentPreset = this.getCurrentPresetInfo()
    if (currentPreset.name == "")
      return

    let preset = this.getHighestVersionPreset(currentPreset)
    this.setHighestDisplayedPresetVersion(preset.name, preset.version)
  }

  /**
   * Returns array of version numbers newer than inPreset version
   */
  function getNewerVersions(inPreset)
  {
    let result = []
    let controlsPresetsList = this.getControlsPresetsList()

    foreach (value in controlsPresetsList)
    {
      let preset = this.parsePresetName(value)
      if (preset.name != inPreset.name)
        continue

      if (preset.version < inPreset.version)
        continue

      result.append(preset.version)
    }

    return result
  }

  function getPatchNoteTextForCurrentPreset()
  {
    local result = ""
    let currentPreset = this.getCurrentPresetInfo()
    let versions = this.getNewerVersions(currentPreset)

    foreach (version in versions)
    {
      let patchNote = loc("presets/" + currentPreset.name + "_ver" + version + "/patchnote", "")
      if (patchNote.len())
        result += (result.len() ? "\n" : "") + patchNote
    }

    return result
  }

  /**
   * Returns current players preset in format { name, version, filename }.
   */
  getCurrentPresetInfo = @() this.parsePresetFileName(::get_controls_preset())

  /**
   * Breaks preset file name string into table {version = @integer, name = @string }
   */
  function parsePresetFileName(presetFileName)
  {
    let preset = clone this.nullPreset

    if (presetFileName.len() < stdPresetPathPrefix.len())
      return preset

    preset.fileName = presetFileName
    preset.id = presetFileName.slice(stdPresetPathPrefix.len()).slice(0, -1 * presetFileNameExtention.len())

    _handleVersion(preset)

    return preset
  }

  /**
   * Build preset data table from presetName (typicaly received from getControlsPresetList)
   * Input argument presetName must be trusted source to generate file name for this preset
   */
  function parsePresetName(presetName)
  {
    let preset = clone this.nullPreset

    if (presetName == "")
      return preset

    preset.fileName = this.getControlsPresetFilename(presetName)
    preset.id = presetName

    _handleVersion(preset)

    return preset
  }

  /**
   * Returns list of presets names, fetched from hotkeys/list.blk
   * It also adds the current preset when it is not listed,
   * because deprecated presets are removed from list.blk
   * while being still in use by some players
   */
  function getControlsPresetsList()
  {
    if (this.presetsListCached == null)
    {
      let blk = ::DataBlock()
      blk.load($"{controlsPresetConfigPath.value}config/hotkeys/list.blk")
      local platform = isPlatformSteamDeck ? "steamdeck" : platformId
      this.presetsListCached = (blk?[platform] != null)
        ? blk[platform] % "preset"
        : blk % "preset"
    }
    let result = [].extend(this.presetsListCached)
    let curPresetId = this.getCurrentPresetInfo().id
    if (curPresetId != "" && this.presetsListCached.indexof(curPresetId) == null)
      result.append(curPresetId)
    return result
  }

  /**
   * Return preset file name, converted from preset name.
   */
  function getControlsPresetFilename(presetName)
  {
    return stdPresetPathPrefix + presetName + ".blk"
  }
}
