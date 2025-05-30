from "%rGui/globals/ui_library.nut" import *

function getTexReplaceString(item) {
  let { objTexReplace = null } = item
  if (objTexReplace == null)
    return ""

  if (type(objTexReplace) == "string")
    return objTexReplace

  let ruleSets = type(objTexReplace) == "array" ? objTexReplace : [objTexReplace]
  let list = []
  foreach (idx, set in ruleSets) {
    list.append($"r{idx}")
    list.append("{")
    foreach (from, to in set)
      list.append($"objTexReplace:t={from};objTexReplace:t={to};")
    list.append("}")
  }
  return "".join(list)
}

function getTexSetString(item) {
  let { objTexSet = null } = item
  if (objTexSet == null)
    return ""

  let ruleSets = type(objTexSet) == "array" ? objTexSet : [objTexSet]
  let list = []
  foreach (idx, set in ruleSets) {
    list.append($"r{idx}")
    list.append("{")
    foreach (key, pair in set) {
      let from = pair?.keys()[0]
      let to = pair?[from]
      if (from != null && to != null) {
        list.append($"objTexSet:t={key};objTexSet:t={from};objTexSet:t={to};")
      }
    }
    list.append("}")
  }
  return "".join(list)
}

return {
  getTexReplaceString
  getTexSetString
}