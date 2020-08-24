local optionsListModule = require("scripts/options/optionsList.nut")

::gui_start_options <- function gui_start_options(owner = null, curOption = null)
{
  local isInFlight = ::is_in_flight()
  if(isInFlight)
    ::init_options()

  local options = optionsListModule.getOptionsList()

  if(curOption != null)
    foreach(o in options)
      if (o.name == curOption)
        o.selected <- true;

  local params = {
    titleText = isInFlight ?
      ::is_multiplayer() ? null : ::loc("flightmenu/title")
      : ::loc("mainmenu/btnGameplay")
    optGroups = options
    wndOptionsMode = ::OPTIONS_MODE_GAMEPLAY
    sceneNavBlkName = "gui/options/navOptionsIngame.blk"
    owner = owner
  }
  params.cancelFunc <- function()
  {
    ::set_option_gamma(::get_option_gamma(), false)
    for (local i = 0; i < ::SND_NUM_TYPES; i++)
      ::set_sound_volume(i, ::get_sound_volume(i), false)
  }

  local handler = ::handlersManager.loadHandler(::gui_handlers.GroupOptionsModal, params)

  ::showBtn("btn_postfx_settings", !::is_compatibility_mode(), handler.scene)
  ::showBtn("btn_hdr_settings", ::is_hdr_enabled(), handler.scene)

  if (isInFlight && "WebUI" in getroottable())
    ::showBtn("web_ui_button", ::is_platform_pc && ::WebUI.get_port() != 0, handler.scene)
}
