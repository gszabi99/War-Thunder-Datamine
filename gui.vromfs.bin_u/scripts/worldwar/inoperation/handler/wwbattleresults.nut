import "%scripts/worldWar/worldWarUtils.nut" as g_world_war
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/replays/replayScreen.nut" import guiStartReplayBattle
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let WwBattleResults = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/worldWar/battleResultsWindow.tpl"

  battleRes = null

  static function open(battleRes) {
    if (!battleRes || !battleRes.isValid())
      return addPopup("", loc("worldwar/battle_not_found"),
        null, null, null, "battle_result_view_error")

    handlersManager.loadHandler(get_gui_handler("WwBattleResults"), { battleRes = battleRes })
  }

  function getSceneTplContainerObj() {
    return this.scene.findObject("root-box")
  }

  function getSceneTplView() {
    return this.battleRes.getView()
  }

  function getCurrentEdiff() {
    return g_world_war.defaultDiffCode
  }

  function onViewServerReplay() {
    guiStartReplayBattle(this.battleRes.getSessionId(), @() g_world_war.openMainWnd())
  }
}
register_gui_handler("WwBattleResults", WwBattleResults)
