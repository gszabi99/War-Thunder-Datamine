let { speedValue, speedUnits, machineSpeed } = require("%rGui/hud/shipStateView.nut")
let { safeAreaSizeHud, rh } = require("%rGui/style/screenState.nut")
let { dmgIndicatorStates } = require("%rGui/hudState.nut")
let { isMultiplayer } = require("%rGui/networkState.nut")
let { mkTouchButton, touchButtonSize, bigTouchButtonSize, touchButtonMargin
} = require("%rGui/hud/hudTouchButton.nut")

let speedHeight = 2.5*touchButtonMargin
let bottomLeftBlockHeigh = 2*bigTouchButtonSize + speedHeight
let hudFont = Fonts.small_text_hud

let speedComp = @() {
  size = [bigTouchButtonSize, speedHeight]
  pos = [bigTouchButtonSize + touchButtonMargin, bigTouchButtonSize]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    machineSpeed({ font = hudFont, fontColor = Color(255, 255, 255)})
    {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_BOTTOM
      children = [
        speedValue({ font = hudFont, margin = 0 })
        speedUnits()
      ]
    }
  ]
}

let menuButtonsBlock = @() {
  watch = isMultiplayer
  hplace = ALIGN_RIGHT
  flow = FLOW_HORIZONTAL
  gap = touchButtonMargin
  children = isMultiplayer.value
    ? [
        mkTouchButton("ID_SHOW_VOICE_MESSAGE_LIST")
        mkTouchButton("ID_MPSTATSCREEN")
        mkTouchButton("ID_TACTICAL_MAP")
        mkTouchButton("ID_FLIGHTMENU_SETUP")
      ]
    : [
        mkTouchButton("ID_TACTICAL_MAP")
        mkTouchButton("ID_FLIGHTMENU_SETUP")
      ]
}

let movementBlock = @() {
  watch = [rh, dmgIndicatorStates]
  size = [3*bigTouchButtonSize + 2*touchButtonMargin, bottomLeftBlockHeigh]
  pos = [0, rh.value - bottomLeftBlockHeigh - dmgIndicatorStates.value.padding[2]]
  children = [
    mkTouchButton("ship_steering_rangeMax", {
      vplace = ALIGN_CENTER
    })
    mkTouchButton("ship_steering_rangeMin", {
      hplace = ALIGN_RIGHT
      vplace = ALIGN_CENTER
    })
    mkTouchButton("ship_main_engine_rangeMax", {
      hplace = ALIGN_CENTER })
    mkTouchButton("ship_main_engine_rangeMin", {
      hplace = ALIGN_CENTER
      vplace = ALIGN_BOTTOM
    })
    speedComp()
  ]
}

let weaponryBlock = @() {
  size = [bigTouchButtonSize + 1.5*touchButtonSize, bigTouchButtonSize + 1.5*touchButtonSize]
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  children = [
    mkTouchButton("ID_ZOOM_TOGGLE")
    mkTouchButton("ID_SHIP_WEAPON_ALL", {
      pos = [0.75*touchButtonSize, touchButtonSize]
    })
  ]
}

return @() {
  watch = safeAreaSizeHud
  size = safeAreaSizeHud.value.size
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = [
    menuButtonsBlock
    movementBlock
    weaponryBlock()
  ]
}
