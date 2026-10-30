from "frp" import Watched, Computed
import "%globalScripts/sharedWatched.nut" as sharedWatched


let isOneUiVm = require_optional("daRg") != null && require_optional("daguiScene") != null
let mkUiWatched = @(name, ctor) isOneUiVm ? Watched(ctor()) : sharedWatched(name, ctor)


function mkScreenModel(name, mkFields) {
  let screen = mkUiWatched($"{name}.screen", mkFields)
  
  let items = mkUiWatched($"{name}.items", @() {})
  let itemWatches = {}

  function itemW(id) {
    if (id not in itemWatches)
      itemWatches[id] <- Computed(@() items.get()?[id])
    return itemWatches[id]
  }

  let setField = @(field, value) screen.mutate(@(s) s[field] = value)

  function setItem(id, field, value) {
    let item = items.get()?[id]
    if (item != null && field in item && item[field] == value)
      return
    items.mutate(@(v) v[id] <- (item ?? {}).__merge({ [field] = value }))
  }

  function reset() {
    itemWatches.clear()
    screen.set(mkFields())
    items.set({})
  }

  return { screen, items, itemW, setField, setItem, reset }
}

return freeze({
  mkScreenModel
  mkUiWatched
})
