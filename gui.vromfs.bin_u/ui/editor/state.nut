local daEditor4 = require_optional("daEditor4")

return {
  showUIinEditor = ::mkWatched(persist, "showUIinEditor", false)
  editorIsActive = ::mkWatched(persist, "editorIsActive", false)
  selectedEntity = ::mkWatched(persist, "selectedEntity", INVALID_ENTITY_ID)
  propPanelVisible = ::mkWatched(persist, "propPanelVisible", false)
  filterString = ::mkWatched(persist, "filterString", "")
  selectedCompName = ::mkWatched(persist, "selectedCompName")
  showEntitySelect = ::mkWatched(persist, "showEntitySelect", false)
  showTemplateSelect = ::mkWatched(persist, "showTemplateSelect", false)
  showHelp = ::mkWatched(persist, "showHelp", false)
  entitiesListUpdateTrigger = ::mkWatched(persist, "entitiesListUpdateTrigger", 0)
  de4editMode = ::mkWatched(persist, "de4editMode", daEditor4?.getEditMode())
  extraPropPanelCtors = Watched([])
}
