from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isInReloading } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_charserver_time_sec } = require("chard")
let { registerInviteClass } = require("%scripts/invites/invitesClasses.nut")
let BaseInvite = require("%scripts/invites/inviteBase.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { queues } = require("%scripts/queue/queueManager.nut")

let g_world_war = require("%scripts/worldWar/worldWarUtils.nut")

const WW_OPERATION_BATTLE_INVITE_EXPIRE_SEC = 900

let WwOperationBattle = class (BaseInvite) {
  squadronId = -1
  operationId = -1
  battleId = ""

  inviteActiveColor = "userlogColoredText"

  static function getUidByParams(params) {
    return "".concat("WW_", (params?.operationId ?? "null"), "_", (params?.battleId ?? "null"))
  }

  function updateCustomParams(params, initial = false) {
    this.operationId = params?.operationId ?? this.operationId
    this.battleId = params?.battleId ?? this.battleId

    
    this.setDelayed(!isInReloading() && !this.getOperation())

    if (!initial)
      return

    add_event_listener("WWGlobalStatusChanged",
      function (p) {
        if (!(p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS))
          return

        if (this.getOperation())
          this.setDelayed(false)
        else if (!this.isDelayed)
          this.remove()
      },
      this)
    add_event_listener("QueueChangeState", this.onEventQueueChangeState, this)

    this.setTimedParams(0, get_charserver_time_sec() + WW_OPERATION_BATTLE_INVITE_EXPIRE_SEC)
  }

  function getOperation() {
    return getOperationById(this.operationId)
  }

  function isValid() {
    return this.isDelayed || !!this.getOperation()
  }

  function getInviteText() {
    let operation = this.getOperation()
    return loc("worldwar/inviteSquadsText", {
      operation = colorize(this.inviteActiveColor, operation ? operation.getNameText() : this.operationId)
    })
  }

  function getPopupText() {
    return this.getInviteText()
  }

  function getIcon() {
    return "#ui/gameuiskin#battles_open"
  }

  function haveRestrictions() {
    return !isInMenu()
  }

  function getRestrictionText() {
    if (this.haveRestrictions())
      return loc("invite/session/cant_apply_in_flight")
    return ""
  }

  function accept() {
    queues.checkAndStart(
      Callback(function() {
        g_world_war.joinOperationById(this.operationId, null, false,
          Callback(function() {
            let wwBattle = g_world_war.getBattleById(this.battleId)
            gui_handlers.WwBattleDescription.open(wwBattle)
          }, this))
      }, this),
      null, "isCanNewflight")
  }

  function onEventQueueChangeState(p) {
    if (p?.queue?.params?.operationId == this.operationId &&
        p?.queue?.params?.battleId == this.battleId)
      this.remove()
  }
}

registerInviteClass("WwOperationBattle", WwOperationBattle)
