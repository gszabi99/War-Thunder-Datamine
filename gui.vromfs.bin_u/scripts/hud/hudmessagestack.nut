from "%scripts/dagui_library.nut" import *

let { g_hud_messages } = require("%scripts/hud/hudMessages.nut")
let { getHasCompassObservable } = require("hudCompassState")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")

let DaguiSceneTimers = require("%sqDagui/timer/daguiSceneTimers.nut")

let g_hud_message_stack = {
  scene = null
  guiScene = null
  timers = DaguiSceneTimers(0.25, "hudMessagesTimers")

  function init(v_scene) {
    if (!checkObj(v_scene))
      return
    this.scene = v_scene
    this.guiScene = this.scene.getScene()
    g_hud_event_manager.subscribe("ReinitHud", function(_eventData) {
        this.clearMessageStacks()
      }, this)

    foreach (hudMessage in g_hud_messages.types)
      hudMessage.subscribeHudEvents()

    this.initMessageNests()
    this.updateMainNotificationsCompassOffset()
  }

  function reinit() {
    this.initMessageNests()
    this.updateMainNotificationsCompassOffset()
  }

  function initMessageNests() {
    this.timers.setUpdaterObj(this.scene.findObject("hud_message_timer"))

    foreach (hudMessage in g_hud_messages.types)
      hudMessage.reinit(this.scene, this.timers)
  }

  function clearMessageStacks() {
    this.timers.resetTimers()
    foreach (hudMessage in g_hud_messages.types)
      hudMessage.clearStack()
  }

  function updateMainNotificationsCompassOffset() {
    let containerObj = this.scene?.findObject("hud_messages_top_center_container")
    if (containerObj?.isValid())
      containerObj.setValue(stashBhvValueConfig([{
        watch = getHasCompassObservable()
        updateFunc = function(obj, value) {
          obj["margin-top"] = value ? "@notificationsWithCompassTopOffset" : "0"
        }
      }]))
  }
}

return {
  g_hud_message_stack
}