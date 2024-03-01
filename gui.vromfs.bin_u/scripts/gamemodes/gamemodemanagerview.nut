from "%scripts/dagui_library.nut" import *

let { openUrl } = require("%scripts/onlineShop/url.nut")
let { isCrossPlayEnabled,
  needShowCrossPlayInfo } = require("%scripts/social/crossplay.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { guiStartSkirmish } = require("%scripts/missions/startMissionsList.nut")
let { guiStartModalEvents } = require("%scripts/events/eventsHandler.nut")
let { setCurrentGameModeById } = require("%scripts/gameModes/gameModeManagerState.nut")

let fullRealModeOnBattleButtonClick = @(gameMode)
  guiStartModalEvents({ event = gameMode?.getEventId() ?? gameMode?.modeId })

let customActionsByGameModeId = {
  world_war_featured_game_mode = {
    startFunction = @(_gameMode) ::g_world_war.openMainWnd()
  }
  tss_featured_game_mode = {
    function startFunction(_gameMode) {
      if (!needShowCrossPlayInfo() || isCrossPlayEnabled())
        openUrl(loc("url/tss_all_tournaments"), false, false)
      else if (!isMultiplayerPrivilegeAvailable.value)
        checkAndShowMultiplayerPrivilegeWarning()
      else if (!isShowGoldBalanceWarning())
        checkAndShowCrossplayWarning(@() showInfoMsgBox(loc("xbox/actionNotAvailableCrossNetworkPlay")))
    }
  }
  tournaments_and_event_featured_game_mode = {
    startFunction = @(_gameMode) guiStartModalEvents()
  }
  custom_battles_featured_game_mode = {
    function startFunction(_gameMode) {
      if (!isMultiplayerPrivilegeAvailable.value) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      guiStartSkirmish()
    }
  }
  custom_mode_fullreal = {
    onBattleButtonClick = fullRealModeOnBattleButtonClick
    function startFunction(gameMode) {
      setCurrentGameModeById(gameMode.id, true) //need this for fast start SB battle in next time
      fullRealModeOnBattleButtonClick(gameMode)
    }
  }
}

return {
  getGameModeStartFunction = @(id) customActionsByGameModeId?[id].startFunction
  getGameModeOnBattleButtonClick = @(id) customActionsByGameModeId?[id].onBattleButtonClick
}
