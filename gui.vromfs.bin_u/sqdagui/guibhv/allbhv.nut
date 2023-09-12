from "%sqDagui/daguiNativeApi.nut" import *

let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
loadOnce("%sqstd/math.nut")

let {
  basicSize, basicPos, basicTransparency, syncTransparency, massTransparency, basicRotation, basicFontSize,
  basicFontSizeTextArea, motionCursor, motionCursorField, shakePos, shakeRotation, multiLayerImage
} = require("bhvBasic.nut")

let { Timer } = require("bhvTimer.nut")
let { posNavigator } = require("bhvPosNavigator.nut")
let { MultiSelect } = require("bhvMultiSelect.nut")
let { ActivateSelect } = require("bhvActivateSelect.nut")
let { PosOptionsNavigator } = require("bhvPosOptionsNavigator.nut")
let { HoverNavigator } = require("bhvHoverNavigator.nut")
let { wrapBroadcast } = require("bhvWrapBroadcast.nut")
let { ControlsInput } = require("bhvControlsInput.nut")

if (!("gui_bhv" in getroottable()))
  ::gui_bhv <- {
    Timer, posNavigator, MultiSelect, ActivateSelect, PosOptionsNavigator,
    ControlsInput, HoverNavigator, wrapBroadcast
  }

if (!("gui_bhv_deprecated" in getroottable()))
  ::gui_bhv_deprecated <- {
    basicSize, basicPos, basicTransparency, syncTransparency, massTransparency, basicRotation, basicFontSize,
    basicFontSizeTextArea, motionCursor, motionCursorField, shakePos, shakeRotation, multiLayerImage
  }

