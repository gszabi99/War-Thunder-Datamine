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
  }

  function onUpdate(obj, dt)
  {
    if (::loading_is_finished())
      ::loading_press_apply()
  }
}