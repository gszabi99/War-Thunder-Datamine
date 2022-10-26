from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

const WW_OPERATION_INVITE_EXPIRE_SEC = 3600

::g_invites_classes.WwOperation <- class extends ::BaseInvite
{
  //custom class params, not exist in base invite
  operationId = ""
  isStarted = false
  clanName = ""
  startTime = -1

  inviteActiveColor = "userlogColoredText"

  static function getUidByParams(params)
  {
    return "WWO_" + getTblValue("operationId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    this.operationId = getTblValue("operationId", params, this.operationId)
    this.isStarted = getTblValue("isStarted", params, this.isStarted)
    this.clanName = getTblValue("clanName", params, this.clanName)

    //do not set delayed when scipt reload to not receive invite popup on each script reload
    this.setDelayed(!::g_script_reloader.isInReloading && !this.getOperation())

    if (!initial)
      return

    ::add_event_listener("WWGlobalStatusChanged",
      function (p)
      {
        if (!(p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS))
          return

        if (this.getOperation())
          this.setDelayed(false)
        else if (!this.isDelayed)
          this.remove()
      },
      this)

    ::add_event_listener("WWLoadOperation",
      function (_p)
      {
        if (::ww_get_operation_id() == this.operationId)
          this.remove()
      },
      this)

    this.startTime = params?.inviteTime??this.startTime
    if (this.startTime > 0)
      this.setTimedParams(0, this.startTime + WW_OPERATION_INVITE_EXPIRE_SEC)
  }

  function getOperation()
  {
    return getOperationById(this.operationId)
  }

  function isValid()
  {
    return this.isDelayed || !!this.getOperation()
  }

  function getInviteText()
  {
    let operation = this.getOperation()
    let locId = this.isStarted ? "worldWar/userlog/startOperation"
                            : "worldWar/userlog/createOperation"
    let params = {
      clan = colorize(this.inviteActiveColor, this.clanName)
      operation = colorize(this.inviteActiveColor, operation ? operation.getNameText() : this.operationId)
    }
    return loc(locId, params)
  }

  function getPopupText()
  {
    return this.getInviteText()
  }

  function getIcon()
  {
    return "#ui/gameuiskin#battles_open.png"
  }

  function haveRestrictions()
  {
    return !::isInMenu()
  }

  function getRestrictionText()
  {
    if (this.haveRestrictions())
      return loc("invite/session/cant_apply_in_flight")
    return ""
  }

  function accept()
  {
    ::g_world_war.joinOperationById(this.operationId)
  }
}