from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")

::hudEnemyDamage <- {
  // HitCamera HUE color range is: 160 (100%hp) - 0 (0%hp).
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
        //"tank_suspension"
        "tank_fuel_tank"
        "ship_engine_room"
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
        "tank_countermeasure"
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

  function init(nest)
  {
    if (!checkObj(nest))
      return

    scene = nest
    guiScene = scene.getScene()
    listObj = scene.findObject("hud_enemy_damage")

    ::g_hud_event_manager.subscribe("EnemyPartDamage", function (damageData) {
        onEnemyPartDamage(damageData)
      }, this)
    ::g_hud_event_manager.subscribe("HitcamTargetKilled", function (hitcamData) {
        onHitcamTargetKilled(hitcamData)
      }, this)

    rebuildWidgets()
    resetTargetData()
    reinit()
  }

  function reinit()
  {
    enabled = ::get_show_destroyed_parts()

    if (checkObj(listObj))
      listObj.pos = ::get_option_xray_kill() ? listObj.posHitcamOn : listObj.posHitcamOff
  }

  function resetTargetData()
  {
    lastTargetId = null
    lastTargetVersion = null
    lastTargetType = ES_UNIT_TYPE_INVALID
    lastTargetKilled = false

    partsConfig = {}
    foreach (sectionIdx, section in partsOrder)
      foreach (partId in section.parts)
        partsConfig[partId] <- {
          section = section.id
          sectionIdx = sectionIdx
          dmParts = {}
          show = false
        }
  }

  function rebuildWidgets()
  {
    if (!checkObj(listObj))
      return

    local markup = ""
    foreach (_sectionIdx, section in partsOrder)
    {
      foreach (partId in section.parts)
        markup += ::handyman.renderCached(("%gui/hud/hudEnemyDamage"), {
          id = partId
          text = loc($"dmg_msg_short/{partId}")
        })
    }
    guiScene.replaceContentFromText(listObj, markup, markup.len(), this)
  }

  function resetWidgets()
  {
    foreach (_sectionIdx, section in partsOrder)
      foreach (partId in section.parts)
        hidePart(partId)
  }

  function onEnemyPartDamage(data)
  {
    if (!enabled || !checkObj(listObj))
      return

    /*
    data {
      unitId - unique unit number
      unitVersion - unit respawn counter
      unitType - unit economic type
      partNo - decimal index of part
      partDmName - string with dm name
      partName - string with localization name
      partHp - float of 0..1 calculated as hp/maxHp
      partDmg - float in range of 0..1 with applied damage
      partDead - bool flag indicating that part was dead before the shot occured
      partKilled - bool flag, true if part was kiled by current shot
    }

    data {
      unitId - unique unit number
      unitVersion - unit respawn counter
      unitType - unit economic type
      unitKilled - bool, true if target has been killed by the current player
    }
    */

    let { unitId, unitVersion, partName = null } = data
    if (unitId != lastTargetId || unitVersion != lastTargetVersion)
    {
      if (!isAllAnimationsFinished())
        resetWidgets()

      resetTargetData()
      lastTargetId = unitId
      lastTargetVersion = unitVersion
      lastTargetType = data?.unitType ?? ES_UNIT_TYPE_INVALID
      lastTargetKilled = data?.unitKilled ?? false
    }
    else
    {
      lastTargetKilled = data?.unitKilled ?? lastTargetKilled
    }

    if (partName == null || (partName not in partsConfig))
      return

    let cfg = partsConfig[partName]
    cfg.dmParts[data.partDmName] <- (cfg.dmParts?[data.partDmName] ?? {}).__merge(data)
    let { partDead = false, partKilled = false, partHp = 1.0, partDmg = 0.0
    } = cfg.dmParts[data.partDmName]
    let showHp = (partDead || partKilled) ? 0.0 : partHp
    cfg.dmParts[data.partDmName].partHp <- showHp

    let isHit = partKilled || partDmg > 0
    let isTank = lastTargetType == ES_UNIT_TYPE_TANK
    let thresholdShowHealthBelow = isTank ? tankThresholdShowHp : 1.0
    let brightnessKill = isTank ? tankBrightnessKill : 0.0
    cfg.show = isHit && showHp < thresholdShowHealthBelow
    if (!cfg.show)
      return

    let value = 1.0 / thresholdShowHealthBelow * showHp
    let hue =  showHp ? (hueHpMin + (hueHpMax - hueHpMin) * value) : hueKill
    let brightness =  showHp ? (brightnessHpMin - (brightnessHpMin - brightnessHpMax) * value) : brightnessKill
    let color = format("#%s", ::get_color_from_hsv(hue, 1, brightness))
    showPart(partName, color, !showHp)
  }

  function onHitcamTargetKilled(params)
  {
    if (::is_multiplayer() || lastTargetKilled)
      return

    let unitId      = getTblValue("unitId", params)
    let unitVersion = getTblValue("unitVersion", params)
    if (unitId == null || unitId != lastTargetId || unitVersion != lastTargetVersion)
      return

    onEnemyPartDamage({
      unitId      = lastTargetId
      unitVersion = lastTargetVersion
      unitType    = lastTargetType
      unitKilled  = true
    })
  }

  function showPart(partId, color, isKilled)
  {
    if (!checkObj(listObj))
      return
    let obj = listObj.findObject(partId)
    if (!checkObj(obj))
      return
    obj.color = color
    obj.partKilled = isKilled ? "yes" : "no"
    obj._blink = "yes"
  }

  function hidePart(partId)
  {
    if (!checkObj(listObj))
      return
    let obj = listObj.findObject(partId)
    if (checkObj(obj) && obj?._blink != "no")
      obj._blink = "no"
  }

  function onEnemyDamageAnimationFinish(obj)
  {
    if (!checkObj(obj))
      return
    if (!(obj?.id in partsConfig))
      return

    let cfg = partsConfig[obj.id]
    cfg.show = false
  }

  function isAllAnimationsFinished()
  {
    foreach (_partName, cfg in partsConfig)
      if (cfg.show)
        return false
    return true
  }
}
