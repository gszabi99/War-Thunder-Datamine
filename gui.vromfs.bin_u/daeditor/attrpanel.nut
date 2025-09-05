import "math" as math
from "dagor.math" import Point2, Point3, Point4
from "string" import endswith
from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *
from "%sqstd/ecs.nut" import *

let entity_editor = require_optional("entity_editor")
let { getValFromObj, isCompReadOnly, updateComp } = require("components/attrUtil.nut")
let { filterString, propPanelVisible, propPanelClosed, selectedCompName, extraPropPanelCtors, selectedEntity, selectedEntities, de4workMode, wantOpenRISelect } = require("state.nut")
let { colors, gridHeight } = require("components/style.nut")

let selectedCompComp = Watched(null)
let selectedCompPath = Watched(null)
let deselectComp = function() {
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
let { getEntityExtraName, getSceneLoadTypeText } = require("%daeditor/daeditor_es.nut")

let entitySortState = Watched({})

let windowState = Watched({
  pos = [-fsh(1.1), fsh(5)]
  size = [sw(29), sh(80)]
})


function onMoveResize(dx, dy, dw, dh) {
  let w = windowState.get()
  w.pos[0] = math.clamp(w.pos[0]+dx, -(sw(100)-w.size[0]), 0)
  w.pos[1] = math.max(w.pos[1]+dy, 0)
  w.size[0] = math.clamp(w.size[0]+dw, sw(14), sw(80))
  w.size[1] = math.clamp(w.size[1]+dh, sh(20), sh(95))
  return w
}

function get_tags(comp_flags){
  let tags = []
  comp_flags = comp_flags ?? 0
  if (comp_flags & COMP_FLAG_REPLICATED)
    tags.append("r")
  if (comp_flags & COMP_FLAG_CHANGE_EVENT)
    tags.append("t")
  return tags
}

function get_tagged_comp_name(comp_flags, comp_name) {
  local tags = get_tags(comp_flags).map(@(v) $"[{v}]")
  tags = "".join(tags)
  if (tags.len() <= 0)
    return comp_name
  return $"{tags} {comp_name}"
}

function makeBgToggle(initial=true) {
  local showBg = !initial
  function toggleBg() {
    showBg = !showBg
    return showBg
  }
  return toggleBg
}


let getModComps = function() {
  if (selectedEntity.get() == INVALID_ENTITY_ID)
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

function isNonSceneEntity() {
  return modifiedComponents.get() == null
}
function isModifiedComponent(cname, cpath) {
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
  selectedCompName.trigger()
}
function doResetSelectedComponent() {
  let eid = selectedEntity.get() ?? INVALID_ENTITY_ID
  if (eid == INVALID_ENTITY_ID)
    return
  if (selectedCompComp.get() == null)
    return
  doResetComponent(eid, selectedCompComp.get())
}


function panelRowColorC(comp_fullname, stateFlags, selectedCompNameVal, isOdd){
  local color = 0
  if (comp_fullname == selectedCompNameVal) {
    color = colors.Active
  } else {
    color = stateFlags & S_TOP_HOVER ? colors.GridRowHover
      : isOdd ? colors.GridBg[0]
      : colors.GridBg[1]
  }
  return color
}

let metaComponentPrefix     = "· "
let metaContainerPrefix     = "· "
let modifiedComponentPrefix = "• "
let modifiedContainerPrefix = "• "
let modifiedNoMetaPrefix    = "• "
let transformPrefix         = "¤ "
let modifiedSuffix          = ""

let mkCompNameText = function(comp_name, comp_name_text, metaInfo, modified, group=null) {
  let prefix = (comp_name=="transform") ? transformPrefix :
               modified ? (metaInfo ? modifiedComponentPrefix : modifiedNoMetaPrefix)
               : (metaInfo ? metaComponentPrefix : "")
  let suffix = modified ? modifiedSuffix : ""
  return {
    rendObj = ROBJ_TEXT
    text = $"{prefix}{comp_name_text}{suffix}"
    color = colors.TextDefault
    size = [flex(), fontH(100)]
    margin = fsh(0.5)
    group = group
    behavior = Behaviors.Marquee
    scrollOnHover = true
    delay = 0.3
    speed = hdpx(100)
  }
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

function panelCompRow(params={}) {
  let comp_name_ext = params?.comp_name_ext
  let comp_flags = params?.comp_flags ?? 0
  let {eid, comp_sq_type, rawComponentName, path, obj=null} = params
  let comp_name = params?.comp_name ?? comp_name_ext
  let fieldEditCtor = getCompNamePropEdit(rawComponentName) ?? getCompSqTypePropEdit(comp_sq_type) ?? fieldReadOnly
  let isOdd = toggleBg()
  let stateFlags = Watched(0)
  let group = ElemGroup()
  local comp_name_text = get_tagged_comp_name(comp_flags, (comp_name_ext ? comp_name_ext : comp_name))
  if (comp_sq_type == "TMatrix")
    comp_name_text = $"{comp_name_text}[3]"

  local comp_fullname = clone rawComponentName
  foreach (comp_key in (path ?? []))
    comp_fullname = $"{comp_fullname}.{comp_key}"
  let metaInfo = path==null ? g_entity_mgr.getTemplateDB().getComponentMetaInfo(comp_name) : null
  let modified = !isNonSceneEntity() && isModifiedComponent(comp_name, path)
  return function() {
    return {
      size = [flex(), gridHeight]
      behavior = Behaviors.Button

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
          watch = stateFlags
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

let removeSelectedByEditorTemplate = @(tname) tname.replace("+daeditor_selected+","+").replace("+daeditor_selected","").replace("daeditor_selected+","")

const attrPanelAddEntityTemplateUID = "attr_panel_add_entity_template"

function doAddTemplate(templateName) {
  let eid = selectedEntity.get()
  if (eid != INVALID_ENTITY_ID) {
    if (g_entity_mgr.getTemplateDB().getTemplateByName(templateName) == null) {
      infoBox("Invalid template name")
    } else {
      recreateEntityWithTemplates({eid, addTemplates=[templateName], callback=function(recreatedEid) {
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
  if (eid != INVALID_ENTITY_ID) {
    local tname = removeSelectedByEditorTemplate(g_entity_mgr.getEntityTemplateName(eid))
    if (tname == templateName) {
      infoBox("You can't remove last template")
    } else if (g_entity_mgr.getTemplateDB().getTemplateByName(templateName) == null) {
      infoBox("Invalid template name")
    } else {
      recreateEntityWithTemplates({eid, removeTemplates=[templateName], callback=function(recreatedEid) {
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
    padding = [0,hdpx(5)]
    scrollOnHover = true
    eventPassThrough = true
    behavior = [Behaviors.Marquee, Behaviors.Button]
    onHover = @(on) templateTooltip.set(on && tpl_name ? mkTemplateTooltip(tpl_name, sceneText) : null)
    onClick = function() {
      if (selectedEntities.get().len() > 1) {
        selectedEntity.set(INVALID_ENTITY_ID)
        entity_editor?.get_instance()?.setFocusedEntity(INVALID_ENTITY_ID)
      }
    }

    children = {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      text = text
      margin = [hdpx(5), 0]
    }
  }
}

function warningGenerated() {
  return {
    size = FLEX_H
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,10,210)
    padding = [0,hdpx(5)]

    children = {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      color = Color(192,150,150)
      fontSize = hdpx(12)
      text = " BEWARE : Generated entities are never saved to scene file, all changes will be lost upon restart"
      margin = [hdpx(5), 0]
    }
  }
}

function closePropPanel() {
  propPanelVisible.set(false)
  propPanelClosed.set(true)
}

function panelButtons() {
  return {
    size = [flex(), fsh(3.3)]
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)
    borderColor = Color(30,30,30,100)
    borderWidth = hdpx(1)
    padding = [0,hdpx(5)]
    eventPassThrough = true
    watch = [selectedCompComp, selectedCompPath]
    children = {
      flow = FLOW_HORIZONTAL
      hplace = ALIGN_RIGHT
      vplace = ALIGN_CENTER
      children = [
        isModifiedComponent(selectedCompComp.get(), selectedCompPath.get()) ? textButton("R", doResetSelectedComponent) : null
        textButton("-", openDelTemplateDialog)
        textButton("+", openAddTemplateDialog)
        textButton("Close", closePropPanel)
      ]
    }
  }
}

let autoOpenClosePropPanel = function(_) {
  local show = selectedEntity.get() != INVALID_ENTITY_ID || selectedEntities.get().len() > 0
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

function isComponentHidden(k){
  if (hiddenComponents?[k] || k.slice(0,1)=="_")
    return true
  if (endswith(k, "$copy"))
    return true
  return false
}

function isKeyInFilter(key, filterStr=null){
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
  padding = [0,hdpx(1)]
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
let isOpenedCache = persist("isOpenedCache", @() {})
selectedEntity.subscribe(function(_eid){
  const maxCacheEntries = 100
  if (isOpenedCache.len()>maxCacheEntries)
    isOpenedCache.clear()
})

function getOpenedCacheEntry(eid, cname, cpath) {
  local cachekey = clone cname
  foreach (key in (cpath ?? []))
    cachekey = $"{cachekey}.{key}"
  let isOpened = isOpenedCache?[eid][cachekey] ?? Watched(false)
  if (eid not in isOpenedCache)
    isOpenedCache[eid] <- {}
  if (isOpenedCache?[eid][cachekey]==null)
    isOpenedCache[eid][cachekey] <- isOpened
  return isOpened
}


let addPropValueTypes = ["text" "real" "bool" "integer" "array" "object" "Point2" "Point3" "Point4"]

const attrPanelAddObjectValueUID = "attr_panel_add_object_value"

function doAddObjectValue(eid, cname, cpath, value_name, value_type) {
  local object = _dbg_get_comp_val_inspect(eid, cname)
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

    obsolete_dbg_set_comp_val(eid, cname, object)
    entity_editor?.save_component(eid, cname)

    getOpenedCacheEntry(eid, cname, cpath).set(true)
    selectedCompName.trigger()
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
  local object = _dbg_get_comp_val_inspect(eid, cname)
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
      obsolete_dbg_set_comp_val(eid, cname, object)
      entity_editor?.save_component(eid, cname)
      getOpenedCacheEntry(eid, cname, cpath).set(true)
      selectedCompName.trigger()
    } catch(e) {
      logerr($"Failed to append array value, reason: {e}")
    }
  }
  else {
    try {
      ccobj.insert(ckey.tointeger(), value)
      obsolete_dbg_set_comp_val(eid, cname, object)
      entity_editor?.save_component(eid, cname)
      getOpenedCacheEntry(eid, cname, cpath).set(true)
      selectedCompName.trigger()
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

  local object = _dbg_get_comp_val_inspect(eid, cname)
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
    selectedCompName.trigger()
    return
  }

  if (type(ccobj)=="table" || ccobj instanceof CompObject) {
    if (op=="insert") {
      openAddObjectValueDialog(eid, cname, cpath, ccobj)
    }
    else if (op=="delete") {
      if (ckey==null) {
        infoBox("Please, select object value to delete")
        return
      }
      try {
        ccobj.remove(ckey)
      } catch(e) {
        logerr($"Failed to remove value {ckey}, reason: {e}")
      }
      obsolete_dbg_set_comp_val(eid, cname, object)
      entity_editor?.save_component(eid, cname)
      getOpenedCacheEntry(eid, cname, cpath).set(true)
      deselectComp()
    }
  }
  else if (type(ccobj)=="array" || ccobj?.getAll()!=null) {
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
      else if (listType=="int")
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
          obsolete_dbg_set_comp_val(eid, cname, object)
          entity_editor?.save_component(eid, cname)
          getOpenedCacheEntry(eid, cname, cpath).set(true)
          selectedCompName.trigger()
        } catch(e) {
          logerr($"Failed to append array value, reason: {e}")
        }
      }
      else {
        try {
          ccobj.insert(ckey.tointeger(), value)
          obsolete_dbg_set_comp_val(eid, cname, object)
          entity_editor?.save_component(eid, cname)
          getOpenedCacheEntry(eid, cname, cpath).set(true)
          selectedCompName.trigger()
        } catch(e) {
          logerr($"Failed to insert array value, reason: {e}")
        }
      }
    }
    else if (op=="delete") {
      if (ckey==null) {
        try {
          ccobj.pop()
          obsolete_dbg_set_comp_val(eid, cname, object)
          entity_editor?.save_component(eid, cname)
          getOpenedCacheEntry(eid, cname, cpath).set(true)
          selectedCompName.trigger()
        } catch(e) {
          logerr($"Failed to pop array value, reason: {e}")
        }
      }
      else {
        try {
          ccobj.remove(ckey.tointeger())
          obsolete_dbg_set_comp_val(eid, cname, object)
          entity_editor?.save_component(eid, cname)
          getOpenedCacheEntry(eid, cname, cpath).set(true)
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
        margin = [0,hdpx(3)]
        padding = [0,hdpx(8)]
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
        margin = [0,hdpx(3)]
        padding = [0,hdpx(8)]
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

function mkCollapsible(isConst, caption, childrenCtor=@() null, len=0, tags = null, eid=null, rawComponentName=null, path=null){
  let empty = len==0
  tags = tags ?? []
  let isRoot = (path?.len()??0) < 1
  let metaInfo = isRoot ? g_entity_mgr.getTemplateDB().getComponentMetaInfo(rawComponentName) : null
  let modified = isRoot && !isNonSceneEntity() ? isModifiedComponent(rawComponentName, null) : false
  let prefix = modified ? (metaInfo ? modifiedContainerPrefix : modifiedNoMetaPrefix)
               : (metaInfo ? metaContainerPrefix : "")
  let suffix = modified ? modifiedSuffix : ""
  let captionText = {rendObj = ROBJ_TEXT, text = $"{prefix}{caption}{suffix}", color = Color(180,180,180)}
  let padding = [hdpx(5), hdpx(5)]
  let gap = hdpx(4)
  let isOdd = toggleBg()
  if (empty){
    return @() {
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
            isConst || !isModifiedComponent(rawComponentName, path) ? null : textButton("R", @() doResetComponent(eid, rawComponentName), collapsibleButtonsStyleDark)
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
    }
  }
  let isOpened = getOpenedCacheEntry(eid, rawComponentName, path)
  let captionUi = @() {
    watch = isOpened
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)
    borderColor = Color(30,30,30,20)
    padding
    key = caption
    gap
    borderWidth = hdpx(1)
    children = [
      {
        gap
        size = FLEX_H
        hplace = ALIGN_LEFT
        flow = FLOW_HORIZONTAL
        children = [isOpened.get() ? downArrow : rightArrow].append(isConst ? constTag : null).extend(tags).append(captionText)
      }
      {
        gap
        hplace = ALIGN_RIGHT
        flow = FLOW_HORIZONTAL
        children = [
          isConst || !isModifiedComponent(rawComponentName, path) ? null : textButton("R", @() doResetComponent(eid, rawComponentName), collapsibleButtonsStyleDark)
          !isOpened.get() || isConst ? null : textButton("-", @() doContainerOp(eid, rawComponentName, path, "delete"), collapsibleButtonsStyle)
          !isOpened.get() || isConst ? null : textButton("+", @() doContainerOp(eid, rawComponentName, path, "insert"), collapsibleButtonsStyle)
        ]
      }
    ]
    flow = FLOW_HORIZONTAL
    behavior = Behaviors.Button
    onClick = @() isOpened.set(!isOpened.get())
    onHover = @(on) cursors.setTooltip(on ? mkCompTooltip(metaInfo) : null)
    size = FLEX_H
    margin = [hdpx(1),0]
  }
  return function(){
    local content = null
    if (isOpened.get())
      content = {children = childrenCtor(), size=FLEX_H, flow = FLOW_VERTICAL, margin = [0,0,0, fsh(1)]}
    return {
      children = [captionUi, content]
      watch = isOpened
      flow = FLOW_VERTICAL
      size = FLEX_H
    }
  }
}

local mkCompList
local mkCompObject
local mkComp

let compTag = memoize(mkTagFromText)
let mkCompFlagTag = memoize(@(text) mkTagFromTextColor(text, Color(40,90,90, 50), [SIZE_TO_CONTENT, hdpx(15)]))
let mkFlagTags = @(eid, rawComponentName)
  get_tags(get_comp_flags(eid, rawComponentName)).map(mkCompFlagTag)

function updateAttrComponent(eid, cname) {
  updateComp(eid, cname)
  gui_scene.resetTimeout(0.1, @() selectedCompName.trigger())
}

mkCompObject = function(eid, rawComponentName, rawObject, caption=null, onChange = null, path = null){
  local isFirst = caption==null
  caption = caption ?? rawComponentName
  isFirst = isFirst || rawComponentName==caption
  onChange = @() updateAttrComponent(eid, rawComponentName)
  let object = getValFromObj(eid, rawComponentName, path)
  let objData = object?.getAll() ?? object
  let objLen = objData.len()
  path = path ?? []
  function childrenCtor() {
    let contentChildren = []
    let objKeys = objData.keys().filter(@(v) !isComponentHidden(v)).sort(@(a, b) a <=> b)
    foreach (ok in objKeys) {
      let nkeys = (clone path).append(ok)
      if (objData[ok]?.getAll() != null ) {
        contentChildren.append(mkComp(eid, rawComponentName, rawObject, ok, onChange, nkeys))
      }
      else if (type(objData[ok])=="table") {
        contentChildren.append(mkComp(eid, rawComponentName, rawObject, ok, onChange, nkeys))
      }
      else if (type(objData[ok])=="array") {
        contentChildren.append(mkComp(eid, rawComponentName, rawObject, ok, onChange, nkeys))
      }
      else {
        contentChildren.append(panelCompRow({rawComponentName, comp_name_ext = ok, obj=rawObject, eid, comp_sq_type = typeof objData[ok], onChange, path=nkeys}))
      }
    }
    return contentChildren
  }
  let isConst = isCompReadOnly(eid, rawComponentName)
  let tags = isFirst ? mkFlagTags(eid, rawComponentName).append(ecsObjectSign) : [ecsObjectSign]
  return mkCollapsible(isConst, caption, childrenCtor, objLen, tags, eid, rawComponentName, path)
}

let compTypeName = function(object){
  local typeName = ""
  if (type(object)=="array")
    typeName = "Array"
  else if (type(object)=="table")
    typeName = "Obj"
  else {
    typeName = object.tostring()
    let isComp = typeName.indexof("Comp") !=null
    typeName = typeName.slice(isComp ? "Comp".len() : 0, typeName.indexof(" (") ?? typeName.len())
  }
  return typeName
}

mkCompList = function(eid, rawComponentName, rawObject, caption=null, onChange=null, path = null){
  let isFirst = caption == null
  caption = caption ?? rawComponentName
  onChange = @() updateAttrComponent(eid, rawComponentName)
  let object = getValFromObj(eid, rawComponentName, path)
  let len = object?.len() ?? 0
  path = path ?? []
  function childrenCtor(){
    let res = []
    foreach (num, _val in (object?.getAll() ?? object)) {
      let nkeys = (clone path).append(num)
      res.append(mkComp(eid, rawComponentName, rawObject, $"{caption}[{num}]", onChange, nkeys))
    }
    return res
  }
  let isConst = isCompReadOnly(eid, rawComponentName)
  let fCaption = len>0 ? $"{caption} [{len}]" : caption
  let typeTag = compTag(compTypeName(object))
  let tags = isFirst ? mkFlagTags(eid, rawComponentName).append(typeTag) : [typeTag]
  return mkCollapsible(isConst, fCaption, childrenCtor, len, tags, eid, rawComponentName, path)
}


mkComp = function(eid, rawComponentName, rawObject, caption=null, onChange = null, path = null){
  onChange = @() updateAttrComponent(eid, rawComponentName)
  let object = getValFromObj(eid, rawComponentName, path)
  let comp_sq_type = typeof object

  let isFirst = caption==null
  let params = {
    eid, comp_sq_type, onChange, path
    comp_flags = isFirst ? get_comp_flags(eid, rawComponentName) : null,
    comp_name=rawComponentName,
    rawComponentName,
    comp_name_ext = caption
    obj = rawObject
  }
  if (path == null && get_comp_type(eid, rawComponentName) != TYPE_STRING && type(object) == "string"){
    return panelCompRow(params.__merge({comp_sq_type="null" comp_flags = get_comp_flags(eid, rawComponentName)}))
  }
  if (getCompSqTypePropEdit(comp_sq_type) != null) {
    return panelCompRow(params)
  }
  if (type(object) == "table" || object instanceof CompObject) {
    return mkCompObject(eid, rawComponentName, rawObject, caption, onChange, path)
  }
  if (object?.getAll()!=null || type(object)=="array") {
    return mkCompList(eid, rawComponentName, rawObject, caption, onChange, path)
  }
  return panelCompRow(params)
}

function ecsObjToQuirrel(x) {
  return x.map(@(val) val?.getAll() ?? val)
}

let getCurComps = @() (selectedEntity.get() ?? INVALID_ENTITY_ID) == INVALID_ENTITY_ID ? {} : ecsObjToQuirrel(_dbg_get_all_comps_inspect(selectedEntity.get()))
let curEntityComponents = Watched(getCurComps())
let setCurComps = @() curEntityComponents.set(getCurComps())

selectedEntity.subscribe_with_nasty_disregard_of_frp_update(function(eid){
  gui_scene.resetTimeout(0.1, setCurComps)

  if (wantOpenRISelect.get()) {
    wantOpenRISelect.set(false)
    gui_scene.resetTimeout(0.1, function() {
      openRISelectForEntity(eid)
    })
  }
})

register_es("update_cur_components_on_entity_recreated",
{
  [[EventEntityRecreated]] = function(...){
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
  if (eid != INVALID_ENTITY_ID) {
    local loadTypeVal = entity_editor?.get_instance().getEntityRecordLoadType(eid)
    if (loadTypeVal != 0) {
      let index = entity_editor?.get_instance().getEntityRecordIndex(eid)
      return entity_editor?.get_instance().getSceneRecord(loadTypeVal, index)
    }
  }
  return {}
}

function getSceneIdTextForEntity(eid) {
  if (eid != INVALID_ENTITY_ID) {
    local loadTypeVal = entity_editor?.get_instance().getEntityRecordLoadType(eid)
    if (loadTypeVal != 0) {
      let loadType = getSceneLoadTypeText(loadTypeVal)
      let index = entity_editor?.get_instance().getEntityRecordIndex(eid)
      return "{0}:{1}".subst(loadType, index)
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
      @(){
        rendObj = ROBJ_TEXT
        text = $"{eid}  {div}  {name} {extra}  {sceneText}"
        size = [flex(), fontH(100)]
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

let sortedEntities = Computed(function() {
  if (!propPanelVisible.get())
    return []

  local entitiesList = []
  foreach (eid, _v in selectedEntities.get()) {
    let tplName = g_entity_mgr.getEntityTemplateName(eid) ?? ""
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

  function onChange(text) {
    templateFilterText.set(text)
  }

  function onEscape() {
    set_kb_focus(null)
  }

  function onReturn() {
    set_kb_focus(null)
  }

  function onClear() {
    templateFilterText.set("")
    set_kb_focus(null)
  }
})


function compPanel() {

  if (!propPanelVisible.get()) {
    return {
      watch = propPanelVisible
    }
  }
  else {
    updateModComps()

    toggleBg = makeBgToggle() 

    let showComps = !riSelectShown.get() && selectedEntity.get() != INVALID_ENTITY_ID
    let showList  = !riSelectShown.get() && !showComps && selectedEntities.get().len() > 1

    let eid = selectedEntity.get()
    let rows = filteredCurComponents.get().map(function(v) {
      return mkComp(eid, v.compName, v.compObj)
    })
    rows.extend((extraPropPanelCtors.get() ?? []).map(@(ctor) ctor(eid)))
    let scrolledGrid = {
      size = flex()
      rendObj = ROBJ_SOLID
      color = Color(50,50,50,100)
      children = makeVertScroll(rows, {
        rootBase = {
          size = flex()
          flow = FLOW_VERTICAL
          behavior = Behaviors.Pannable
        }
      })
    }

    let nonSceneEntity = isNonSceneEntity()
    local captionPrefix = nonSceneEntity ? "[generated] " : ""
    if (eid!=INVALID_ENTITY_ID && selectedEntities.get().len() > 1)
      captionPrefix = $"<- {selectedEntities.get().len()} entities | {captionPrefix}"

    let templName = eid!=INVALID_ENTITY_ID ? removeSelectedByEditorTemplate(g_entity_mgr.getEntityTemplateName(eid) ?? "") : null
    let uiTemplName = eid!=INVALID_ENTITY_ID ? entity_editor?.get_template_name_for_ui(eid) : null
    local extraName = getEntityExtraName(eid)
    extraName = (extraName != null) ? $" / {extraName}" : ""

    let sceneIdText = getSceneIdTextForEntity(eid)
    let scene = getSceneForEntity(eid)
    local sceneTooltipText = ""
    if ("path" in scene) {
      sceneTooltipText = "{0} {1}".subst(sceneIdText, scene.path)
    }

    let captionText = eid!=INVALID_ENTITY_ID ? "{0}{1}: {2}{3}  {4}".subst(captionPrefix, eid, uiTemplName, extraName, sceneIdText) :
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
        windowState, isCurEntityComponents, filteredCurComponents, selectedCompName,
        de4workMode, riSelectShown, filteredEntities
      ]
      size = [sw(100), sh(100)]

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
                showComps ? panelButtons : null
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
