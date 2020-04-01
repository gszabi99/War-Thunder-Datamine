local { animBgLoad } = require("scripts/loading/animBg.nut")

class ::gui_handlers.LoadingHangarHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/loading/loadingHangar.blk"
  sceneNavBlkName = "gui/loadingNav.blk"

  isEnteringMission = false // true on entering mission, false on quiting.

  function initScreen()
  {
    animBgLoad()
    ::setVersionText()
    ::set_help_text_on_loading(scene.findObject("help_text"))

    initFocusArray()

    local updObj = scene.findObject("cutscene_update")
    if (::checkObj(updObj))
      updObj.setUserData(this)

    if (::should_show_controls_help_on_loading && isEnteringMission && ::is_suit_mission())
    {
      ::should_show_controls_help_on_loading = false
      ::gui_modal_help(false, HELP_CONTENT_SET.CONTROLS_SUIT)
    }
  }

  function onUpdate(obj, dt)
  {
    if (::loading_is_finished())
      ::loading_press_apply()
  }
}