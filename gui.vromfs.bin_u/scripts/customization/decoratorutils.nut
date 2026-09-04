from "%sqstd/string.nut" import utf8ToLower

function filterDecorators(decorsList, decorType, filterOptions) {
  let { onlyRecieved = false, searchName = "" } = filterOptions
  if (!onlyRecieved && searchName == "")
    return decorsList

  let filtered = decorsList.filter(function(v) {
    if ((searchName != "") && utf8ToLower(v.getName()).indexof(searchName) == null)
      return false
    if (onlyRecieved && !decorType.isPlayerHaveDecorator(v.id))
      return false
    return true
  })
  return filtered
}

return {
  filterDecorators
}