from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { guiStartReplayBattle } = require("%scripts/replays/replayScreen.nut")
let { addPopup } = require("%scripts/popups/popups.nut")

gui_handlers.WwBattleResults <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/worldWar/battleResultsWindow.tpl"

  battleRes = null

  static function open(battleRes) {
    if (!battleRes || !battleRes.isValid())
      return addPopup("", loc("worldwar/battle_not_found"),
        null, null, null, "battle_result_view_error")

    handlersManager.loadHandler(gui_handlers.WwBattleResults, { battleRes = battleRes })
  }

  function getSceneTplContainerObj() {
    return this.scene.findObject("root-box")
  }

  function getSceneTplView() {
    return this.battleRes.getView()
  }

  function getCurrentEdiff() {
    return ::g_world_war.defaultDiffCode
  }

  function onViewServerReplay() {
    guiStartReplayBattle(this.battleRes.getSessionId(), @() ::g_world_war.openMainWnd())
  }
}
