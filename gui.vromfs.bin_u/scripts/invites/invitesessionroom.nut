from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { suggestAndAllowPsnPremiumFeatures } = require("%scripts/user/psnFeatures.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")

::g_invites_classes.SessionRoom <- class extends ::BaseInvite
{
  //custom class params, not exist in base invite
  roomId = ""
  password = ""
  isAccepted = false
  needCheckSystemRestriction = true

  static function getUidByParams(params)
  {
    return "SR_" + getTblValue("inviterName", params, "") + "/" + getTblValue("roomId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    roomId = getTblValue("roomId", params, roomId)
    password = getTblValue("password", params, password)

    if (::g_squad_manager.isMySquadLeader(this.inviterUid))
    {
      implAccept(true) //auto accept squad leader room invite
      isAccepted = true //if fail to join, it will try again on ready
      return
    }

    if (initial)
    {
      ::add_event_listener("RoomJoined",
        function (_p) {
          if (::SessionLobby.isInRoom() && ::SessionLobby.roomId == roomId)
          {
            remove()
            onSuccessfulAccept()
          }
        },
        this)
      ::add_event_listener("MRoomInfoUpdated",
        function (p) {
          if (p.roomId != roomId)
            return
          this.setDelayed(false)
          if (!isValid())
            remove()
          else
            ::g_invites.broadcastInviteUpdated(this)
        },
        this)
    }

    //do not set delayed when scipt reload to not receive invite popup on each script reload
    this.setDelayed(!::g_script_reloader.isInReloading && !::g_mroom_info.get(roomId).getFullRoomData())
  }

  function isValid()
  {
    return !isAccepted
        && !::g_mroom_info.get(roomId).isRoomDestroyed
  }

  function remove()
  {
    isAccepted = true
    base.remove()
  }

  function getText(locIdFormat, activeColor = null)
  {
    if (!activeColor)
      activeColor = this.inviteActiveColor

    let room = ::g_mroom_info.get(roomId).getFullRoomData()
    let event = room ? ::SessionLobby.getRoomEvent(room) : null
    local modeId = "skirmish"
    let params = { player = colorize(activeColor, this.getInviterName()) }
    if (event)
    {
      modeId = "event"
      params.eventName <- colorize(activeColor, ::events.getEventNameText(event))
    }
    else
      params.missionName <- room ? colorize(activeColor, ::SessionLobby.getMissionNameLoc(room)) : ""

    return loc(format(locIdFormat, modeId), params)
  }

  function getInviteText()
  {
    return getText("invite/%s/message_no_nick", "userlogColoredText")
  }

  function getPopupText()
  {
    return getText("invite/%s/message")
  }

  function getIcon()
  {
    return "#ui/gameuiskin#lb_each_player_session.svg"
  }

  function haveRestrictions()
  {
    return !::isInMenu()
      || !isMissionAvailable()
      || !this.isAvailableByCrossPlay()
      || !isMultiplayerPrivilegeAvailable.value
  }

  function isMissionAvailable()
  {
    let room = ::g_mroom_info.get(roomId).getFullRoomData()
    return !::SessionLobby.isUrlMission(room) || ::ps4_is_ugc_enabled()
  }

  function getRestrictionText()
  {
    if (haveRestrictions())
    {
      if (!isMultiplayerPrivilegeAvailable.value)
        return loc("xbox/noMultiplayer")
      if (!this.isAvailableByCrossPlay())
        return loc("xbox/crossPlayRequired")
      if (!isMissionAvailable())
        return loc("invite/session/ugc_restriction")
      return loc("invite/session/cant_apply_in_flight")
    }
    return ""
  }

  function onSuccessfulReject() {}
  function onSuccessfulAccept() {}

  function reject()
  {
    base.reject()
    onSuccessfulReject()
  }

  function accept()
  {
    if (!suggestAndAllowPsnPremiumFeatures())
      return

    if (!isMultiplayerPrivilegeAvailable.value) {
      checkAndShowMultiplayerPrivilegeWarning()
      return
    }

    let room = ::g_mroom_info.get(roomId).getFullRoomData()
    if (!::check_gamemode_pkg(::SessionLobby.getGameMode(room)))
      return

    implAccept()
  }

  function implAccept(ignoreCheckSquad = false)
  {
    if (!::check_gamemode_pkg(GM_SKIRMISH))
      return

    let room = ::g_mroom_info.get(roomId).getFullRoomData()
    let event = room ? ::SessionLobby.getRoomEvent(room) : null
    if (event != null && (!antiCheat.showMsgboxIfEacInactive(event)||
                          !showMsgboxIfSoundModsNotAllowed(event)))
      return

    let canJoin = ignoreCheckSquad
                    ||  ::g_squad_utils.canJoinFlightMsgBox(
                          { isLeaderCanJoin = true }, Callback(_implAccept, this))
    if (canJoin)
      _implAccept()
  }

  function _implAccept()
  {
    if (this.isOutdated())
      return ::g_invites.showExpiredInvitePopup()

    let room = ::g_mroom_info.get(roomId).getFullRoomData()
    let event = room ? ::SessionLobby.getRoomEvent(room) : null
    if (event)
      ::gui_handlers.EventRoomsHandler.open(event, false, roomId)
    else
      ::SessionLobby.joinRoom(roomId, this.inviterUid, password)
  }
}
