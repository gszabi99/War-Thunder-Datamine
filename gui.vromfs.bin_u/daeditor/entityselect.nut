from "%darg/ui_imports.nut" import *
from "%sqstd/ecs.nut" import *
from "components/style.nut" import colors
import "entity_editor" as entity_editor
from "%darg/laconic.nut" import *
from "%sqstd/underscore.nut" import partition, flatten

let {EntitySelectWndId, selectedEntities, de4workMode} = require("state.nut")
let textButton = require("components/textButton.nut")
let closeButton = require("components/closeButton.nut")
let nameFilter = require("components/nameFilter.nut")
let {makeVertScroll} = require("%daeditor/components/scrollbar.nut")
let {getEntityExtraName} = require("%daeditor/daeditor_es.nut")
let { format } = require("string")
let mkSortModeButton = require("components/mkSortModeButton.nut")
let {addModalWindow, removeModalWindow} = require("%daeditor/components/modalWindows.nut")

let selectedGroup = Watched("")
let selectionState = mkWatched(persist, "selectionState", {})
let filterString = mkWatched(persist, "filterString", "")
let scrollHandler = ScrollHandler()
let allEntities = mkWatched(persist, "allEntities", [])

let statusAnimTrigger = { lastN = null }
local locateOnDoubleClick = false

let entitySortState = Watched({})

local entitySortFuncCache = null

let numSelectedEntities = Computed(function() {
  local nSel = 0
  foreach (v in selectionState.get()) {
    if (v)
      ++nSel
  }
  return nSel
})


function matchEntityByText(eid, text) {
  if (text==null || text=="" || eid.tostring().indexof(text)!=null)
    return true
  let tplName = g_entity_mgr.getEntityTemplateName(eid)
  if (tplName==null)
    return false
  if (tplName.tolower().contains(text.tolower()))
    return true
  let riExtraName = getEntityExtraName(eid)
  if (riExtraName != null && riExtraName.tolower().contains(text.tolower()))
    return true
  return false
}

let filteredEntites = Computed(function() {
  local entities = allEntities.get()
  if (filterString.get() != "")
    entities = entities.filter(@(eid) matchEntityByText(eid, filterString.get()))
  if (entitySortFuncCache != null)
    entities.sort(entitySortFuncCache)
  return entities
})

let filteredEntitiesCount = Computed(@() filteredEntites.get().len())

function applySelection(cb) {
  selectionState.mutate(function(value) {
    foreach (k, v in value)
      value[k] = cb(k, v)
  })
}



let selectAllFiltered = @() applySelection(@(eid, _cur) matchEntityByText(eid, filterString.get()))

let selectNone = @() applySelection(@(_eid, _cur) false)


let selectInvert = @() applySelection(@(eid, cur) matchEntityByText(eid, filterString.get()) ? !cur : false)


function scrollBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("eid" in desc) && selectionState.get()?[desc.eid]
  }, 2, false, true)
}


function doSelect() {
  let eids = []
  foreach (k, v in selectionState.get()) if (v) eids.append(k)
  entity_editor.get_instance().selectEntities(eids)
  gui_scene.resetTimeout(0.1, function() {
    selectedEntities.trigger()
    selectionState.trigger()
  })

}

function doLocate() {
  let eids = []
  foreach (k, v in selectionState.get()) if (v) eids.append(k)
  entity_editor.get_instance().selectEntities(eids)
  entity_editor.get_instance().zoomAndCenter()
}

function statusLine() {
  let nMrk = numSelectedEntities.get()
  let nSel = selectedEntities.get().len()

  if (statusAnimTrigger.lastN != null && statusAnimTrigger.lastN != nSel)
    anim_start(statusAnimTrigger)
  statusAnimTrigger.lastN = nSel

  return {
    watch = [numSelectedEntities, filteredEntitiesCount, selectedEntities]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    children = [
      {
         rendObj = ROBJ_TEXT
         size = [flex(), SIZE_TO_CONTENT]
         text = format(" %d %s marked, %d selected", nMrk, nMrk==1 ? "entity" : "entities", nSel)
         animations = [
           { prop=AnimProp.color, from=colors.HighlightSuccess, duration=0.5, trigger=statusAnimTrigger }
         ]
      }
      {
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        size = [flex(), SIZE_TO_CONTENT]
        text = format("%d listed   ", filteredEntitiesCount.get())
        color = Color(170,170,170)
     }
    ]
  }
}


let filter = nameFilter(filterString, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterString(text)
  }

  function onEscape() {
    set_kb_focus(null)
  }

  function onReturn() {
    set_kb_focus(null)
  }

  function onClear() {
    filterString.update("")
    set_kb_focus(null)
  }
})

function doSelectEid(eid, mod) {
  let eids = []
  local found = false
  foreach (k, _v in selectedEntities.get()) {
    if (k == eid)
      found = true
    else if (mod)
      eids.append(k)
  }
  if (!found)
    eids.append(eid)
  entity_editor.get_instance().selectEntities(eids)
  gui_scene.resetTimeout(0.1, @() selectionState.trigger())
}

let removeSelectedByEditorTemplate = @(tname) tname.replace("+daeditor_selected+","+").replace("+daeditor_selected","").replace("daeditor_selected+","")

function listRow(eid, idx) {
  return watchElemState(function(sf) {
    let isSelected = selectionState.get()?[eid]
    let textColor = isSelected ? colors.TextDefault : colors.TextDarker
    let color = isSelected ? colors.Active
      : sf & S_TOP_HOVER ? colors.GridRowHover
      : colors.GridBg[idx % colors.GridBg.len()]

    let extraName = getEntityExtraName(eid)
    let extra = (extraName != null) ? $"/ {extraName}" : ""

    local tplName = g_entity_mgr.getEntityTemplateName(eid) ?? ""
    let name = removeSelectedByEditorTemplate(tplName)
    let div = (tplName != name) ? "•" : "|"

    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      eid
      behavior = Behaviors.Button

      function onClick(evt) {
        if (evt.shiftKey) {
          local selCount = 0
          foreach (_k, v in selectionState.get()) {
            if (v)
              ++selCount
          }
          if (selCount > 0) {
            local idx1 = -1
            local idx2 = -1
            foreach (i, filteredEid in filteredEntites.get()) {
              if (eid == filteredEid) {
                idx1 = i
                idx2 = i
              }
            }
            foreach (i, filteredEid in filteredEntites.get()) {
              if (selectionState.get()?[filteredEid]) {
                if (idx1 > i)
                  idx1 = i
                if (idx2 < i)
                  idx2 = i
              }
            }
            if (idx1 >= 0 && idx2 >= 0) {
              if (idx1 > idx2) {
                let tmp = idx1
                idx1 = idx2
                idx2 = tmp
              }
              selectionState.mutate(function(value) {
                for (local i = idx1; i <= idx2; i++) {
                  let filteredEid = filteredEntites.get()[i]
                  value[filteredEid] <- !evt.ctrlKey
                }
              })
            }
          }
        }
        else if (evt.ctrlKey) {
          selectionState.mutate(function(value) {
            value[eid] <- !value?[eid]
          })
        }
        else {
          applySelection(@(eid_, _cur) eid_==eid)
        }
      }

      onDoubleClick = function(evt) {
        if (locateOnDoubleClick) { doLocate(); return }
        locateOnDoubleClick = true
        gui_scene.resetTimeout(0.3, @() locateOnDoubleClick = false)
        doSelectEid(eid, evt.ctrlKey)
      }

      children = {
        rendObj = ROBJ_TEXT
        text = $"{eid}  {div}  {name} {extra}"
        color = textColor
        margin = fsh(0.5)
      }
    }
  })
}

function listRowMoreLeft(num, idx) {
  return watchElemState(function(sf) {
    let color = (sf & S_TOP_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      children = {
        rendObj = ROBJ_TEXT
        text = $"{num} more ..."
        color = colors.TextReadOnly
        margin = fsh(0.5)
      }
    }
  })
}


function initEntitiesList() {
  let entities = entity_editor.get_instance()?.getEntities(selectedGroup.get()) ?? []
  foreach (eid in entities) {
    let isSelected = selectedEntities.get()?[eid] ?? false
    selectionState.get()[eid] <- isSelected
  }
  allEntities(entities)
  selectionState.trigger()
}

entitySortState.subscribe(function(v) {
  entitySortFuncCache = v?.func
  selectedEntities.trigger()
  selectionState.trigger()
  initEntitiesList()
})

selectedGroup.subscribe(@(_) initEntitiesList())
de4workMode.subscribe(@(_) gui_scene.resetTimeout(0.1, initEntitiesList))

function mkEntitySelect() {
  let templatesGroups = ["(all workset entities)"].extend(entity_editor.get_instance().getEcsTemplatesGroups())

  function listContent() {
    const maxVisibleItems = 500
    let rows = filteredEntites.get().slice(0, maxVisibleItems).map(@(eid, idx) listRow(eid, idx))
    if (rows.len() < filteredEntites.get().len())
      rows.append(listRowMoreLeft(filteredEntites.get().len() - rows.len(), rows.len()))

    return {
      watch = [selectionState, filteredEntites]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = rows
      behavior = Behaviors.Button
    }
  }


  let scrollList = makeVertScroll(listContent, {
    scrollHandler
    rootBase = {
      size = flex()
      function onAttach() {
        scrollBySelection()
      }
    }
  })
  const WORKSET_FILTER = "workset filter"
  let closeWorkset = @() removeModalWindow(WORKSET_FILTER)
  let mkSelectWorkSet = function(ws) {
    let hovered = Watched(false)
    let group = ElemGroup()
    return @() {
      watch = [hovered, selectedGroup]
      rendObj = ROBJ_BOX
      size = const [hdpx(300), SIZE_TO_CONTENT]
      group
      children = { rendObj = ROBJ_TEXT text = ws group, behavior = Behaviors.Marquee, scrollOnHover = true, size = [flex(), SIZE_TO_CONTENT] delay = [0.1, 0.5], speed = hdpx(80)}
      padding = const [hdpx(1), hdpx(5)]
      key = ws
      borderWidth = hovered.get() ? hdpx(1) : 0
      fillColor = hovered.get()
        ? Color(30,30,30,5)
        : selectedGroup.get()==ws ? Color(100,120,120) : 0
      borderColor = Color(160,160,180)
      behavior = Behaviors.Button
      onHover = @(on) hovered.set(on)
      onClick = function(){
        selectedGroup.set(ws)
        closeWorkset()
      }
    }
  }
  return @() {
    flow = FLOW_VERTICAL
    gap = fsh(0.5)
    watch = const [allEntities, selectedEntities]
    size = flex()
    children = [
      {
        size = const [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        children = [
          mkSortModeButton(entitySortState)
          const { size = [sw(0.2), SIZE_TO_CONTENT] }
          filter
          function() {
            
            return {
              size = const [sw(11), sh(2.7)]
              watch = selectedGroup

              children = textButton((selectedGroup.get() ?? "")=="" ? "_unspecified_" : selectedGroup.get(), @() addModalWindow({
                key = WORKSET_FILTER
                size = flex()
                hotkeys = [["Esc", closeWorkset]]
                padding = hdpx(20)
                rendObj = ROBJ_SOLID
                color = Color(30, 30, 30)
                children = [
                  { hplace = ALIGN_RIGHT vplace = ALIGN_TOP children = closeButton(closeWorkset)}
                  { hplace = ALIGN_LEFT vplace = ALIGN_TOP children = {rendObj = ROBJ_TEXT text = "Select filter for working set"}}
                  { padding = [sh(5), sh(2) ] size = flex() children = makeVertScroll(wrap(templatesGroups.map(mkSelectWorkSet), {width = sw(80)}))}
                ]
              }))
            }
          }
        ]
      }
      { size = flex() children = scrollList }
      statusLine
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        children = [
          textButton("All filtered", selectAllFiltered)
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
          textButton("Locate", doLocate, {hotkeys=["^Z"]})
        ]
      }
    ]
  }
}
return {
  onAttach = initEntitiesList
  id = EntitySelectWndId
  mkContent = mkEntitySelect
  saveState=true
}

