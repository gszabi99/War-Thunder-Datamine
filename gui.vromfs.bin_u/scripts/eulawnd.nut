::gui_start_eula <- function gui_start_eula(eulaType, isForView = false)
{
  ::gui_start_modal_wnd(::gui_handlers.EulaWndHandler, { eulaType = eulaType, isForView = isForView })
}

class ::gui_handlers.EulaWndHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/eulaFrame.blk"

  eulaType = ::TEXT_EULA
  isForView = false

  function initScreen()
  {
    local textObj = scene.findObject("eulaText")
    textObj["punctuation-exception"] = "-.,'\"():/\\@"
    local isEULA = eulaType == ::TEXT_EULA
    ::load_text_content_to_gui_object(textObj, isEULA ? ::loc("eula_filename") : ::loc("nda_filename"))
    if (isEULA && ::is_platform_ps4)
    {
      local regionTextRootMainPart = "scee"
      if (::ps4_get_region() == ::SCE_REGION_SCEA)
        regionTextRootMainPart = "scea"

      local eulaText = textObj.getValue()
      local locId = "sony/" + regionTextRootMainPart
      local legalLocText = ::loc(locId, "")
      if (legalLocText == "")
      {
        ::dagor.debug("Cannot find '" + locId + "' text for " + ::get_current_language() + " language.")
        eulaText += ::dagor.getLocTextForLang(locId, "English")
      }
      else
        eulaText += legalLocText

      textObj.setValue(eulaText)
    }

    showSceneBtn("accept", !isForView)
    showSceneBtn("decline", !isForView)
    showSceneBtn("close", isForView)
  }

  function onAcceptEula()
  {
    set_agreed_eula_version(eulaType == ::TEXT_NDA ? ::nda_version : ::eula_version, eulaType)
    sendEulaStatistic("accept")
    goBack()
  }

  function afterModalDestroy()
  {
    if (eulaType == ::TEXT_NDA)
      if (should_agree_eula(::eula_version, ::TEXT_EULA))
        ::gui_start_eula(::TEXT_EULA)
  }

  function onExit()
  {
    sendEulaStatistic("decline")
    ::exit_game()
  }

  function sendEulaStatistic(action)
  {
    ::add_big_query_record("eula_screen", action)
  }
}
