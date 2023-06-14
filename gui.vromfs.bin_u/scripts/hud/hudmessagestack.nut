//checked for plus_string
from "%scripts/dagui_library.nut" import *


let DaguiSceneTimers = require("%sqDagui/timer/daguiSceneTimers.nut")

::g_hud_message_stack <- {
  scene = null
  guiScene = null
  timers = DaguiSceneTimers(0.25, "hudMessagesTimers")

  function init(v_scene) {
    if (!checkObj(v_scene))
      return
    this.scene = v_scene
    this.guiScene = this.scene.getScene()
    ::g_hud_event_manager.subscribe("ReinitHud", function(_eventData) {
        this.clearMessageStacks()
      }, this)

    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.subscribeHudEvents()

    this.initMessageNests()
  }

  function reinit() {
    this.initMessageNests()
  }

  function initMessageNests() {
    this.timers.setUpdaterObj(this.scene.findObject("hud_message_timer"))

    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.reinit(this.scene, this.timers)
  }

  function clearMessageStacks() {
    this.timers.resetTimers()
    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.clearStack()
  }
}