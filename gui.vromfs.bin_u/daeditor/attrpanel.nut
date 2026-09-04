import "math" as math
from "dagor.math" import Point2, Point3, Point4
from "string" import endswith
from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *
from "types" import Table, Array, String

let entity_editor = require_optional("entity_editor")
let { isCompReadOnly, updateComp, valueAtPath } = require("components/attrUtil.nut")
let { filterString, propPanelVisible, propPanelClosed, selectedCompName, extraPropPanelCtors, selectedEntity,
  selectedEntities, de4workMode, wantOpenRISelect, sceneIdMap, getAllScenes, allScenesWatcher,
  edObjectFlagsUpdateTrigger } = require("state.nut")
let { colors, gridHeight } = require("components/style.nut")

let selectedCompComp = Watched(null)
let selectedCompPath = Watched(null)
function deselectComp() {
  selectedCompName.set("")
  selectedCompComp.set(null)
  selectedCompPath.set(null)
}

let textButton = require("components/textButton.nut")
let closeButton = require("components/closeButton.nut")
let textInput = require("%daeditor/components/textInput.nut")
let { addModalWindow, removeModalWindow, modalWindowsComponent } = require("%daeditor/components/modalWindows.nut")
let { showMsgbox } = require("%daeditor/components/msgbox.nut")
let infoBox = @(text) showMsgbox({text})
let mkSortModeButton = require("components/mkSortModeButton.nut")
let nameFilter = require("components/nameFilter.nut")

let cursors = require("components/cursors.nut")
let { mkTemplateTooltip, mkCompMetaInfoText } = require("components/templateHelp.nut")
let { getCompSqTypePropEdit, getCompNamePropEdit } = require("propPanelControls.nut")
let { makeVertScroll } = require("%daeditor/components/scrollbar.nut")

let fieldReadOnly = require("components/apFieldReadOnly.nut")
let compNameFilter = require("components/apNameFilter.nut")(filterString, selectedCompName)

let { riSelectShown, riSelectWindow, openRISelectForEntity } = require("riSelect.nut")

let combobox = require("%daeditor/components/combobox.nut")
let { getEntityExtraName, getSceneLoadTypeText, sceneToComboboxEntry, canSceneBeModified,
  isEntityInLockedHierarchy } = require("%daeditor/daeditor_es.nut")
let { sortScenesByLoadType } = require("components/sceneSorting.nut")

let ecs = require("%sqstd/ecs.nut")

function ecsObjToQuirrel(x) {
  return x.map(@(val) val?.getAll() ?? val)
}



let getCurComps = @() (selectedEntity.get() ?? ecs.INVALID_ENTITY_ID) == ecs.INVALID_ENTITY_ID ? {} : ecsObjToQuirrel(ecs._dbg_get_all_comps_inspect(selectedEntity.get()))
let curEntityComponents = Watched(getCurComps())
let setCurComps = @() curEntityComponents.set(getCurComps())

function saveComponent(eid, cname, object) {
  ecs.obsolete_dbg_set_comp_val(eid, cname, object)
  entity_editor?.save_component(eid, cname)
  setCurComps()
}

let entitySortState = Watched({})






let gridScrollHandler = ScrollHandler()
let listScrollHandler = ScrollHandler()




local scrolledEid = ecs.INVALID_ENTITY_ID
selectedEntity.subscribe(function(eid) {
  if (eid == scrolledEid)
    return
  scrolledEid = eid
  gridScrollHandler.scrollToY(0)
})

let windowState = Watched({
  pos = [-fsh(1.1), fsh(5)]
  size = [sw(29), sh(80)]
})

let allModifiableScenes = Watched([])
let allSceneTexts = Watched([])

const noSceneParent = "No Scene"

allModifiableScenes.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  allSceneTexts.set(v.filter(@(scene) canSceneBeModified(scene)).map(@(scene, _idx) sceneToComboboxEntry(scene)))
  allSceneTexts.get().append(noSceneParent)
})

function onMoveResize(dx, dy, dw, dh): table {
  let w = windowState.get()
  w.pos[0] = math.clamp(w.pos[0]+dx, -(sw(100)-w.size[0]), 0)
  w.pos[1] = math.max(w.pos[1]+dy, 0)
  w.size[0] = math.clamp(w.size[0]+dw, sw(14), sw(80))
  w.size[1] = math.clamp(w.size[1]+dh, sh(20), sh(95))
  return w
}

function get_tags(comp_flags: int|null): array {
  let tags = []
  comp_flags = comp_flags ?? 0
  if (comp_flags & ecs.COMP_FLAG_REPLICATED)
    tags.append("r")
  if (comp_flags & ecs.COMP_FLAG_CHANGE_EVENT)
    tags.append("t")
  return tags
}

function get_tagged_comp_name(comp_flags: int|null, comp_name) {
  local tags = get_tags(comp_flags).map(@(v) $"[{v}]")
  tags = "".join(tags)
  if (tags.len() <= 0)
    return comp_name
  return $"{tags} {comp_name}"
}

function makeBgToggle(initial=true): function {
  local showBg = !initial
  function toggleBg(): bool {
    showBg = !showBg
    return showBg
  }
  return toggleBg
}


function getModComps(): table|null {
  if (selectedEntity.get() == ecs.INVALID_ENTITY_ID)
    return {}
  let comps = entity_editor?.get_saved_components(selectedEntity.get())
  if (comps == null) 
    return null
  let compsObj = {}
  comps.map(@(v) compsObj[v] <- true)
  return compsObj
}
let modifiedComponents = Watched(getModComps())
let updateModComps = @() modifiedComponents.set(getModComps())

function isNonSceneEntity(): bool {
  return modifiedComponents.get() == null
}

function isModifiedComponent(cname, cpath): bool {
  if (cname == null || (cpath?.len()??0) > 0)
    return false
  if (cname == "transform")
    return false
  if (isNonSceneEntity())
    return true
  return modifiedComponents.get()?[cname] == true
}

function doResetComponent(eid, comp_name) {
  entity_editor?.reset_component(eid, comp_name)
  selectedCompName.set(null)
  selectedCompComp.set(null)
  selectedCompPath.set(null)
  setCurComps()
}

function doResetSelectedComponent() {
  let eid = selectedEntity.get() ?? ecs.INVALID_ENTITY_ID
  if (eid == ecs.INVALID_ENTITY_ID)
    return
  if (selectedCompComp.get() == null)
    return
  doResetComponent(eid, selectedCompComp.get())
}

function panelRowColor(stateFlags: int, isOdd) {
  return stateFlags & S_TOP_HOVER ? colors.GridRowHover
    : isOdd ? colors.GridBg[0]
    : colors.GridBg[1]
}

function panelRowColorC(comp_fullname, stateFlags, selectedCompNameVal, isOdd){
  local color = 0
  if (comp_fullname == selectedCompNameVal) {
    color = colors.Active
  } else {
    color = panelRowColor(stateFlags, isOdd)
  }
  return color
}

const metaComponentPrefix     = "· "
const metaContainerPrefix     = "· "
const modifiedComponentPrefix = "• "
const modifiedContainerPrefix = "• "
const modifiedNoMetaPrefix    = "• "
const transformPrefix         = "¤ "
const modifiedSuffix          = ""


function mkEntityRowText(prefix, name, suffix, group=null) {
  return {
    rendObj = ROBJ_TEXT
    text = $"{prefix}{name}{suffix}"
    color = colors.TextDefault
    size = const [flex(), fontH(100)]
    margin = fsh(0.5)
    group = group
    behavior = Behaviors.Marquee
    scrollOnHover = true
    delay = 0.3
    speed = hdpx(100)
  }
}

function mkCompNameText(comp_name, comp_name_text, metaInfo, modified, group=null) {
  let prefix = (comp_name=="transform") ? transformPrefix :
               modified ? (metaInfo ? modifiedComponentPrefix : modifiedNoMetaPrefix)
               : (metaInfo ? metaComponentPrefix : "")
  let suffix = modified ? modifiedSuffix : ""
  return mkEntityRowText(prefix, comp_name_text, suffix, group)
}

local toggleBg = makeBgToggle()

function mkCompTooltip(metaInfo) {
  local text = metaInfo?.desc
  if (text == null)
    return null

  return {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = Color(30, 30, 30, 200)
    children = {
      rendObj = ROBJ_FRAME
      color =  Color(50, 50, 50, 20)
      borderWidth = hdpx(1)
      padding = fsh(1)
      flow = FLOW_VERTICAL
      children = {
        maxWidth = hdpx(480)
        rendObj = ROBJ_TEXTAREA
        halign = ALIGN_LEFT
        behavior = Behaviors.TextArea
        text = mkCompMetaInfoText(metaInfo, "multiLine")
        fontSize = hdpx(14)
        color = Color(180,180,180)
      }
    }
  }
}



function mkCompPathKey(cname, cpath) {
  local key = cname
  foreach (k in (cpath ?? []))
    key = $"{key}.{k}"
  return key
}

function mkPanelCompRow(params={}) {
  let comp_name_ext = params?.comp_name_ext
  let comp_flags = params?.comp_flags ?? 0
  
  
  let {eid, comp_sq_type, rawComponentName, path, isOdd, obj=null} = params
  let comp_name = params?.comp_name ?? comp_name_ext
  let stateFlags = Watched(0)
  let group = ElemGroup()
  local comp_name_text = get_tagged_comp_name(comp_flags, (comp_name_ext ? comp_name_ext : comp_name))
  if (comp_sq_type == "TMatrix")
    comp_name_text = $"{comp_name_text}[3]"
  local fieldEditCtor = null
  if (params.isLocked) {
    fieldEditCtor = fieldReadOnly
  }
  else {
    fieldEditCtor = getCompNamePropEdit(rawComponentName) ?? getCompSqTypePropEdit(comp_sq_type) ?? fieldReadOnly
  }

  let comp_fullname = mkCompPathKey(rawComponentName, path)
  let metaInfo = path==null ? ecs.g_entity_mgr.getTemplateDB().getComponentMetaInfo(comp_name) : null
  let modified = !isNonSceneEntity() && isModifiedComponent(comp_name, path)
  let indent = params?.indent ?? 0
  return function() {
    return {
      size = [flex(), gridHeight]
      behavior = Behaviors.Button
      margin = [0, 0, 0, indent]

      onClick = function() {
        let deselect = (selectedCompName.get() == comp_fullname)
        selectedCompName.set(deselect ? null : comp_fullname)
        selectedCompComp.set(deselect ? null : rawComponentName)
        selectedCompPath.set(deselect ? null : path)
      }
      onHover = @(on) cursors.setTooltip(on ? mkCompTooltip(metaInfo) : null)
      eventPassThrough = true
      onElemState = @(sf) stateFlags.set(sf & S_TOP_HOVER)
      group = group

      children = [
        @(){
          size = [flex(), gridHeight]
          rendObj = ROBJ_SOLID
          watch = [stateFlags, selectedCompName]
          color = panelRowColorC(comp_fullname, stateFlags.get(), selectedCompName.get(), isOdd)
          group
        }
        {
          group
          gap = hdpx(2)
          valign = ALIGN_CENTER
          size = [flex(), gridHeight]
          flow = FLOW_HORIZONTAL
          children = [
            mkCompNameText(comp_name, comp_name_text, metaInfo, modified, group)
            fieldEditCtor(params.__merge({eid, obj, comp_name, rawComponentName}))
          ]
        }
      ]
    }
  }
}

let removeSelectedByEditorTemplate = @(tname: string): string tname.replace("+daeditor_selected+","+").replace("+daeditor_selected","").replace("daeditor_selected+","")

const attrPanelAddEntityTemplateUID = "attr_panel_add_entity_template"

function doAddTemplate(templateName) {
  let eid = selectedEntity.get()
  if (eid != ecs.INVALID_ENTITY_ID) {
    if (ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName) == null) {
      infoBox("Invalid template name")
    } else {
      ecs.recreateEntityWithTemplates({eid, addTemplates=[templateName], callback=function(recreatedEid) {
        log("Added entity template =", templateName)
        entity_editor?.save_add_template(recreatedEid, templateName)
      }, checkComps=false})
    }
  } else {
    infoBox("Entity not selected")
  }
  removeModalWindow(attrPanelAddEntityTemplateUID)
  selectedEntity.trigger()
}

function openAddTemplateDialog() {
  let templateName = Watched("")
  let templateNameComp = textInput(templateName, {onAttach = @(elem) set_kb_focus(elem)})
  let close = @() removeModalWindow(attrPanelAddEntityTemplateUID)

  let isTemplateNameValid = Computed(@() templateName.get()!=null && templateName.get()!="")

  addModalWindow({
    key = attrPanelAddEntityTemplateUID
    children = vflow(
      Button
      RendObj(ROBJ_SOLID)
      Padding(hdpx(10))
      Colr(30,30,30)
      Gap(hdpx(10))
      txt("ADD ENTITY TEMPLATE", {hplace = ALIGN_CENTER})
      vflow(Size(flex(), SIZE_TO_CONTENT), txt("Template name:"), templateNameComp)
      hflow(
        textButton("Cancel", close, {hotkeys=[["Esc"]]})
        @() {
          watch = isTemplateNameValid
          children = isTemplateNameValid.get() ? textButton("Add template", @() doAddTemplate(templateName.get())) : null
        }
      )
    )
  })
}

const attrPanelDelEntityTemplateUID = "attr_panel_del_entity_template"

function doDelTemplate(templateName) {
  let eid = selectedEntity.get()
  if (eid != ecs.INVALID_ENTITY_ID) {
    local tname = removeSelectedByEditorTemplate(ecs.g_entity_mgr.getEntityTemplateName(eid) ?? "")
    if (tname == templateName) {
      infoBox("You can't remove last template")
    } else if (ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName) == null) {
      infoBox("Invalid template name")
    } else {
      ecs.recreateEntityWithTemplates({eid, removeTemplates=[templateName], callback=function(recreatedEid) {
        log("Removed entity template =", templateName)
        entity_editor?.save_del_template(recreatedEid, templateName)
      }, checkComps=false})
    }
  } else {
    infoBox("Entity not selected")
  }
  removeModalWindow(attrPanelDelEntityTemplateUID)
  selectedEntity.trigger()
}

function openDelTemplateDialog() {
  let templateName = Watched("")
  let templateNameComp = textInput(templateName, {onAttach = @(elem) set_kb_focus(elem)})
  let close = @() removeModalWindow(attrPanelDelEntityTemplateUID)

  let isTemplateNameValid = Computed(@() templateName.get()!=null && templateName.get()!="")

  addModalWindow({
    key = attrPanelDelEntityTemplateUID
    children = vflow(
      Button
      RendObj(ROBJ_SOLID)
      Padding(hdpx(10))
      Colr(30,30,30)
      Gap(hdpx(10))
      txt("REMOVE ENTITY TEMPLATE", {hplace = ALIGN_CENTER})
      vflow(Size(flex(), SIZE_TO_CONTENT), txt("Template name:"), templateNameComp)
      hflow(
        textButton("Cancel", close, {hotkeys=[["Esc"]]})
        @() {
          watch = isTemplateNameValid
          children = isTemplateNameValid.get() ? textButton("Remove template", @() doDelTemplate(templateName.get())) : null
        }
      )
    )
  })
}

let templateTooltip = Watched(null)

function panelCaption(text, tpl_name, sceneText) {
  return {
    size = FLEX_H
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)
    borderColor = Color(30,30,30,20)
    borderWidth = hdpx(1)
    padding = const [0,hdpx(5)]
    scrollOnHover = true
    eventPassThrough = true
    behavior = [Behaviors.Marquee, Behaviors.Button]
    onHover = @(on) templateTooltip.set(on && tpl_name ? mkTemplateTooltip(tpl_name, sceneText) : null)
    onClick = function() {
      if (selectedEntities.get().len() > 1) {
        selectedEntity.set(ecs.INVALID_ENTITY_ID)
        entity_editor?.get_instance()?.setFocusedEntity(ecs.INVALID_ENTITY_ID)
      }
    }

    children = {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      text = text
      margin = const [hdpx(5), 0]
    }
  }
}

function warningGenerated() {
  return {
    size = FLEX_H
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,10,210)
    padding = const [0,hdpx(5)]

    children = {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      color = Color(192,150,150)
      fontSize = hdpx(12)
      text = " BEWARE : Generated entities are never saved to scene file, all changes will be lost upon restart"
      margin = const [hdpx(5), 0]
    }
  }
}

function closePropPanel() {
  propPanelVisible.set(false)
  propPanelClosed.set(true)
}

function panelButtons(eid) {
  let isLocked = isEntityInLockedHierarchy(eid)
  return {
    size = const [flex(), fsh(3.3)]
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)
    borderColor = Color(30,30,30,100)
    borderWidth = hdpx(1)
    padding = const [0,hdpx(5)]
    eventPassThrough = true
    watch = [selectedCompComp, selectedCompPath]
    children = {
      flow = FLOW_HORIZONTAL
      hplace = ALIGN_RIGHT
      vplace = ALIGN_CENTER
      children = [
        isModifiedComponent(selectedCompComp.get(), selectedCompPath.get()) ? textButton("R", doResetSelectedComponent) : null
        !isLocked ? textButton("-", openDelTemplateDialog) : null
        !isLocked ? textButton("+", openAddTemplateDialog) : null
        textButton("Close", closePropPanel)
      ]
    }
  }
}

function autoOpenClosePropPanel(_) {
  local show = selectedEntity.get() != ecs.INVALID_ENTITY_ID || selectedEntities.get().len() > 0
  if (show && propPanelClosed.get())
    return
  propPanelVisible.set(show)
}
selectedEntity.subscribe_with_nasty_disregard_of_frp_update(autoOpenClosePropPanel)
selectedEntities.subscribe_with_nasty_disregard_of_frp_update(autoOpenClosePropPanel)


let hiddenComponents = {
  editableObj        = true
  editableTemplate   = true
  nonCreatableObj    = true
  daeditor__selected = true
}

function isComponentHidden(k): bool {
  if (hiddenComponents?[k] || k.slice(0,1)=="_")
    return true
  if (endswith(k, "$copy"))
    return true
  return false
}

function isKeyInFilter(key, filterStr=null): bool {
  if (filterStr==null || filterStr.len()==0 || key.tolower().contains(filterStr.tolower()))
    return true
  return false
}

let rightArrow = {rendObj = ROBJ_TEXT text = "^" transform = {rotate=90}}
let downArrow = {rendObj = ROBJ_TEXT text = "^" transform = {rotate=180}}
let mkTagFromTextColor = @(text, fillColor = Color(100,100,100), size = SIZE_TO_CONTENT, textColor = Color(0,0,0)) {
  rendObj = ROBJ_BOX
  size
  borderWidth = 0
  borderRadius = hdpx(4)
  fillColor
  padding = const [0,hdpx(1)]
  vplace = ALIGN_CENTER
  children = {
    rendObj = ROBJ_TEXT
    size
    text
    fontSize = hdpx(10)
    color = textColor
  }
}

let mkTagFromText = @(text) mkTagFromTextColor(text)

let ecsObjectSign = mkTagFromText("obj")
let emptyTag = mkTagFromText("empty")
let constTag = mkTagFromText("Shared")

let openedPaths = mkWatched(persist, "openedPaths", {})

let isOpened = @(eid, cname, cpath) openedPaths.get()?[eid][mkCompPathKey(cname, cpath)] ?? false

function setOpened(eid, cname, cpath, v) {
  const maxEntities = 100
  let key = mkCompPathKey(cname, cpath)
  openedPaths.mutate(function(all) {
    if (eid not in all) {
      if (all.len() >= maxEntities)
        all.clear()
      all[eid] <- {}
    }
    if (v)
      all[eid][key] <- true
    else
      all[eid].$rawdelete(key)
  })
}


let addPropValueTypes = ["text" "real" "bool" "integer" "array" "object" "Point2" "Point3" "Point4"]

const attrPanelAddObjectValueUID = "attr_panel_add_object_value"

function doAddObjectValue(eid, cname, cpath, value_name, value_type) {
  local object = ecs._dbg_get_comp_val_inspect(eid, cname)
  local ccobj = object
  foreach (key in (cpath ?? []))
    ccobj = ccobj?[key]
  if (ccobj == null)
    return

  try {
    if (value_type == "text")
      ccobj[value_name] = ""
    else if (value_type == "real")
      ccobj[value_name] = 0.0
    else if (value_type == "bool")
      ccobj[value_name] = false
    else if (value_type == "integer")
      ccobj[value_name] = 0
    else if (value_type == "array")
      ccobj[value_name] = []
    else if (value_type == "object")
      ccobj[value_name] = {}
    else if (value_type == "Point2")
      ccobj[value_name] = Point2(0,0)
    else if (value_type == "Point3")
      ccobj[value_name] = Point3(0,0,0)
    else if (value_type == "Point4")
      ccobj[value_name] = Point4(0,0,0,0)

    saveComponent(eid, cname, object)

    setOpened(eid, cname, cpath, true)
  } catch (e) {
    logerr($"Failed to add object value {value_name} (type {value_type}), reason: {e}")
  }

  removeModalWindow(attrPanelAddObjectValueUID)
}

function openAddObjectValueDialog(eid, cname, cpath, ccobj) {
  let valueName = Watched("")
  let valueType = Watched(addPropValueTypes[0])
  let valueNameComp = textInput(valueName, {onAttach = @(elem) set_kb_focus(elem)})
  let valueTypeComp = combobox(valueType, addPropValueTypes)
  let close = @() removeModalWindow(attrPanelAddObjectValueUID)

  let isValueNameValid = Computed(@() valueName.get()!=null && valueName.get()!="" && ccobj!=null && ccobj?[valueName.get()]==null)

  addModalWindow({
    key = attrPanelAddObjectValueUID
    children = vflow(
      Button
      RendObj(ROBJ_SOLID)
      Padding(hdpx(10))
      Colr(30,30,30)
      Gap(hdpx(10))
      txt("ADD OBJECT VALUE", {hplace = ALIGN_CENTER})
      {
        size = [flex(), sh(2)]
        children = valueTypeComp
      }
      valueNameComp
      hflow(
        textButton("Cancel", close, {hotkeys=[["Esc"]]})
        @() {
          watch = [isValueNameValid]
          children = isValueNameValid.get() ? textButton("Add value", @() doAddObjectValue(eid, cname, cpath, valueName.get(), valueType.get())) : null
        }
      )
    )
  })
}

const attrPanelAddArrayValueUID = "attr_panel_add_array_value"

function doAddArrayValue(eid, cname, cpath, ckey, value_type) {
  local object = ecs._dbg_get_comp_val_inspect(eid, cname)
  local ccobj = object
  foreach (key in (cpath ?? []))
    ccobj = ccobj?[key]
  if (ccobj == null)
    return

  local value = null
  if (value_type=="text")
    value = ""
  else if (value_type=="real")
    value = 0.0
  else if (value_type=="bool")
    value = false
  else if (value_type=="integer")
    value = 0
  else if (value_type=="array")
    value = []
  else if (value_type=="object")
    value = {}
  else if (value_type == "Point2")
    value = Point2(0,0)
  else if (value_type == "Point3")
    value = Point3(0,0,0)
  else if (value_type == "Point4")
    value = Point4(0,0,0,0)

  if (value==null) {
    infoBox($"Unsupported array value type: {value_type}")
    return
  }

  if (ckey==null) {
    try {
      ccobj.append(value)
      saveComponent(eid, cname, object)
      setOpened(eid, cname, cpath, true)
    } catch(e) {
      logerr($"Failed to append array value, reason: {e}")
    }
  }
  else {
    try {
      ccobj.insert(ckey.tointeger(), value)
      saveComponent(eid, cname, object)
      setOpened(eid, cname, cpath, true)
    } catch(e) {
      logerr($"Failed to insert array value, reason: {e}")
    }
  }

  removeModalWindow(attrPanelAddArrayValueUID)
}

function openAddArrayValueDialog(eid, cname, cpath, ckey) {
  let valueType = Watched(addPropValueTypes[0])
  let valueTypeComp = combobox(valueType, addPropValueTypes)
  let close = @() removeModalWindow(attrPanelAddArrayValueUID)

  addModalWindow({
    key = attrPanelAddArrayValueUID
    children = vflow(
      Button
      RendObj(ROBJ_SOLID)
      Padding(hdpx(10))
      Colr(30,30,30)
      Gap(hdpx(10))
      txt("ADD ARRAY VALUE", {hplace = ALIGN_CENTER})
      {
        size = [flex(), sh(2)]
        children = valueTypeComp
      }
      hflow(
        textButton("Cancel", close, {hotkeys=[["Esc"]]})
        @() {
          children = textButton("Add value", @() doAddArrayValue(eid, cname, cpath, ckey, valueType.get()))
        }
      )
    )
  })
}

function doContainerOp(eid, comp_name, cont_path, op) {
  local cname = comp_name
  local cpath = cont_path
  local ckey  = null
  let spath = selectedCompPath.get()
  let len1 = (spath?.len()??0)
  let len2 = (cpath?.len()??0)
  if (selectedCompComp.get() == comp_name && len1 == len2 + 1) {
    local same = true
    foreach(idx, key in (cpath ?? []))
      if (spath[idx] != key)
        same = false
    if (same)
      ckey = spath[spath.len()-1]
  }

  local object = ecs._dbg_get_comp_val_inspect(eid, cname)
  local ccobj = object
  foreach (key in (cpath ?? []))
    ccobj = ccobj?[key]
  if (ccobj == null)
    return

  if (op=="delself") {
    if (cpath==null)
      return
    local dpath = clone cpath
    dpath.pop()
    selectedCompComp.set(comp_name)
    selectedCompPath.set(cpath)
    doContainerOp(eid, comp_name, dpath, "delete")
    return
  }

  if (ccobj instanceof Table || ccobj instanceof ecs.CompObject) {
    if (op=="insert") {
      openAddObjectValueDialog(eid, cname, cpath, ccobj)
    }
    else if (op=="delete") {
      if (ckey==null) {
        infoBox("Please, select object value to delete")
        return
      }
      try {
        if (ccobj instanceof Table)
          ccobj.rawdelete(ckey)
        else
          ccobj.remove(ckey)
      } catch(e) {
        logerr($"Failed to remove value {ckey}, reason: {e}")
      }
      saveComponent(eid, cname, object)
      setOpened(eid, cname, cpath, true)
      deselectComp()
    }
  }
  else if (ccobj instanceof Array || ccobj?.getAll()!=null) {
    if (op=="insert") {
      let listType = ccobj?.listType()

      local value = null
      if (listType==null) {
        openAddArrayValueDialog(eid, cname, cpath, ckey)
        return
      }
      if (listType=="ecs::string")
        value = ""
      else if (listType=="bool")
        value = false
      else if (listType=="float")
        value = 0.0
      else if (listType=="int" || listType=="integer")
        value = 0
      else if (listType=="Point2")
        value = Point2(0,0)
      else if (listType=="Point3")
        value = Point3(0,0,0)
      else if (listType=="Point4")
        value = Point4(0,0,0,0)

      if (value==null) {
        infoBox($"Unsupported array value type: {listType}")
        return
      }

      if (ckey==null) {
        try {
          ccobj.append(value)
          saveComponent(eid, cname, object)
          setOpened(eid, cname, cpath, true)
        } catch(e) {
          logerr($"Failed to append array value, reason: {e}")
        }
      }
      else {
        try {
          ccobj.insert(ckey.tointeger(), value)
          saveComponent(eid, cname, object)
          setOpened(eid, cname, cpath, true)
        } catch(e) {
          logerr($"Failed to insert array value, reason: {e}")
        }
      }
    }
    else if (op=="delete") {
      if (ckey==null) {
        try {
          ccobj.pop()
          saveComponent(eid, cname, object)
          setOpened(eid, cname, cpath, true)
        } catch(e) {
          logerr($"Failed to pop array value, reason: {e}")
        }
      }
      else {
        try {
          ccobj.remove(ckey.tointeger())
          saveComponent(eid, cname, object)
          setOpened(eid, cname, cpath, true)
          deselectComp()
        } catch(e) {
          logerr($"Failed to remove array value, reason: {e}")
        }
      }
    }
  }
}

let collapsibleButtonsStyle = {
  boxStyle = {
    normal = {
        margin = const [0,hdpx(3)]
        padding = const [0,hdpx(8)]
        borderColor = Color(0,0,0,100)
        fillColor = Color(0,0,0,0)
    }
  }
  textStyle = {
    normal = {
      color = Color(180,180,180)
    }
  }
}
let collapsibleButtonsStyleDark = {
  boxStyle = {
    normal = {
        margin = const [0,hdpx(3)]
        padding = const [0,hdpx(8)]
        borderColor = Color(0,0,0,0)
        fillColor = Color(0,0,0,0)
    }
  }
  textStyle = {
    normal = {
      color = Color(0,0,0,0)
    }
  }
}

let rowHeightByShape = {}
local rowHeightScreenH = 0




function measuredRowHeight(shape, ctor) {
  
  
  let screenH = sh(100)
  if (screenH != rowHeightScreenH) {
    rowHeightByShape.clear()
    rowHeightScreenH = screenH
  }
  if (shape not in rowHeightByShape)
    rowHeightByShape[shape] <- calc_comp_size(ctor)[1]
  return rowHeightByShape[shape]
}

function mkRowAcc() {
  let ctors = []
  let ownH = []
  let marginV = []
  return {
    ctors
    ownH
    marginV
    add = function(ctor, h, margin_v) {
      ctors.append(ctor)
      ownH.append(h)
      marginV.append(margin_v)
    }
    addLeaf = function(ctor) {
      ctors.append(ctor)
      ownH.append(gridHeight)
      marginV.append(0)
    }
  }
}

let rowIndent = @(depth) depth > 0 ? depth * fsh(1) : 0

let compTag = memoize(mkTagFromText)
let mkCompFlagTag = memoize(@(text) mkTagFromTextColor(text, Color(40,90,90, 50), [SIZE_TO_CONTENT, hdpx(15)]))
let mkFlagTags = @(eid, rawComponentName)
  get_tags(ecs.get_comp_flags(eid, rawComponentName)).map(mkCompFlagTag)

function updateAttrComponent(eid, cname) {
  updateComp(eid, cname)
  gui_scene.resetTimeout(0.1, setCurComps)
}





function mkLazyRow(row_params) {
  local ctor = null
  return function() {
    ctor = ctor ?? mkPanelCompRow(row_params)
    return ctor()
  }
}

local flattenComp

function containerRows(acc, isConst, caption, len, tags, eid, rawComponentName, path, depth, walk_children) {
  tags = tags ?? []
  let isRoot = (path?.len()??0) < 1
  let metaInfo = isRoot ? ecs.g_entity_mgr.getTemplateDB().getComponentMetaInfo(rawComponentName) : null
  let modified = isRoot && !isNonSceneEntity() ? isModifiedComponent(rawComponentName, null) : false
  let prefix = modified ? (metaInfo ? modifiedContainerPrefix : modifiedNoMetaPrefix)
               : (metaInfo ? metaContainerPrefix : "")
  let suffix = modified ? modifiedSuffix : ""
  let captionText = {rendObj = ROBJ_TEXT, text = $"{prefix}{caption}{suffix}", color = Color(180,180,180)}
  let padding = [hdpx(5), hdpx(5)]
  let gap = hdpx(4)
  let hasReset = !isConst && isModifiedComponent(rawComponentName, path)
  
  
  let isOdd = toggleBg()
  let indent = rowIndent(depth)

  if (len == 0) {
    let emptyRow = @() {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      children = [
        {
          gap
          size = FLEX_H
          hplace = ALIGN_LEFT
          flow = FLOW_HORIZONTAL
          children = [].append(isConst ? constTag : null).extend(clone tags).append(emptyTag, captionText)
        }
        {
          gap
          hplace = ALIGN_RIGHT
          flow = FLOW_HORIZONTAL
          children = [
            !hasReset          ? null : textButton("R", @() doResetComponent(eid, rawComponentName), collapsibleButtonsStyleDark)
            isConst || isRoot  ? null : textButton("X", @() doContainerOp(eid, rawComponentName, path, "delself"), collapsibleButtonsStyleDark)
            isConst            ? null : textButton("+", @() doContainerOp(eid, rawComponentName, path, "insert"), collapsibleButtonsStyle)
          ]
        }

      ]
      padding = padding
      gap = gap
      rendObj = ROBJ_SOLID
      color = isOdd ? colors.GridBg[0] : colors.GridBg[1]
      behavior = Behaviors.Button
      onHover = @(on) cursors.setTooltip(on ? mkCompTooltip(metaInfo) : null)
      margin = [0, 0, 0, indent]
    }
    acc.add(emptyRow, measuredRowHeight($"e|{isConst}|{modified}|{hasReset}|{isRoot}|{tags.len()}", emptyRow), 0)
    return
  }

  let opened = isOpened(eid, rawComponentName, path)
  
  
  let captionMarginV = hdpx(1)
  let captionUi = @() {
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)
    borderColor = Color(30,30,30,20)
    padding
    key = mkCompPathKey(rawComponentName, path)
    gap
    borderWidth = hdpx(1)
    children = [
      {
        gap
        size = FLEX_H
        hplace = ALIGN_LEFT
        flow = FLOW_HORIZONTAL
        children = [opened ? downArrow : rightArrow].append(isConst ? constTag : null).extend(tags).append(captionText)
      }
      {
        gap
        hplace = ALIGN_RIGHT
        flow = FLOW_HORIZONTAL
        children = [
          !hasReset ? null : textButton("R", @() doResetComponent(eid, rawComponentName), collapsibleButtonsStyleDark)
          !opened || isConst ? null : textButton("-", @() doContainerOp(eid, rawComponentName, path, "delete"), collapsibleButtonsStyle)
          !opened || isConst ? null : textButton("+", @() doContainerOp(eid, rawComponentName, path, "insert"), collapsibleButtonsStyle)
        ]
      }
    ]
    flow = FLOW_HORIZONTAL
    behavior = Behaviors.Button
    onClick = @() setOpened(eid, rawComponentName, path, !isOpened(eid, rawComponentName, path))
    onHover = @(on) cursors.setTooltip(on ? mkCompTooltip(metaInfo) : null)
    size = FLEX_H
    margin = [captionMarginV, 0, captionMarginV, indent]
  }
  acc.add(captionUi, measuredRowHeight($"c|{isConst}|{modified}|{hasReset}|{isRoot}|{opened}|{tags.len()}", captionUi),
    captionMarginV)

  if (opened)
    walk_children(depth + 1)
}

function compTypeName(object): string {
  local typeName = ""
  if (object instanceof Array)
    typeName = "Array"
  else if (object instanceof Table)
    typeName = "Obj"
  else {
    typeName = object.tostring()
    let isComp = typeName.contains("Comp")
    typeName = typeName.slice(isComp ? "Comp".len() : 0, typeName.indexof(" (") ?? typeName.len())
  }
  return typeName
}

flattenComp = function(acc, eid, rawComponentName, rawObject, isLocked, caption, path, depth) {
  let onChange = @() updateAttrComponent(eid, rawComponentName)
  let object = valueAtPath(rawObject, path)
  let comp_sq_type = typeof object
  let indent = rowIndent(depth)

  
  
  let addLeafRow = function(row_params) {
    row_params.isOdd <- toggleBg()
    acc.addLeaf(mkLazyRow(row_params))
  }

  let isFirst = caption == null
  let params = {
    eid, comp_sq_type, onChange, path
    comp_flags = isFirst ? ecs.get_comp_flags(eid, rawComponentName) : null,
    comp_name=rawComponentName,
    rawComponentName,
    comp_name_ext = caption
    obj = rawObject
    isLocked
    indent
  }
  if (path == null && ecs.get_comp_type(eid, rawComponentName) != ecs.TYPE_STRING && object instanceof String) {
    addLeafRow(params.__merge({comp_sq_type="null" comp_flags = ecs.get_comp_flags(eid, rawComponentName)}))
    return
  }
  if (getCompSqTypePropEdit(comp_sq_type) != null) {
    addLeafRow(params)
    return
  }

  let cpath = path ?? []

  if (object instanceof Table || object instanceof ecs.CompObject) {
    let isConst = isCompReadOnly(eid, rawComponentName) 
    local cap = caption ?? rawComponentName
    let isObjFirst = isFirst || rawComponentName == cap
    let objData = object?.getAll() ?? object
    let tags = isObjFirst ? mkFlagTags(eid, rawComponentName).append(ecsObjectSign) : [ecsObjectSign]
    containerRows(acc, isConst, cap, objData.len(), tags, eid, rawComponentName, cpath, depth,
      function(child_depth) {
        let objKeys = objData.keys().filter(@(v) !isComponentHidden(v)).sort(@(a, b) a <=> b)
        foreach (ok in objKeys) {
          let nkeys = (clone cpath).append(ok)
          if (objData[ok]?.getAll() != null || objData[ok] instanceof Table || objData[ok] instanceof Array)
            flattenComp(acc, eid, rawComponentName, rawObject, isLocked, ok, nkeys, child_depth)
          else
            addLeafRow({rawComponentName, comp_name_ext = ok, obj=rawObject, eid,
              comp_sq_type = typeof objData[ok], onChange, path=nkeys, isLocked, indent = rowIndent(child_depth)})
        }
      })
    return
  }

  if (object?.getAll()!=null || object instanceof Array) {
    let isConst = isCompReadOnly(eid, rawComponentName)
    let cap = caption ?? rawComponentName
    let len = object?.len() ?? 0
    let typeTag = compTag(compTypeName(object))
    let tags = isFirst ? mkFlagTags(eid, rawComponentName).append(typeTag) : [typeTag]
    let fCaption = len>0 ? $"{cap} [{len}]" : cap
    containerRows(acc, isConst, fCaption, len, tags, eid, rawComponentName, cpath, depth,
      function(child_depth) {
        foreach (num, _val in (object?.getAll() ?? object)) {
          let nkeys = (clone cpath).append(num)
          flattenComp(acc, eid, rawComponentName, rawObject, isLocked, $"{cap}[{num}]", nkeys, child_depth)
        }
      })
    return
  }

  addLeafRow(params)
}

selectedEntity.subscribe_with_nasty_disregard_of_frp_update(function(eid){
  setCurComps()

  if (wantOpenRISelect.get()) {
    wantOpenRISelect.set(false)
    gui_scene.resetTimeout(0.1, function() {
      openRISelectForEntity(eid)
    })
  }
})

ecs.register_es("update_cur_components_on_entity_recreated",
{
  [[ecs.EventEntityRecreated]] = function(...){
    setCurComps()
  }
},{
  comps_rq = ["daeditor__selected"]
})

let isCurEntityComponents = Computed(@() curEntityComponents.get().len()>0)

let filteredCurComponents = Computed(function(){
  let res = []
  let noTags = de4workMode.get() == "Designer"
  foreach(compName, compObj in curEntityComponents.get()) {
    if (isComponentHidden(compName))
      continue
    if (noTags && compObj.tostring() == "ecs::Tag")
      continue
    if (isKeyInFilter(compName, filterString.get()))
      res.append({compName, compObj, eid = selectedEntity.get()})
    }
  res.sort(@(a, b) a.compName <=> b.compName)
  return res
})

function getSceneForEntity(eid) {
  if (eid != ecs.INVALID_ENTITY_ID) {
    return entity_editor?.get_instance().getSceneRecord(entity_editor?.get_instance().getEntityRecordSceneId(eid))
  }
  return {}
}

function getSceneIdTextForEntity(eid): string {
  if (eid != ecs.INVALID_ENTITY_ID) {
    local loadTypeVal = entity_editor?.get_instance().getEntityRecordLoadType(eid)
    if (loadTypeVal != 0) {
      let loadType = getSceneLoadTypeText(loadTypeVal)
      return "{0}:{1}".subst(loadType, entity_editor?.get_instance().getEntityRecordSceneId(eid))
    }
  }
  return ""
}

function mkEntityRow(eid, template_name, name, is_odd) {
  let group = ElemGroup()
  let stateFlags = Watched(0)

  let extraName = getEntityExtraName(eid)
  let extra = (extraName != null) ? $"/ {extraName}" : ""

  let div = (template_name != name) ? "•" : "|"

  let sceneText = getSceneIdTextForEntity(eid)

  return {
    size = [flex(), gridHeight]
    behavior = Behaviors.Button

    onClick = function(evt) {
      if (selectedEntities.get().len() > 1) {
        if (evt.ctrlKey)
          entity_editor?.get_instance().selectEntity(eid, false)
        else {
          selectedEntity.set(eid)
          entity_editor?.get_instance().setFocusedEntity(eid)
        }
      }
    }
    onHover = @(_on) null
    eventPassThrough = true
    onElemState = @(sf) stateFlags.set(sf & S_TOP_HOVER)
    group = group

    children = [
      @(){
        size = [flex(), gridHeight]
        rendObj = ROBJ_SOLID
        watch = stateFlags
        color = panelRowColorC(name, stateFlags.get(), "", is_odd)
        group
      }
      {
        rendObj = ROBJ_TEXT
        text = $"{eid}  {div}  {name} {extra}  {sceneText}"
        size = const [flex(), fontH(100)]
        margin = fsh(0.5)
        group = group
        behavior = Behaviors.Marquee
        scrollOnHover = true
        delay = 1.0
        speed = 50
      }
    ]
  }
}


function mkSceneComboBox(eid, sceneId) {
  let currentScene = Watched(null)
  if (sceneId == ecs.INVALID_SCENE_ID) {
    currentScene.set(noSceneParent)
  }
  else {
    let scene = sceneIdMap?.get()[sceneId]
    currentScene.set(sceneToComboboxEntry(scene))
  }

  return combobox(
    { value = currentScene,
      update = function(v) {
        local newSceneId = ecs.INVALID_SCENE_ID
        if (v != noSceneParent) {
          local index = allSceneTexts.get().indexof(v)
          if (index == null) {
            return
          }
          newSceneId = allModifiableScenes.get()[index].id
        }
        if (sceneId != newSceneId) {
          let item = {}
          item.isEntity <- true
          item.id <- eid
          entity_editor?.get_instance().setSceneNewParent(newSceneId, [item])
        }
      }
    }, allSceneTexts)
}






function mkEntityEditableDataRows(eid) {
  let acc = mkRowAcc()
  let isLocked = isEntityInLockedHierarchy(eid)

  
  
  
  let stateFlags = Watched(0)
  let group = ElemGroup()
  let isOdd = toggleBg()
  acc.addLeaf( 
    function() {
      let sceneId = entity_editor?.get_instance().getEntityRecordSceneId(eid) ?? ecs.INVALID_SCENE_ID
      let readOnly = (sceneId != ecs.INVALID_SCENE_ID && !canSceneBeModified(sceneIdMap.get()[sceneId])) || isLocked

      return {
        size = [flex(), gridHeight]
        behavior = Behaviors.Button
        eventPassThrough = true
        onElemState = @(sf) stateFlags.set(sf & S_TOP_HOVER)
        group = group
        watch = allScenesWatcher
        children = [
          @(){
            size = [flex(), gridHeight]
            rendObj = ROBJ_SOLID
            watch = stateFlags
            color = panelRowColor(stateFlags.get(), isOdd)
            group
          }
          {
            group
            gap = hdpx(2)
            valign = ALIGN_CENTER
            size = [flex(), gridHeight]
            flow = FLOW_HORIZONTAL
            children = [
              mkEntityRowText("", "Scene", "")
              readOnly
                ? {
                  rendObj = ROBJ_TEXT
                  halign = ALIGN_LEFT
                  valign = ALIGN_CENTER
                  size = flex()
                  text = sceneId != ecs.INVALID_SCENE_ID ? sceneToComboboxEntry(sceneIdMap.get()[sceneId]) : noSceneParent
                }
                : mkSceneComboBox(eid, sceneId)
            ]
          }
        ]
      }
    })

  foreach (v in filteredCurComponents.get())
    flattenComp(acc, eid, v.compName, v.compObj, isLocked, null, null, 0)

  
  
  
  
  let n = acc.ctors.len()
  let heights = []
  foreach (i, h in acc.ownH)
    heights.append(h + (i + 1 < n ? math.max(acc.marginV[i], acc.marginV[i + 1]) : 0))

  let tail = (extraPropPanelCtors.get() ?? []).map(@(ctor) ctor(eid)).filter(@(c) c != null)
  return { rows = acc.ctors, heights, tail }
}

let sortedEntities = Computed(function() {
  if (!propPanelVisible.get())
    return []

  local entitiesList = []
  foreach (eid, _v in selectedEntities.get()) {
    let tplName = ecs.g_entity_mgr.getEntityTemplateName(eid) ?? ""
    let name = removeSelectedByEditorTemplate(tplName)
    entitiesList.append({
      tplName
      name
      eid
    })
  }

  if (entitySortState.get()?.func != null)
    entitiesList.sort(@(lsh, rsh) entitySortState.get().func(lsh.eid, rsh.eid))
  return entitiesList
})

let templateFilterText = Watched("")

let filteredEntities = Computed(function() {
  let text = templateFilterText.get()
  let needFilter = (text?.len() ?? 0) > 0
  return needFilter
    ? sortedEntities.get().filter(@(v) v.name.contains(text))
    : sortedEntities.get()
})

let templateFilter = nameFilter(templateFilterText, {
  placeholder = "Filter by template"
  onChange = @(text) templateFilterText.set(text)
  onEscape = @() set_kb_focus(null)
  onReturn = @() set_kb_focus(null)
  onClear = function() {
    templateFilterText.set("")
    set_kb_focus(null)
  }
})

function compPanel() {
  local scenes = getAllScenes().map(function (item, ind) {
    item.index <- ind
    return item
  }) ?? [] 

  scenes.sort(sortScenesByLoadType)
  allModifiableScenes.set(scenes.filter(@(scene) canSceneBeModified(scene)))

  if (!propPanelVisible.get()) {
    return {
      watch = propPanelVisible
    }
  }
  else {
    updateModComps()

    toggleBg = makeBgToggle() 

    let showComps = !riSelectShown.get() && selectedEntity.get() != ecs.INVALID_ENTITY_ID
    let showList  = !riSelectShown.get() && !showComps && selectedEntities.get().len() > 1

    let eid = selectedEntity.get()
    let grid = mkEntityEditableDataRows(eid)
    let gridRootBase = {
      size = flex()
      flow = FLOW_VERTICAL
      behavior = Behaviors.Pannable
    }
    let scrolledGrid = {
      size = flex()
      rendObj = ROBJ_SOLID
      color = Color(50,50,50,100)
      children = makeVertScroll(null, {
        scrollHandler = gridScrollHandler
        rootBase = gridRootBase
        virtualItems = grid.rows
        virtualItemHeights = grid.heights
        virtualTail = grid.tail
      })
    }

    let nonSceneEntity = isNonSceneEntity()
    local captionPrefix = nonSceneEntity ? "[generated] " : ""
    if (eid!=ecs.INVALID_ENTITY_ID && selectedEntities.get().len() > 1)
      captionPrefix = $"<- {selectedEntities.get().len()} entities | {captionPrefix}"

    let templName = eid!=ecs.INVALID_ENTITY_ID ? removeSelectedByEditorTemplate(ecs.g_entity_mgr.getEntityTemplateName(eid) ?? "") : null
    let uiTemplName = eid!=ecs.INVALID_ENTITY_ID ? entity_editor?.get_template_name_for_ui(eid) : null
    local extraName = getEntityExtraName(eid)
    extraName = (extraName != null) ? $" / {extraName}" : ""

    let sceneIdText = getSceneIdTextForEntity(eid)
    let scene = getSceneForEntity(eid)
    local sceneTooltipText = ""
    if ("path" in scene) {
      sceneTooltipText = "{0} {1}".subst(sceneIdText, scene.path)
    }

    let captionText = eid!=ecs.INVALID_ENTITY_ID ? "{0}{1}: {2}{3}  {4}".subst(captionPrefix, eid, uiTemplName, extraName, sceneIdText) :
      selectedEntities.get().len() == 0 ? "No entity selected"
      : $"{selectedEntities.get().len()} entities selected"

    local listRows = []
    if (showList) {
      local odd = true
      foreach (v in filteredEntities.get()) {
        listRows.append(mkEntityRow(v.eid, v.tplName, v.name, odd))
        odd = !odd
      }
    }
    let scrolledList = {
      size = flex()
      rendObj = ROBJ_SOLID
      color = Color(50,50,50,100)
      children = makeVertScroll(listRows, {
        scrollHandler = listScrollHandler
        rootBase = {
          size = flex()
          flow = FLOW_VERTICAL
          behavior = Behaviors.Pannable
        }
      })
    }

    return {
      watch = [
        selectedEntity, selectedEntities, propPanelVisible, filterString,
        windowState, isCurEntityComponents, filteredCurComponents,
        de4workMode, riSelectShown, filteredEntities, edObjectFlagsUpdateTrigger,
        openedPaths
      ]
      size = const [sw(100), sh(100)]

      children = [
        {
          size = windowState.get().size
          pos = windowState.get().pos
          hplace = ALIGN_RIGHT

          behavior = Behaviors.MoveResize
          onMoveResize

          moveResizeCursors = cursors.moveResizeCursors
          cursor = cursors.normal

          padding = hdpx(2)
          rendObj = ROBJ_FRAME
          color = colors.ControlBg
          borderWidth = hdpx(2)

          children = [
            {
              size = flex() 
              rendObj = ROBJ_WORLD_BLUR_PANEL
              fillColor = Color(20,20,20,235)
              clipChildren = true

              flow = FLOW_VERTICAL
              children = [
                {
                  flow = FLOW_HORIZONTAL
                  size = FLEX_H
                  fillColor = colors.ControlBg
                  rendObj = ROBJ_BOX
                  children = [
                    showList ? mkSortModeButton(entitySortState, { fillColor = Color(0,10,20,210) }) : null
                    panelCaption(captionText, templName, sceneTooltipText)
                    closeButton(closePropPanel)
                  ]
                }
                showList ? templateFilter : null
                nonSceneEntity ? warningGenerated() : null
                showComps && isCurEntityComponents.get() ? compNameFilter : null
                showComps ? scrolledGrid : null
                showComps ? @() panelButtons(eid) : null
                showList  ? scrolledList : null
              ]
            }
            riSelectShown.get() ? riSelectWindow : null
            modalWindowsComponent
          ]
        }
        @() {
          watch = [templateTooltip]
          pos = windowState.get().pos
          hplace = ALIGN_CENTER
          children = templateTooltip.get()
        }
      ]
    }
  }
}

return compPanel
