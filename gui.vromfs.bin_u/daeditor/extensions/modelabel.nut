from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *

let {showPointAction, namePointAction, editorFreeCam} = require("%daeditor/state.nut")

return @(levelLoaded) @() {
  watch = [
    levelLoaded
    editorFreeCam
    showPointAction
    namePointAction
  ],
  size = flex(),
  children = [
    !levelLoaded.get() ? null : (
      editorFreeCam.get() ? { rendObj = ROBJ_BOX, fillColor = const Color(20,20,20,100), borderRadius = const hdpx(10), padding = const hdpx(8), hplace = ALIGN_CENTER,
                              children = txt(showPointAction.get() ? $"Free camera [ {namePointAction.get()} ]" : const "Free camera mode") } :
      showPointAction.get() ? { rendObj = ROBJ_BOX, fillColor = const Color(20,20,20,100), borderRadius = const hdpx(10), padding = const hdpx(8), hplace = ALIGN_CENTER,
                                children = txt(namePointAction.get()) } :
      null
    )
  ]
}
