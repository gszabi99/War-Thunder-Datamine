local u = ::require("sqStdLibs/helpers/u.nut")
local time = require("scripts/time.nut")
local seenListEvents = require("scripts/seen/seenListEvents.nut")

local activeSeenLists = {}

local SeenList = class {
  id = "" //unique list id

  listGetter = null
  canBeNew = null

  isInited = false
  entitiesData = null
  compatibilityLoadData = null

  subListGetters = null

  daysToUnseen = -1

  constructor(listId)
  {
    id = listId
    activeSeenLists[id] <- this
    setCanBeNewFunc(@(entity) true)

    entitiesData = {}
    subListGetters = {}
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function setListGetter(getter)
  {
    listGetter = getter
  }

  //sublistId must be uniq with usual entities, because they able to be used in usual entities list
  function setSubListGetter(sublistId, subListGetterFunc)
  {
    subListGetters[sublistId] <- subListGetterFunc
  }
  isSubList = @(name) name in subListGetters

  //make entity unseen if it missing in the list for such amount of days
  //better to set this when full list available by listGetter
  function setDaysToUnseen(days)
  {
    daysToUnseen = days
    validateEntitesDays()
  }

  //when no data in the current storage, this function will be called to gather data fromprevious storage.
  //func result must be table { <entity> = <last seen days> }
  //better also clear data in the previous storage, beacuse result will be saved in correct place.
  //so compatibility function will be called only once per account.
  function setCompatibilityLoadData(func)
  {
    compatibilityLoadData = func
  }

  //func = (bool) function(entity). Returns can entity from the list be marked as new or not
  function setCanBeNewFunc(func)
  {
    canBeNew = func
  }

  //call this when list which can be received by listGetter has changed
  function onListChanged()
  {
    validateEntitesDays()
    seenListEvents.notifyChanged(id, null)
  }

  isNew      = @(entity) !(entity in entitiesData) && canBeNew(entity)
  isNewSaved = @(entity) !(entity in entitiesData)
  hasSeen    = @() entitiesData.len() > 0

  //when null, will mark all entities received by listGetter
  markSeen   = @(entityOrList = null) setSeen(entityOrList, true)
  markUnseen = @(entityOrList = null) setSeen(entityOrList, false)

  function getNewCount(entityList = null) //when null, count all entities
  {
    initOnce()

    local res = 0
    if (!entityList)
      if (listGetter)
        entityList = listGetter()
      else
        return res

    foreach(name in entityList)
      if (isSubList(name))
      {
        if (subListGetters[name])
          res += getNewCount(subListGetters[name]())
      }
      else if (isNew(name))
        res++
    return res
  }

  function clearSeenData()
  {
    entitiesData.clear()
    save()
    seenListEvents.notifyChanged(id, null)
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function initOnce()
  {
    if (isInited || !::g_login.isProfileReceived())
      return
    isInited = true

    entitiesData.clear()
    local blk = ::load_local_account_settings(getSaveId())
    if (u.isDataBlock(blk))
      for (local i = 0; i < blk.paramCount(); i++)
        entitiesData[blk.getParamName(i)] <- blk.getParamValue(i)
    else if (compatibilityLoadData)
    {
      entitiesData = compatibilityLoadData()
      if (entitiesData.len())
        save()
    }

    validateEntitesDays()
  }

  function validateEntitesDays()
  {
    if (daysToUnseen < 0 || !isInited || !listGetter)
      return

    local hasChanges = false
    local curDays = time.getUtcDays()
    local entitiesList = listGetter()

    foreach(entity in entitiesList)
      if ((entity in entitiesData) && entitiesData[entity] != curDays)
      {
        entitiesData[entity] = curDays
        hasChanges = true
      }

    local removeList = []
    foreach(entity, days in entitiesData)
      if (days + daysToUnseen < curDays)
        removeList.append(entity)

    hasChanges = hasChanges || removeList.len()
    foreach(entity in removeList)
      delete entitiesData[entity]

    if (hasChanges)
      save()
  }

  getSaveId = @() "seen/" + id

  function save()
  {
    local saveBlk = null
    if (entitiesData.len())
    {
      saveBlk = ::DataBlock()
      foreach(name, day in entitiesData)
        saveBlk[name] = day
    }
    ::save_local_account_settings(getSaveId(), saveBlk)
  }

  function setSeen(entityOrList, shouldSeen)
  {
    if (!::g_login.isProfileReceived()) //Don't try to mark or init seen list before profile received
      return

    initOnce()

    if (!entityOrList)
      if (listGetter)
        entityOrList = listGetter()
      else
        return

    local entityList = (u.isArray(entityOrList) || u.isTable(entityOrList)) ? entityOrList : [entityOrList]
    local changedList = []
    local curDays = time.getUtcDays()
    foreach(entity in entityList)
    {
      if (isSubList(entity))
      {
        ::script_net_assert_once("Seen " + id + ": try to setSeen for subList " + entity)
        continue
      }
      if (!canBeNew(entity))
        continue //no need to hcange seen state for entities that can't be new.
                 //they need to be marked unseen when they become can be new.
      if (isNewSaved(entity) == shouldSeen)
        changedList.append(entity)
      if (shouldSeen)
        entitiesData[entity] <- curDays
      else if (entity in entitiesData)
        delete entitiesData[entity]
    }

    if (changedList.len())
    {
      seenListEvents.notifyChanged(id, changedList)
      save()
    }
  }

  function onEventSignOut(p)
  {
    isInited = false
    entitiesData.clear()
  }

  function onEventAccountReset(p)
  {
    clearSeenData()
  }
}

return {
  get = @(id) activeSeenLists?[id] ?? SeenList(id)
  isSeenList = @(id) activeSeenLists?[id] != null

  clearAllSeenData = function()
  {
    foreach(seenList in activeSeenLists)
      seenList.clearSeenData()
  }
}