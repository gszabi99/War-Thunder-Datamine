from "dagor.workcycle" import resetTimeout
from "math" import max
import "%globalScripts/sharedWatched.nut" as sharedWatched


function mkStack(name, params) {
  let { maxCount, showSec, fadeSec, appearSec, isUnique = false, isOverflowDropped = false } = params
  let entries = sharedWatched(name, @() [])
  local lastId = entries.get().reduce(@(res, e) max(res, e.id), 0)

  let findEntry = @(id) entries.get().findvalue(@(e) e.id == id)

  function dropEntry(id) {
    entries.mutate(function(list) {
      let idx = list.findindex(@(e) e.id == id)
      if (idx != null)
        list.remove(idx)
    })
  }

  function startFade(id) {
    let entry = findEntry(id)
    if (entry == null || entry.isFading)
      return
    entries.mutate(@(_) entry.isFading = true)
    resetTimeout(fadeSec, @() dropEntry(id), $"{name}Drop{id}")
  }

  function endAppear(id) {
    let entry = findEntry(id)
    if (entry?.isNew)
      entries.mutate(@(_) entry.isNew = false)
  }

  let restartShow = @(id) resetTimeout(showSec, @() startFade(id), $"{name}Fade{id}")

  
  if (require_optional("daguiScene") != null) {
    entries.set(entries.get().filter(@(e) !e.isFading))
    entries.get().each(@(e) restartShow(e.id))
  }

  function push(text, msgId = -1) {
    let visible = entries.get().filter(@(e) !e.isFading)
    let shown = !isUnique ? null
      : visible.findvalue(@(e) msgId != -1 ? e.msgId == msgId : e.text == text)
    if (shown != null) {
      if (shown.text != text || shown.msgId != msgId)
        entries.mutate(function(_) {
          shown.text = text
          shown.msgId = msgId
        })
      restartShow(shown.id)
      return
    }
    if (visible.len() >= maxCount)
      (isOverflowDropped ? dropEntry : startFade)(visible[0].id)
    lastId++
    let id = lastId
    entries.mutate(@(list) list.append({ id, msgId, text, isNew = true, isFading = false }))
    resetTimeout(appearSec, @() endAppear(id), $"{name}Shown{id}")
    restartShow(id)
  }

  return freeze({
    entries
    push
    clear = @() entries.set([])
    fadeSec
    appearSec
  })
}

let killFeed = mkStack("killFeed", { maxCount = 5, showSec = 11, fadeSec = 10, appearSec = 0.1 })
const notificationParams = { maxCount = 3, showSec = 5, fadeSec = 0.3, appearSec = 0.3, isUnique = true, isOverflowDropped = true }
let tankNotifications = mkStack("tankNotifications", notificationParams)
let shipNotifications = mkStack("shipNotifications", notificationParams)
let playerDamage = mkStack("playerDamage", notificationParams)
let hintMessagesHeight = sharedWatched("hintMessagesHeight", @() 0)

return freeze({
  killFeed
  tankNotifications
  shipNotifications
  playerDamage
  hintMessagesHeight
})
