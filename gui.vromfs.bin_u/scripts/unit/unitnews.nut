let unitsNews = persist("unitsNews", @() {})

return freeze({
  addUnitNewsId = @(unitName, id) unitsNews[unitName] <- id
  getUnitNewsId = @(unitName) unitsNews?[unitName]
  hasUnitNews = @(unitName) unitsNews?[unitName] != null
})