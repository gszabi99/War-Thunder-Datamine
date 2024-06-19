from "%rGui/globals/ui_library.nut" import *

let { CustomPages } = require("%rGui/planeState/planeToolsState.nut")
let ah64Flt = require("ah64FltPage.nut")
let ah64Wpn = require("ah64WpnPage.nut")
let f15cWpn = require("f15cWpnPage.nut")
let su27Pod = require("mfdSu27Pod.nut")

function yellow(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(255, 255, 0)
  }
}

function red(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(255, 0, 0)
  }
}

function blue(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(0, 0, 255)
  }
}

let pageByName = {
  yellow,
  red,
  blue,
  ah64Flt,
  ah64Wpn,
  f15cWpn,
  su27Pod
}

function mfdCustomPages() {
  let pages = []

  foreach (name, pos in CustomPages.value) {
    if (name != null)
      pages.append(pageByName?[name]?([pos.x, pos.y], [pos.z, pos.w]))
  }
  return {
    watch = CustomPages
    size = flex()
    children = pages
  }
}

return mfdCustomPages