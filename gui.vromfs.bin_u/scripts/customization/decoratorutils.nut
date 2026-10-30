from "%sqstd/string.nut" import utf8ToLower
from "%scripts/customization/decoratorGetters.nut" import getDecorator

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

function filterDecorIds(decorIds, decorType, filterOptions) {
  let { onlyRecieved = false, searchName = "" } = filterOptions
  if (!onlyRecieved && searchName == "")
    return decorIds

  return decorIds.filter(@(id) (!onlyRecieved || decorType.isPlayerHaveDecorator(id))
    && (searchName == "" || utf8ToLower(getDecorator(id, decorType)?.getName() ?? "").indexof(searchName) != null))
}

return freeze({
  filterDecorators
  filterDecorIds
})