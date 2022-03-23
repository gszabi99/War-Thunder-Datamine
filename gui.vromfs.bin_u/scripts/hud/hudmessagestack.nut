let DaguiSceneTimers = require("%sqDagui/timer/daguiSceneTimers.nut")

::g_hud_message_stack <- {
  scene = null
  guiScene = null
  timers = DaguiSceneTimers(0.25, "hudMessagesTimers")

  function init(_scene)
  {
    if (!::checkObj(_scene))
      return
    scene = _scene
    guiScene = scene.getScene()
    ::g_hud_event_manager.subscribe("ReinitHud", function(eventData)
      {
        clearMessageStacks()
      }, this)

    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.subscribeHudEvents()

    initMessageNests()
  }

  function reinit()
  {
    initMessageNests()
  }

  function initMessageNests()
  {
    timers.setUpdaterObj(scene.findObject("hud_message_timer"))

    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.reinit(scene, timers)
  }

  function clearMessageStacks()
  {
    timers.resetTimers()
    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.clearStack()
  }
}