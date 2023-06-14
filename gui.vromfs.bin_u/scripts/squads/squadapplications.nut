//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerPersistentData, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

let SquadApplicationsList = class {
  [PERSISTENT_DATA_PARAMS] = ["applicationsList"]
  popupTextColor = "@chatTextInviteColor"
  applicationsList = {}

  constructor() {
    registerPersistentData("SquadApplicationsList", this, this.PERSISTENT_DATA_PARAMS)
    subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

/*************************************************************************************************/
/*************************************PUBLIC FUNCTIONS *******************************************/
/*************************************************************************************************/

  function addApplication(squadId, leaderId, isEventNeed = true) {
    if (squadId in this.applicationsList)
      return
    let squad = this.createApplication(squadId, leaderId)
    this.applicationsList[squadId] <- squad
    this.updateApplication(this.applicationsList[squadId])
    if (isEventNeed)
      this.sendChangedEvent([leaderId])
  }

  function deleteApplication(squadId, isEventNeed = true) {
    if (!(squadId in this.applicationsList))
      return

    this.applicationsList.rawdelete(squadId)
    if (isEventNeed)
      this.sendChangedEvent([squadId])
  }

  function updateApplicationsList(applicationsArr) {
    local sid = null
    let leadersArr = []
    local isEventNeed = false
    foreach (squad in this.applicationsList) {
      sid = squad.squadId
      if (isInArray(sid, applicationsArr))
        continue

      leadersArr.append(sid)
      this.deleteApplication(sid, false)
      isEventNeed = true
    }
    foreach (squadId in applicationsArr) {
      if (!(squadId in this.applicationsList)) {
        leadersArr.append(squadId)
        this.addApplication(squadId, squadId, false) // warning disable: -param-pos
        isEventNeed = true
      }
    }
    if (isEventNeed)
      this.sendChangedEvent(leadersArr)
  }

  function onDeniedApplication(squadId, needPopup = false) {
    if (!(squadId in this.applicationsList))
      return

    if (::g_squad_manager.isInSquad())
      return

    if (needPopup) {
      let msg = colorize(this.popupTextColor, this.getDeniedPopupText(this.applicationsList[squadId]))
      ::g_popups.add(null, msg)
    }
    this.deleteApplication(squadId)
  }

  function onAcceptApplication() {
    if (this.applicationsList.len() <= 0)
      return

    let leadersArr = []
    foreach (squad in this.applicationsList) {
      leadersArr.append(squad.squadId)
    }
    this.applicationsList.clear()
    this.sendChangedEvent(leadersArr)
  }

  function hasApplication(leaderId) {
    return (leaderId in this.applicationsList)
  }

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

  function createApplication(squadId, leaderId) {
    return {
      squadId = squadId
      leaderId = leaderId
      leaderName = this.getLeaderName(leaderId)
    }
  }

  function updateApplication(application) {
    if (application.leaderName.len() == 0) {
      let leaderId = application.leaderId

      let cb = Callback(function(_r) {
                              application.leaderName <- this.getLeaderName(leaderId)
                            }, this)
      requestUsersInfo([leaderId.tostring()], cb, cb)
    }
  }

  function getLeaderName(leaderId) {
    let leaderContact = ::getContact(leaderId.tostring())
    if (!leaderContact)
      return ""

    return leaderContact.name
  }

  function getDeniedPopupText(squad) {
    return loc("multiplayer/squad/application/denied",
             {
               name = squad?.leaderName || squad?.leaderId
             })
  }

  function sendChangedEvent(leadersArr) {
    broadcastEvent("PlayerApplicationsChanged", { leadersArr = leadersArr })
  }

  function onEventSquadStatusChanged(_params) {
    if (::g_squad_manager.isInSquad())
      this.onAcceptApplication()
  }
}

return SquadApplicationsList()