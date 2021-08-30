local {showEntitySelect} = require("state.nut")
local {colors} = require("components/style.nut")
local textButton = require("components/textButton.nut")
local nameFilter = require("components/nameFilter.nut")
local scrollbar = require("daRg/components/scrollbar.nut")
local string = require("string")
local cursors = require("components/cursors.nut")
local {checkbox} = require("daRg/components/checkbox.nut")
local entity_editor = require("entity_editor")

local selectionState = ::mkWatched(persist, "selectionState", {})
local filterState = ::mkWatched(persist, "filterState", {})
local filterByNameText = ::mkWatched(persist, "filterByNameText", "")
local scrollHandler = ScrollHandler()
local entitiesState = ::mkWatched(persist, "entitiesState", [])
local filterEntities = ::mkWatched(persist, "filterEntities", true)

local statusAnimTrigger = { lastN = null }

local filteredEntitesByNow = ::Computed(function(){
  local entities = entitiesState.value
  if (filterByNameText.value != "" && filterEntities.value)
    entities = entities.filter(@(e, idx) filterState.value?[e.getEid()])
 return entities
})

local function setFilter(cb) {
  filterState.update(function(value) {
    foreach (k, v in value)
      value[k] = cb(k, v)
  })
}

local function matchEntityByText(eid, text) {
  if (eid.tostring().indexof(text)!=null)
    return true
  local tplName = ::ecs.g_entity_mgr.getEntityTemplateName(eid)
  if (!tplName)
    return false
  if (tplName.indexof(text)!=null)
    return true
  return false
}

local function setSelection(cb) {
  selectionState.update(function(value) {
    foreach (k, v in value)
      value[k] = cb(k, v)
  })
}
local function setSelectionFiltered(cb) {
  if (!filterEntities.value)
    setSelection(cb)
  else
    selectionState.update(function(value) {
      foreach (k, v in value) {
        if (matchEntityByText(k, filterByNameText.value))
          value[k] = cb(k, v)
        else
          value[k] = false
      }
    })
}

local selectAll = @() setSelectionFiltered(@(eid, cur) true)
local selectNone = @() setSelection(@(eid, cur) false)
local selectInvert = @() setSelectionFiltered(@(eid, cur) !cur)
local selectByName = @(text) setSelection(@(eid, cur) matchEntityByText(eid, text))


local function scrollByName(text) {
  scrollHandler.scrollToChildren(function(desc) {
    return ("eid" in desc) && matchEntityByText(desc.eid, text)
  }, 2, false, true)
}


local function scrollBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("eid" in desc) && selectionState.value?[desc.eid]
  }, 2, false, true)
}


local function doSelect() {
  local eids = []
  foreach (k, v in selectionState.value) {
    if (v) {
      eids.append(k)
    }
  }
  entity_editor.get_instance().selectEntities(eids)
  showEntitySelect(false)
//  filterByNameText.update("")
}


local function doCancel() {
  showEntitySelect(false)
//  filterByNameText.update("")
}


local function statusLine() {
  local nSel = 0
  foreach (k, v in selectionState.value) {
    if (v) {
      ++nSel
    }
  }

  if (statusAnimTrigger.lastN != null && statusAnimTrigger.lastN != nSel)
    ::anim_start(statusAnimTrigger)
  statusAnimTrigger.lastN = nSel

  return {
    watch = selectionState
    size = [flex(), SIZE_TO_CONTENT]
    children = {
      rendObj = ROBJ_DTEXT
      text = string.format("%d %s selected", nSel, nSel==1 ? "entity" : "entities")
      animations = [
        { prop=AnimProp.color, from=colors.HighlightSuccess, duration=0.5, trigger=statusAnimTrigger }
      ]
    }
  }
}
local select = nameFilter(filterByNameText, {
  placeholder = "Select by name"
  function onChange(text) {
    filterByNameText.update(text)
    if (text.len()==0)
      selectNone()
    else {
      selectByName(text)
      scrollByName(text)
    }
  }
  function onEscape() {
//    filterByNameText.update("")
    selectNone()
  }
})

filterEntities.subscribe(function(val){
  if (!val)
    setFilter(@(eid, cur) false)
  else
    setFilter(@(eid, cur) matchEntityByText(eid, filterByNameText.value))
})

local filter = nameFilter(filterByNameText, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterByNameText.update(text)

    if (text.len()==0)
      setFilter(@(eid, cur) false)
    else
      setFilter(@(eid, cur) matchEntityByText(eid, text))
  }

  function onEscape() {
    filterByNameText.update("")
    setFilter(@(eid, cur) false)
  }
})

local function listRow(entity, idx) {
  return ::watchElemState(function(sf) {
    local isSelected = selectionState.value?[entity.getEid()]

    local color
    if (isSelected) {
      color = colors.Active
    } else {
      color = (sf & S_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    }
    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color = color
      behavior = Behaviors.Button
      eid = entity.getEid()

      function onClick(evt) {
        if (evt.ctrlKey) {
          selectionState.update(function(value) {
            value[entity.getEid()] <- !value?[entity.getEid()]
          })
        }
        else {
          local selEid = entity.getEid()
          setSelection(@(eid, cur) eid==selEid)
        }
      }

      onDoubleClick = doSelect

      children = {
        rendObj = ROBJ_DTEXT
        text = "{0}  |  {1}".subst(entity.getEid(), ::ecs.g_entity_mgr.getEntityTemplateName(entity.getEid()))
        margin = sh(0.5)
      }
    }
  })
}


local windowState = ::mkWatched(persist, "windowState", {
  pos = [0, 0]
  size = [sw(40), sh(65)]
})


local function onMoveResize(dx, dy, dw, dh) {
  local w = windowState.value
  w.pos[0] = ::clamp(w.pos[0]+dx, -(sw(100)-w.size[0]), 0)
  w.pos[1] = ::max(w.pos[1]+dy, 0)
  w.size[0] = ::clamp(w.size[0]+dw, sw(14), sw(80))
  w.size[1] = ::clamp(w.size[1]+dh, sh(25), sh(90))
  return w
}

local function updateEntites(){
  local entities = entity_editor.get_instance().getEntities()
  foreach (e in entities) {
    local eEid = e.getEid()
    selectionState.value[eEid] <- e.isSelected()
    filterState.value[eEid] <- e.isSelected() || (filterState.value?[eEid] ?? false)
  }
  entitiesState(entities)
}

local filterCheckbox = checkbox({state=filterEntities, text = "filter by name"})

local function entitySelectRoot() {
  local function listContent() {
    local rows = filteredEntitesByNow.value.map(@(entity, idx) listRow(entity, idx))
    return {
      watch = [filterState, selectionState, filterByNameText, filterEntities, entitiesState, filteredEntitesByNow]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = rows
      behavior = Behaviors.Button
    }
  }


  local scrollList = scrollbar.makeVertScroll(listContent, {
    scrollHandler = scrollHandler
    rootBase = class {
      size = flex()
      behavior = Behaviors.RecalcHandler
      function onRecalcLayout(initial) {
        if (initial) {
          scrollBySelection()
        }
      }
    }
  })


  return {
    onAttach = updateEntites
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    rendObj = ROBJ_WORLD_BLUR_PANEL
    color = Color(150,150,150,250)
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    moveResizeModes = MR_AREA | MR_L | MR_R | MR_T | MR_B
    onMoveResize = onMoveResize
    size = windowState.value.size
    pos = windowState.value.pos
    moveResizeCursors = cursors.moveResizeCursors
    behavior = [Behaviors.MoveResize]
    key = "entity_select"
    padding = sh(0.5)
    gap = sh(0.5)
    watch = [windowState, entitiesState]
    stopMouse = true
    children = [
      @(){watch = filterEntities, children = filterEntities.value ? filter : select, size = [flex(), SIZE_TO_CONTENT]}
      {
        size = flex()
        children = scrollList
      }
      {padding = [hdpx(10), 0] size = [flex(), SIZE_TO_CONTENT], flow = FLOW_HORIZONTAL children = [statusLine, {children = filterCheckbox, hplace = ALIGN_RIGHT}]}
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        children = [
          textButton("All",    selectAll)
          textButton("None",   selectNone)
          textButton("Invert", selectInvert)
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        children = [
          textButton("Select", doSelect, {hotkeys=["^Enter"]})
          textButton("Cancel", doCancel, {hotkeys=["^Esc"]})
        ]
      }
    ]
  }
}


return entitySelectRoot
