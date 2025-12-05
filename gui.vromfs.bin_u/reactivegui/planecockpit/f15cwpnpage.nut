from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { FlaresCount, ChaffsCount, CannonCount, IsChaffsEmpty, IsFlrEmpty } = require("%rGui/airState.nut")
let string = require("string")
let { WeaponSlots, WeaponSlotsTrigger, WeaponSlotsCnt, SelectedWeapSlot,
 WeaponSlotsTotalCnt, WeaponSlotsName, WeaponSlotsBulletId } = require("%rGui/planeState/planeWeaponState.nut")
let { weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")

let baseColor = Color(255, 255, 255, 255)
let baseLineWidth = 2
let baseFontSize = 20

let aircraft = {
  size = const [pw(80), ph(47)]
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
  watch = [ChaffsCount, IsChaffsEmpty]
  size = SIZE_TO_CONTENT
  pos = [pw(67), ph(18)]
  rendObj = ROBJ_TEXT
  color = ChaffsCount.get() <= 0 || IsChaffsEmpty.get() ? Color(255, 0, 0, 255) : (ChaffsCount.get() <= 10 ? Color(255, 100, 0, 255) : Color(0, 255, 0, 255))
  font = Fonts.hud
  fontSize = baseFontSize
  text = string.format("CHF %d", IsChaffsEmpty.get() ? 0 : ChaffsCount.get())
}

let flares = @(){
  watch = [FlaresCount, IsFlrEmpty]
  size = SIZE_TO_CONTENT
  pos = [pw(67), ph(22)]
  rendObj = ROBJ_TEXT
  color = FlaresCount.get() <= 0 || IsFlrEmpty.get() ? Color(255, 0, 0, 255) : (FlaresCount.get() <= 10 ? Color(255, 100, 0, 255) : Color(0, 255, 0, 255))
  font = Fonts.hud
  fontSize = baseFontSize
  text = string.format("FLR %d", IsFlrEmpty.get() ? 0 : FlaresCount.get())
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

function isSlotSelected(idx) {
  if (SelectedWeapSlot.get() == WeaponSlots.get()[idx])
    return true

  local selectedWeaponBulletId = -1;
  foreach (i, _ in WeaponSlots.get()) {
    if (SelectedWeapSlot.get() == WeaponSlots.get()[i]) {
      selectedWeaponBulletId = WeaponSlotsBulletId.get()[i]
      break
    }
  }

  return selectedWeaponBulletId >= 0 && selectedWeaponBulletId == WeaponSlotsBulletId.get()[idx]
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
        size = [baseFontSize * (isSlotSelected(i) ? 2 : 2.4), baseFontSize]
        rendObj = ROBJ_TEXT
        color = isSlotSelected(i) ? Color(0, 255, 0, 255) : baseColor
        font = Fonts.hud
        fontSize = baseFontSize
        text = isSlotSelected(i) ? "RDY" : "STBY"
        children = isSlotSelected(i) ? {
          rendObj = ROBJ_FRAME
          size = const [pw(105), ph(105)]
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
        text = loc_checked(string.format("%s/f15mfd", WeaponSlotsName.get()[i]))
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
    [width * 0.7, height * 0.5],
    [width * 0.15, height * 0.5],
    [width * 0.16, height * 0.01],
    [width * 0.29, height * 0.5],
    [width * 0.34, height * 0.68],
    [width * 0.34, height * 0.22],
    [width * 0.5, height * 0.22],
    [width * 0.46, height * 0.01],
    [width * 0.3, height * 0.22],
    [width * 0.5, height * 0.22],
    [width * 0.5, height * 0.68],
    [width * 0.55, height * 0.5],
    [width * 0.76 height * 0.01],
    [width * 0.7, height * 0.5]
  ]
  let positionsJ = [
    [width * 0.7, height * 0.5],
    [width * 0.15, height * 0.5],
    [width * 0.16, height * 0.01],
    [width * 0.29, height * 0.5],
    [width * 0.34, height * 0.68],
    [width * 0.34, height * 0.22],
    [width * 0.46, height * 0.01],
    [width * 0.5, height * 0.22],
    [width * 0.5, height * 0.68],
    [width * 0.55, height * 0.5],
    [width * 0.76 height * 0.01],
    [width * 0.7, height * 0.5]
  ]

  foreach (idx, weaponSlot in WeaponSlots.get()) {
    if (weaponSlot == null)
      continue
    let weaponSlotTrigger = WeaponSlotsTrigger.get()?[idx]
    let weaponSlotCnt = WeaponSlotsCnt.get()?[idx] ?? 0
    if (weaponSlotTrigger == weaponTriggerName.AAM_TRIGGER && weaponSlotCnt > 0) {
      childrens.append(aamMark(less_pods ? positionsJ[weaponSlot] : positionsC[weaponSlot], idx))
      continue
    }

    if (!less_pods && (weaponSlot == 2 || weaponSlot == 12 || weaponSlot == 7)) {
      childrens.append(fuelMark(positionsC[weaponSlot], idx))
      if (weaponSlot != 2) {
        let isCenter = weaponSlot == 7
        childrens.append(cbt(isCenter ? [width * 0.32, height * 0.8] : [width * 0.32, height * 0.85], isCenter, weaponSlotTrigger != weaponTriggerName.EXTERNAL_FUEL_TANKS_TRIGGER))
      }
      continue
    }

    if (less_pods && (weaponSlot == 2 || weaponSlot == 10 || weaponSlot == 6)) {
      childrens.append(fuelMark(positionsJ[weaponSlot], idx))
      if (weaponSlot != 2) {
        let isCenter = weaponSlot == 6
        childrens.append(cbt(isCenter ? [width * 0.32, height * 0.8] : [width * 0.32, height * 0.85], isCenter, weaponSlotTrigger != weaponTriggerName.EXTERNAL_FUEL_TANKS_TRIGGER))
      }
      continue
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