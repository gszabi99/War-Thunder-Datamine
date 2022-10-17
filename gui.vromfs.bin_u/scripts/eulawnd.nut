let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { fillUserNick } = require("%scripts/firstChoice/firstChoice.nut")

::gui_start_eula <- function gui_start_eula(eulaType, isForView = false)
{
  ::gui_start_modal_wnd(::gui_handlers.EulaWndHandler, { eulaType = eulaType, isForView = isForView })
}

::gui_handlers.EulaWndHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/eulaFrame.blk"

  eulaType = ::TEXT_EULA
  isForView = false

  function initScreen()
  {
    fillUserNick(scene.findObject("usernick_place"))
    let textObj = scene.findObject("eulaText")
    textObj["punctuation-exception"] = "-.,'\"():/\\@"
    let isEULA = eulaType == ::TEXT_EULA
    ::load_text_content_to_gui_object(textObj, isEULA ? ::loc("eula_filename") : ::loc("nda_filename"))
    if (isEULA && isPlatformSony)
    {
      local regionTextRootMainPart = "scee"
      if (::ps4_get_region() == ::SCE_REGION_SCEA)
        regionTextRootMainPart = "scea"

      local eulaText = textObj.getValue()
      let locId = "sony/" + regionTextRootMainPart
      let legalLocText = ::loc(locId, "")
      if (legalLocText == "")
      {
        ::dagor.debug("Cannot find '" + locId + "' text for " + ::get_current_language() + " language.")
        eulaText += ::dagor.getLocTextForLang(locId, "English")
      }
      else
        eulaText += legalLocText

      textObj.setValue(eulaText)
    }

    this.showSceneBtn("accept", !isForView)
    this.showSceneBtn("decline", !isForView)
    this.showSceneBtn("close", isForView)
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
      if (::should_agree_eula(::eula_version, ::TEXT_EULA))
        ::gui_start_eula(::TEXT_EULA)
  }

  function onExit()
  {
    sendEulaStatistic("decline")
    exitGame()
  }

  function sendEulaStatistic(action)
  {
    ::add_big_query_record("eula_screen", action)
  }
}
