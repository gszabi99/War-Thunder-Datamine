let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = ::require_native("guiOptions")
let lobbyStates = require("%scripts/matchingRooms/lobbyStates.nut")

let class AutoStartBattleHandler extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.ROOT
  wndGameMode = ::GM_DOMINATION
  sceneBlkName = "%gui/autoStartBattle.blk"
  queueMask = QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE

  curGameMode = null
  queueTableHandler = null
  curQueue = null

  WAIT_BATTLE_DURATION = 20
  goBackTime = -1

  function initScreen() {
    ::set_presence_to_player("menu")
    ::enableHangarControls(true)

    mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(::OPTIONS_MODE_MP_DOMINATION)

    setCurQueue(::queues.findQueue({}, queueMask))
  }

  function onTimer(_, __) {
    if (!isValid())
      return

    if (::handlersManager.isAnyModalHandlerActive())
      return

    let timeLeft = goBackTime - ::get_charserver_time_sec()
    if (timeLeft < 0)
      return goBack()

    if (!::queues.isQueueActive(curQueue)
        && ::SessionLobby.status == lobbyStates.NOT_IN_ROOM)
      return goBack()
  }

  function setCurQueue(value) {
    curQueue = value
    if (curQueue == null)
      return

    loadQueueTableHandler()
  }

  function onEventRequestToggleVisibility(params) {
    ::show_obj(params.target, params.visible)
  }

  function loadQueueTableHandler() {
    if (::handlersManager.isHandlerValid(queueTableHandler))
      return

    let container = scene.findObject("queue_table_container")
    if (container == null)
      return

    queueTableHandler = ::handlersManager.loadHandler(::gui_handlers.QueueTable, {
      scene = container
      queueMask = queueMask
    })
    queueTableHandler.setShowQueueTable(true)
  }

  function joinMpQueue() {
    if (curQueue != null)
      return

    let gameMode = ::game_mode_manager.getCurrentGameMode()
    if (gameMode == null)
      return

    guiScene.performDelayed(this, function() {
      if (isValid() && curQueue == null) {
        let event = ::game_mode_manager.getGameModeEvent(gameMode)
        ::EventJoinProcess(event, null, null, ::Callback(goBack, this))
      }
    })
  }

  function goBack() {
    guiScene.performDelayed(this, function() {
      gui_start_mainmenu()
    })
    ::queues.leaveAllQueuesSilent()
    base.goBack()
  }

  function onStartAction() {
    if (!::is_online_available()) {
      let handler = this
      goForwardIfOnline(function() {
          if (handler?.isValid())
            handler.onStartAction.call(handler)
        }, false, true)
      return
    }
    ::queues.checkAndStart((@() joinMpQueue()).bindenv(this), null, "isCanNewflight")
  }

  function onEventQueueChangeState(p) {
    if (!::queues.checkQueueType(p.queue, queueMask))
      return

    setCurQueue(::queues.isQueueActive(p.queue) ? p.queue : null)
  }

  function startBattle() {
    if (!isSceneActive() || curQueue)
      return

    checkedNewFlight(onStartAction.bindenv(this))

    goBackTime = ::get_charserver_time_sec() + WAIT_BATTLE_DURATION
    scene.findObject("queue_timeout_time").setUserData(this)
  }

  function onEventCurrentGameModeIdChanged(_) {
    if (curGameMode == ::game_mode_manager.getCurrentGameMode())
      return

    curGameMode = ::game_mode_manager.getCurrentGameMode()
    doWhenActiveOnce("startBattle")
  }
}

::gui_handlers.AutoStartBattleHandler <- AutoStartBattleHandler