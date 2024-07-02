from "%rGui/globals/ui_library.nut" import *
let { FlaresCount, ChaffsCount, CannonCount } = require("%rGui/airState.nut")
let string = require("string")
let { WeaponSlots, WeaponSlotsTrigger, WeaponSlotsCnt, SelectedWeapSlot,
 WeaponSlotsTotalCnt, WeaponSlotsName } = require("%rGui/planeState/planeWeaponState.nut")
let { weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")

let baseColor = Color(255, 255, 255, 255)
let baseLineWidth = 2
let baseFontSize = 20

let aircraft = {
  size = [pw(80), ph(47)]
  pos = [pw(5), ph(26)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 34, 0, 0, 62],
    [VECTOR_LINE, 0, 62, 10, 100],
    [VECTOR_LINE, 10, 100, 22, 97],
    [VECTOR_LINE, 22, 97, 34, 97],
    [VECTOR_LINE, 68, 0, 100, 62],
    [VECTOR_LINE, 100, 62, 90, 100],
    [VECTOR_LINE, 90, 100, 78, 97],
    [VECTOR_LINE, 78, 97, 68, 97]
  ]
}

let chaffs = @(){
  watch = ChaffsCount
  size = SIZE_TO_CONTENT
  pos = [pw(67), ph(18)]
  rendObj = ROBJ_TEXT
  color = ChaffsCount.get() <= 0 ? Color(255, 0, 0, 255) : (ChaffsCount.get() <= 10 ? Color(255, 100, 0, 255) : Color(0, 255, 0, 255))
  font = Fonts.hud
  fontSize = baseFontSize
  text = string.format("CHF %d", ChaffsCount.get())
}

let flares = @(){
  watch = FlaresCount
  size = SIZE_TO_CONTENT
  pos = [pw(67), ph(22)]
  rendObj = ROBJ_TEXT
  color = FlaresCount.get() <= 0 ? Color(255, 0, 0, 255) : (FlaresCount.get() <= 10 ? Color(255, 100, 0, 255) : Color(0, 255, 0, 255))
  font = Fonts.hud
  fontSize = baseFontSize
  text = string.format("FLR %d", FlaresCount.get())
}

let CannonAmmoCount = CannonCount[0]
let cannonDozens = Computed(@() (CannonAmmoCount.get() * 0.1).tointeger())
let cannons = @(){
  watch = cannonDozens
  size = SIZE_TO_CONTENT
  pos = [pw(1), ph(22)]
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.hud
  fontSize = baseFontSize
  text = string.format("%d", cannonDozens.get() * 10)
}

let labels = {
  size = flex()
  children = [
    {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(18)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = "HIGH"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(48)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = "A/G"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(90), ph(80)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = "MENU"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(66), ph(26)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = "CMD MSS"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(16), ph(14)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = "B3 AUT"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(16), ph(18)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = "B2 AUT"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(16), ph(22)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      text = "B1 AUT"
    }
  ]
}

function aamMark(pos, i) {
  return @(){
    pos
    size = SIZE_TO_CONTENT
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      @(){
        watch = SelectedWeapSlot
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = SelectedWeapSlot.get() == WeaponSlots.get()[i] ? Color(0, 255, 0, 255) : baseColor
        font = Fonts.hud
        fontSize = baseFontSize
        text = SelectedWeapSlot.get() == WeaponSlots.get()[i] ? "RDY" : "STBY"
        children = SelectedWeapSlot.get() == WeaponSlots.get()[i] ? {
          rendObj = ROBJ_FRAME
          size = [pw(105), ph(105)]
          pos = [-2, -2]
          color = Color(0, 255, 0, 255)
        } : null
      }
      {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.hud
        fontSize = baseFontSize
        text = loc(string.format("%s/f15mfd", WeaponSlotsName.get()[i]))
      }
    ]
  }
}

function fuelMark(pos, i) {
  return @(){
    pos
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    color = baseColor
    font = Fonts.hud
    fontSize = baseFontSize
    text = WeaponSlotsTrigger.get()[i] == weaponTriggerName.EXTERNAL_FUEL_TANKS_TRIGGER ? "FUEL" : "PYLON"
  }
}

function cbt(pos, is_center, is_pylon) {
  return @(){
    pos
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    color = baseColor
    font = Fonts.hud
    fontSize = baseFontSize
    text = string.format("CBT %d %c %s", is_center ? 1 : 2, is_center ? 'C' : 'R', is_pylon ? "PYLON" : "STORE")
  }
}

let pods = @(width, height, less_pods) function() {
  let childrens = []

  let positionsC = [
    [width * 0.7, height * 0.5],//0
    [width * 0.15, height * 0.5],//1 left wing, left AA pylon
    [width * 0.16, height * 0.01],//2 left fuel tank or agm pylon
    [width * 0.29, height * 0.5],//3 left wing, right AA pylon
    [width * 0.34, height * 0.68],//4 left back body AA pylon
    [width * 0.34, height * 0.22],//5 left front body AA pylon
    [width * 0.5, height * 0.22],//6
    [width * 0.46, height * 0.01],//7 central fuel tank or AGM
    [width * 0.3, height * 0.22],//8
    [width * 0.5, height * 0.22],//9 right front body AA pylon
    [width * 0.5, height * 0.68],//10 right back body AA pylon
    [width * 0.55, height * 0.5],//11 right wing, left AA pylon
    [width * 0.76 height * 0.01],//12 right fuel tank or AGM pylon
    [width * 0.7, height * 0.5]//13 right wing, right AA pylon
  ]
  let positionsJ = [
    [width * 0.7, height * 0.5],//0
    [width * 0.15, height * 0.5],//1 left wing, left AA pylon
    [width * 0.16, height * 0.01],//2 left fuel tank or agm pylon
    [width * 0.29, height * 0.5],//3 left wing, right AA pylon
    [width * 0.34, height * 0.68],//4 left back body AA pylon
    [width * 0.34, height * 0.22],//5 left front body AA pylon
    [width * 0.46, height * 0.01],//6 central fuel tank or AGM
    [width * 0.5, height * 0.22],//7 right front body AA pylon
    [width * 0.5, height * 0.68],//8 right back body AA pylon
    [width * 0.55, height * 0.5],//9 right wing, left AA pylon
    [width * 0.76 height * 0.01],//10 right fuel tank or AGM pylon
    [width * 0.7, height * 0.5]//11 right wing, right AA pylon
  ]

  for (local i = 0; i < WeaponSlots.get().len(); ++i) {
    if (WeaponSlots.get()[i] != null) {
      if (WeaponSlotsTrigger.get()[i] == weaponTriggerName.AAM_TRIGGER && WeaponSlotsCnt.get()[i] > 0) {
        childrens.append(aamMark(less_pods ? positionsJ[WeaponSlots.get()[i]] : positionsC[WeaponSlots.get()[i]], i))
      }
      else if (!less_pods && (WeaponSlots.get()[i] == 2 || WeaponSlots.get()[i] == 12 || WeaponSlots.get()[i] == 7)) {
        childrens.append(fuelMark(less_pods ? positionsJ[WeaponSlots.get()[i]] : positionsC[WeaponSlots.get()[i]], i))
        if (WeaponSlots.get()[i] != 2) {
          let isCenter = WeaponSlots.get()[i] == 7
          childrens.append(cbt(isCenter ? [width * 0.32, height * 0.8] : [width * 0.32, height * 0.85], isCenter, WeaponSlotsTrigger.get()[i] != weaponTriggerName.EXTERNAL_FUEL_TANKS_TRIGGER))
        }
      }
      else if (less_pods && (WeaponSlots.get()[i] == 2 || WeaponSlots.get()[i] == 10 || WeaponSlots.get()[i] == 6)) {
        childrens.append(fuelMark(less_pods ? positionsJ[WeaponSlots.get()[i]] : positionsC[WeaponSlots.get()[i]], i))
        if (WeaponSlots.get()[i] != 2) {
          let isCenter = WeaponSlots.get()[i] == 6
          childrens.append(cbt(isCenter ? [width * 0.32, height * 0.8] : [width * 0.32, height * 0.85], isCenter, WeaponSlotsTrigger.get()[i] != weaponTriggerName.EXTERNAL_FUEL_TANKS_TRIGGER))
        }
      }
    }
  }

  return {
    watch = [WeaponSlots, WeaponSlotsCnt, WeaponSlotsTotalCnt]
    size = [width, height]
    children = childrens
  }
}

function f15cWpn(pos, size) {
  return {
    size
    pos
    children = [
      aircraft
      chaffs
      flares
      cannons
      labels
      pods(size[0], size[1], false)
    ]
  }
}

function f15jWpn(pos, size) {
  return {
    size
    pos
    children = [
      aircraft
      chaffs
      flares
      cannons
      labels
      pods(size[0], size[1], true)
    ]
  }
}

return {
  f15cWpn
  f15jWpn
}