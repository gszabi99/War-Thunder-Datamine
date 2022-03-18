let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")


::gui_handlers.QiHandlerBase <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName   = "%gui/events/eventQueue.blk"

  queueTypeMask = QUEUE_TYPE_BIT.EVENT
  hasTimerText = true
  timerUpdateObjId = null
  timerTextObjId = null

  queue = null
  event = null
  needAutoDestroy = true //auto destroy when no queue

  isStatsCreated = false

  leaveQueueCb = null

  function initScreen()
  {
    initTimer()
    checkCurQueue(true)
  }

  function initTimer()
  {
    if (!hasTimerText || !timerUpdateObjId)
      return

    let timerObj = scene.findObject(timerUpdateObjId)
    timerObj.setUserData(this)
    timerObj.timer_handler_func = "onUpdate"
  }

  function destroy()
  {
    if (!isValid())
      return
    scene.show(false)
    guiScene.replaceContentFromText(scene, "", 0, null)
    scene = null
  }

  function checkCurQueue(forceUpdate = false)
  {
    local q = ::queues.findQueue({}, queueTypeMask)
    if (q && !::queues.isQueueActive(q))
      q = null

    if (needAutoDestroy && !q)
      return destroy()

    let isQueueChanged = q != queue
    if (!isQueueChanged && !forceUpdate)
      return isQueueChanged

    queue = q
    event = queue && ::queues.getQueueEvent(queue)
    if (!isStatsCreated)
    {
      createStats()
      isStatsCreated = true
    }
    onQueueChange()
    return isQueueChanged
  }

  function onQueueChange()
  {
    scene.show(queue != null)
    if (!queue)
      return

    updateTimer()
    updateStats()
  }

  function onUpdate(obj, dt)
  {
    if (queue)
      updateTimer()
  }

  function updateTimer()
  {
    let textObj = scene.findObject(timerTextObjId)
    let timerObj = scene.findObject("wait_time_block")
    let iconObj = scene.findObject("queue_wait_icon")
    ::g_qi_view_utils.updateShortQueueInfo(timerObj, textObj,
      iconObj, ::loc("yn1/waiting_for_game_query"))
  }

  function leaveQueue(obj) { if (leaveQueueCb) leaveQueueCb() }

  function onEventQueueChangeState(p)     { checkCurQueue() }
  function onEventQueueInfoUpdated(p)     { if (queue) updateStats() }

  function createStats() {}
  function updateStats() {}
}
