from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let u = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let seenListEvents = require("%scripts/seen/seenListEvents.nut")
let { register_command } = require("console")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

let activeSeenLists = {}

local SeenList = class {
  id = "" 

  listGetter = null
  canBeNew = null

  isInited = false
  entitiesData = null
  compatibilityLoadData = null

  subListGetters = null

  daysToUnseen = -1

  constructor(listId) {
    this.id = listId
    activeSeenLists[listId] <- this
    this.setCanBeNewFunc(@(_entity) true)

    this.entitiesData = {}
    this.subListGetters = {}
    subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
  }

  
  
  

  function setListGetter(getter) {
    this.listGetter = getter
  }

  
  function setSubListGetter(sublistId, subListGetterFunc) {
    this.subListGetters[sublistId] <- subListGetterFunc
  }
  isSubList = @(name) name in this.subListGetters

  
  
  function setDaysToUnseen(days) {
    this.daysToUnseen = days
    this.validateEntitesDays()
  }

  
  
  
  
  function setCompatibilityLoadData(func) {
    this.compatibilityLoadData = func
  }

  
  function setCanBeNewFunc(func) {
    this.canBeNew = func
  }

  
  function onListChanged() {
    this.validateEntitesDays()
    seenListEvents.notifyChanged(this.id, null)
  }

  isNew      = @(entity) !(entity in this.entitiesData) && this.canBeNew(entity)
  isNewSaved = @(entity) !(entity in this.entitiesData)
  hasSeen    = @() this.entitiesData.len() > 0

  
  markSeen   = @(entityOrList = null) this.setSeen(entityOrList, true)
  markUnseen = @(entityOrList = null) this.setSeen(entityOrList, false)

  function getNewCount(entityList = null) { 
    this.initOnce()

    local res = 0
    if (!entityList)
      if (this.listGetter)
        entityList = this.listGetter()
      else
        return res

    foreach (name in entityList)
      if (this.isSubList(name)) {
        if (this.subListGetters[name])
          res += this.getNewCount(this.subListGetters[name]())
      }
      else if (this.isNew(name))
        res++
    return res
  }

  function clearSeenData() {
    this.entitiesData.clear()
    this.save()
    seenListEvents.notifyChanged(this.id, null)
  }

  
  
  

  function initOnce() {
    if (this.isInited || !isProfileReceived.get())
      return
    this.isInited = true

    this.entitiesData.clear()
    let blk = loadLocalAccountSettings(this.getSaveId())
    if (u.isDataBlock(blk))
      for (local i = 0; i < blk.paramCount(); i++)
        this.entitiesData[blk.getParamName(i)] <- blk.getParamValue(i)
    else if (this.compatibilityLoadData) {
      this.entitiesData = this.compatibilityLoadData()
      if (this.entitiesData.len())
        this.save()
    }

    this.validateEntitesDays()
  }

  function validateEntitesDays() {
    if (this.daysToUnseen < 0 || !this.isInited || !this.listGetter)
      return

    local hasChanges = false
    let curDays = time.getUtcDays()
    let entitiesList = this.listGetter()

    foreach (entity in entitiesList)
      if ((entity in this.entitiesData) && this.entitiesData[entity] != curDays) {
        this.entitiesData[entity] = curDays
        hasChanges = true
      }

    let removeList = []
    foreach (entity, days in this.entitiesData)
      if (days + this.daysToUnseen < curDays)
        removeList.append(entity)

    hasChanges = hasChanges || removeList.len()
    foreach (entity in removeList)
      this.entitiesData.$rawdelete(entity)

    if (hasChanges)
      this.save()
  }

  getSaveId = @() $"seen/{this.id}"

  function save() {
    local saveBlk = null
    if (this.entitiesData.len()) {
      saveBlk = DataBlock()
      foreach (name, day in this.entitiesData)
        saveBlk[name] = day
    }
    saveLocalAccountSettings(this.getSaveId(), saveBlk)
  }

  function setSeen(entityOrList, shouldSeen) {
    if (!isProfileReceived.get()) 
      return

    this.initOnce()

    if (!entityOrList)
      if (this.listGetter)
        entityOrList = this.listGetter()
      else
        return

    let entityList = (u.isArray(entityOrList) || u.isTable(entityOrList)) ? entityOrList : [entityOrList]
    let changedList = []
    let curDays = time.getUtcDays()
    foreach (entity in entityList) {
      if (this.isSubList(entity)) {
        script_net_assert_once(false, $"Seen {this.id}: try to setSeen for subList {entity}")
        continue
      }
      if (!this.canBeNew(entity))
        continue 
                 
      if (this.isNewSaved(entity) == shouldSeen)
        changedList.append(entity)
      if (shouldSeen)
        this.entitiesData[entity] <- curDays
      else if (entity in this.entitiesData)
        this.entitiesData.$rawdelete(entity)
    }

    if (changedList.len()) {
      seenListEvents.notifyChanged(this.id, changedList)
      this.save()
    }
  }

  function onEventSignOut(_p) {
    this.isInited = false
    this.entitiesData.clear()
  }

  function onEventAccountReset(_p) {
    this.clearSeenData()
  }
}

function clearAllSeenData() {
  foreach (seenList in activeSeenLists)
    seenList.clearSeenData()
}

register_command(clearAllSeenData, "debug.reset_unseen")

return {
  get = @(id) activeSeenLists?[id] ?? SeenList(id)
  isSeenList = @(id) activeSeenLists?[id] != null
}