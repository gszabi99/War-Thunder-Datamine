local SquadApplicationsList = class
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
    local squad = createApplication(squadId,leaderId)
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
    local leadersArr = []
    local isEventNeed = false
    foreach (squad in applicationsList)
    {
      sid = squad.squadId
      if (::isInArray(sid, applicationsArr))
        continue

      leadersArr.append(sid)
      deleteApplication(sid,false)
      isEventNeed = true
    }
    foreach (squadId in applicationsArr)
    {
      if (!(squadId in applicationsList))
      {
        leadersArr.append(sid)
        addApplication(squadId, squadId, false)
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
      local msg = ::colorize(popupTextColor,getDeniedPopupText(applicationsList[squadId]))
      ::g_popups.add(null, msg)
    }
    deleteApplication(squadId)
  }

  function onAcceptApplication()
  {
    if (applicationsList.len() <= 0)
      return

    local leadersArr = []
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
      local leaderId = application.leaderId

      local cb = ::Callback(function(r)
                            {
                              application.leaderName <- getLeaderName(leaderId)
                            }, this)
      ::g_users_info_manager.requestInfo([leaderId.tostring()], cb, cb)
    }
  }

  function getLeaderName(leaderId)
  {
    local leaderContact = ::getContact(leaderId.tostring())
    if (!leaderContact)
      return ""

    return leaderContact.name
  }

  function getDeniedPopupText(squad)
  {
    return ::loc("multiplayer/squad/application/denied",
             {
               name = squad?.leaderName || squad?.leaderId
             })
  }

  function sendChangedEvent(leadersArr)
  {
    ::broadcastEvent("PlayerApplicationsChanged", {leadersArr = leadersArr})
  }

  function onEventSquadStatusChanged(params)
  {
    if (::g_squad_manager.isInSquad())
      onAcceptApplication()
  }
}

return SquadApplicationsList()