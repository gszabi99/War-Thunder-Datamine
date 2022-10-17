from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.RemoteMissionModalHandler <- class extends ::gui_handlers.CampaignChapter {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/empty.blk"

  mission = null

  function initScreen()
  {
    if (mission == null)
      return goBack()

    gm = ::get_game_mode()
    curMission = mission
    setMission()
  }

  function getModalOptionsParam(optionItems, applyFunc)
  {
    return {
      options = optionItems
      applyAtClose = false
      wndOptionsMode = ::get_options_mode(gm)
      owner = this
      applyFunc = applyFunc
      cancelFunc = Callback(function() {
                                ::g_missions_manager.isRemoteMission = false
                                goBack()
                              }, this)
    }
  }
}