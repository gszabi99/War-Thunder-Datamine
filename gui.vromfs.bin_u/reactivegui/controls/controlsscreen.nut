from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import px
from "%rGui/components/wndFrame.nut" import wndFrame, frameInnerW, frameContentH, searchBox, searchBoxH
from "%rGui/components/optionRows.nut" import rowPitch, mkRowsList
from "%rGui/controls/controlRows.nut" import mkControlsRowCtx
from "%appGlobals/controls/controlsScreenState.nut" import controlsScreen, controlsItems, controlsItemW,
  controlsScrollOffsY
from "eventbus" import eventbus_send
import "%rGui/components/navButtons.nut" as mkNavButtons
import "%rGui/control/gui_buttons.nut" as JB
import "%rGui/components/headerTabs.nut" as headerTabs
import "%rGui/components/filterTabs.nut" as filterTabs
import "%rGui/components/navigationPanel.nut" as navigationPanel
import "%rGui/components/scrollBox.nut" as scrollBox



let contentH = frameContentH()
let navPanelWidth = "0.35@sf"
let filterMargin = px("0.015@sf")
let filterH = px("@cIco + 2@buttonImgPadding")

let sendAction = @(action, params = {}) eventbus_send("controlsScreen.action", params.__merge({ action }))
let sendButton = @(id) sendAction("button", { id })

let groupTabsW = Computed(@() controlsScreen.get().groupTabs)
let curGroupIdxW = Computed(@() controlsScreen.get().curGroupIdx)
let helpersFilterW = Computed(@() controlsScreen.get().helpersFilter)
let helpersFilterIdxW = Computed(@() controlsScreen.get().helpersFilterIdx)
let isHelpersFilterShownW = Computed(@() controlsScreen.get().isHelpersFilterShown)
let navItemsW = Computed(@() controlsScreen.get().navItems)
let curNavIdxW = Computed(@() controlsScreen.get().curNavIdx)
let searchTextW = Computed(@() controlsScreen.get().searchText)
let rowsW = Computed(@() controlsScreen.get().rows)
let selectedRowIdW = Computed(@() controlsScreen.get().selectedRowId)
let backSceneNameW = Computed(@() controlsScreen.get().backSceneName)

let shownRowsW = Computed(@() rowsW.get().filter(@(row) controlsItems.get()?[row.itemId]?.shown ?? true))
let contentHeightW = Computed(@() shownRowsW.get().len() * rowPitch)
let activeRowIdW = Watched(null)
rowsW.subscribe(@(_) activeRowIdW.set(null))

let listHW = Computed(@() contentH - searchBoxH - filterMargin
  - (isHelpersFilterShownW.get() ? filterH + filterMargin : 0))
let rowCtx = mkControlsRowCtx({ itemW = controlsItemW, selectedRowIdW, activeRowIdW, sendAction })

let groupTabs = @() {
  watch = groupTabsW
  children = headerTabs({ tabs = groupTabsW.get().map(@(t) { id = t.id, tabName = t.text }) },
    curGroupIdxW, @(idx) sendAction("groupTab", { idx }))
}


function onNavSelect(idx) {
  sendAction("navItem", { idx })
  let sectionId = navItemsW.get()?[idx].id
  let rowIdx = shownRowsW.get().findindex(@(r) r.itemId == sectionId)
  if (rowIdx != null)
    controlsScrollOffsY.set(rowIdx * rowPitch)
}

let navigation = @() {
  watch = navItemsW
  size = const [SIZE_TO_CONTENT, flex()]
  children = navigationPanel({ panelWidth = navPanelWidth, headerHeight = "0.05@sf + @sf/@pf", items = navItemsW.get() },
    curNavIdxW, onNavSelect)
}

let helpersFilter = @(listW) @() {
  watch = [helpersFilterW, isHelpersFilterShownW]
  size = [listW, SIZE_TO_CONTENT]
  children = !isHelpersFilterShownW.get() ? null : {
    margin = [filterMargin, 0, 0, 0]
    children = filterTabs({ items = helpersFilterW.get(), width = listW }, helpersFilterIdxW,
      @(idx) sendAction("helpersFilter", { idx }))
  }
}

let controlsList = @(listW, listH)
  scrollBox({ size = [listW, listH], contentHeight = contentHeightW, scrollOffsY = controlsScrollOffsY },
    mkRowsList(shownRowsW, rowCtx))

let searchComp = searchBox(searchTextW, @(text) sendAction("search", { text }), @() sendAction("searchCancel"))

let content = {
  size = flex()
  flow = FLOW_HORIZONTAL
  children = [
    navigation
    function() {
      let listW = frameInnerW - (navItemsW.get().len() > 1 ? px(navPanelWidth) : 0)
      return {
        watch = [navItemsW, listHW]
        size = [listW, flex()]
        flow = FLOW_VERTICAL
        children = [
          searchComp
          helpersFilter(listW)
          {
            margin = [filterMargin, 0, 0, 0]
            children = controlsList(listW, listHW.get())
          }
        ]
      }
    }
  ]
}

let { textButton, imageButton, linkButton } = mkNavButtons(controlsItemW, sendButton,
  ["btn_reset_shortcut", "btn_reset_axis", "btn_assign"])

return wndFrame({
  title = loc("mainmenu/btnControls")
  backSceneName = backSceneNameW
  onBack = @() sendButton("btn_back")
  tabs = groupTabs
  content
  navLeft = [
    textButton("btn_switchMode", loc("mainmenu/switchToSimplifiedControls"), "J:X")
    textButton("btn_controlsWizard", loc("mainmenu/btnControlsWizard"), "J:Y")
    imageButton("btn_controlsHelp", "btn_current_assigned_buttons.svg", "J:LT", loc("options/help"))
    imageButton("btn_clearAll", "btn_clear_all.svg", "J:LS", loc("options/clearAll"))
    imageButton("btn_exportToFile", "btn_save_to_file.svg", null, loc("options/exportToFile"))
    imageButton("btn_importFromFile", "btn_load_from_file.svg", null, loc("options/importFromFile"))
    imageButton("btn_backupManager", "btn_save_to_file.svg")
    linkButton("btn_controls_workshop_online", loc("controls/workshop"))
  ]
  navRight = [
    imageButton("btn_reset_shortcut", "btn_reset_shortcut.svg", "J:RS", loc("mainmenu/btnResetButton"))
    imageButton("btn_reset_axis", "btn_reset_axis.svg", "J:RS", loc("mainmenu/btnResetAxis"))
    textButton("btn_assign", loc("mainmenu/btnAssign"))
    textButton("btn_apply", loc("mainmenu/btnClose"), JB.B)
  ]
})
