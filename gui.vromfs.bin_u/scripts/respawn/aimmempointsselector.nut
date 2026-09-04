from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener, removeEventListenersByEnv, broadcastEvent
from "weaponSelector" import get_all_weapons, get_current_weapon_preset
from "aimingMemPoints" import get_aim_points_linked_weapons, get_secondary_cycles, get_aim_point_relative_pos, set_aim_slot_idx_for_bullet, can_use_aiming_points
from "unit" import is_player_unit_alive
from "eventbus" import eventbus_subscribe
from "%sqstd/math.nut" import roundToDigits
from "%scripts/dagui_library.nut" import *
from "dagor.workcycle" import deferOnce

let { getWeaponryByPresetInfo } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { updateTierStats, preparePresetData } = require("%scripts/respawn/weaponSelectorUtils.nut")

const UPDATE_WEAPONS_DELAY = 0.5

class MapAimPointWeaponSelector {
  nestObj = null
  guiScene = null

  updateWeaponsDelay = 0
  aimPointIdx = -1
  chosenPreset = null
  unit = null
  lastWeaponsData = null
  lastLinksData = null
  lastTierStats = null
  slotIdToTiersId = null
  weaponCycles = null
  weaponsToTiers = null
  slots = null
  slotByWeaponIdx = null
  isSlotsInited = false
  isOpened = false
  lastRelativePos = null

  constructor(nestObj) {
    this.nestObj = nestObj
    this.slots = []
    this.guiScene = nestObj.getScene()

    add_event_listener("aim_point_right_click", this.onRightClickOnPoint, this)
    add_event_listener("select_aim_map_point", this.onSelectAimPoint, this)
    add_event_listener("aim_mem_point_start_drag", this.onStartDragAimPoint, this)
    add_event_listener("aim_mem_point_stop_drag", this.onStopDragAimPoint, this)
  }

  function selectUnit(unit) {
    if (this.unit?.name == unit.name)
      return
    this.clear()
    this.unit = unit
    if (!can_use_aiming_points()) {
      this.hide()
      return
    }
    let presetName = get_current_weapon_preset()?.presetName ?? ""
    this.selectPresetByName(presetName)
  }

  function selectPresetByName(presetName) {
    if (this.chosenPreset?.name == presetName)
      return
    let allPresets = getWeaponryByPresetInfo(this.unit, null, false).presets
    let chosenPresetIdx = allPresets.findindex(@(w) w.name == presetName) ?? 0
    let preset = clone allPresets[chosenPresetIdx]
    this.selectPreset(preset)
  }

  function selectPreset(preset) {
    this.chosenPreset = preset
    let preparedData = preparePresetData(preset, this.unit)
    this.slotIdToTiersId = preparedData.slotIdToTiersId

    this.slots = []
    let slotByBulletName = {}
    let presetsMarkup = []
    foreach (tier in preset.tiersView) {
      let bullet = tier?.weaponry.name
      if (!bullet)
        continue
      if (slotByBulletName?[bullet] == null) {
        let data = {
          img              = tier?.img,
          tierTooltipId    = tier?.tierTooltipId
          isActive         = tier?.img != null
          slotId           = this.slots.len()
        }
        slotByBulletName[bullet] <- data
        presetsMarkup.append(data)
        this.slots.append({
          bulletsAvailable = 0, links = {}, cycle = -1, tiers = []
        })
      }
      this.slots[slotByBulletName[bullet].slotId].tiers.append(tier.tierId)
    }

    let data = handyman.renderCached("%gui/respawn/aimPointSelectorPreset.tpl", { slots = presetsMarkup })
    this.guiScene.replaceContentFromText(this.nestObj, data, data.len(), this)

    let updateTimer = this.nestObj.findObject("aim_mem_points_selector_timer")
    updateTimer.setUserData(this)

    this.isSlotsInited = false
    this.weaponCycles = get_secondary_cycles()?.cycles
  }

  function updateCurrentWeaponsData(data) {
    let presetName = get_current_weapon_preset()?.presetName ?? ""
    if (this.chosenPreset?.name != presetName)
      this.selectPresetByName(presetName)
    this.lastWeaponsData = data
    let updateData = updateTierStats(data, this.slotIdToTiersId)
    this.lastTierStats = updateData.lastTiersStats
    this.weaponsToTiers = updateData.weaponsToTiers
  }

  function updateCountText() {
    let buttons_container = this.nestObj.findObject("buttons_container")
    let aimPointIdx = this.aimPointIdx
    foreach (slotId, slot in this.slots) {
      let slotObj = buttons_container.findObject($"slot_{slotId}")
      let linkedToPointCount = slot.links.filter(@(a) a == aimPointIdx).len()
      let linkedTotal = slot.links.filter(@(a) a != -1).len()
      let freeBulletsCount = slot.bulletsAvailable - linkedTotal
      slotObj.enabled = slot.links.len() > 0 ? "yes" : "no"
      if (slot.links.len() == 0)
        continue
      let text = "".concat(
        colorize("apsLinkedTextColor", linkedToPointCount.tostring()),
        "-",
        freeBulletsCount.tostring()
      )
      slotObj.findObject("label").setValue(text)
      slotObj.findObject("total_count").setValue(slot.bulletsAvailable.tostring())
    }
  }

  function updateCurrentLinks(linksData) {
    this.lastLinksData = linksData
    let linksCycles = this.lastLinksData.cycles

    for (local i = 0; i < linksCycles.len(); i++) {
      let linksCycle = linksCycles[i]
      let weaponIdxByBullet = this.weaponCycles[i]?.bulletsToWeapons
      if (weaponIdxByBullet == null)
        continue
      for (local j = 0; j < linksCycle.bullets.len(); j++) {
        let weaponIdx = weaponIdxByBullet[j]
        let aimPointId = linksCycle.bullets[j]

        let slotId = this.slotByWeaponIdx[weaponIdx]
        let slot = this.slots[slotId]
        slot.links[j] <- aimPointId
      }
    }
  }

  function getFreeBulletsForSlot(slotId) {
    let freeBullets = []
    let slot = this.slots[slotId]
    foreach (bulletIdx, aimPoint in slot.links)
      if (aimPoint < 0)
        freeBullets.append(bulletIdx)

    return freeBullets.sort()
  }

  function getLinkedToPointBullets(slotId, targetAimPoint) {
    let linkedBullets = []
    let slot = this.slots[slotId]
    foreach (bulletIdx, aimPoint in slot.links)
      if (aimPoint == targetAimPoint)
        linkedBullets.append(bulletIdx)

    return linkedBullets.sort()
  }

  function getCycleIdxByWeaponIdx(weaponIdx) {
    if (!this.weaponCycles)
      return -1
    let cyclesCount = this.weaponCycles.len()
    for (local i = 0; i < cyclesCount; i++) {
      let cycle = this.weaponCycles[i]
      if (cycle && cycle.bulletsToWeapons.contains(weaponIdx))
        return i
    }
    return -1
  }

  function initSlotsData() {
    if (this.lastTierStats == null)
      return

    this.isSlotsInited = true
    let slotByWeaponIdx = {}
    let tiersToSlots = {}
    foreach (slotId, slot in this.slots)
      foreach (tier in slot.tiers)
        tiersToSlots[tier] <- slotId

    foreach (weaponIdx, tierId in this.weaponsToTiers) {
      let slotId = tiersToSlots?[tierId]
      let slot = this.slots?[slotId]
      if (slot == null)
        continue
      slotByWeaponIdx[weaponIdx] <- slotId
      if (slot.cycle == -1)
        slot.cycle = this.getCycleIdxByWeaponIdx(weaponIdx)
    }
    this.slotByWeaponIdx = slotByWeaponIdx
  }

  function updateDataByTimer() {
    if (!this.nestObj?.isValid()) {
      this.destroy()
      return
    }
    if (!this.nestObj.isVisible())
      return

    let curUnit = getPlayerCurUnit()
    if (!curUnit || !is_player_unit_alive()) {
      this.hide()
      return
    }
    if (this.unit?.name != curUnit.name)
      this.selectUnit(curUnit)

    let data = get_all_weapons()
    if (data == null)
      return

    let isWeaponsDataChanged = this.isWeaponsDataChanged(this.lastWeaponsData, data)
    if (isWeaponsDataChanged)
      this.updateCurrentWeaponsData(data)

    if (!this.isSlotsInited)
      this.initSlotsData()

    let linksData = get_aim_points_linked_weapons()
    if (linksData == null)
      return
    let isLinksDataChanged = this.isLinksDataChanged(this.lastLinksData, linksData)
    if (isLinksDataChanged)
      this.updateCurrentLinks(linksData)

    if (isWeaponsDataChanged || isLinksDataChanged)
      this.updateWeaponsCount()

  }

  function updateWeaponsCount() {
    foreach (slot in this.slots)
      slot.bulletsAvailable = 0

    foreach (stat in this.lastTierStats) {
      let slotIdx = this.slotByWeaponIdx[stat.weaponIdx]
      let slot = this.slots[slotIdx]
      slot.bulletsAvailable += stat.count
    }
    this.updateCountText()
  }

  function hide() {
    this.isOpened = false
    if (!this.nestObj?.isValid())
      return
    this.nestObj.show(false)
  }

  function close() {
    this.hide()
    this.aimPointIdx = -1
  }

  function clear() {
    this.chosenPreset = null
    this.lastRelativePos = null
    this.unit = null
    this.lastWeaponsData = null
    this.slotIdToTiersId = null
    this.aimPointIdx = -1
    this.lastLinksData = null
    this.weaponCycles = null
    this.isSlotsInited = false
  }

  function show() {
    if (!this.nestObj.isValid())
      return
    this.nestObj.show(true)
    this.isOpened = true
  }

  function onRightClickOnPoint(params) {
    if (!this.nestObj?.isValid()) {
      this.destroy()
      return
    }
    if (!this.canBeShowed())
      return

    if (!this.isOpened) {
      this.show()
    } else {
      if (this.aimPointIdx == params.idx) {
        this.hide()
        return
      }
      let selector = this.nestObj.findObject("weapon_to_point_selector")
      if (selector.isHovered())
        return
    }

    let unit = getPlayerCurUnit()
    this.selectUnit(unit)
    this.aimPointIdx = params.idx
    this.setRelativePosition(params.x, params.y)

    if (this.isSlotsInited)
      this.updateCountText()
  }

  function onSelectAimPoint(params) {
    if (this.aimPointIdx == params.idx)
      return
    if (this.isOpened) {
      let presetNest = this.nestObj.findObject("weapon_to_point_selector")
      if (presetNest != null && presetNest.isHovered())
        return
    }
    this.close()
  }

  function onStartDragAimPoint(_params) {
    if (this.isOpened)
      this.hide()
  }

  function onStopDragAimPoint(params) {
    if (this.aimPointIdx == params.idx) {
      this.show()
      this.setRelativePosition(params.x, params.y)
    }
  }

  function destroy() {
    this.hide()
    this.clear()
    removeEventListenersByEnv("aim_point_right_click", this)
    removeEventListenersByEnv("select_aim_map_point", this)
    removeEventListenersByEnv("aim_mem_point_start_drag", this)
    removeEventListenersByEnv("aim_mem_point_stop_drag", this)
    if (this.nestObj?.isValid())
      this.guiScene.replaceContentFromText(this.nestObj, "", 0, this)
    this.nestObj = null
  }

  function onAimMemPointsSelectorTimer(_obj, dt) {
    if (!this.isOpened)
      return

    this.updateWeaponsDelay -= dt
    if (this.aimPointIdx >= 0) {
      let newPos = get_aim_point_relative_pos(this.aimPointIdx)
      if (newPos)
        this.setRelativePosition(newPos.x, newPos.y)
      else {
        this.hide()
        return
      }
    }

    if (this.updateWeaponsDelay > 0)
      return
    this.updateWeaponsDelay = UPDATE_WEAPONS_DELAY
    this.updateDataByTimer()
  }

  function onWeaponSlotClick(obj) {
    let slotId = to_integer_safe(obj.slotId)
    let freeBullets = this.getFreeBulletsForSlot(slotId)
    if (freeBullets.len() == 0)
      return
    let cycleIdx = this.slots[slotId].cycle
    set_aim_slot_idx_for_bullet(freeBullets[0], cycleIdx, this.aimPointIdx)
    let cb = Callback(@() this.updateDataByTimer(), this)
    deferOnce(@() cb())
  }

  function onWeaponRightClick(obj) {
    let slotId = to_integer_safe(obj.slotId)
    let linkedBullets = this.getLinkedToPointBullets(slotId, this.aimPointIdx)
    let linkedCount = linkedBullets.len()
    if (linkedCount == 0)
      return
    set_aim_slot_idx_for_bullet(linkedBullets[linkedCount-1], this.slots[slotId].cycle, -1)
    let cb = Callback(@() this.updateDataByTimer(), this)
    deferOnce(@() cb())
  }

  function isWeaponsDataChanged(old, current) {
    let newCount = current.weapons.len()
    if (old?.weapons.len() != newCount)
      return true
    if (old?.nextWeapon != current?.nextWeapon)
      return true
    foreach (idx, val in old.weapons)
      if (current.weapons[idx] != val)
        return true
    foreach (idx, val in old.selected)
      if (current.selected?[idx] != val)
        return true
    return false
  }

  function isLinksDataChanged(oldData, newData) {
    if (oldData?.cycles.len() != newData?.cycles.len())
      return true
    for (local i = 0; i < newData.cycles.len(); i++) {
      let newCycle = newData.cycles[i]
      let oldCycle = oldData.cycles[i]
      if (oldCycle.bullets.len() != newCycle.bullets.len())
        return true
      for (local j = 0; j < newCycle.bullets.len(); j++) {
        if (newCycle.bullets[j] != oldCycle.bullets[j])
          return true
      }
    }
    return false
  }

  function setRelativePosition(relativeX, relativeY) {
    let roundedX = roundToDigits(relativeX, 2)
    let roundedY = roundToDigits(relativeY, 2)
    if ((this.lastRelativePos?.x == relativeX) || (this.lastRelativePos?.y == relativeY))
      return
    this.lastRelativePos = { x = roundedX, y = roundedY }

    let tacticalMapBox = this.nestObj.getParent()
    let mapSize = tacticalMapBox.getSize()

    let child = this.nestObj.getChild(0)
    let selectorSize = child.getSize()
    let x = relativeX * mapSize[0]
    let y = relativeY * mapSize[1]

    let shiftY = to_pixels("1@apsShiftY")
    let pos = [x - selectorSize[0]/2, y - selectorSize[1] - shiftY]
    if (x > 0 && x < mapSize[0]) {
      let leftCorner = pos[0]
      let rightCorner = x + selectorSize[0]/2
      if (leftCorner < 0)
        pos[0] = 0
      else if (rightCorner > mapSize[0])
        pos[0] = mapSize[0] - selectorSize[0]
    }
    if (y < selectorSize[1] + shiftY)
      pos[1] = y + shiftY

    child.pos = $"{pos[0]}, {pos[1]}"
  }

  function canBeShowed() {
    if (!can_use_aiming_points())
      return false
    let unit = getPlayerCurUnit()
    if (unit == null || !is_player_unit_alive())
      return false
    return true
  }

  function isValid() {
    return this.nestObj?.isValid()
  }
}

function onRightClickAimPoint(params) {
  broadcastEvent("aim_point_right_click", params)
}

function onSelectAimMapPoint(params) {
  broadcastEvent("select_aim_map_point", params)
}

function onAimMemPointStartDrag(params) {
  broadcastEvent("aim_mem_point_start_drag", params)
}

function onAimMemPointStopDrag(params) {
  broadcastEvent("aim_mem_point_stop_drag", params)
}

eventbus_subscribe("aim_mem_point_right_click", onRightClickAimPoint)
eventbus_subscribe("select_aim_map_point", onSelectAimMapPoint)
eventbus_subscribe("aim_mem_point_stop_drag", onAimMemPointStopDrag)
eventbus_subscribe("aim_mem_point_start_drag", onAimMemPointStartDrag)


return {
  MapAimPointWeaponSelector
}