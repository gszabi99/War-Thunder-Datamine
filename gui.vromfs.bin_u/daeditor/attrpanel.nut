from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *
from "ecs" import *

let {logerr} = require("dagor.debug")
let { Point2, Point3, Point4 } = require("dagor.math")

let {endswith} = require("string")
let {getValFromObj, isCompReadOnly} = require("components/attrUtil.nut")
let {filterString, propPanelVisible, propPanelClosed, selectedCompName, extraPropPanelCtors, selectedEntity, selectedEntities} = require("state.nut")
let {colors, gridHeight} = require("components/style.nut")

let selectedCompComp = Watched(null)
let selectedCompPath = Watched(null)
let deselectComp = function() {
  selectedCompName("")
  selectedCompComp(null)
  selectedCompPath(null)
}

let entity_editor = require("entity_editor")
let textButton = require("components/textButton.nut")
let textInput = require("%darg/components/textInput.nut")
let modalWindows = require("%darg/components/modalWindowsMngr.nut")({halign = ALIGN_CENTER valign = ALIGN_CENTER rendObj=ROBJ_WORLD_BLUR})
let {addModalWindow, removeModalWindow, modalWindowsComponent} = modalWindows
let {showMsgbox} = require("editor_msgbox.nut")
let infoBox = @(text) showMsgbox({text})

let cursors = require("components/cursors.nut")
let {getCompSqTypePropEdit, getCompNamePropEdit} = require("propPanelControls.nut")
let scrollbar = require("%darg/components/scrollbar.nut")

let fieldReadOnly = require("components/apFieldReadOnly.nut")
let compNameFilter = require("components/apNameFilter.nut")(filterString, selectedCompName)

let combobox = require("%darg/components/combobox.nut")

let windowState = Watched({
  pos = [-fsh(1.1), fsh(5)]
  size = [sw(29), SIZE_TO_CONTENT]
})


let function onMoveResize(dx, dy, dw, dh) {
  let w = windowState.value
  w.pos[0] = clamp(w.pos[0]+dx, -(sw(100)-w.size[0]), 0)
  w.pos[1] = max(w.pos[1]+dy, 0)
  w.size[0] = clamp(w.size[0]+dw, sw(14), sw(80))
  return w
}

local function get_tags(comp_flags){
  let tags = []
  comp_flags = comp_flags ?? 0
  if (comp_flags & COMP_FLAG_REPLICATED)
    tags.append("r")
  if (comp_flags & COMP_FLAG_CHANGE_EVENT)
    tags.append("t")
  return tags
}

let function get_tagged_comp_name(comp_flags, comp_name) {
  local tags = get_tags(comp_flags).map(@(v) $"[{v}]")
  tags = "".join(tags)
  return $"{tags} {comp_name}"
}

let function makeBgToggle(initial=true) {
  local showBg = !initial
  let function toggleBg() {
    showBg = !showBg
    return showBg
  }
  return toggleBg
}

let function panelRowColorC(comp_fullname, stateFlags, selectedCompNameVal, isOdd){
  local color = 0
  if (comp_fullname == selectedCompNameVal) {
    color = colors.Active
  } else {
    color = (stateFlags & S_HOVER) ? colors.GridRowHover : isOdd ? colors.GridBg[0] : colors.GridBg[1]
  }
  return color
}

let mkCompNameText = @(comp_name_text, group=null) {
  rendObj = ROBJ_DTEXT
  text = comp_name_text
  size = [flex(), fontH(100)]
  margin = fsh(0.5)
  group = group
  behavior = Behaviors.Marquee
  scrollOnHover = true
  delay = 1.0
  speed = 50
}

local toggleBg = makeBgToggle()

let function panelCompRow(params={}) {
  let comp_name_ext = params?.comp_name_ext
  let comp_flags = params?.comp_flags ?? 0
  let {eid, comp_sq_type, rawComponentName, path, obj=null} = params
  let comp_name = params?.comp_name ?? comp_name_ext
  let fieldEditCtor = getCompNamePropEdit(rawComponentName) ?? getCompSqTypePropEdit(comp_sq_type) ?? fieldReadOnly
  let isOdd = toggleBg()
  let stateFlags = Watched(0)
  let group = ElemGroup()
  let comp_name_text = get_tagged_comp_name(comp_flags, (comp_name_ext ? comp_name_ext : comp_name))
  local comp_fullname = clone rawComponentName
  foreach (comp_key in (path ?? []))
    comp_fullname = $"{comp_fullname}.{comp_key}"
  return function() {

    return {
      size = [flex(), gridHeight]
      behavior = Behaviors.Button

      onClick = function() {
        let deselect = (selectedCompName.value == comp_fullname)
        selectedCompName(deselect ? null : comp_fullname)
        selectedCompComp(deselect ? null : rawComponentName)
        selectedCompPath(deselect ? null : path)
      }
      eventPassThrough = true
      onElemState = @(sf) stateFlags.update(sf)
      group = group

      children = [
        @(){
          size = [flex(), gridHeight]
          rendObj = ROBJ_SOLID
          watch = stateFlags
          color = panelRowColorC(comp_fullname, stateFlags.value, selectedCompName.value, isOdd)
          group
        }
        {
          group
          gap = hdpx(2)
          valign = ALIGN_CENTER
          size = [flex(), gridHeight]
          flow = FLOW_HORIZONTAL
          children = [
            mkCompNameText(comp_name_text, group)
            fieldEditCtor(params.__merge({eid, obj, comp_name, rawComponentName}))
          ]
        }
      ]
    }
  }
}

let removeSelectedByEditorTemplate = @(tname) tname.replace("+daeditor_selected+","+").replace("+daeditor_selected","").replace("daeditor_selected+","")

let function updateEntityTemplateNameCallback(recreatedEid) {
  local tname = removeSelectedByEditorTemplate(g_entity_mgr.getEntityTemplateName(recreatedEid))
  log("Saving entity template =", tname)
  entity_editor.save_template(recreatedEid, tname)
}

const attrPanelAddEntityTemplateUID = "attr_panel_add_entity_template"

let function doAddTemplate(templateName) {
  let eid = selectedEntity.value
  if (eid != INVALID_ENTITY_ID) {
    if (g_entity_mgr.getTemplateDB().getTemplateByName(templateName) == null) {
      infoBox("Invalid template name")
    } else {
      recreateEntityWithTemplates({eid=eid, addTemplates=[templateName], callback=updateEntityTemplateNameCallback})
    }
  } else {
    infoBox("Entity not selected")
  }
  removeModalWindow(attrPanelAddEntityTemplateUID)
  selectedEntity.trigger()
}

let function openAddTemplateDialog() {
  let templateName = Watched("")
  let templateNameComp = textInput(templateName, {onAttach = @(elem) set_kb_focus(elem)})
  let close = @() removeModalWindow(attrPanelAddEntityTemplateUID)

  let isTemplateNameValid = Computed(@() templateName.value!=null && templateName.value!="")

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
          children = isTemplateNameValid.value ? textButton("Add template", @() doAddTemplate(templateName.value)) : null
        }
      )
    )
  })
}

const attrPanelDelEntityTemplateUID = "attr_panel_del_entity_template"

let function doDelTemplate(templateName) {
  let eid = selectedEntity.value
  if (eid != INVALID_ENTITY_ID) {
    local tname = removeSelectedByEditorTemplate(g_entity_mgr.getEntityTemplateName(eid))
    if (tname == templateName) {
      infoBox("You can't remove last template")
    } else if (g_entity_mgr.getTemplateDB().getTemplateByName(templateName) == null) {
      infoBox("Invalid template name")
    } else {
      recreateEntityWithTemplates({eid=eid, removeTemplates=[templateName], callback=updateEntityTemplateNameCallback})
    }
  } else {
    infoBox("Entity not selected")
  }
  removeModalWindow(attrPanelDelEntityTemplateUID)
  selectedEntity.trigger()
}

let function openDelTemplateDialog() {
  let templateName = Watched("")
  let templateNameComp = textInput(templateName, {onAttach = @(elem) set_kb_focus(elem)})
  let close = @() removeModalWindow(attrPanelDelEntityTemplateUID)

  let isTemplateNameValid = Computed(@() templateName.value!=null && templateName.value!="")

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
          children = isTemplateNameValid.value ? textButton("Remove template", @() doDelTemplate(templateName.value)) : null
        }
      )
    )
  })
}

let function panelCaption(text) {
  return {
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)//colors.ControlBg
    borderColor = Color(30,30,30,20)
    borderWidth = hdpx(1)
    padding = [0,hdpx(5)]
    scrollOnHover = true
    eventPassThrough = true
    behavior = [Behaviors.Marquee, Behaviors.Button]

    children = {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      rendObj = ROBJ_DTEXT
      text = text
      margin = [hdpx(5), 0]
    }
  }
}

let function panelButtons() {
  return {
    size = [flex(), fsh(3.3)]
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)//colors.ControlBg
    borderColor = Color(30,30,30,100)
    borderWidth = hdpx(1)
    padding = [0,hdpx(5)]
    eventPassThrough = true
    children = {
      flow = FLOW_HORIZONTAL
      hplace = ALIGN_RIGHT
      vplace = ALIGN_CENTER
      children = [
        textButton("-", openDelTemplateDialog)
        textButton("+", openAddTemplateDialog)
        textButton("Close", function() {
          propPanelVisible(false)
          propPanelClosed(true)
        })
      ]
    }
  }
}

let autoOpenClosePropPanel = function(v) {
  local show = selectedEntity.value != INVALID_ENTITY_ID && selectedEntities.value.len() == 1
  if (show && propPanelClosed.value)
    return
  propPanelVisible(show)
}
selectedEntity.subscribe(autoOpenClosePropPanel)
selectedEntities.subscribe(autoOpenClosePropPanel)


let hiddenComponents = {
  editableObj = true
  nonCreatableObj = true
  daeditor__selected = true
}

let function isComponentHidden(k){
  if (hiddenComponents?[k] || k.slice(0,1)=="_")
    return true
  if (endswith(k, "$copy"))
    return true
  return false
}

let function isKeyInFilter(key, filterStr=null){
  if (filterStr==null || filterStr.len()==0 || key.tolower().contains(filterStr.tolower()))
    return true
  return false
}

let rightArrow = {rendObj = ROBJ_DTEXT text = "^" transform = {rotate=90}}
let downArrow = {rendObj = ROBJ_DTEXT text = "^" transform = {rotate=180}}
let mkTagFromTextColor = @(text, fillColor = Color(100,100,100), size = SIZE_TO_CONTENT, textColor = Color(0,0,0)) {
  rendObj = ROBJ_BOX
  size
  borderWidth = 0
  borderRadius = hdpx(4)
  fillColor
  padding = [0,hdpx(1)]
  vplace = ALIGN_CENTER
  children = {
    rendObj = ROBJ_DTEXT
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
selectedEntity.subscribe(function(eid){
  const maxCacheEntries = 100
  if (isOpenedCache.len()>maxCacheEntries)
    isOpenedCache.clear()
})

let function getOpenedCacheEntry(eid, cname, cpath) {
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


let addPropValueTypes = ["text" "real" "bool" "integer" "array" "object"]

const attrPanelAddObjectValueUID = "attr_panel_add_object_value"

let function doAddObjectValue(eid, cname, cpath, value_name, value_type) {
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

    obsolete_dbg_set_comp_val(eid, cname, object)
    entity_editor.save_component(eid, cname)

    getOpenedCacheEntry(eid, cname, cpath).update(true)
    selectedCompName.trigger()
  } catch (e) {
    logerr($"Failed to add object value {value_name} (type {value_type}), reason: {e}")
  }

  removeModalWindow(attrPanelAddObjectValueUID)
}

let function openAddObjectValueDialog(eid, cname, cpath, ccobj) {
  let valueName = Watched("")
  let valueType = Watched(addPropValueTypes[0])
  let valueNameComp = textInput(valueName, {onAttach = @(elem) set_kb_focus(elem)})
  let valueTypeComp = combobox(valueType, addPropValueTypes)
  let close = @() removeModalWindow(attrPanelAddObjectValueUID)

  let isValueNameValid = Computed(@() valueName.value!=null && valueName.value!="" && ccobj!=null && ccobj?[valueName.value]==null)

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
          children = isValueNameValid.value ? textButton("Add value", @() doAddObjectValue(eid, cname, cpath, valueName.value, valueType.value)) : null
        }
      )
    )
  })
}

const attrPanelAddArrayValueUID = "attr_panel_add_array_value"

let function doAddArrayValue(eid, cname, cpath, ckey, value_type) {
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

  if (value==null) {
    infoBox($"Unsupported array value type: {value_type}")
    return
  }

  if (ckey==null) {
    try {
      ccobj.append(value)
      obsolete_dbg_set_comp_val(eid, cname, object)
      entity_editor.save_component(eid, cname)
      getOpenedCacheEntry(eid, cname, cpath).update(true)
      selectedCompName.trigger()
    } catch(e) {
      logerr($"Failed to append array value, reason: {e}")
    }
  }
  else {
    try {
      ccobj.insert(ckey.tointeger(), value)
      obsolete_dbg_set_comp_val(eid, cname, object)
      entity_editor.save_component(eid, cname)
      getOpenedCacheEntry(eid, cname, cpath).update(true)
      selectedCompName.trigger()
    } catch(e) {
      logerr($"Failed to insert array value, reason: {e}")
    }
  }

  removeModalWindow(attrPanelAddArrayValueUID)
}

let function openAddArrayValueDialog(eid, cname, cpath, ckey) {
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
          children = textButton("Add value", @() doAddArrayValue(eid, cname, cpath, ckey, valueType.value))
        }
      )
    )
  })
}

let function doContainerOp(eid, comp_name, cont_path, op) {
  local cname = comp_name
  local cpath = cont_path
  local ckey  = null
  let spath = selectedCompPath.value
  let len1 = (spath?.len()??0)
  let len2 = (cpath?.len()??0)
  if (selectedCompComp.value == comp_name && len1 == len2 + 1) {
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
    selectedCompComp(comp_name)
    selectedCompPath(cpath)
    local strpath = clone comp_name
    foreach (key in cpath)
      strpath = $"{strpath}.{key}"
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
      entity_editor.save_component(eid, cname)
      getOpenedCacheEntry(eid, cname, cpath).update(true)
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
          entity_editor.save_component(eid, cname)
          getOpenedCacheEntry(eid, cname, cpath).update(true)
          selectedCompName.trigger()
        } catch(e) {
          logerr($"Failed to append array value, reason: {e}")
        }
      }
      else {
        try {
          ccobj.insert(ckey.tointeger(), value)
          obsolete_dbg_set_comp_val(eid, cname, object)
          entity_editor.save_component(eid, cname)
          getOpenedCacheEntry(eid, cname, cpath).update(true)
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
          entity_editor.save_component(eid, cname)
          getOpenedCacheEntry(eid, cname, cpath).update(true)
          selectedCompName.trigger()
        } catch(e) {
          logerr($"Failed to pop array value, reason: {e}")
        }
      }
      else {
        try {
          ccobj.remove(ckey.tointeger())
          obsolete_dbg_set_comp_val(eid, cname, object)
          entity_editor.save_component(eid, cname)
          getOpenedCacheEntry(eid, cname, cpath).update(true)
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

local function mkCollapsible(isConst, caption, childrenCtor=@() null, len=0, tags = null, eid=null, rawComponentName=null, path=null){
  let empty = len==0
  tags = tags ?? []
  let captionText = {rendObj = ROBJ_DTEXT, text = caption, color = Color(180,180,180)}
  let padding = [hdpx(5), hdpx(5)]
  let gap = hdpx(4)
  let isOdd = toggleBg()
  if (empty){
    return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      children = [
        {
          gap
          size = [flex(), SIZE_TO_CONTENT]
          hplace = ALIGN_LEFT
          flow = FLOW_HORIZONTAL
          children = [].append(isConst ? constTag : null).extend(clone tags).append(emptyTag, captionText)
        }
        {
          gap
          hplace = ALIGN_RIGHT
          flow = FLOW_HORIZONTAL
          children = [
            isConst || ((path?.len()??0)<1) ? null : textButton("X", @() doContainerOp(eid, rawComponentName, path, "delself"), collapsibleButtonsStyleDark)
            isConst                         ? null : textButton("+", @() doContainerOp(eid, rawComponentName, path, "insert"), collapsibleButtonsStyle)
          ]
        }

      ]
      padding = padding
      gap = gap
      rendObj = ROBJ_SOLID
      color = isOdd ? colors.GridBg[0] : colors.GridBg[1]
    }
  }
  let isOpened = getOpenedCacheEntry(eid, rawComponentName, path)
  let captionUi = @() {
    watch = isOpened
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)//colors.ControlBg
    borderColor = Color(30,30,30,20)
    padding
    key = caption
    gap
    borderWidth = hdpx(1)
    children = [
      {
        gap
        size = [flex(), SIZE_TO_CONTENT]
        hplace = ALIGN_LEFT
        flow = FLOW_HORIZONTAL
        children = [isOpened.value ? downArrow : rightArrow].append(isConst ? constTag : null).extend(tags).append(captionText)
      }
      {
        gap
        hplace = ALIGN_RIGHT
        flow = FLOW_HORIZONTAL
        children = [
          !isOpened.value || isConst ? null : textButton("-", @() doContainerOp(eid, rawComponentName, path, "delete"), collapsibleButtonsStyle)
          !isOpened.value || isConst ? null : textButton("+", @() doContainerOp(eid, rawComponentName, path, "insert"), collapsibleButtonsStyle)
        ]
      }
    ]
    flow = FLOW_HORIZONTAL
    behavior = Behaviors.Button
    onClick = @() isOpened(!isOpened.value)
    size = [flex(), SIZE_TO_CONTENT]
    margin = [hdpx(1),0]
  }
  return function(){
    local content = null
    if (isOpened.value)
      content = {children = childrenCtor(), size=[flex(), SIZE_TO_CONTENT], flow = FLOW_VERTICAL, margin = [0,0,0, fsh(1)]}
    return {
      children = [captionUi, content]
      watch = isOpened
      flow = FLOW_VERTICAL
      size = [flex(), SIZE_TO_CONTENT]
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

mkCompObject = function(eid, rawComponentName, rawObject, caption=null, onChange = null, path = null){
  local isFirst = caption==null
  caption = caption ?? rawComponentName
  isFirst = isFirst || rawComponentName==caption
  onChange = onChange ?? (@() update_component(eid, rawComponentName) ?? true)
  let object = getValFromObj(eid, rawComponentName, path)
  let objData = object?.getAll() ?? object
  let objLen = objData.len()
  path = path ?? []
  let function childrenCtor() {
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
  onChange = onChange ?? (@() update_component(eid, rawComponentName) ?? true)
  let object = getValFromObj(eid, rawComponentName, path)
  let len = object?.len() ?? 0
  path = path ?? []
  let function childrenCtor(){
    let res = []
    foreach (num, val in (object?.getAll() ?? object)) {
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
  onChange = path != null ? @() update_component(eid, rawComponentName) : null
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
  if (path == null && get_comp_type(eid, rawComponentName) != TYPE_STRING && typeof object == "string"){
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

let function ecsObjToQuirrel(x) {
  return x.map(@(val) val?.getAll() ?? val)
}

let getCurComps = @() (selectedEntity.value ?? INVALID_ENTITY_ID) == INVALID_ENTITY_ID ? {} : ecsObjToQuirrel(_dbg_get_all_comps_inspect(selectedEntity.value))
let curEntityComponents = Watched(getCurComps())
let setCurComps = @() curEntityComponents(getCurComps())

selectedEntity.subscribe(function(eid){
  gui_scene.resetTimeout(0.1, setCurComps)
})

let isCurEntityComponents = Computed(@() curEntityComponents.value.len()>0)

let filteredCurComponents = Computed(function(){
  let res = []
  foreach(compName, compObj in curEntityComponents.value) {
    if (isComponentHidden(compName))
      continue
    if (isKeyInFilter(compName, filterString.value))
      res.append({compName, compObj, eid = selectedEntity.value})
    }
  res.sort(@(a, b) a.compName <=> b.compName)
  return res
})

let function compPanel() {

  if (!propPanelVisible.value) {
    return {
      watch = propPanelVisible
    }
  }
  else {
    toggleBg = makeBgToggle() // achtung!: implicit state reset - better pass it via arguments

    let eid = selectedEntity.value
    let rows = filteredCurComponents.value.map(function(v) {
      return mkComp(eid, v.compName, v.compObj)
    })
    rows.extend((extraPropPanelCtors.value ?? []).map(@(ctor) ctor(eid)))
    let scrolledGrid = {
      size = flex()
      rendObj = ROBJ_SOLID
      color = Color(50,50,50,100)
      children = scrollbar.makeVertScroll(rows, {
        rootBase = class {
          size = flex()
          flow = FLOW_VERTICAL
          behavior = Behaviors.Pannable
        }
      })
    }

    let captionText = eid!=INVALID_ENTITY_ID ? "{0}: {1}".subst(eid, removeSelectedByEditorTemplate(g_entity_mgr.getEntityTemplateName(eid))) :
      selectedEntities.value.len() == 0 ? "No entity selected"
      : $"{selectedEntities.value.len()} entities selected"

    return {
      watch = [
        selectedEntity, selectedEntities, propPanelVisible, filterString,
        windowState, isCurEntityComponents, filteredCurComponents, selectedCompName
      ]
      size = [sw(100), sh(100)]

      children = [
        {
          size = windowState.value.size
          pos = windowState.value.pos
          hplace = ALIGN_RIGHT

          behavior = Behaviors.MoveResize
          moveResizeModes = MR_AREA | MR_L | MR_R
          onMoveResize

          moveResizeCursors = cursors.moveResizeCursors
          cursor = cursors.normal

          padding = [0, hdpx(2)]
          rendObj = ROBJ_FRAME
          color = colors.ControlBg
          borderWidth = [0, hdpx(2)]
          children = [
            {
              size = [flex(), sh(80)] // free some space for combo
              rendObj = ROBJ_WORLD_BLUR
              color = Color(220,220,220,205)
              clipChildren = true

              flow = FLOW_VERTICAL
              children = [
                panelCaption(captionText)
                isCurEntityComponents.value ? compNameFilter : null
                scrolledGrid
                panelButtons
              ]
            }
            modalWindowsComponent
          ]
        }
      ]
    }
  }
}

return compPanel
