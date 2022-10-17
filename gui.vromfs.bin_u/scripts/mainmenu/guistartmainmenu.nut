from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let onMainMenuReturnActions = require("%scripts/mainmenu/onMainMenuReturnActions.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")

local dbgStartCheck = 0

::gui_start_mainmenu <- function gui_start_mainmenu(allowMainmenuActions = true)
{
  if (dbgStartCheck++)
  {
    let msg = "Error: recursive start mainmenu call. loginState = " + ::g_login.curState
    log(msg)
    ::dagor.debug_dump_stack()
    ::script_net_assert_once("mainmenu recursion", msg)
  }

  ::back_from_replays = null

  ::dynamic_clear()
  ::mission_desc_clear()
  ::mission_settings.dynlist <- []

  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu)

  let handler = ::handlersManager.loadHandler(::gui_handlers.MainMenu)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu)
  ::showBtn("gamercard_center", !topMenuShopActive.value)

  if (allowMainmenuActions)
    onMainMenuReturnActions.value?.onMainMenuReturn(handler, false)

  dbgStartCheck--
  return handler
}

::gui_start_mainmenu_reload <- function gui_start_mainmenu_reload(showShop = false)
{
  log("Forced reload mainmenu")
  if (dbgStartCheck)
  {
    let msg = "Error: recursive start mainmenu call. loginState = " + ::g_login.curState
    log(msg)
    ::dagor.debug_dump_stack()
    ::script_net_assert_once("mainmenu recursion", msg)
  }

  ::handlersManager.clearScene()
  topMenuShopActive(showShop)
  ::gui_start_mainmenu()
}

::cross_call_api.startMainmenu <- @() ::get_cur_gui_scene().performDelayed({},
  @() ::switch_gui_scene(::gui_start_mainmenu))
