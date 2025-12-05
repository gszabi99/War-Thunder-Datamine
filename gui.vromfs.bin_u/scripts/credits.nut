from "%scripts/dagui_natives.nut" import load_text_content_to_gui_object
from "%scripts/dagui_library.nut" import *

let { register_gui_handler, gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let topMenuHandlerClass = require("%scripts/mainmenu/topMenuHandler.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { format } = require("string")


function guiStartCredits() {
  handlersManager.loadHandler(gui_handlers.CreditsMenu)
}

function on_credits_finish(canceled = false) {
  if (!canceled)
    reqUnlockByClient("view_credits")
  topMenuHandler.get()?.topMenuGoBack.call(topMenuHandler.get())
}

const timeToShowAll = 500.0

let CreditsScroll = class {
  function onTimer(obj, dt) {
    local curOffs = obj.cur_slide_offs.tofloat()

    let pos = obj.getPos()
    let size = obj.getSize()
    let parentSize = obj.getParent().getSize()
    let speedCreditsScroll = (size[1] / parentSize[1]) / timeToShowAll

    if (pos[1] + size[1] < 0) {
      curOffs = -(0.9 * parentSize[1]).tointeger()
      if (obj?.inited == "yes") {
        obj.getScene().performDelayed({}, on_credits_finish)
        return
      }
      else
        obj.inited = "yes"
    }
    else
      curOffs += dt * parentSize[1] * speedCreditsScroll 
    obj.cur_slide_offs = format("%f", curOffs)
    obj.top = (-curOffs).tointeger().tostring()
  }











  eventMask = EV_TIMER 
  

}

replace_script_gui_behaviour("CreditsScroll", CreditsScroll)

register_gui_handler("CreditsMenu", class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/credits.blk"
  rootHandlerClass = topMenuHandlerClass.getHandler()
  static hasTopMenuResearch = false

  function initScreen() {
    let textArea = (this.guiScene / "credits-text" / "textarea")
    load_text_content_to_gui_object(textArea, "%langTxt/credits.txt")
  }

  function onScreenClick() {
    on_credits_finish(true)
  }
})

return {
  guiStartCredits
}
