from "%scripts/dagui_library.nut" import *
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { isEqual, isArray, isEmpty } = require("%sqStdLibs/helpers/u.nut")

let class SquadMember {
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
  presenceStatus = null
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
  queueProfileJwt = ""
  isGdkClient = false

  isWaiting = true
  isInvite = false
  isApplication = false
  isNewApplication = false
  isInvitedToSquadChat = false

  needSendFullData = true
  isFullDataReceived = false

  updatedProperties = ["name", "rank", "country", "clanTag", "pilotIcon", "platform", "selAirs",
                       "selSlots", "crewAirs", "brokenAirs", "missedPkg", "wwOperations",
                       "isReady", "isCrewsReady", "canPlayWorldWar", "isWorldWarAvailable", "cyberCafeId",
                       "unallowedEventsENames", "sessionRoomId", "crossplay", "bannedMissions", "dislikedMissions",
                       "craftsInfoByUnitsGroups", "isEacInited", "fakeName", "queueProfileJwt", "presenceStatus", "isGdkClient"]

  constructor(v_uid, v_isInvite = false, v_isApplication = false) {
    this.uid = v_uid.tostring()
    this.isInvite = v_isInvite
    this.isApplication = v_isApplication
    this.isNewApplication = v_isApplication

    this.initUniqueInstanceValues()

    let contact = getContact(this.uid)
    if (contact)
      this.update(contact)
  }

  function initUniqueInstanceValues() {
    this.selAirs = {}
    this.selSlots = {}
    this.crewAirs = {}
    this.brokenAirs = []
    this.missedPkg = []
    this.wwOperations = {}
    this.unallowedEventsENames = []
    this.bannedMissions = []
    this.dislikedMissions = []
    this.craftsInfoByUnitsGroups = []
  }

  function update(data) {
    local newValue = null
    local isChanged = false
    let updatedData = {}
    foreach (_idx, property in this.updatedProperties) {
      newValue = getTblValue(property, data, null)
      if (newValue == null)
        continue

      if (isInArray(property, ["brokenAirs", "missedPkg", "unallowedEventsENames",     
             "bannedMissions", "dislikedMissions", "craftsInfoByUnitsGroups"])        
          && !isArray(newValue))
        newValue = []

      if (!isEqual(newValue, this[property])) {
        this[property] = newValue
        updatedData[property] <- newValue
        isChanged = true
      }
    }
    this.isWaiting = false
    return { isChanged, updatedData }
  }

  function isActualData() {
    return !this.isWaiting && !this.isInvite
  }

  function canJoinSessionRoom() {
    return this.isReady && this.sessionRoomId == ""
  }

  function getData() {
    let result = { uid = this.uid }
    foreach (_idx, property in this.updatedProperties)
      if (!isEmpty(this[property]))
        result[property] <- this[property]

    return result
  }

  function getWwOperationCountryById(wwOperationId) {
    foreach (operationData in this.wwOperations)
      if (operationData?.id == wwOperationId)
        return operationData?.country

    return null
  }

  function isEventAllowed(eventEconomicName) {
    return !isInArray(eventEconomicName, this.unallowedEventsENames)
  }

  function isMe() {
    return this.uid == userIdStr.get()
  }
}

return SquadMember
