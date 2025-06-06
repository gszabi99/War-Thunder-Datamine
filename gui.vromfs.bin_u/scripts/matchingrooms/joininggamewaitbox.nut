from "%scripts/dagui_library.nut" import *
import "%scripts/matchingRooms/lobbyStates.nut" as lobbyStates

let { set_game_mode, get_game_mode, get_cur_game_mode_name } = require("mission")
let { format } = require("string")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isInJoiningGame, getSessionLobbyMissionParams, sessionLobbyStatus, getSessionLobbyGameMode
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getRoomEvent, getSessionLobbyMissionNameLoc } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getEventDisplayType } = require("%scripts/events/eventInfo.nut")
let { g_event_display_type } = require("%scripts/events/eventDisplayType.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { leaveSessionRoom } = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")

gui_handlers.JoiningGameWaitBox <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/msgBox.blk"
  timeToShowCancel = 30
  timer = -1

  function initScreen() {
    this.scene.findObject("msgWaitAnimation").show(true)
    this.scene.findObject("msg_box_timer").setUserData(this)
    this.updateInfo()
  }

  function onEventLobbyStatusChange(_params) {
    this.updateInfo()
  }

  function onEventEventsDataUpdated(_params) {
    this.updateInfo()
  }

  function updateInfo() {
    if (!isInJoiningGame.get())
      return this.goBack()

    this.resetTimer() 
    this.checkGameMode()

    let misData = getSessionLobbyMissionParams()
    local msg = loc("wait/sessionJoin")
    if (sessionLobbyStatus.get() == lobbyStates.UPLOAD_CONTENT)
      msg = loc("wait/sessionUpload")
    if (misData)
      msg = "".concat(msg, "\n\n", colorize("activeTextColor", this.getCurrentMissionGameMode()),
        "\n", colorize("userlogColoredText", this.getCurrentMissionName()))

    this.scene.findObject("msgText").setValue(msg)
  }

  function getCurrentMissionGameMode() {
    local gameModeName = get_cur_game_mode_name()
    if (gameModeName == "domination") {
      let event = getRoomEvent()
      if (event == null)
        return ""

      if (getEventDisplayType(event) != g_event_display_type.RANDOM_BATTLE)
        gameModeName = "event"
    }
    return loc($"multiplayer/{gameModeName}Mode")
  }

  function getCurrentMissionName() {
    if (get_game_mode() == GM_DOMINATION) {
      let event = getRoomEvent()
      if (event)
        return events.getEventNameText(event)
    }
    else {
      let misName = getSessionLobbyMissionNameLoc()
      if (misName != "")
        return misName
    }
    return ""
  }

  function checkGameMode() {
    let gm = getSessionLobbyGameMode()
    let curGm = get_game_mode()
    if (gm < 0 || curGm == gm)
      return

    set_game_mode(gm)
    if (this.mainGameMode < 0)
      this.mainGameMode = curGm  
  }

  function showCancelButton(show) {
    let btnId = "btn_cancel"
    local obj = this.scene.findObject(btnId)
    if (obj) {
      obj.show(show)
      obj.enable(show)
      if (show)
        move_mouse_on_obj(obj)
      return
    }
    if (!show)
      return

    let data = format(
      "Button_text{id:t='%s'; btnName:t='AB'; text:t='#msgbox/btn_cancel'; on_click:t='onCancel'}",
      btnId)
    let holderObj = this.scene.findObject("buttons_holder")
    if (!holderObj)
      return

    this.guiScene.appendWithBlk(holderObj, data, this)
    obj = this.scene.findObject(btnId)
    move_mouse_on_obj(obj)
  }

  function resetTimer() {
    this.timer = this.timeToShowCancel
    this.showCancelButton(false)
  }

  function onUpdate(_obj, dt) {
    if (this.timer < 0)
      return
    this.timer -= dt
    if (this.timer < 0)
      this.showCancelButton(true)
  }

  function onCancel() {
    this.guiScene.performDelayed(this, function() {
      if (this.timer >= 0)
        return
      destroySessionScripted("on cancel join game")
      leaveSessionRoom()
    })
  }
}
