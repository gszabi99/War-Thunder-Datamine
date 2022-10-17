::SquadMember <- class
{
  uid = ""
  name = ""
  rank = -1
  country = ""
  clanTag = ""
  pilotIcon = "cardicon_default"
  platform = ""
  online = false
  selAirs = null
  selSlots = null
  crewAirs = null
  brokenAirs = null
  missedPkg = null
  wwOperations = null
  isReady = false
  isCrewsReady = false
  canPlayWorldWar = false
  isWorldWarAvailable = false
  cyberCafeId = ""
  unallowedEventsENames = null
  sessionRoomId = ""
  crossplay = false
  bannedMissions = null
  dislikedMissions = null
  craftsInfoByUnitsGroups = null
  isEacInited = false
  fakeName = false

  isWaiting = true
  isInvite = false
  isApplication = false
  isNewApplication = false
  isInvitedToSquadChat = false

  updatedProperties = ["name", "rank", "country", "clanTag", "pilotIcon", "platform", "selAirs",
                       "selSlots", "crewAirs", "brokenAirs", "missedPkg", "wwOperations",
                       "isReady", "isCrewsReady", "canPlayWorldWar", "isWorldWarAvailable", "cyberCafeId",
                       "unallowedEventsENames", "sessionRoomId", "crossplay", "bannedMissions", "dislikedMissions",
                       "craftsInfoByUnitsGroups", "isEacInited", "fakeName"]

  constructor(v_uid, v_isInvite = false, v_isApplication = false)
  {
    uid = v_uid.tostring()
    isInvite = v_isInvite
    isApplication = v_isApplication
    isNewApplication = v_isApplication

    initUniqueInstanceValues()

    let contact = ::getContact(uid)
    if (contact)
      update(contact)
  }

  function initUniqueInstanceValues()
  {
    selAirs = {}
    selSlots = {}
    crewAirs = {}
    brokenAirs = []
    missedPkg = []
    wwOperations = {}
    unallowedEventsENames = []
    bannedMissions = []
    dislikedMissions = []
    craftsInfoByUnitsGroups = []
  }

  function update(data)
  {
    local newValue = null
    local isChanged = false
    foreach(idx, property in updatedProperties)
    {
      newValue = ::getTblValue(property, data, null)
      if (newValue == null)
        continue

      if (::isInArray(property, ["brokenAirs", "missedPkg","unallowedEventsENames",     //!!!FIX ME If this parametrs is empty then msquad returns table instead array
             "bannedMissions", "dislikedMissions", "craftsInfoByUnitsGroups"])        // Need remove this block after msquad fixed
          && !::u.isArray(newValue))
        newValue = []

      if (newValue != this[property])
      {
        this[property] = newValue
        isChanged = true
      }
    }
    isWaiting = false
    return isChanged
  }

  function isActualData()
  {
    return !isWaiting && !isInvite
  }

  function canJoinSessionRoom()
  {
    return isReady && sessionRoomId == ""
  }

  function getData()
  {
    let result = {uid = uid}
    foreach(idx, property in updatedProperties)
      if (!::u.isEmpty(this[property]))
        result[property] <- this[property]

    return result
  }

  function getWwOperationCountryById(wwOperationId)
  {
    foreach (operationData in wwOperations)
      if (operationData?.id == wwOperationId)
        return operationData?.country

    return null
  }

  function isEventAllowed(eventEconomicName)
  {
    return !::isInArray(eventEconomicName, unallowedEventsENames)
  }

  function isMe()
  {
    return uid == ::my_user_id_str
  }
}