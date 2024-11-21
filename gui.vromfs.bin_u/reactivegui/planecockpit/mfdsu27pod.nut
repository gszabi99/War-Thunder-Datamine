from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { WeaponSlots, WeaponSlotsCnt, WeaponSlotsName, WeaponSlotsTrigger, WeaponSlotActive, SlotCount } = require("%rGui/planeState/planeWeaponState.nut")
let { weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")

let baseColor = Color(255, 255, 255, 255)
let baseLineWidth = 2

let aircraft = {
  size = flex()
  pos = [pw(2), ph(-8)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  lineWidth = baseLineWidth
  fillColor = 0
  commands = [
    [VECTOR_LINE, 2, 40, 80, 40],
    [VECTOR_SECTOR, 41, 40, 10, 10, 196, 344],
    [VECTOR_LINE, 2, 40, 25, 37.8],
    [VECTOR_LINE, 27, 37.5, 31.2, 37],
    [VECTOR_LINE, 25, 37.5, 24, 25],
    [VECTOR_LINE, 27, 37.5, 24, 25],
    [VECTOR_LINE, 80, 40, 57, 37.8],
    [VECTOR_LINE, 55, 37.5, 50.8, 37],
    [VECTOR_LINE, 57, 37.5, 58, 25],
    [VECTOR_LINE, 55, 37.5, 58, 25]
  ]
}

function getWeaponSlotNumber(WeaponSlotsV, WeaponSlotsCntV, WeaponSlotActiveV, SlotCountV) {
  let numbers = []
  let count = SlotCountV > 0 ? SlotCountV : 10
  let size = (100 / count)
  let added = {}
  foreach (i, weaponSlot in WeaponSlotsV) {
    let posL = size * i
    if (i < count)
      numbers.append(
        {
          rendObj = ROBJ_SOLID
          size = [baseLineWidth, ph(10)]
          pos = [pw(posL + size * 0.5), 0]
          color = baseColor
        }
      )

    if (weaponSlot == null || (weaponSlot in added))
      continue

    let pos = size * (weaponSlot - 1)
    let leng = 15 * (weaponSlot <= (count / 2) ? weaponSlot : (count + 1) - weaponSlot)
    let slotText = (i + 1).tostring()
    added[weaponSlot] <- true
    numbers.append(
      {
        rendObj = ROBJ_TEXT
        size = [pw(size), SIZE_TO_CONTENT]
        pos = [pw(pos), 20]
        color = baseColor
        fontSize = 20
        font = Fonts.ils31
        text = slotText
        halign = ALIGN_CENTER
      }
    )

    if ((WeaponSlotsCntV?[i] ?? 0) <= 0)
      continue

    let countColor = WeaponSlotActiveV?[i] ? Color(0, 255, 0, 255) : baseColor
    let curIdx = i
    let weaponName = Computed(@() (WeaponSlotsTrigger.get()?[curIdx] ?? -1) == weaponTriggerName.BOMBS_TRIGGER ? "АБ"
      : WeaponSlotsName.get()?[curIdx] != null ? loc_checked(WeaponSlotsName.get()[curIdx])
      : "")
    let weaponNamePos = [weaponSlot <= count / 2 ? pw(-2) : pw(103), ph(leng + 27)]
    numbers.append(
      {
        rendObj = ROBJ_VECTOR_CANVAS
        pos = [pw(pos), 40]
        size = [pw(size), flex()]
        color = baseColor
        fillColor = 0
        commands = [
          [VECTOR_LINE, 50, 0, 50, leng],
          [VECTOR_COLOR, countColor],
          [VECTOR_ELLIPSE, 50, leng + 5, 15, 5],
          [VECTOR_LINE, 40, leng + 2, 34, leng - 1],
          [VECTOR_LINE, 60, leng + 2, 66, leng - 1],
          [VECTOR_LINE, 40, leng + 8, 34, leng + 11],
          [VECTOR_LINE, 60, leng + 8, 66, leng + 11],
        ]
      }
      @() {
        watch = weaponName
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        pos = weaponNamePos
        color = countColor
        fontSize = 15
        font = Fonts.ils31
        text = weaponName.get()
      }
    )
  }
  return numbers
}

let connectors = @() {
  watch = [WeaponSlots, WeaponSlotsCnt, WeaponSlotActive, SlotCount]
  size = [pw(78), ph(30)]
  pos = [pw(4), ph(32)]
  children = getWeaponSlotNumber(WeaponSlots.get(), WeaponSlotsCnt.get(), WeaponSlotActive.get(), SlotCount.get())
}

let text = {
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(30)]
  size = [pw(18), SIZE_TO_CONTENT]
  color = Color(0, 255, 0)
  font = Fonts.hud
  fontSize = 20
  text = "ПИТАНИЕ"
  halign = ALIGN_RIGHT
}

let labels = {
  size = flex()
  children = [
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      size = SIZE_TO_CONTENT
      pos = [pw(16), ph(13)]
      font = Fonts.ils31
      fontSize = 15
      text = "ПИЛ"
    }
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      size = SIZE_TO_CONTENT
      pos = [pw(27), ph(13)]
      font = Fonts.ils31
      fontSize = 15
      text = "ТО"
    }
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      size = SIZE_TO_CONTENT
      pos = [pw(37), ph(13)]
      font = Fonts.ils31
      fontSize = 15
      text = "РЭП"
    }
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      size = SIZE_TO_CONTENT
      pos = [pw(47), ph(13)]
      font = Fonts.ils31
      fontSize = 15
      text = "ОПС"
    }
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      size = SIZE_TO_CONTENT
      pos = [pw(58), ph(13)]
      font = Fonts.ils31
      fontSize = 15
      text = "ИЛС"
    }
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      size = SIZE_TO_CONTENT
      pos = [pw(79), ph(13)]
      font = Fonts.ils31
      fontSize = 15
      text = "ПУМ"
    }
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      size = SIZE_TO_CONTENT
      pos = [pw(90), ph(13)]
      font = Fonts.ils31
      fontSize = 15
      text = "МФИ"
    }
  ]
}

function page(pos, size) {
  return {
    size
    pos
    children = [
      aircraft
      text
      connectors
      labels
    ]
  }
}
return page