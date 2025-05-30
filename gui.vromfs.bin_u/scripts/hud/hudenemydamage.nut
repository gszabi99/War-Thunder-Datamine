from "%scripts/dagui_natives.nut" import get_show_destroyed_parts, get_option_xray_kill
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { eventbus_subscribe } = require("eventbus")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { format } = require("string")
let { getRgbStrFromHsv } = require("colorCorrector")

local hudEnemyDamage = null
hudEnemyDamage = {
  
  tankThresholdShowHp = 0.25
  hueHpMax = 60
  hueHpMin = 0
  hueKill  =  0
  brightnessHpMax = 0.6
  brightnessHpMin = 0.75
  tankBrightnessKill  = 1.0

  partsOrder = [
    {
      id = "crew"
      parts = [
        "tank_commander"
        "tank_driver"
        "tank_gunner"
        "tank_loader"
        "tank_machine_gunner"
        "ship_driver"
        "ship_operator"
        "ship_motorist"
        "ship_sailor"
        "ship_bridge"
        "ship_compartment"
      ]
    },
    {
      id = "movement"
      parts = [
        "tank_engine"
        "tank_transmission"
        "tank_track"
        "tank_radiator"
        "tank_driver_controls"
        "tank_power_system"
        
        "tank_fuel_tank"
        "ship_engine_room"
        "ship_shaft"
        "ship_pump"
        "ship_rudder"
        "ship_steering_gear"
        "ship_funnel"
        "ship_hydrofoil"
        "ship_elevator"
        "ship_fuel_tank"
        "ship_coal_bunker"
      ]
    },
    {
      id = "fire"
      parts = [
        "tank_gun_barrel"
        "tank_cannon_breech"
        "tank_drive_turret_h"
        "tank_drive_turret_v"
        "tank_ammo"
        "tank_autoloader"
        "tank_countermeasure"
        "tank_fire_control_system"
        "tank_electronic_equipment"
        "turret_hydraulics"
        
        "ship_main_caliber_gun"
        "ship_auxiliary_caliber_gun"
        "ship_main_caliber_turret"
        "ship_auxiliary_caliber_turret"
        "ship_aa_gun"
        "ship_machine_gun"
        "ship_torpedo_tube"
        "ship_torpedo"
        "ship_depth_charge"
        "ship_ammunition_storage"
        "ship_ammunition_storage_charges"
        "ship_ammunition_storage_shells"
        "ship_ammunition_storage_aux"
        "ship_ammo"
      ]
    },
  ]

  scene     = null
  guiScene  = null

  enabled = true
  lastTargetId = null
  lastTargetVersion = null
  lastTargetType = ES_UNIT_TYPE_INVALID
  lastTargetKilled = false
  partsConfig = {}

  listObj   = null

  function init(nest) {
    if (!checkObj(nest))
      return

    this.scene = nest
    this.guiScene = this.scene.getScene()
    this.listObj = this.scene.findObject("hud_enemy_damage")

    eventbus_subscribe("EnemyPartsDamage", function(allDamageData) {
        foreach (damageData in allDamageData) {
          hudEnemyDamage.onEnemyPartDamage(damageData)
        }
      })
    g_hud_event_manager.subscribe("HitcamTargetKilled", function (hitcamData) {
        this.onHitcamTargetKilled(hitcamData)
      }, this)

    this.rebuildWidgets()
    this.resetTargetData()
    this.reinit()
  }

  function reinit() {
    this.enabled = get_show_destroyed_parts()

    if (checkObj(this.listObj))
      this.listObj.pos = get_option_xray_kill() ? this.listObj.posHitcamOn : this.listObj.posHitcamOff
  }

  function resetTargetData() {
    this.lastTargetId = null
    this.lastTargetVersion = null
    this.lastTargetType = ES_UNIT_TYPE_INVALID
    this.lastTargetKilled = false

    this.partsConfig = {}
    foreach (sectionIdx, section in this.partsOrder)
      foreach (partId in section.parts)
        this.partsConfig[partId] <- {
          section = section.id
          sectionIdx = sectionIdx
          dmParts = {}
          show = false
        }
  }

  function rebuildWidgets() {
    if (!checkObj(this.listObj))
      return

    local markup = ""
    foreach (_sectionIdx, section in this.partsOrder) {
      foreach (partId in section.parts)
        markup = "".concat(markup, handyman.renderCached(("%gui/hud/hudEnemyDamage.tpl"), {
          id = partId
          text = loc($"dmg_msg_short/{partId}")
        }))
    }
    this.guiScene.replaceContentFromText(this.listObj, markup, markup.len(), this)
  }

  function resetWidgets() {
    foreach (_sectionIdx, section in this.partsOrder)
      foreach (partId in section.parts)
        this.hidePart(partId)
  }

  function onEnemyPartDamage(data) {
    if (!this.enabled || !checkObj(this.listObj))
      return

    





















    let { unitId, unitVersion, partName = null } = data
    if (unitId != this.lastTargetId || unitVersion != this.lastTargetVersion) {
      if (!this.isAllAnimationsFinished())
        this.resetWidgets()

      this.resetTargetData()
      this.lastTargetId = unitId
      this.lastTargetVersion = unitVersion
      this.lastTargetType = data?.unitType ?? ES_UNIT_TYPE_INVALID
      this.lastTargetKilled = data?.unitKilled ?? false
    }
    else {
      this.lastTargetKilled = data?.unitKilled ?? this.lastTargetKilled
    }

    if (partName == null || (partName not in this.partsConfig))
      return

    let cfg = this.partsConfig[partName]
    cfg.dmParts[data.partDmName] <- (cfg.dmParts?[data.partDmName] ?? {}).__merge(data)
    let { partDead = false, partKilled = false, partHp = 1.0, partDmg = 0.0
    } = cfg.dmParts[data.partDmName]
    let showHp = (partDead || partKilled) ? 0.0 : partHp
    cfg.dmParts[data.partDmName].partHp <- showHp

    let isHit = partKilled || partDmg > 0
    let isTank = this.lastTargetType == ES_UNIT_TYPE_TANK
    let thresholdShowHealthBelow = isTank ? this.tankThresholdShowHp : 1.0
    let brightnessKill = isTank ? this.tankBrightnessKill : 0.0
    cfg.show = isHit && showHp < thresholdShowHealthBelow
    if (!cfg.show)
      return

    let value = 1.0 / thresholdShowHealthBelow * showHp
    let hue =  showHp ? (this.hueHpMin + (this.hueHpMax - this.hueHpMin) * value) : this.hueKill
    let brightness =  showHp ? (this.brightnessHpMin - (this.brightnessHpMin - this.brightnessHpMax) * value) : brightnessKill
    let color = format("#%s", getRgbStrFromHsv(hue, 1, brightness))
    this.showPart(partName, color, !showHp)
  }

  function onHitcamTargetKilled(params) {
    if (is_multiplayer() || this.lastTargetKilled)
      return

    let unitId      = getTblValue("unitId", params)
    let unitVersion = getTblValue("unitVersion", params)
    if (unitId == null || unitId != this.lastTargetId || unitVersion != this.lastTargetVersion)
      return

    this.onEnemyPartDamage({
      unitId      = this.lastTargetId
      unitVersion = this.lastTargetVersion
      unitType    = this.lastTargetType
      unitKilled  = true
    })
  }

  function showPart(partId, color, isKilled) {
    if (!checkObj(this.listObj))
      return
    let obj = this.listObj.findObject(partId)
    if (!checkObj(obj))
      return
    obj.color = color
    obj.partKilled = isKilled ? "yes" : "no"
    obj._blink = "yes"
  }

  function hidePart(partId) {
    if (!checkObj(this.listObj))
      return
    let obj = this.listObj.findObject(partId)
    if (checkObj(obj) && obj?._blink != "no")
      obj._blink = "no"
  }

  function onEnemyDamageAnimationFinish(obj) {
    if (!checkObj(obj))
      return
    if (!(obj?.id in this.partsConfig))
      return

    let cfg = this.partsConfig[obj.id]
    cfg.show = false
  }

  function isAllAnimationsFinished() {
    foreach (_partName, cfg in this.partsConfig)
      if (cfg.show)
        return false
    return true
  }
}

return hudEnemyDamage