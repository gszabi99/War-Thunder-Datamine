from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")

let applicationsList = persist("applicationsList", @() {})
let popupTextColor = "@chatTextInviteColor"

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

    if (g_squad_manager.isInSquad())
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
    if (application.leaderName.len() == 0) {
      let leaderId = application.leaderId

      let cb = Callback(function(_r) {
                              application.leaderName <- this.getLeaderName(leaderId)
                            }, this)
      requestUsersInfo([leaderId.tostring()], cb, cb)
    }
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
    if (g_squad_manager.isInSquad())
      this.onAcceptApplication()
  }
})

subscribe_handler(SquadApplicationsList, g_listener_priority.DEFAULT_HANDLER)

return SquadApplicationsList