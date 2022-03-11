from "%darg/ui_imports.nut" import *
import "%sqstd/ecs.nut" as ecs

let {getEditMode=null, isFreeCamMode=null, setWorkMode=null} = require_optional("daEditor4")
let {is_editor_activated=null, get_scene_filepath=null, set_start_work_mode=null, get_instance=null} = require_optional("entity_editor")
let selectedEntity = Watched(ecs.INVALID_ENTITY_ID)
let selectedEntities = Watched({}) // table used as set

const SETTING_EDITOR_WORKMODE = "daEditor4/workMode"
let { save_settings=null, get_setting_by_blk_path=null, set_setting_by_blk_path=null } = require_optional("settings")
let de4workMode = Watched("")
let de4workModes = Watched([""])
de4workMode.subscribe(function(v) {
  set_start_work_mode?(v ?? "")
  setWorkMode?(v ?? "")
  set_setting_by_blk_path?(SETTING_EDITOR_WORKMODE, v ?? "")
  save_settings?()
})
let initWorkModes = function(modes) {
  de4workModes(modes ?? [""])
  local good_mode = modes?[0] ?? ""
  local last_mode = get_setting_by_blk_path?(SETTING_EDITOR_WORKMODE) ?? good_mode
  foreach(mode in modes)
    if (last_mode == mode)
      good_mode = mode
  de4workMode(good_mode)
}

let proceedWithSavingUnsavedChanges = function(showMsgbox, callback, unsavedText=null, proceedText=null) {
  local hasUnsavedChanges = (get_instance!= null && (get_instance()?.hasUnsavedChanges() ?? false))
  if (!hasUnsavedChanges && proceedText==null) { callback(); return }
  showMsgbox({
    text = hasUnsavedChanges ? (unsavedText!=null ? unsavedText : "You have unsaved changes. How do you want to proceed?")
                             : (proceedText!=null ? proceedText : "No unsaved changes. Proceed?")
    buttons = hasUnsavedChanges ? [
      { text = "Save changes",  isCurrent = true, action = function() { get_instance().saveObjects(""); callback() }}
      { text = "Ignore changes" action = callback }
      { text = "Cancel", isCancel = true }
    ] : [
      { text = "Proceed" action = callback }
      { text = "Cancel", isCancel = true }
    ]
  })
}

return {
  showUIinEditor = mkWatched(persist, "showUIinEditor", false)
  editorIsActive = Watched(is_editor_activated?())
  editorFreeCam = Watched(isFreeCamMode?())
  selectedEntity
  selectedEntities
  scenePath = Watched(get_scene_filepath?())
  propPanelVisible = mkWatched(persist, "propPanelVisible", false)
  propPanelClosed  = mkWatched(persist, "propPanelClosed", false)
  filterString = mkWatched(persist, "filterString", "")
  selectedCompName = Watched()
  showEntitySelect = mkWatched(persist, "showEntitySelect", false)
  showTemplateSelect = mkWatched(persist, "showTemplateSelect", false)
  showHelp = mkWatched(persist, "showHelp", false)
  entitiesListUpdateTrigger = mkWatched(persist, "entitiesListUpdateTrigger", 0)
  de4editMode = Watched(getEditMode?())
  extraPropPanelCtors = Watched([])
  de4workMode
  de4workModes
  initWorkModes
  proceedWithSavingUnsavedChanges
  showDebugButtons = Watched(true)
}

