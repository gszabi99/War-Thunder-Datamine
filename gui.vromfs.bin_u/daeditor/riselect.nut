from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *
from "ecs" import *

let DataBlock = require("DataBlock")

let nameFilter = require("components/nameFilter.nut")
let textButton = require("%daeditor/components/textButton.nut")
let {makeVertScroll} = require("%darg/components/scrollbar.nut")

let entity_editor = require_optional("entity_editor")
let {propPanelVisible, selectedEntity} = require("state.nut")
let {registerPerCompPropEdit} = require("%daeditor/propPanelControls.nut")

let {floor} = require("math")


let riSelectShown = Watched(false)
let riSelectSaved = Watched("")
let riSelectValue = Watched("")
local riSelectCB = @(_) null


let riNames = []
let riFile = Watched(null)

let riPage = Watched(0)
let riPageCount = 25

let riFilter = Watched("")
let riFiltered = Computed(function() {
  if (riNames.len() == 0) {
    if (riFile.value == null)
      return []
    local blk = DataBlock()
    blk.load(riFile.value)
    let cnt = blk.paramCount()
    riNames.resize(cnt)
    for (local i = 0; i < cnt; i++)
      riNames[i] = blk.getParamName(i)
  }
  let filtered = []
  let total = riNames.len()
  filtered.resize(total)
  filtered.resize(0)
  for (local i = 0; i < total; i++) {
    let name = riNames[i]
    if (riFilter.value=="" || name.contains(riFilter.value))
      filtered.append(name)
  }
  return filtered
})

let riPages = Computed(function() {
  let filtered = riFiltered.value
  local pages = floor(filtered.len() / riPageCount)
  if (filtered.len() > pages * riPageCount)
    ++pages
  if (pages < 1)
    pages = 1
  return pages
})

let riPageClamped = Computed(function() {
  local page = riPage.value
  if (page < 0)
    page = 0
  if (page >= riPages.value)
    page = riPages.value-1
  return page
})

let riDisplayed = Computed(function() {
  let filtered = riFiltered.value
  local start = riPageCount * riPageClamped.value
  local count = riPageCount
  if (start < 0)
    start = 0
  if (start+count > filtered.len())
    count = filtered.len() - start
  if (count < 0)
    count = 0
  let displayed = []
  displayed.resize(count)
  for (local i = 0; i < count; i++)
    displayed[i] = filtered[start + i]
  return displayed
})

let function riGotoPage(page) {
  set_kb_focus(null)
  if (page < 0)
    page = 0
  if (page >= riPages.value)
    page = riPages.value-1
  riPage(page)
}

let function riGotoPageByValue(v) {
  let filtered = riFiltered.value
  let fcount = filtered.len()
  for (local i = 0; i < fcount; i++) {
    if (filtered[i] == v) {
      local page = floor(i / riPageCount)
      if (page < 0)
        page = 0
      if (page >= riPages.value)
        page = riPages.value-1
      riPage(page)
      return
    }
  }
  riPage(0)
}

let riNameFilter = nameFilter(riFilter, {
  placeholder = "Filter by name"
  function onChange(text) {
    riFilter(text)
    riGotoPageByValue(riSelectValue.value)
  }
  function onEscape() {
    set_kb_focus(null)
  }
})


let mkSelectLine = kwarg(function(selected, textCtor = null, onSelect=null, onDClick=null){
  textCtor = textCtor ?? @(opt) opt
  return function(opt, i){
    let isSelected = Computed(@() selected.value == opt)
    let onClick = onSelect != null ? @() onSelect?(opt) : @() (!isSelected.value ? selected(opt) : selected(null))
    let onDoubleClick = onDClick != null ? @() onDClick?(opt) : null
    return watchElemState(@(sf) {
      size = [flex(), SIZE_TO_CONTENT]
      padding = [hdpx(3), hdpx(10)]
      behavior = Behaviors.Button
      watch = isSelected
      onClick
      onDoubleClick
      children = txt(textCtor(opt), {color = isSelected.value ? null : Color(190,190,190)})
      rendObj = ROBJ_BOX
      fillColor = sf & S_HOVER ? Color(120,120,160) : (i%2) ? Color(0,0,0,120) : 0
      borderWidth = isSelected.value ? hdpx(2) : 0
    })
  }
})

let function riSelectChange(v) {
  set_kb_focus(null)
  if (riSelectValue.value != v) {
    riSelectValue(v)
    riSelectCB?(v)
  }
}
let function riSelectChangeAndClose(v) {
  riSelectChange(v)
  riSelectShown(false)
}

let riSelectWindow = function() {
  let mkSelectedRI = mkSelectLine({
    selected = riSelectValue
    onSelect = @(v) riSelectChange(v)
    onDClick = @(v) riSelectChangeAndClose(v)
  })
  return {
    watch = [riDisplayed, riFilter]
    behavior = Behaviors.Button
    pos = [0, fsh(1)]
    size = [sw(29), sh(77)]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    rendObj = ROBJ_SOLID
    color = Color(30,30,30, 190)
    padding = hdpx(10)
    children = vflow(
      Flex()
      Gap(hdpx(10))
      txt("SELECT RENDINST", {hplace = ALIGN_CENTER})
      riNameFilter
      makeVertScroll(vflow(Size(flex(), SIZE_TO_CONTENT), riDisplayed.value.map(mkSelectedRI)))
      hflow(
        HCenter,
        textButton("First", @() riGotoPage(0), {hotkeys = [["Home"]], vplace = ALIGN_BOTTOM}),
        textButton("Prev",  @() riGotoPage(riPageClamped.value-1),  {hotkeys = [["Left"]], vplace = ALIGN_BOTTOM}),
        txt($"Page {1+riPageClamped.value} / {riPages.value}", { vplace = ALIGN_CENTER}),
        textButton("Next",  @() riGotoPage(riPageClamped.value+1),  {hotkeys = [["Right"]], vplace = ALIGN_BOTTOM}),
        textButton("Last",  @() riGotoPage(riPages.value-1), {hotkeys = [["End"]], vplace = ALIGN_BOTTOM})
      )
      hflow(
        HCenter,
        textButton("Cancel", @() riSelectChangeAndClose(riSelectSaved.value), {hotkeys = [["Esc"]], vplace = ALIGN_BOTTOM}),
        textButton("Accept",   @() riSelectShown(false), {hotkeys = [["Esc"]], vplace = ALIGN_BOTTOM})
      )
    )
  }
}

let function openSelectRI(selectedRI, onSelect=null) {
  riSelectCB = onSelect
  riSelectSaved(selectedRI.value)
  riSelectValue(selectedRI.value)
  riSelectShown(true)
  riGotoPageByValue(riSelectValue.value)
}

let riSelectEid = Watched(INVALID_ENTITY_ID)
propPanelVisible.subscribe(function(v) {
  if (v && selectedEntity.value != riSelectEid.value && riSelectShown.value)
    riSelectChangeAndClose(riSelectSaved.value)
})

let function initRISelect(file) {
  riFile(file)
  registerPerCompPropEdit("ri_extra__name", function(params) {
    let selectedRI = Watched(params?.obj)
    riSelectEid(params.eid)
    let function onSelect(v){
      let eid = riSelectEid.value
      if ((eid ?? INVALID_ENTITY_ID) != INVALID_ENTITY_ID){
        obsolete_dbg_set_comp_val(eid, "ri_extra__name", v)
        entity_editor?.save_component(eid, "ri_extra__name")
        let newEid = entity_editor?.get_instance().reCreateEditorEntity(eid)
        if (newEid != INVALID_ENTITY_ID)
          riSelectEid(newEid)
      }
    }
    return @() {
      watch = selectedRI
      halign = ALIGN_LEFT
      children = textButton(selectedRI.value, @() openSelectRI(selectedRI, onSelect))
    }
  })
}

return {
  initRISelect
  riSelectShown
  riSelectWindow
}
