from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "eventbus" import eventbus_subscribe
from "dagor.debug" import debug_dump_stack
from "dynamicMission" import dynamicClear
from "guiMission" import mission_desc_clear
from "%scripts/dagui_natives.nut" import switch_gui_scene
from "%scripts/dagui_library.nut" import *

let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let onMainMenuReturnActions = require("%scripts/mainmenu/onMainMenuReturnActions.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { getStateDebugStr } = require("%scripts/login/loginStates.nut")
let { set_mission_settings } = require("%scripts/missions/missionsStates.nut")
let { setBackFromReplaysFn } = require("%scripts/replays/backFromReplaysFn.nut")

local dbgStartCheck = 0

function gui_start_mainmenu(params = {}) {
  let { allowMainmenuActions = true } = params
  if (dbgStartCheck++) {
    let msg = $"Error: recursive start mainmenu call. loginState = {getStateDebugStr()}"
    log(msg)
    debug_dump_stack()
    script_net_assert_once("mainmenu recursion", msg)
  }

  setBackFromReplaysFn(null)

  dynamicClear()
  mission_desc_clear()
  set_mission_settings("dynlist", [])

  let handler = handlersManager.loadHandler(get_gui_handler("MainMenu"))
  handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_mainmenu" })
  showObjById("gamercard_center", !topMenuShopActive.get())

  if (allowMainmenuActions)
    onMainMenuReturnActions.get()?.onMainMenuReturn(handler, false)

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
  topMenuShopActive.set(showShop)
  gui_start_mainmenu()
}

let guiStartMainmenuDelayed = @() get_cur_gui_scene().performDelayed({},
  @() switch_gui_scene(gui_start_mainmenu))

eventbus_subscribe("gui_start_mainmenu", gui_start_mainmenu)
eventbus_subscribe("guiStartMainmenuDelayed", @(_) guiStartMainmenuDelayed())

return {
  gui_start_mainmenu
  gui_start_mainmenu_reload
}
