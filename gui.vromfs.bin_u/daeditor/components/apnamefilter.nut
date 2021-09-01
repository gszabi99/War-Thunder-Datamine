local nameFilter = require("nameFilter.nut")

return @(filterString, selectedCompName) nameFilter(filterString, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterString.update(text)

    if ((text.len() > 0 ) && selectedCompName.value
      && !selectedCompName.value.contains(text)) {
      selectedCompName.update(null)
    }
  }

  function onEscape() {
//    state.filterString.update("")
  }
})

