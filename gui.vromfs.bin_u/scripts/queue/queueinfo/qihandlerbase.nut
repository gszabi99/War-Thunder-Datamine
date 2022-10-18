from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")



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

    let timerObj = this.scene.findObject(timerUpdateObjId)
    timerObj.setUserData(this)
    timerObj.timer_handler_func = "onUpdate"
  }

  function destroy()
  {
    if (!this.isValid())
      return
    this.scene.show(false)
    this.guiScene.replaceContentFromText(this.scene, "", 0, null)
    this.scene = null
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
    this.scene.show(queue != null)
    if (!queue)
      return

    updateTimer()
    updateStats()
  }

  function onUpdate(_obj, _dt)
  {
    if (queue)
      updateTimer()
  }

  function updateTimer()
  {
    let textObj = this.scene.findObject(timerTextObjId)
    let timerObj = this.scene.findObject("wait_time_block")
    let iconObj = this.scene.findObject("queue_wait_icon")
    ::g_qi_view_utils.updateShortQueueInfo(timerObj, textObj,
      iconObj, loc("yn1/waiting_for_game_query"))
  }

  function leaveQueue(_obj) { if (leaveQueueCb) leaveQueueCb() }

  function onEventQueueChangeState(_p)     { checkCurQueue() }
  function onEventQueueInfoUpdated(_p)     { if (queue) updateStats() }

  function createStats() {}
  function updateStats() {}
}
