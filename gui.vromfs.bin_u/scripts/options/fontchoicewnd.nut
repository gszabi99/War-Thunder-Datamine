let FONT_CHOICE_SAVE_ID = "tutor/fontChange"

local wasOpened = false

::gui_handlers.FontChoiceWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "%gui/options/fontChoiceWnd"

  option = null

  static function openIfRequired()
  {
    if (!::gui_handlers.FontChoiceWnd.isSeen() && ::g_font.getAvailableFonts().len() > 1)
      ::handlersManager.loadHandler(::gui_handlers.FontChoiceWnd)
  }

  static function isSeen()
  {
    return ::load_local_account_settings(FONT_CHOICE_SAVE_ID, false)
  }

  static function markSeen(isMarkSeen = true)
  {
    return ::save_local_account_settings(FONT_CHOICE_SAVE_ID, isMarkSeen)
  }

  function getSceneTplView()
  {
    option = ::get_option(::USEROPT_FONTS_CSS)
    return {
      options = ::create_option_combobox(option.id, option.items, option.value, null, false)
    }
  }

  function initScreen()
  {
    if (!wasOpened)
    {
      wasOpened = true
    }
  }

  function onFontsChange(obj)
  {
    let newValue = obj.getValue()
    if (newValue == option.value)
      return

    ::set_option(::USEROPT_FONTS_CSS, newValue, option)
    guiScene.performDelayed(this, @() ::handlersManager.getActiveBaseHandler().fullReloadScene())
  }

  function goBack()
  {
    markSeen(true)
    base.goBack()
  }
}