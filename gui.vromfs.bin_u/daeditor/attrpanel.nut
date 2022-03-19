from "%darg/ui_imports.nut" import *
from "ecs" import *

local {endswith} = require("string")
local {getValFromObj} = require("components/attrUtil.nut")
local {filterString, propPanelVisible, selectedCompName, extraPropPanelCtors, selectedEntity} = require("state.nut")
local {colors, gridHeight} = require("components/style.nut")
local cursors = require("components/cursors.nut")
local {getCompSqTypePropEdit, getCompNamePropEdit} = require("propPanelControls.nut")
local scrollbar = require("%darg/components/scrollbar.nut")

local fieldReadOnly = require("components/apFieldReadOnly.nut")
local compNameFilter = require("components/apNameFilter.nut")(filterString, selectedCompName)

local windowState = Watched({
  pos = [-fsh(1), fsh(5)]
  size = [sw(32), SIZE_TO_CONTENT]
})


local function onMoveResize(dx, dy, dw, dh) {
  local w = windowState.value
  w.pos[0] = clamp(w.pos[0]+dx, -(sw(100)-w.size[0]), 0)
  w.pos[1] = max(w.pos[1]+dy, 0)
  w.size[0] = clamp(w.size[0]+dw, sw(14), sw(80))
  return w
}

local function get_tags(comp_flags){
  local tags = []
  comp_flags = comp_flags ?? 0
  if (comp_flags & COMP_FLAG_REPLICATED)
    tags.append("r")
  if (comp_flags & COMP_FLAG_CHANGE_EVENT)
    tags.append("t")
  return tags
}

local function get_tagged_comp_name(comp_flags, comp_name) {
  local tags = get_tags(comp_flags).map(@(v) $"[{v}]")
  tags = "".join(tags)
  return $"{tags} {comp_name}"
}

local function makeBgToggle(initial=true) {
  local showBg = !initial
  local function toggleBg() {
    showBg = !showBg
    return showBg
  }
  return toggleBg
}

local function panelRowColorC(comp_name, stateFlags, selectedCompNameVal, isOdd){
  local color = 0
  if (comp_name == selectedCompNameVal) {
    color = colors.Active
  } else {
    color = (stateFlags & S_HOVER) ? colors.GridRowHover : isOdd ? colors.GridBg[0] : colors.GridBg[1]
  }
  return color
}

local mkCompNameText = @(comp_name_text, group=null) {
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

local function panelCompRow(params={}) {
  local comp_name_ext = params?.comp_name_ext
  local comp_flags = params?.comp_flags ?? 0
  local {eid, comp_sq_type, rawComponentName, obj=null} = params
  local comp_name = params?.comp_name ?? comp_name_ext
  local fieldEditCtor = getCompNamePropEdit(rawComponentName) ?? getCompSqTypePropEdit(comp_sq_type) ?? fieldReadOnly
  local isOdd = toggleBg()
  local stateFlags = Watched(0)
  local group = ElemGroup()
  local comp_name_text = get_tagged_comp_name(comp_flags, (comp_name_ext ? comp_name_ext : comp_name))
  return function() {

    return {
      size = [flex(), gridHeight]
      behavior = Behaviors.Button

      onClick = function() {
        selectedCompName.update(selectedCompName.value==comp_name ? null : comp_name)
      }
      eventPassThrough = true
      onElemState = @(sf) stateFlags.update(sf)
      group = group

      children = [
        @(){
          size = [flex(), gridHeight]
          rendObj = ROBJ_SOLID
          watch = stateFlags
          color = panelRowColorC(comp_name, stateFlags.value, selectedCompName.value, isOdd)
          group = group
        }
        {
          group = group
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

local function panelCaption(text) {
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



local function compPanelToolbar() {
  local children = []

  return {
    watch = [selectedCompName]
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_SOLID
    color = colors.ControlBg
    flow = FLOW_HORIZONTAL

    children = children
  }
}


local hiddenComponents = {
  editableObj = true
}

local function isComponentHidden(k){
  if (hiddenComponents?[k] || k.slice(0,1)=="_")
    return true
  if (endswith(k, "$copy"))
    return true
  return false
}

local function isKeyInFilter(key, filterStr=null){
  if (filterStr==null || filterStr.len()==0 || key.tolower().contains(filterStr.tolower()))
    return true
  return false
}

local rightArrow = {rendObj = ROBJ_DTEXT text = "^" transform = {rotate=90}}
local downArrow = {rendObj = ROBJ_DTEXT text = "^" transform = {rotate=180}}
local mkTagFromTextColor = @(text, fillColor = Color(100,100,100), size = SIZE_TO_CONTENT, textColor = Color(0,0,0)) {
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

local mkTagFromText = @(text) mkTagFromTextColor(text)

local ecsObjectSign = mkTagFromText("obj")
local emptyTag = mkTagFromText("empty")
local isOpenedCache = persist("isOpenedCache", @() {})
selectedEntity.subscribe(function(eid){
  const maxCacheEntries = 100
  if (isOpenedCache.len()>maxCacheEntries)
    isOpenedCache.clear()
})

local function mkCollapsible(caption, childrenCtor=@() null, len=0, tags = null, eid=null, path=null){
  local empty = len==0
  tags = tags ?? []
  local captionText = {rendObj = ROBJ_DTEXT, text = caption, color = Color(180,180,180)}
  local padding = [hdpx(5), hdpx(5)]
  local gap = hdpx(4)
  local isOdd = toggleBg()
  if (empty){
    return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      children = (clone tags).append(emptyTag, captionText)
      padding = padding
      gap = gap
      rendObj = ROBJ_SOLID
      color = isOdd ? colors.GridBg[0] : colors.GridBg[1]
    }
  }
  local cachekey = eid !=null ? $"{len}_{caption}_{path?.len() ?? 0}" : null
  local isOpened = isOpenedCache?[eid][cachekey] ?? Watched(false)
  if (eid not in isOpenedCache)
    isOpenedCache[eid] <- {}
  if (isOpenedCache?[eid][cachekey]==null)
    isOpenedCache[eid][cachekey] <- isOpened
  local captionUi = @() {
    watch = isOpened
    rendObj = ROBJ_BOX
    fillColor = Color(0,10,20,210)//colors.ControlBg
    borderColor = Color(30,30,30,20)
    padding = padding
    key = caption
    gap
    borderWidth = hdpx(1)
    children = [isOpened.value ? downArrow : rightArrow].extend(tags).append(captionText)
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

local compTag = memoize(mkTagFromText)
local mkCompFlagTag = memoize(@(text) mkTagFromTextColor(text, Color(40,90,90, 50), [SIZE_TO_CONTENT, hdpx(15)]))
local mkFlagTags = @(eid, rawComponentName)
  get_tags(get_comp_flags(eid, rawComponentName)).map(mkCompFlagTag)

mkCompObject = function(eid, rawComponentName, rawObject, caption=null, onChange = null, path = null){
  local isFirst = caption==null
  caption = caption ?? rawComponentName
  isFirst = isFirst || rawComponentName==caption
  onChange = onChange ?? (@() update_component(eid, rawComponentName) ?? true)
  local object = getValFromObj(eid, rawComponentName, path)
  local objData = object?.getAll() ?? object
  local objLen = objData.len()
  path = path ?? []
  local function childrenCtor() {
    local contentChildren = []
    local objKeys = objData.keys().filter(@(v) !isComponentHidden(v))
    foreach (ok in objKeys) {
      local nkeys = (clone path).append(ok)
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
  local tags = isFirst ? mkFlagTags(eid, rawComponentName).append(ecsObjectSign) : [ecsObjectSign]
  return mkCollapsible(caption, childrenCtor, objLen, tags, eid, path)
}

local compTypeName = function(object){
  local typeName = ""
  if (type(object)=="array")
    typeName = "Array"
  else if (type(object)=="table")
    typeName = "Obj"
  else {
    typeName = object.tostring()
    local isComp = typeName.indexof("Comp") !=null
    typeName = typeName.slice(isComp ? "Comp".len() : 0, typeName.indexof(" (") ?? typeName.len())
  }
  return typeName
}

mkCompList = function(eid, rawComponentName, rawObject, caption=null, onChange=null, path = null){
  local isFirst = caption == null
  caption = caption ?? rawComponentName
  onChange = onChange ?? (@() update_component(eid, rawComponentName) ?? true)
  local object = getValFromObj(eid, rawComponentName, path)
  local len = object?.len() ?? 0
  path = path ?? []
  local function childrenCtor(){
    local res = []
    foreach (num, val in (object?.getAll() ?? object)) {
      local nkeys = (clone path).append(num)
      res.append(mkComp(eid, rawComponentName, rawObject, $"{caption}[{num}]", onChange, nkeys))
    }
   return res
  }
  local fCaption = len>0 ? $"{caption} [0..{len}]" : caption
  local typeTag = compTag(compTypeName(object))
  local tags = isFirst ? mkFlagTags(eid, rawComponentName).append(typeTag) : [typeTag]
  return mkCollapsible(fCaption, childrenCtor, len, tags, eid, path)
}


mkComp = function(eid, rawComponentName, rawObject, caption=null, onChange = null, path = null){
  onChange = path != null ? @() update_component(eid, rawComponentName) : null
  local object = getValFromObj(eid, rawComponentName, path)
  local comp_sq_type = typeof object

  local isFirst = caption==null
  local params = {
    eid, comp_sq_type, onChange, path
    comp_flags = isFirst ? get_comp_flags(eid, rawComponentName) : null,
    comp_name=rawComponentName,
    rawComponentName,
    comp_name_ext = caption
    obj = rawObject
  }
  if (get_comp_type(eid, rawComponentName) != TYPE_STRING && typeof object == "string"){
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

local function ecsObjToQuirrel(x) {
  return x.map(@(val) val?.getAll() ?? val)
}

local getCurComps = @() (selectedEntity.value ?? INVALID_ENTITY_ID) == INVALID_ENTITY_ID ? {} : ecsObjToQuirrel(_dbg_get_all_comps(selectedEntity.value))
local curEntityComponents = Watched(getCurComps())
local setCurComps = @() curEntityComponents(getCurComps())

selectedEntity.subscribe(function(eid){
  gui_scene.resetTimeout(0.1, setCurComps)
})

local isCurEntityComponents = Computed(@() curEntityComponents.value.len()>0)

local filteredCurComponents = Computed(function(){
  local res = []
  foreach(compName, comp in curEntityComponents.value) {
    if (isComponentHidden(compName))
      continue
    if (isKeyInFilter(compName, filterString.value))
      res.append({compName, comp, eid = selectedEntity.value})
    }
  res.sort(@(a, b) a.compName <=> b.compName)
  return res
})

local function compPanel() {

  if (!propPanelVisible.value) {
    return {
      watch = propPanelVisible
    }
  }
  else {
    local eid = selectedEntity.value
    local rows = filteredCurComponents.value.map(function(v) {
      return mkComp(eid, v.compName, v.comp)
    })
    rows.extend((extraPropPanelCtors.value ?? []).map(@(ctor) ctor(eid)))
    local scrolledGrid = {
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
    return {
      watch = [selectedEntity, propPanelVisible, filterString, windowState, isCurEntityComponents, filteredCurComponents]
      size = [sw(100), sh(100)]

      children = {
        size = windowState.value.size
        pos = windowState.value.pos
        hplace = ALIGN_RIGHT

        behavior = Behaviors.MoveResize
        moveResizeModes = MR_AREA | MR_L | MR_R
        onMoveResize = onMoveResize

        moveResizeCursors = cursors.moveResizeCursors
        cursor = cursors.normal

        padding = [0, hdpx(2)]
        rendObj = ROBJ_FRAME
        color = colors.ControlBg
        borderWidth = [0, hdpx(2)]
        children = {
          size = [flex(), sh(80)] // free some space for combo
          rendObj = ROBJ_WORLD_BLUR
          color = Color(220,220,220,205)
          clipChildren = true

          flow = FLOW_VERTICAL
          children = [
            panelCaption(eid!=INVALID_ENTITY_ID ?
                "{0}: {1}".subst(eid, g_entity_mgr.getEntityTemplateName(eid)) :
               "No entity selected"),
            isCurEntityComponents.value ? compNameFilter : null,
            scrolledGrid,
            compPanelToolbar,
          ]
        }
      }
    }
  }
}

return compPanel
