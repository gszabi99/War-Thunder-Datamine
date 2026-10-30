from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_DISPLAY_MY_REAL_CLAN
from "%scripts/options/options.nut" import get_gui_option_in_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import clan_get_my_clan_tag, clan_get_my_clan_name, clan_get_my_clan_id

function _getVisibleClanInfo(getInfoFn) {
  let isInClan = clan_get_my_clan_id() != "-1"
  if (isInClan && !get_gui_option_in_mode(USEROPT_DISPLAY_MY_REAL_CLAN, OPTIONS_MODE_GAMEPLAY, true))
    return ""
  return getInfoFn()
}

let getMyClanTag = @() _getVisibleClanInfo(clan_get_my_clan_tag)
let getMyClanName = @() _getVisibleClanInfo(clan_get_my_clan_name)

return freeze({
  getMyClanTag
  getMyClanName
})