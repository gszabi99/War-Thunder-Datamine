from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import pictureName
from "%rGui/components/wndFrame.nut" import wndFrame, frameInnerW, frameContentH, searchBox, searchBoxH
from "%rGui/components/optionRows.nut" import rowH, rowButtonH, controlX, headerCells, rowLabel, rowBox,
  scrollToRow, mkListXmb, optionRow
from "%appGlobals/options/optionsScreenState.nut" import OPTIONS_HIDDEN_AT_START, optionsScreen, optionsItems,
  optionsItemW
from "eventbus" import eventbus_send
import "%rGui/control/gui_buttons.nut" as JB
import "%rGui/components/button.nut" as button
import "%rGui/components/navButtons.nut" as mkNavButtons
import "%rGui/components/headerTabs.nut" as headerTabs
import "%rGui/components/navigationPanel.nut" as navigationPanel
import "%rGui/components/scrollBox.nut" as scrollBox
import "%rGui/options/systemOptionsPage.nut" as systemOptionsPage
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors



let fontNormal = fontsState.get("normal")
let fontMedium = fontsState.get("medium")

let blockInterval = cssConst("blockInterval")
let btnMargin = cssConst("buttonMargin")
let rightCellMaxW = cssConst("optContainerRightCellWidth")
let contentPad = [2 * blockInterval, blockInterval]
let contentH = frameContentH(contentPad)
let navPanelWidth = "0.4@sf"
let infoPadding = [blockInterval, 4 * blockInterval]
let infoTextPadding = [px("14@sf/@pf"), 0, 0, px("10@sf/@pf")]

let sendAction = @(action, params = {}) eventbus_send("optionsScreen.action", params.__merge({ action }))
let callWnd = @(funcName, isDelayed = true) sendAction("call", { funcName, isDelayed })

let itemW = optionsItemW


const BUTTON_CALLS = { web_ui_button = "onWebUiMap", assistant_map_qr_button = "onAssistantMapQrCode",
  btn_gpu_benchmark = "onOpenGpuBenchmark", btn_reset_tab = "onSystemOptionsResetTab",
  btn_restart = "onSystemOptionsRestartClient", btn_reset = "onSystemOptionsReset", btn_apply = "onApply",
  btn_edit_radio = "onDialogEditRadio", btn_remove_radio = "onRemoveRadio", joinEchoButton = "onEchoTestButton" }
let { textButton } = mkNavButtons(itemW, @(id) callWnd(BUTTON_CALLS[id]), OPTIONS_HIDDEN_AT_START)

let tabsW = Computed(@() optionsScreen.get().tabs)
let curTabW = Computed(@() optionsScreen.get().curTab)
let inactiveTabsW = Computed(@() optionsScreen.get().inactiveTabs)
let navItemsW = Computed(@() optionsScreen.get().navItems)
let curNavIdxW = Computed(@() optionsScreen.get().curNavIdx)
let rowsW = Computed(@() optionsScreen.get().rows)
let columnsRatioW = Computed(@() optionsScreen.get().columnsRatio)
let isInfoOnTheRightW = Computed(@() optionsScreen.get().isInfoOnTheRight)
let extraRowsW = Computed(@() optionsScreen.get().extraRows)
let infoW = Computed(@() optionsScreen.get().info)
let searchTextW = Computed(@() optionsScreen.get().searchText)
let backSceneNameW = Computed(@() optionsScreen.get().backSceneName)
let isSysoptPageW = Computed(@() optionsScreen.get().sysopt != null)


function hotkeyCell(opt, width, alpha) {
  let btnW = ((width - blockInterval) / 2).tointeger()
  let shortcutItem = itemW(opt.shortcutTextareaId)
  let shortcutText = @(_sf, _isEnabled, _textColor) @() {
    watch = shortcutItem
    size = [btnW, flex()]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = rowLabel(shortcutItem.get()?.value ?? "", cssColors.buttonFontColor)
  }
  return [{
    pos = [controlX, 0]
    vplace = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = blockInterval
    children = [
      button({ id = opt.shortcutTextareaId, size = [btnW, rowButtonH], minWidth = 0, margin = 0, skipDirPadNav = true,
        alpha, content = shortcutText, tooltip = @() opt.tip }, @() callWnd(opt.onAssignFnName))
      button({ id = $"{opt.shortcutTextareaId}_reset", text = loc("mainmenu/btnReset"), size = [btnW, rowButtonH],
        minWidth = 0, margin = 0, skipDirPadNav = true, alpha, tooltip = @() opt.resetTip }, @() callWnd(opt.onResetFnName))
    ]
  }]
}


let activeRowIdW = Watched(null)

let listOffsY = Watched(0)
rowsW.subscribe(function(_) {
  activeRowIdW.set(null)
  listOffsY.set(0)
})

let rowCtx = {
  itemW
  activeRowIdW
  onChange = @(id, value) sendAction("changeValue", { id, value })
  onButton = @(row) callWnd(row.control.funcName, row.control.isDelayed)
  mkCell = @(row, w, alpha) row.control.kind == "hotkey" ? hotkeyCell(row.control.opt, w, alpha) : null
  function onHover(row) {
    activeRowIdW.set(row.id)
    sendAction("hoverRow", { trId = row.id })
  }
  onClick = @(row) sendAction("selectRow", { trId = row.id })
}

let tabs = @() {
  watch = tabsW
  children = headerTabs({ tabs = tabsW.get().map(@(t) { id = t.id, tabName = t.text, visualDisable = t.visualDisable }) },
    curTabW, @(idx) sendAction("selectTab", { idx }), inactiveTabsW)
}

let navigation = @() {
  watch = navItemsW
  size = const [SIZE_TO_CONTENT, flex()]
  children = navigationPanel({ panelWidth = navPanelWidth, headerHeight = "1@buttonHeight", items = navItemsW.get() },
    curNavIdxW, @(idx) sendAction("selectNav", { idx }))
}

let searchItem = itemW("search_container")
let searchComp = searchBox(searchTextW, @(text) sendAction("search", { text }), @() sendAction("searchCancel"))
let searchBlock = @() {
  watch = searchItem
  size = const [flex(), SIZE_TO_CONTENT]
  children = (searchItem.get()?.shown ?? false) ? searchComp : null
}


let hotkeyRow = @(opt) { id = $"{opt.shortcutTextareaId}_tr", itemId = opt?.optRowId, label = opt.optionText,
  control = { kind = "hotkey", opt } }

let extraHeaderRow = @(text, tableW) rowBox(tableW, false, true, { children = headerCells(text) })

let radioTip = @(id) @() loc($"guiHints/internet_radio_{id}")

function extraRows(extra, tableW, ctx) {
  if (extra == null)
    return []
  if (extra.kind == "radio")
    return [
      {
        flow = FLOW_HORIZONTAL
        margin = [2 * blockInterval, 0, 0, 0]
        padding = btnMargin
        gap = btnMargin
        children = [
          button({ id = "btn_add_radio", text = loc("options/internet_radio_add"), margin = 0, tooltip = radioTip("add") },
            @() callWnd("onDialogAddRadio"))
          textButton("btn_edit_radio", loc("options/internet_radio_edit"), null, { tooltip = radioTip("edit") })
          textButton("btn_remove_radio", loc("options/internet_radio_remove"), null, { tooltip = radioTip("remove") })
        ]
      }
      extraHeaderRow(loc("mainmenu/btnControls"), tableW)
    ].extend(extra.hotkeyOpts.map(@(o) optionRow(ctx, hotkeyRow(o), tableW)))
  let { needShowOptions, hotkeyOpts } = extra
  if (!needShowOptions)
    return [
      extraHeaderRow(loc("options/voicechat"), tableW)
      {
        size = [tableW / 2, SIZE_TO_CONTENT]
        hplace = ALIGN_CENTER
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        halign = ALIGN_CENTER
        font = fontNormal
        color = cssColors.warningTextColor
        text = loc("options/voiceChat/disableWarning")
      }
    ]
  return [
    hotkeyOpts == null ? null : optionRow(ctx, hotkeyRow(hotkeyOpts), tableW)
    {
      size = [tableW, rowH]
      margin = [blockInterval, 0, 0, 0]
      children = {
        pos = [ctx.leftW(tableW) + controlX, 0]
        vplace = ALIGN_CENTER
        children = textButton("joinEchoButton", loc("options/joinEcho"), null, { size = [SIZE_TO_CONTENT, rowButtonH] })
      }
    }
  ]
}

let listHeightW = Watched(0)
let measureList = @(_initial, elem) listHeightW.set(elem.getHeight())

let infoListWidth = @(listW) (0.45 * listW).tointeger()


function shownRowIdx(rowId) {
  let shown = rowsW.get().filter(@(r) optionsItems.get()?[r.itemId]?.shown ?? true)
  return shown.findindex(@(r) r.id == rowId) ?? shown.len()
}

function optionsList(listW, listH) {
  let infoListW = infoListWidth(listW)
  return function() {
    let isInfoOnTheRight = isInfoOnTheRightW.get()
    let rows = rowsW.get()
    let ratio = columnsRatioW.get()
    let extra = extraRowsW.get()
    return {
      watch = [rowsW, columnsRatioW, isInfoOnTheRightW, extraRowsW]
      hplace = isInfoOnTheRight ? ALIGN_LEFT : ALIGN_CENTER
      children = scrollBox({ size = [isInfoOnTheRight ? infoListW : listW, listH], contentHeight = listHeightW,
          scrollOffsY = listOffsY },
        function(tableW, offset, viewH) {
          let ctx = rowCtx.__merge({
            leftW = @(w) (ratio * w).tointeger()
            isLabelLeft = isInfoOnTheRight
            rightMaxW = rightCellMaxW
            keepInView = @(rowId) scrollToRow(offset, viewH, shownRowIdx(rowId))
            onHover = isInfoOnTheRight ? rowCtx.onHover : null
          })
          return {
            size = [tableW, SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            behavior = Behaviors.RecalcHandler
            onRecalcLayout = measureList
            xmbNode = mkListXmb()
            children = rows.map(@(row) optionRow(ctx, row, tableW)).extend(extraRows(extra, tableW, ctx))
          }
        })
    }
  }
}

function infoPanel(listW) {
  let panelW = listW - infoListWidth(listW)
  let textW = panelW - 2 * infoPadding[1] - px("10@sf/@pf")
  return @() {
    watch = [infoW, isInfoOnTheRightW]
    size = [panelW, flex()]
    hplace = ALIGN_RIGHT
    padding = infoPadding
    children = infoW.get() == null || !isInfoOnTheRightW.get() ? null : {
      size = flex()
      flow = FLOW_VERTICAL
      gap = 3 * blockInterval
      padding = infoTextPadding
      children = [
        { rendObj = ROBJ_TEXT, font = fontMedium, color = cssColors.activeTextColor, text = infoW.get().title }
        "" == (infoW.get()?.imageSrc ?? "") ? null : {
          size = [textW, (0.552 * textW).tointeger()]
          rendObj = ROBJ_IMAGE
          image = Picture(pictureName(infoW.get().imageSrc))
          keepAspect = KEEP_ASPECT_FIT
        }
        {
          size = [textW, SIZE_TO_CONTENT]
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          font = fontNormal
          color = cssColors.commonTextColor
          text = infoW.get().description
        }
      ]
    }
  }
}

let content = {
  size = flex()
  flow = FLOW_HORIZONTAL
  children = [
    navigation
    function() {
      let listW = frameInnerW - (navItemsW.get().len() > 1 ? px(navPanelWidth) : 0)
      let listH = contentH - ((searchItem.get()?.shown ?? false) ? searchBoxH : 0)
      return {
        watch = [navItemsW, searchItem, isSysoptPageW]
        size = [listW, flex()]
        children = [
          {
            size = flex()
            flow = FLOW_VERTICAL
            children = [searchBlock, isSysoptPageW.get()
              ? systemOptionsPage(rowCtx, sendAction, infoListWidth(listW), listH)
              : optionsList(listW, listH)]
          }
          infoPanel(listW)
        ]
      }
    }
  ]
}

function navText(id, defText) {
  let item = itemW(id)
  return @() {
    watch = item
    children = !(item.get()?.shown ?? false) ? null
      : rowLabel(item.get()?.value ?? defText, cssColors.commonTextColor, { margin = [0, btnMargin] })
  }
}

return wndFrame({
  title = loc("mainmenu/btnSessionSettings")
  backSceneName = backSceneNameW
  onBack = @() callWnd("goBack")
  tabs
  content
  contentPad
  navLeft = [
    textButton("web_ui_button", loc("mainmenu/webui_map"), "J:Y")
    textButton("assistant_map_qr_button", loc("mainmenu/webui_map_qr"))
    textButton("btn_gpu_benchmark", "", "J:X")
    textButton("btn_reset_tab", loc("mainmenu/btnResetTab"))
  ]
  navRight = [
    navText("restart_suggestion", loc("msgbox/client_restart_pending"))
    navText("filter_notify", "")
    textButton("btn_restart", loc("msgbox/btn_restart"), "J:LS")
    textButton("btn_reset", loc("mainmenu/btnReset"), "J:RS")
    textButton("btn_apply", loc("mainmenu/btnClose"), JB.B)
  ]
})
