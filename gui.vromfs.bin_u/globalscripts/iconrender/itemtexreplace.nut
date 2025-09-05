function getTexReplaceString(item) {
  let { objTexReplace = null } = item
  if (typeof(objTexReplace) != "table" || objTexReplace.len() == 0)
    return ""

  local list = ""
  foreach (from, to in objTexReplace)
    list = "".concat(list, $"objTexReplace:t={from};objTexReplace:t={to};")

  return $"r0{list}"
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