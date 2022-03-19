local enums = require("sqStdlibs/helpers/enums.nut")

::g_wrap_dir <- {
  types = []

  template = {
    notifyId = "wrap_down"
    isVertical = true
    isPositive = true
  }

  function getWrapDir(isVertical, isPositive) {
    if (isVertical)
      return isPositive ? DOWN : UP
    return isPositive ? RIGHT : LEFT
  }
}

enums.addTypes(::g_wrap_dir, {
  UP = {
    notifyId = "wrap_up"
    isVertical = true
    isPositive = false
  }
  DOWN = {
    notifyId = "wrap_down"
    isVertical = true
    isPositive = true
  }
  LEFT = {
    notifyId = "wrap_left"
    isVertical = false
    isPositive = false
  }
  RIGHT = {
    notifyId = "wrap_right"
    isVertical = false
    isPositive = true
  }
})
