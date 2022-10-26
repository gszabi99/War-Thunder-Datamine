from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")
let platformModule = require("%scripts/clientState/platform.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { isChatEnableWithPlayer, isCrossNetworkMessageAllowed } = require("%scripts/chat/chatStates.nut")

::g_invites_classes <- {}

::BaseInvite <- class
{
  static lifeTimeMsec = 3600000
  static chatLinkPrefix = "INV_"

  inviteColor = "@chatTextInviteColor"
  inviteActiveColor = "@chatTextInviteActiveColor"

  uid = ""
  receivedTime = -1

  inviterName = ""
  inviterUid = null

  isSeen = false
  isDelayed = false //do not show it to player while delayed
  isAutoAccepted = false
  isRejected = false

  needCheckSystemRestriction = false //Required for displaying console system message

  timedShowStamp = -1   //  invite must be hidden till this timestamp
  timedExpireStamp = -1 //  invite must autoexpire after this timestamp

  reloadParams = null //params to reload invite on script reload

  constructor(params)
  {
    this.uid = this.getUidByParams(params)
    this.updateParams(params, true)
  }

  static function getUidByParams(params) //must be uniq between invites classes
  {
    return "ERR_" + getTblValue("inviterName", params, "")
  }

  function updateParams(params, initial = false)
  {
    this.reloadParams = params
    this.receivedTime = get_time_msec()
    this.inviterName = getTblValue("inviterName", params, this.inviterName)
    this.inviterUid = getTblValue("inviterUid", params, this.inviterUid)

    this.updateCustomParams(params, initial)

    this.showInvitePopup() //we are show popup on repeat the same invite.
  }

  function afterScriptsReload(inviteBeforeReload)
  {
    this.receivedTime = inviteBeforeReload.receivedTime
  }

  function updateCustomParams(_params, _initial = false) {}

  function isValid()
  {
    return !this.isAutoAccepted
  }

  function isOutdated()
  {
    if ( !this.isValid() )
      return true
    if ( this.receivedTime + this.lifeTimeMsec < get_time_msec() )
      return true
    if ( this.timedExpireStamp > 0 && this.timedExpireStamp <= ::get_charserver_time_sec() )
      return true
    return false
  }

  function getInviterName()
  {
    return platformModule.getPlayerName(this.inviterName)
  }

  function isVisible()
  {
    return !this.isOutdated()
           && !this.isDelayed
           && !this.isAutoAccepted
           && !this.isRejected
           && !::isUserBlockedByPrivateSetting(this.inviterUid, this.inviterName)
  }

  function setDelayed(newIsDelayed)
  {
    if (this.isDelayed == newIsDelayed)
      return

    this.isDelayed = newIsDelayed
    if (this.isDelayed)
      return

    ::g_invites.broadcastInviteReceived(this)
    this.showInvitePopup()
  }

  function updateDelayedState( now )
  {
    if ( this.timedShowStamp > 0 && this.timedShowStamp <= now )
    {
      this.timedShowStamp = -1
      this.setDelayed(false)
    }
  }

  function getNextTriggerTimestamp()
  {
    if ( this.timedShowStamp > 0 )
      return this.timedShowStamp

    if ( this.timedExpireStamp > 0 )
      return this.timedExpireStamp

    return -1
  }

  function setTimedParams( timedShowStamp_, timedExpireStamp_ )
  {
    this.timedShowStamp = timedShowStamp_
    this.timedExpireStamp  = timedExpireStamp_
    if ( this.timedShowStamp > 0 && this.timedShowStamp > ::get_charserver_time_sec() )
      this.setDelayed(true)
  }


  function getChatLink()
  {
    return this.chatLinkPrefix + this.uid
  }

  function getChatInviterLink()
  {
    return ::g_chat.generatePlayerLink(this.inviterName)
  }

  function checkChatLink(link)
  {
    return link == this.getChatLink()
  }

  function autoAccept()
  {
    this.isAutoAccepted = true
    this.accept()
  }
  function accept() {}
  function getChatInviteText() { return "" }
  function getPopupText() { return "" }
  function getRestrictionText() { return "" }
  function getInviteText() { return "" }
  function getIcon() { return "" }
  function haveRestrictions() { return false }

  function showInvitePopup()
  {
    if (!this.isVisible()
        || ::g_script_reloader.isInReloading
        || ::get_gui_option_in_mode(::USEROPT_SHOW_SOCIAL_NOTIFICATIONS, ::OPTIONS_MODE_GAMEPLAY) == false
      )
      return
    local msg = this.getPopupText()
    if (!msg.len())
      return

    msg = [colorize(this.inviteColor, msg)]
    msg.append(this.getRestrictionText())

    let buttons = []
    if (!this.haveRestrictions())
    {
      buttons.append(
        { id = "reject_invite",
          text = loc("invite/reject"),
          func = this.reject
        }
        { id = "accept_invite",
          text = loc("contacts/accept_invitation"),
          func = this.accept
        }
      )
    }

    ::g_popups.add(null, ::g_string.implode(msg, "\n"), ::gui_start_invites, buttons, this, "invite_" + this.uid)
  }

  function reject()
  {
    this.remove()
  }

  function onRemove()
  {
    ::g_popups.removeByHandler(this)
  }

  function remove()
  {
    ::g_invites.remove(this)
  }

  function showInviterMenu(position = null)
  {
    let contact = this.inviterUid && ::getContact(this.inviterUid, this.inviterName)
    ::g_chat.showPlayerRClickMenu(this.inviterName, null, contact, position)
  }

  function markSeen(silent = false)
  {
    if (this.isSeen)
      return false

    this.isSeen = true
    if (!silent)
      ::g_invites.updateNewInvitesAmount()
    return true
  }

  function isNew()
  {
    return !this.isSeen && !this.isOutdated()
  }

  function hasInviter()
  {
    return !::u.isEmpty(this.inviterName)
  }

  function isAvailableByCrossPlay()
  {
    return crossplayModule.isCrossPlayEnabled()
           || platformModule.isXBoxPlayerName(this.inviterName)
           || platformModule.isPS4PlayerName(this.inviterName)
  }

  function isAvailableByChatRestriction()
  {
    return isChatEnableWithPlayer(this.inviterName)
      && isCrossNetworkMessageAllowed(this.inviterName)
  }
}
