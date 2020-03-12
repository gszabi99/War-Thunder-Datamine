local stdSubscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local function isArray(v) {return type(v)=="array"}

const SUBSCRPTIONS_LIST_ID = -123
const SUBSCRIPTIONS_TO_CHECK_CLEAR = 10

local subscriptions = {} //<listId> = { [SUBSCRPTIONS_LIST_ID] = array of subsctiptions
                         //             <subListId> = table of same subscriptions }

local eventId = 0

local function getSubList(subs, key)
{
  if (!(key in subs))
    subs[key] <- {}
  return subs[key]
}

local function getSubscriptions(pathArray)
{
  local res = subscriptions
  foreach(key in pathArray)
    res = getSubList(res, key)
  return res
}

local function validateSubscriptionsArray(subArr)
{
  for(local i = subArr.len() - 1; i >= 0; i--)
    if (!subArr[i].isValid())
      subArr.remove(i)
}

local function addSubscription(subs, cb)
{
  if (!(SUBSCRPTIONS_LIST_ID in subs))
    subs[SUBSCRPTIONS_LIST_ID] <- []
  local subArr = subs[SUBSCRPTIONS_LIST_ID]
  subArr.append(cb)
  if (subArr.len() % SUBSCRIPTIONS_TO_CHECK_CLEAR == 0)
    validateSubscriptionsArray(subArr)
}

local function subscribe(pathArray, cb)
{
  if (!isArray(pathArray.top()))
  {
    addSubscription(getSubscriptions(pathArray), cb)
    return
  }

  local basePath = clone pathArray
  basePath.remove(basePath.len() - 1)
  local subs = getSubscriptions(basePath)
  local keys = pathArray.top()
  foreach(key in keys)
    addSubscription(getSubList(subs, key), cb)
}

local fireCb = function(subs)
{
  if (!(SUBSCRPTIONS_LIST_ID in subs))
    return

  local list = subs[SUBSCRPTIONS_LIST_ID]
  for(local i = list.len() - 1; i >= 0; i--)
    if (list[i].isValid())
      list[i](eventId)
    else
      list.remove(i)
}

local fireAllCb
fireAllCb = function(subs) //this function will never remove from memory, but can recursive call.
{
  fireCb(subs)
  foreach(key, list in subs)
    if (key != SUBSCRPTIONS_LIST_ID)
      fireAllCb(list)
}

local function notifyChanged(pathArray)
{
  eventId++
  local subList = subscriptions
  for( local i = 0; i < pathArray.len() - 1; i++ )
  {
    subList = subList?[pathArray[i]]
    if (!subList)
      break
    fireCb(subList)
  }

  if (subList)
  {
    local lastKeys = pathArray.top()
    if (!isArray(lastKeys))
      lastKeys = [lastKeys]
    foreach(key in lastKeys)
      if (key in subList)
        fireAllCb(subList[key])
  }
}

local clearInvalidSubscriptions
clearInvalidSubscriptions = function(subs) //this function will never remove from memory, but can recursive call.
{
  foreach(key, list in subs)
  {
    if (key != SUBSCRPTIONS_LIST_ID)
    {
      clearInvalidSubscriptions(list)
      if (list.len() == 0)
        subs.rawdelete(key)
      continue
    }

    if (list.len() > 0)
      validateSubscriptionsArray(list)

    if (list.len() == 0)
      subs.rawdelete(key)
  }
}

//all subscriptions for dagui objects, so we can clear all on full scene reload.
stdSubscriptions.addEventListener("GuiSceneCleared",
  @(p) clearInvalidSubscriptions(subscriptions),
  null,
  stdSubscriptions.CONFIG_VALIDATION)

return {
  subscribe = subscribe
  notifyChanged = notifyChanged
}