from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "string" import format
from "%scripts/dagui_natives.nut" import ps4_is_ugc_enabled
from "%scripts/dagui_library.nut" import *

let { events } = require("%scripts/events/eventsManager.nut")
let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { EventRoomsHandler } = require("%scripts/events/eventRoomsHandler.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("%scripts/user/psnFeatures.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { checkAndShowMultiplayerPrivilegeWarning, isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { registerInviteClass } = require("%scripts/invites/invitesClasses.nut")
let BaseInvite = require("%scripts/invites/inviteBase.nut")
let { isInSessionRoom, getSessionLobbyRoomId, getSessionLobbyGameMode, isUrlMissionByRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { checkShowMultiplayerAasWarningMsg } = require("%scripts/user/antiAddictSystem.nut")
let { getRoomEvent, getSessionLobbyMissionNameLoc } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { joinSessionRoom } = require("%scripts/matchingRooms/sessionLobbyActions.nut")
let { showExpiredInvitePopup } = require("%scripts/invites/invites.nut")
let { checkGamemodePkg } = require("%scripts/clientState/contentPacks.nut")
let { canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")

let SessionRoom = class (BaseInvite) {
  
  roomId = ""
  password = ""
  roomInfo = null 
  isAccepted = false
  needCheckSystemRestriction = true

  static function getUidByParams(params) {
    return "".concat("SR_", (params?.inviterName ?? ""), "/", (params?.roomId ?? ""))
  }

  function updateCustomParams(params, initial = false) {
    this.roomId = (params?.roomId ?? this.roomId)
    this.password = (params?.password ?? this.password)
    this.roomInfo = params?.roomInfo ?? this.roomInfo

    if (g_squad_manager.isMySquadLeader(this.inviterUid)) {
      this.implAccept(true) 
      this.isAccepted = true 
      return
    }

    if (initial) {
      add_event_listener("RoomJoined",
        function (_p) {
          if (isInSessionRoom.get() && getSessionLobbyRoomId() == this.roomId) {
            this.remove()
            this.onSuccessfulAccept()
          }
        },
        this)
    }
  }

  function getFullRoomData() {
    return this.roomInfo
  }

  function isValid() {
    return !this.isAccepted
  }

  function remove() {
    this.isAccepted = true
    base.remove()
  }

  function getText(locIdFormat, activeColor = null) {
    if (!activeColor)
      activeColor = this.inviteActiveColor

    let room = this.getFullRoomData()
    let event = room ? getRoomEvent(room) : null
    local modeId = "skirmish"
    let params = { player = colorize(activeColor, this.getInviterName()) }
    if (event) {
      modeId = "event"
      params.eventName <- colorize(activeColor, events.getEventNameText(event))
    }
    else
      params.missionName <- room ? colorize(activeColor, getSessionLobbyMissionNameLoc(room)) : ""

    return loc(format(locIdFormat, modeId), params)
  }

  function getInviteText() {
    return this.getText("invite/%s/message_no_nick", "userlogColoredText")
  }

  function getPopupText() {
    return this.getText("invite/%s/message")
  }

  function getIcon() {
    return "#ui/gameuiskin#lb_each_player_session.svg"
  }

  function haveRestrictions() {
    return !isInMenu.get()
      || !this.isMissionAvailable()
      || !this.isAvailableByCrossPlay()
      || !isMultiplayerPrivilegeAvailable.get()
  }

  function isMissionAvailable() {
    let room = this.getFullRoomData()
    return !isUrlMissionByRoom(room) || ps4_is_ugc_enabled()
  }

  function getRestrictionText() {
    if (this.haveRestrictions()) {
      if (!isMultiplayerPrivilegeAvailable.get())
        return loc("xbox/noMultiplayer")
      if (!this.isAvailableByCrossPlay())
        return loc("xbox/crossPlayRequired")
      if (!this.isMissionAvailable())
        return loc("invite/session/ugc_restriction")
      return loc("invite/session/cant_apply_in_flight")
    }
    return ""
  }

  function onSuccessfulReject() {}
  function onSuccessfulAccept() {}

  function reject() {
    base.reject()
    this.onSuccessfulReject()
  }

  function accept() {
    if (!suggestAndAllowPsnPremiumFeatures())
      return

    if (!isMultiplayerPrivilegeAvailable.get()) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    if (isShowGoldBalanceWarning())
      return

    let room = this.getFullRoomData()
    let cb = Callback(@() this.implAccept(), this)
    checkGamemodePkg(getSessionLobbyGameMode(room), cb)
  }

  function implAccept(ignoreCheckSquad = false) {
    let cb = Callback(function() {
      let canJoin = ignoreCheckSquad || canJoinFlightMsgBox(
         { isLeaderCanJoin = true }, Callback(this._implAccept, this))
      if (canJoin)
        this._implAccept()
    }, this)
    let room = this.getFullRoomData()
    let event = room ? getRoomEvent(room) : null
    if (event != null) {
      if (!antiCheat.showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event))
        return

      checkShowMultiplayerAasWarningMsg(cb)
      return
    }

    cb()
  }

  function _implAccept() {
    if (this.isOutdated())
      return showExpiredInvitePopup()

    let room = this.getFullRoomData()
    let event = room ? getRoomEvent(room) : null
    if (event)
      EventRoomsHandler.open(event, false, this.roomId)
    else
      joinSessionRoom(this.roomId, this.inviterUid, this.password)
  }
}

registerInviteClass("SessionRoom", SessionRoom)
