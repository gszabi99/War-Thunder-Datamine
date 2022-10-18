from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

let SquadApplicationsList = class
{
  [PERSISTENT_DATA_PARAMS] = ["applicationsList"]
  popupTextColor = "@chatTextInviteColor"
  applicationsList = {}

  constructor()
  {
    ::g_script_reloader.registerPersistentData("SquadApplicationsList", this, this.PERSISTENT_DATA_PARAMS)
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

/*************************************************************************************************/
/*************************************PUBLIC FUNCTIONS *******************************************/
/*************************************************************************************************/

  function addApplication(squadId, leaderId, isEventNeed = true)
  {
    if (squadId in applicationsList)
      return
    let squad = createApplication(squadId,leaderId)
    applicationsList[squadId] <- squad
    updateApplication(applicationsList[squadId])
    if (isEventNeed)
      sendChangedEvent([leaderId])
  }

  function deleteApplication(squadId, isEventNeed = true)
  {
    if (!(squadId in applicationsList))
      return

    applicationsList.rawdelete(squadId)
    if (isEventNeed)
      sendChangedEvent([squadId])
  }

  function updateApplicationsList(applicationsArr)
  {
    local sid = null
    let leadersArr = []
    local isEventNeed = false
    foreach (squad in applicationsList)
    {
      sid = squad.squadId
      if (isInArray(sid, applicationsArr))
        continue

      leadersArr.append(sid)
      deleteApplication(sid,false)
      isEventNeed = true
    }
    foreach (squadId in applicationsArr)
    {
      if (!(squadId in applicationsList))
      {
        leadersArr.append(squadId)
        addApplication(squadId, squadId, false) // warning disable: -param-pos
        isEventNeed = true
      }
    }
    if (isEventNeed)
      sendChangedEvent(leadersArr)
  }

  function onDeniedApplication(squadId, needPopup = false)
  {
    if (!(squadId in applicationsList))
      return

    if (::g_squad_manager.isInSquad())
      return

    if (needPopup)
    {
      let msg = colorize(popupTextColor,getDeniedPopupText(applicationsList[squadId]))
      ::g_popups.add(null, msg)
    }
    deleteApplication(squadId)
  }

  function onAcceptApplication()
  {
    if (applicationsList.len() <= 0)
      return

    let leadersArr = []
    foreach (squad in applicationsList)
    {
      leadersArr.append(squad.squadId)
    }
    applicationsList.clear()
    sendChangedEvent(leadersArr)
  }

  function hasApplication(leaderId)
  {
    return (leaderId in applicationsList)
  }

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

  function createApplication(squadId,leaderId)
  {
    return {
      squadId = squadId
      leaderId = leaderId
      leaderName = getLeaderName(leaderId)
    }
  }

  function updateApplication(application)
  {
    if (application.leaderName.len() == 0)
    {
      let leaderId = application.leaderId

      let cb = Callback(function(_r)
                            {
                              application.leaderName <- getLeaderName(leaderId)
                            }, this)
      requestUsersInfo([leaderId.tostring()], cb, cb)
    }
  }

  function getLeaderName(leaderId)
  {
    let leaderContact = ::getContact(leaderId.tostring())
    if (!leaderContact)
      return ""

    return leaderContact.name
  }

  function getDeniedPopupText(squad)
  {
    return loc("multiplayer/squad/application/denied",
             {
               name = squad?.leaderName || squad?.leaderId
             })
  }

  function sendChangedEvent(leadersArr)
  {
    ::broadcastEvent("PlayerApplicationsChanged", {leadersArr = leadersArr})
  }

  function onEventSquadStatusChanged(_params)
  {
    if (::g_squad_manager.isInSquad())
      onAcceptApplication()
  }
}

return SquadApplicationsList()