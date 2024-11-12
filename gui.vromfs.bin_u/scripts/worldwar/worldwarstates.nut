from "%scripts/dagui_library.nut" import *
let { get_game_settings_blk } = require("blkGetters")

function getWwSetting(settingName, defaultValue) {
  return get_game_settings_blk()?.ww_settings[settingName] ?? defaultValue
}

return {
  getWwSetting
}