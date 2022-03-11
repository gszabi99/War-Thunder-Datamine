let u = require("sqStdLibs/helpers/u.nut")

const ANY_CHANGED_ID = "___ANY___"
const SUBSCRIPTIONS_TO_CHECK_CLEAR = 10

let subscriptions = {} //<listId> = { <entityId> = array of callbacks }

let function getListSubscriptions(listId)
{
  if (!(listId in subscriptions))
    subscriptions[listId] <- {}
  return subscriptions[listId]
}

let function validateSubscriptionsArray(subArr)
{
  for(local i = subArr.len() - 1; i >= 0; i--)
    if (!subArr[i].isValid())
      subArr.remove(i)
}

let function addSubscription(subList, entityName, cb)
{
  if (!(entityName in subList))
    subList[entityName] <- []
  let subArr = subList[entityName]
  subArr.append(cb)
  if (subArr.len() % SUBSCRIPTIONS_TO_CHECK_CLEAR == 0)
    validateSubscriptionsArray(subArr)
}

let function subscribe(listId, entitiesList, cb)
{
  let subList = getListSubscriptions(listId)
  if (!entitiesList)
  {
    addSubscription(subList, ANY_CHANGED_ID, cb)
    return
  }

  foreach(entityName in entitiesList)
    addSubscription(subList, entityName, cb)
}

let function gatherCbFromList(subArr, resList)
{
  if (!subArr)
    return
  for(local i = subArr.len() - 1; i >= 0; i--)
    if (subArr[i].isValid())
      u.appendOnce(subArr[i], resList)
    else
      subArr.remove(i)
}

let function notifyChanged(listId, entitiesList)
{
  let subList = getListSubscriptions(listId)
  let notifyList = []
  if (entitiesList)
  {
    gatherCbFromList(subList?[ANY_CHANGED_ID], notifyList)
    foreach(entity in entitiesList)
      gatherCbFromList(subList?[entity], notifyList)
  }
  else
    foreach(entity, list in subList)
      gatherCbFromList(subList[entity], notifyList)

  foreach(cb in notifyList)
    cb()
}

return {
  subscribe = subscribe
  notifyChanged = notifyChanged
}