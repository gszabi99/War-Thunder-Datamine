import "%scripts/g_listener_priority.nut" as g_listener_priority
from "%scripts/squads/squadState.nut" import isInSquad
from "%scripts/user/usersInfoManager.nut" import requestUsersInfo
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/contacts/contacts.nut" import getContact
from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler, broadcastEvent
from "%scripts/dagui_library.nut" import *

let applicationsList = mkHardPersist("squads.squadApplications")("applicationsList", {})
let pendingUsersIds = {}

const popupTextColor = "@chatTextInviteColor"

let SquadApplicationsList = freeze({





  function addApplication(squadId, leaderId, isEventNeed = true) {
    if (squadId in applicationsList)
      return
    let squad = this.createApplication(squadId, leaderId)
    applicationsList[squadId] <- squad
    this.updateApplication(applicationsList[squadId])
    if (isEventNeed)
      this.sendChangedEvent([leaderId])
  }

  function deleteApplication(squadId, isEventNeed = true) {
    if (!(squadId in applicationsList))
      return

    applicationsList.$rawdelete(squadId)
    if (isEventNeed)
      this.sendChangedEvent([squadId])
  }

  function updateApplicationsList(applicationsArr) {
    local sid = null
    let leadersArr = []
    local isEventNeed = false
    foreach (squad in applicationsList) {
      sid = squad.squadId
      if (isInArray(sid, applicationsArr))
        continue

      leadersArr.append(sid)
      this.deleteApplication(sid, false)
      isEventNeed = true
    }
    foreach (squadId in applicationsArr) {
      if (!(squadId in applicationsList)) {
        leadersArr.append(squadId)
        this.addApplication(squadId, squadId, false) 
        isEventNeed = true
      }
    }
    if (isEventNeed)
      this.sendChangedEvent(leadersArr)
  }

  function onDeniedApplication(squadId, needPopup = false) {
    if (!(squadId in applicationsList))
      return

    if (isInSquad())
      return

    if (needPopup) {
      let msg = colorize(popupTextColor, this.getDeniedPopupText(applicationsList[squadId]))
      addPopup(null, msg)
    }
    this.deleteApplication(squadId)
  }

  function onAcceptApplication() {
    if (applicationsList.len() <= 0)
      return

    let leadersArr = []
    foreach (squad in applicationsList) {
      leadersArr.append(squad.squadId)
    }
    applicationsList.clear()
    this.sendChangedEvent(leadersArr)
  }

  function hasApplication(leaderId) {
    return (leaderId in applicationsList)
  }





  function createApplication(squadId, leaderId) {
    return {
      squadId = squadId
      leaderId = leaderId
      leaderName = this.getLeaderName(leaderId)
    }
  }

  function updateApplication(application) {
    if (application.leaderName.len() != 0)
      return

    let { leaderId } = application
    pendingUsersIds[leaderId] <- application
    requestUsersInfo(leaderId.tostring())
  }

  function getLeaderName(leaderId) {
    let leaderContact = getContact(leaderId.tostring())
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
    if (isInSquad())
      this.onAcceptApplication()
  }

  function onEventUserInfoManagerDataUpdated(params) {
    let idsToRemove = []
    foreach (userId, _ in pendingUsersIds) {
      if (userId not in params.usersInfo)
        continue
      let app = pendingUsersIds[userId]
      app.leaderName <- this.getLeaderName(userId)
      idsToRemove.append(userId)
    }

    foreach (userId in idsToRemove)
      pendingUsersIds.$rawdelete(userId)
  }
})

subscribe_handler(SquadApplicationsList, g_listener_priority.DEFAULT_HANDLER)
foreach (application in applicationsList) 
  SquadApplicationsList.updateApplication(application)

return SquadApplicationsList