//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.WwBattleResults <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/worldWar/battleResultsWindow.tpl"

  battleRes = null

  static function open(battleRes) {
    if (!battleRes || !battleRes.isValid())
      return ::g_popups.add("", loc("worldwar/battle_not_found"),
        null, null, null, "battle_result_view_error")

    ::handlersManager.loadHandler(::gui_handlers.WwBattleResults, { battleRes = battleRes })
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
    ::gui_start_replay_battle(this.battleRes.getSessionId(), @() ::g_world_war.openMainWnd())
  }
}
