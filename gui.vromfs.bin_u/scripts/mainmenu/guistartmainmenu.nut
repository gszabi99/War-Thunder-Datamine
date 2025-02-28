from "%scripts/dagui_natives.nut" import switch_gui_scene
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let onMainMenuReturnActions = require("%scripts/mainmenu/onMainMenuReturnActions.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { debug_dump_stack } = require("dagor.debug")
let { dynamicClear } = require("dynamicMission")
let { mission_desc_clear } = require("guiMission")
let { getStateDebugStr } = require("%scripts/login/loginStates.nut")
let { set_mission_settings } = require("%scripts/missions/missionsStates.nut")

local dbgStartCheck = 0

function gui_start_mainmenu(params = {}) {
  let { allowMainmenuActions = true } = params
  if (dbgStartCheck++) {
    let msg = $"Error: recursive start mainmenu call. loginState = {getStateDebugStr()}"
    log(msg)
    debug_dump_stack()
    script_net_assert_once("mainmenu recursion", msg)
  }

  ::back_from_replays = null

  dynamicClear()
  mission_desc_clear()
  set_mission_settings("dynlist", [])

  let handler = handlersManager.loadHandler(gui_handlers.MainMenu)
  handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_mainmenu" })
  showObjById("gamercard_center", !topMenuShopActive.value)

  if (allowMainmenuActions)
    onMainMenuReturnActions.value?.onMainMenuReturn(handler, false)

  dbgStartCheck--
  return handler
}

function gui_start_mainmenu_reload(params = {}) {
  log("Forced reload mainmenu")
  let { showShop = false } = params
  if (dbgStartCheck) {
    let msg = $"Error: recursive start mainmenu call. loginState = {getStateDebugStr()}"
    log(msg)
    debug_dump_stack()
    script_net_assert_once("mainmenu recursion", msg)
  }

  handlersManager.clearScene()
  topMenuShopActive(showShop)
  gui_start_mainmenu()
}

eventbus_subscribe("gui_start_mainmenu", gui_start_mainmenu)

::cross_call_api.startMainmenu <- @() get_cur_gui_scene().performDelayed({},
  @() switch_gui_scene(gui_start_mainmenu))

return {
  gui_start_mainmenu
  gui_start_mainmenu_reload
}
