let { Watched } = require("frp")
let { setTimeout } = require("dagor.workcycle")
let { kwarg } = require("%sqstd/functools.nut")

//when event have parameter ttl it will be automatically removed on time finish
//isEventsEqual = @(event1, event2) bool - used only to remove events not only by uid.
//  Previous equal event will be removed on receive new event.
let function mkEventLogState(persistId, maxActiveEvents = 10, defTtl = 0, isEventsEqual = null
) {
  let savedEvents = persist(persistId, @() { v = [] })
  let curEvents = Watched(savedEvents.v)
  curEvents.subscribe(@(v) savedEvents.v = v)
  local lastEventUid = curEvents.value?[curEvents.value.len() - 1].uid ?? 0

  let getEqualIndex = @(event) isEventsEqual == null ? null
    : curEvents.value.findindex(@(e) isEventsEqual(event, e))

  let function removeEvent(uidOrEvent) {
    let idx = type(uidOrEvent) == "integer" ? curEvents.value.findindex(@(e) e.uid == uidOrEvent)
      : getEqualIndex(uidOrEvent)
    if (idx != null)
      curEvents.mutate(@(list) list.remove(idx))
  }

  let function startRemoveTimer(event) {
    let { ttl = defTtl, uid } = event
    if (ttl > 0)
      setTimeout(ttl, @() removeEvent(uid))
  }
  curEvents.value.each(startRemoveTimer)

  let function addEvent(eventExt) {
    let uid = ++lastEventUid
    let event = eventExt.__merge({ uid })

    let idxToRemove = getEqualIndex(event)
      ?? (curEvents.value.len() >= maxActiveEvents ? 0 : null)

    curEvents.mutate(function(list) {
      if (idxToRemove != null)
        list.remove(idxToRemove)
      list.append(event)
    })
    startRemoveTimer(event)
  }

  let clearEvents = @() curEvents([])

  foreach(func in [addEvent, removeEvent, clearEvents])
    curEvents.whiteListMutatorClosure(func)

  return {
    curEvents
    addEvent
    removeEvent
    clearEvents
  }
}

return kwarg(mkEventLogState)