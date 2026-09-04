from "%scripts/dagui_library.nut" import *

let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { guiStartReplayBattle } = require("%scripts/replays/replayScreen.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let g_world_war = require("%scripts/worldWar/worldWarUtils.nut")

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

