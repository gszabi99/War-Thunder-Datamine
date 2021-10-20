local { animBgLoad } = require("scripts/loading/animBg.nut")
local { setHelpTextOnLoading, setVersionText } = require("scripts/viewUtils/objectTextUpdate.nut")

class ::gui_handlers.LoadingHangarHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/loading/loadingHangar.blk"
  sceneNavBlkName = "gui/loading/loadingNav.blk"

  isEnteringMission = false // true on entering mission, false on quiting.

  function initScreen()
  {
    animBgLoad()
    setVersionText()
    setHelpTextOnLoading(scene.findObject("help_text"))

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