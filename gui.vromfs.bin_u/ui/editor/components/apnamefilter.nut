local nameFilter = require("nameFilter.nut")

return @(filterString, selectedCompName) nameFilter(filterString, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterString.update(text)

    if (text.len() && selectedCompName.value
      && selectedCompName.value.indexof(text)==null) {
      selectedCompName.update(null)
    }
  }

  function onEscape() {
//    state.filterString.update("")
  }
})

