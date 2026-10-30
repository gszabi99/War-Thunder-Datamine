from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/optionRows.nut" import rowPitch, mkRowsList
from "%rGui/components/wndFrame.nut" import closeButton
from "%rGui/controls/controlRows.nut" import mkControlsRowCtx
from "%appGlobals/controls/axisSetupState.nut" import axisSetup, axisSetupItemW, axisPoints
from "%appGlobals/controls/assignShortcutState.nut" import isWaitingInput
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/components/gamepadImgByKey.nut" import mkImageCompByDargKey
from "eventbus" import eventbus_send
import "%rGui/components/navButtons.nut" as mkNavButtons
import "%rGui/control/gui_buttons.nut" as JB
import "%rGui/components/comboBox.nut" as comboBox
import "%rGui/components/switchBox.nut" as switchBox
import "%rGui/components/scrollBox.nut" as scrollBox
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors



let fontNormal = fontsState.get("normal")
let fontMedium = fontsState.get("medium")
let blockInterval = cssConst("blockInterval")
let framePadding = cssConst("framePadding")
let headerH = cssConst("frameHeaderHeight")
let navBarH = cssConst("frameFooterHeight")
let btnMargin = cssConst("buttonMargin")
let bottomPanelH = cssConst("bottomMenuPanelHeight")
let wndW = px("@srw") - 2 * px("0.01@scrn_tgt")
let tableW = wndW - 2 * framePadding
let testBoxSize = [px("0.25@scrn_tgt"), px("0.04@scrn_tgt")]
let testBoxPad = px("0.06@scrn_tgt")
let pointSize = px("0.03@scrn_tgt")
let sideW = (tableW - testBoxSize[0] - 2 * testBoxPad) / 2
let listMaxH = sh(100) - bottomPanelH - px("0.3@scrn_tgt")

let sendAction = @(action, p = {}) eventbus_send("axisSetup.action", p.__merge({ action }))
let sendButton = @(id) sendAction("button", { id })

let isOpenW = Computed(@() axisSetup.get().isOpen)
let titleW = Computed(@() axisSetup.get().title)
let axisOptionsW = Computed(@() axisSetup.get().axisOptions)
let axisIdxW = Computed(@() axisSetup.get().axisIdx)
let autodetectW = Computed(@() axisSetup.get().autodetect)
let rowsW = Computed(@() axisSetup.get().rows)
let selectedRowIdW = Computed(@() axisSetup.get().selectedRowId)
let activeRowIdW = Watched(null)

let contentHeightW = Computed(@() rowsW.get().len() * rowPitch)
let listScrollW = Watched(0)
isOpenW.subscribe(function(_) {
  listScrollW.set(0)
  activeRowIdW.set(null)
})

let rowCtx = mkControlsRowCtx({ itemW = axisSetupItemW, selectedRowIdW, activeRowIdW, sendAction })
let { textButton, imageButton } = mkNavButtons(axisSetupItemW, sendButton, ["btn_reset_shortcut", "btn_assign"])

let mkText = @(text, font = fontNormal, color = cssColors.commonTextColor) { rendObj = ROBJ_TEXT, font, color, text }
let pointPic1 = Picture("ui/gameuiskin#axis_point1")
let pointPic2 = Picture("ui/gameuiskin#axis_point2")
let point1 = freeze({ size = pointSize, rendObj = ROBJ_IMAGE, image = pointPic1, color = 0xFFFF0000 })
let point2 = freeze({ size = pointSize, rendObj = ROBJ_IMAGE, image = pointPic2, color = 0xFF00FF00 })

let movingPoint = @(point, idx) @() {
  watch = axisPoints
  size = flex()
  valign = ALIGN_CENTER
  children = {
    pos = [((axisPoints.get()[idx] + 1.0) * 0.5 * (testBoxSize[0] - pointSize)).tointeger(), 0]
    children = point
  }
}

let legendRow = @(point, locId) { flow = FLOW_HORIZONTAL, valign = ALIGN_CENTER, children = [point, mkText(loc(locId))] }

let setAutodetect = @(value) sendAction("autodetect", { value })
let autodetectHint = mkImageCompByDargKey("J:X", null, { height = cssConst("cIco"), vplace = ALIGN_CENTER })
let autodetectBox = switchBox({ id = "autodetect_checkbox", textChecked = loc("mainmenu/btnAutodetectAxis"),
  textUnchecked = loc("mainmenu/btnAutodetectAxis") }, autodetectW, @(_id, value) setAutodetect(value))
let autodetectHotkeys = [["^J:X", @() setAutodetect(!autodetectW.get())]]
let autodetectSwitch = @() {
  watch = showConsoleButtons
  flow = FLOW_HORIZONTAL
  gap = blockInterval
  hotkeys = autodetectHotkeys
  children = [showConsoleButtons.get() ? autodetectHint : null, autodetectBox]
}

let comboSize = [sideW, cssConst("comboOptContainerHeight")]
let onAxisSelect = @(_id, idx) sendAction("axis", { idx })
let axisList = @() {
  watch = axisOptionsW
  children = comboBox({ id = "axis_list", options = axisOptionsW.get(), hotkey = "J:RB" },
    axisIdxW, onAxisSelect, comboSize)
}

let testBox = {
  size = [flex(), SIZE_TO_CONTENT]
  margin = [blockInterval, framePadding]
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = blockInterval
  children = [
    autodetectSwitch
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = testBoxPad
      children = [
        {
          size = [sideW, SIZE_TO_CONTENT]
          halign = ALIGN_RIGHT
          flow = FLOW_VERTICAL
          children = [legendRow(point1, "joystick/physicalAxis"), legendRow(point2, "joystick/logicalAxis")]
        }
        {
          size = testBoxSize
          rendObj = ROBJ_FRAME
          borderWidth = cssConst("dp")
          color = cssColors.separatorBlockColor
          children = [movingPoint(point1, 1), movingPoint(point2, 0)]
        }
        {
          size = [sideW, SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          children = [mkText(loc("joystick/setup_axis_msg")), axisList]
        }
      ]
    }
  ]
}

let rowsContent = mkRowsList(rowsW, rowCtx)
let rowsList = @() {
  watch = contentHeightW
  children = scrollBox({ size = [tableW, min(contentHeightW.get(), listMaxH)], contentHeight = contentHeightW,
    scrollOffsY = listScrollW }, rowsContent)
}

let header = {
  size = [flex(), headerH]
  padding = [0, framePadding]
  rendObj = ROBJ_SOLID
  color = cssColors.frameHeaderBackgroundColor
  valign = ALIGN_CENTER
  children = [
    @() { watch = titleW, children = mkText(titleW.get(), fontMedium, cssColors.activeTextColor) }
    closeButton(@() sendAction("close"))
  ]
}

let navRow = @(children, hplace) { hplace, vplace = ALIGN_CENTER, flow = FLOW_HORIZONTAL, gap = btnMargin, children }
let navBar = {
  size = [flex(), navBarH]
  padding = [0, framePadding]
  children = [
    navRow([imageButton("btn_axis_restore", "btn_undo.svg", "J:LB", loc("mainmenu/btnRestoreAxis")),
      imageButton("btn_axis_reset", "btn_reset_axis.svg", "J:LS", loc("mainmenu/btnResetAxis"))], ALIGN_LEFT)
    navRow([imageButton("btn_reset_shortcut", "btn_reset_shortcut.svg", "J:RS", loc("mainmenu/btnResetButton")),
      textButton("btn_assign", loc("mainmenu/btnAssign")), textButton("btn_apply", loc("mainmenu/btnOk"), JB.B)],
      ALIGN_RIGHT)
  ]
}

let axisWindow = {
  size = [wndW, SIZE_TO_CONTENT]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  rendObj = ROBJ_SOLID
  color = cssColors.frameBackgroundColor
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [header, testBox, rowsList, navBar]
}


let dropKbFocus = @() set_kb_focus(null)

return @() {
  watch = [isOpenW, isWaitingInput]
  size = flex()
  children = !isOpenW.get() || isWaitingInput.get() ? null : {
    size = [flex(), sh(100) - bottomPanelH]
    rendObj = ROBJ_SOLID
    color = cssColors.shadeBackgroundColor
    behavior = Behaviors.Button
    stopMouse = true
    stopHotkeys = true
    onAttach = dropKbFocus
    children = axisWindow
  }
}
