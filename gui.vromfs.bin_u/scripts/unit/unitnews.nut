let unitsNews = persist("unitsNews", @() {})

return {
  addUnitNewsId = @(unitName, id) unitsNews[unitName] <- id
  getUnitNewsId = @(unitName) unitsNews?[unitName]
  hasUnitNews = @(unitName) unitsNews?[unitName] != null
}