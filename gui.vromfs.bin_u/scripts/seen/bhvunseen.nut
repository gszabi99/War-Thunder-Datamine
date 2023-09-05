//checked for plus_string
from "%scripts/dagui_library.nut" import *


let u = require("%sqStdLibs/helpers/u.nut")
let { parse_json } = require("json")
let seenList = require("%scripts/seen/seenList.nut")
let seenListEvents = require("%scripts/seen/seenListEvents.nut")

/*
  behaviour config params:
  listId = uniq seen List Id
  entity = null, uniq entity id, or array of uniq entity ids
             when entityId is null, full list will be used

  when need only listId without entities, you can setValue(listId) without preprocessing
*/

let BhvUnseen = class {
  eventMask    = EV_ON_CMD
  valuePID     = ::dagui_propid.add_name_id("value")

  function onAttach(obj) {
    if (obj?.value)
      this.setNewConfig(obj, this.buildConfig(obj.value))
    this.updateView(obj)
    return RETCODE_NOTHING
  }

  function buildConfig(value) {
    local seenData = this.getVerifiedData(value)

    if (!u.isArray(seenData))
      return [this.getConfig(seenData)]

    seenData = seenData.map((@(s) this.getVerifiedData(s)).bindenv(this))

    return seenData.map((@(s) this.getConfig(s)).bindenv(this))
  }

  function getVerifiedData(value) {
    if (value == "")
      return null
    return u.isString(value)
      ? seenList.isSeenList(value)
        ? { listId = value }
        : parse_json(value)
      : u.isTable(value)
        ? value
        : null
  }

  function getConfig(valueTbl) {
    if (!valueTbl?.listId)
      return null

    let entity = valueTbl?.entity
    let list = u.isArray(entity) ? entity
      : u.isString(entity) ? [entity]
      : null

    return {
      seen = seenList.get(valueTbl.listId)
      entitiesList = list
      hasCounter = !list || list.len() > 1
    }
  }

  function setValue(obj, valueTbl) {
    this.setNewConfig(obj, this.buildConfig(valueTbl))
    this.updateView(obj)
    return u.isString(valueTbl) || u.isTable(valueTbl)
  }

  function setNewConfig(obj, config) {
    obj.setUserData(config) //this is single direct link to config.
                            //So destroy object, or change user data invalidate old subscriptions.
    if (!config)
      return

    foreach (seenData in config) {
      if (!seenData?.seen)
        continue

      local entities = seenData?.entitiesList
      if (entities)
        foreach (entity in entities)
          if (seenData.seen.isSubList(entity)) {
            entities = null //when has sublist, need to subscribe for any changes for current seen list
            seenData.hasCounter = true
            break
          }

      seenListEvents.subscribe(seenData.seen.id, entities,
        Callback(this.getOnSeenChangedCb(obj), seenData))
    }
  }

  function getOnSeenChangedCb(obj) {
    let bhvClass = this
    return @() checkObj(obj) && bhvClass.updateView(obj)
  }

  function updateView(obj) {
    let config = obj.getUserData()
    local hasCounter = false
    local count = 0

    if (config)
      foreach (seenData in config)
        if (seenData) {
          count += seenData.seen.getNewCount(seenData.entitiesList)
          hasCounter = hasCounter || seenData.hasCounter
        }

    obj.isActive = count ? "yes" : "no"

    if (!count || !obj.childrenCount())
      return

    let textObj = obj.getChild(0)
    textObj.isActive = hasCounter ? "yes" : "no"

    if (hasCounter)
      textObj.setValue(count.tostring())
  }
}

::replace_script_gui_behaviour("bhvUnseen", BhvUnseen)

let makeConfig = @(listId, entity = null) { listId, entity }
let makeConfigStr = @(listId, entity = null)
  entity ? ::save_to_json(makeConfig(listId, entity)) : listId
let makeConfigStrByList = @(unseenList) ::save_to_json(unseenList)

return {
  makeConfig
  makeConfigStr
  makeConfigStrByList
}
