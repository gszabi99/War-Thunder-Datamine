from "%darg/ui_imports.nut" import *

from "ecs" import *

let {showEntitySelect, selectedEntities, de4workMode} = require("state.nut")
let {colors} = require("components/style.nut")
let textButton = require("components/textButton.nut")
let mkWindow = require("components/window.nut")
let nameFilter = require("components/nameFilter.nut")
let combobox = require("%darg/components/combobox.nut")
let scrollbar = require("%darg/components/scrollbar.nut")
let string = require("string")
let entity_editor = require("entity_editor")

let selectedGroup = Watched("")
let selectionState = mkWatched(persist, "selectionState", {})
let filterString = mkWatched(persist, "filterString", "")
let scrollHandler = ScrollHandler()
let allEntities = mkWatched(persist, "allEntities", [])

let statusAnimTrigger = { lastN = null }


let numSelectedEntities = Computed(function() {
  local nSel = 0
  foreach (k, v in selectionState.value) {
    if (v)
      ++nSel
  }
  return nSel
})


let function matchEntityByText(eid, text) {
  if (text==null || text=="" || eid.tostring().indexof(text)!=null)
    return true
  let tplName = g_entity_mgr.getEntityTemplateName(eid)
  if (tplName==null)
    return false
  if (tplName.tolower().contains(text.tolower()))
    return true
  return false
}

let filteredEntites = Computed(function() {
  local entities = allEntities.value
  if (filterString.value != "")
    entities = entities.filter(@(eid, idx) matchEntityByText(eid, filterString.value))
 return entities
})


let function applySelection(cb) {
  selectionState.mutate(function(value) {
    foreach (k, v in value)
      value[k] = cb(k, v)
  })
}

// use of filteredEntites here would be more correct here, but reapplying name check should faster than
// linear search in array (O(N) vs O(N^2))
let selectAllFiltered = @() applySelection(@(eid, cur) matchEntityByText(eid, filterString.value))

let selectNone = @() applySelection(@(eid, cur) false)

// invert filtered, deselect unfiltered
let selectInvert = @() applySelection(@(eid, cur) matchEntityByText(eid, filterString.value) ? !cur : false)


let function scrollBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("eid" in desc) && selectionState.value?[desc.eid]
  }, 2, false, true)
}


let function doSelect() {
  let eids = []
  foreach (k, v in selectionState.value) {
    if (v) {
      eids.append(k)
    }
  }
  entity_editor.get_instance().selectEntities(eids)
  showEntitySelect(false)
//  filterString.update("")
}


let function doCancel() {
  showEntitySelect(false)
//  filterString.update("")
}


let function statusLine() {
  let nSel = numSelectedEntities.value

  if (statusAnimTrigger.lastN != null && statusAnimTrigger.lastN != nSel)
    anim_start(statusAnimTrigger)
  statusAnimTrigger.lastN = nSel

  return {
    watch = numSelectedEntities
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


let filter = nameFilter(filterString, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterString(text)
  }

  function onEscape() {
    if (filterString.value != "")
      filterString("")
    else
      set_kb_focus(null)
  }
})

let function doSelectEid(eid) {
  let eids = [eid]
  entity_editor.get_instance().selectEntities(eids)
}

let function listRow(eid, idx) {
  return watchElemState(function(sf) {
    let isSelected = selectionState.value?[eid]

    local color
    if (isSelected) {
      color = colors.Active
    } else {
      color = (sf & S_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    }
    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      eid
      behavior = Behaviors.Button

      function onClick(evt) {
        if (evt.ctrlKey) {
          selectionState.mutate(function(value) {
            value[eid] <- !value?[eid]
          })
        }
        else {
          applySelection(@(eid_, cur) eid_==eid)
        }
      }

      onDoubleClick = @() doSelectEid(eid)

      children = {
        rendObj = ROBJ_DTEXT
        text = $"{eid}  |  {g_entity_mgr.getEntityTemplateName(eid)}"
        margin = fsh(0.5)
      }
    }
  })
}

let function listRowMoreLeft(num, idx) {
  return watchElemState(function(sf) {
    let color = (sf & S_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      children = {
        rendObj = ROBJ_DTEXT
        text = $"{num} more ..."
        margin = fsh(0.5)
        color = Color(160,160,160,160)
      }
    }
  })
}


let function initEntitiesList() {
  let entities = entity_editor.get_instance()?.getEntities(selectedGroup.value) ?? []
  foreach (eid in entities) {
    let isSelected = selectedEntities.value?[eid] ?? false
    selectionState.value[eid] <- isSelected
  }
  allEntities(entities)
  selectionState.trigger()
}

selectedGroup.subscribe(@(v) initEntitiesList())
de4workMode.subscribe(@(v) gui_scene.resetTimeout(0.1, initEntitiesList))

let function entitySelectRoot() {
  let templatesGroups = ["(all workset entities)"].extend(entity_editor.get_instance().getEcsTemplatesGroups())

  let function listContent() {
    const maxVisibleItems = 500
    let rows = filteredEntites.value.slice(0, maxVisibleItems).map(@(eid, idx) listRow(eid, idx))
    if (rows.len() < filteredEntites.value.len())
      rows.append(listRowMoreLeft(filteredEntites.value.len() - rows.len(), rows.len()))

    return {
      watch = [selectionState, filteredEntites]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = rows
      behavior = Behaviors.Button
    }
  }


  let scrollList = scrollbar.makeVertScroll(listContent, {
    scrollHandler
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

  let content = @() {
    flow = FLOW_VERTICAL
    gap = fsh(0.5)
    watch = [allEntities, selectedEntities]
    size = flex()
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        children = [
          filter
          {
            size = [sw(11), sh(2.7)]
            children = combobox(selectedGroup, templatesGroups)
          }
        ]
      }
      {
        size = flex()
        children = scrollList
      }
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
          textButton("Cancel", doCancel, {hotkeys=["^Esc"]})
        ]
      }
    ]
  }
  return mkWindow({
    onAttach = initEntitiesList
    id = "entity_select"
    content
    saveState = true
  })()
}


return entitySelectRoot
