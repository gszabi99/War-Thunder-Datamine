local { getOperationById } = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

const WW_OPERATION_BATTLE_INVITE_EXPIRE_SEC = 900

class ::g_invites_classes.WwOperationBattle extends ::BaseInvite
{
  squadronId = -1
  operationId = -1
  battleId = ""

  inviteActiveColor = "userlogColoredText"

  static function getUidByParams(params)
  {
    return "WW_" + (params?.operationId ?? "null") + "_" + (params?.battleId ?? "null")
  }

  function updateCustomParams(params, initial = false)
  {
    operationId = params?.operationId ?? operationId
    battleId = params?.battleId ?? battleId

    //do not set delayed when scipt reload to not receive invite popup on each script reload
    setDelayed(!::g_script_reloader.isInReloading && !getOperation())

    if (!initial)
      return

    ::add_event_listener("WWGlobalStatusChanged",
      function (p)
      {
        if (!(p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS))
          return

        if (getOperation())
          setDelayed(false)
        else if (!isDelayed)
          remove()
      },
      this)
    ::add_event_listener("QueueChangeState", onEventQueueChangeState, this)

    setTimedParams(0, ::get_charserver_time_sec() + WW_OPERATION_BATTLE_INVITE_EXPIRE_SEC)
  }

  function getOperation()
  {
    return getOperationById(operationId)
  }

  function isValid()
  {
    return isDelayed || !!getOperation()
  }

  function getInviteText()
  {
    local operation = getOperation()
    return ::loc("worldwar/inviteSquadsText", {
      operation = ::colorize(inviteActiveColor, operation ? operation.getNameText() : operationId)
    })
  }

  function getPopupText()
  {
    return getInviteText()
  }

  function getIcon()
  {
    return "#ui/gameuiskin#battles_open"
  }

  function haveRestrictions()
  {
    return !::isInMenu()
  }

  function getRestrictionText()
  {
    if (haveRestrictions())
      return ::loc("invite/session/cant_apply_in_flight")
    return ""
  }

  function accept()
  {
    ::queues.checkAndStart(
      ::Callback(function() {
        ::g_world_war.joinOperationById(operationId, null, false,
          ::Callback(function() {
            local wwBattle = ::g_world_war.getBattleById(battleId)
            ::gui_handlers.WwBattleDescription.open(wwBattle)
          }, this))
      }, this),
      null, "isCanNewflight")
  }

  function onEventQueueChangeState(p)
  {
    if (p?.queue?.params?.operationId == operationId &&
        p?.queue?.params?.battleId == battleId)
      remove()
  }
}
