local onMainMenuReturnActions = require("scripts/mainmenu/onMainMenuReturnActions.nut")
local { topMenuShopActive } = require("scripts/mainmenu/topMenuStates.nut")

local dbgStartCheck = 0

::gui_start_mainmenu <- function gui_start_mainmenu(allowMainmenuActions = true)
{
  if (dbgStartCheck++)
  {
    local msg = "Error: recursive start mainmenu call. loginState = " + ::g_login.curState
    ::dagor.debug(msg)
    ::callstack()
    ::script_net_assert_once("mainmenu recursion", msg)
  }

  ::back_from_replays = null

  ::dynamic_clear()
  ::mission_desc_clear()
  ::mission_settings.dynlist <- []

  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu)

  local handler = ::handlersManager.loadHandler(::gui_handlers.MainMenu)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu)

  if (allowMainmenuActions)
    onMainMenuReturnActions.value?.onMainMenuReturn(handler, false)

  dbgStartCheck--
  return handler
}

::gui_start_mainmenu_reload <- function gui_start_mainmenu_reload(showShop = false)
{
  ::dagor.debug("Forced reload mainmenu")
  if (dbgStartCheck)
  {
    local msg = "Error: recursive start mainmenu call. loginState = " + ::g_login.curState
    ::dagor.debug(msg)
    ::callstack()
    ::script_net_assert_once("mainmenu recursion", msg)
  }

  ::handlersManager.clearScene()
  topMenuShopActive(showShop)
  ::gui_start_mainmenu()
}