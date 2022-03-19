local { get_blk_value_by_path } = require("sqStdLibs/helpers/datablockUtils.nut")
::hudEnemyDamage <- {
  // HitCamera HUE color range is: 160 (100%hp) - 0 (0%hp).
  thresholdShowHealthBelow = 0.25
  hueHpMax = 60
  hueHpMin = 40
  hueKill  =  0
  brightnessHpMax = 0.6
  brightnessHpMin = 0.75
  brightnessKill  = 1.0
  minAliveCrewCount = 2

  partsOrder = [
    {
      id = "status"
      isStatus = true
      parts = [
        "crew_count"
      ]
    },
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
  lastTargetType = ::ES_UNIT_TYPE_INVALID
  lastTargetKilled = false
  lastTargetCrew = -1
  partsConfig = {}

  listObj   = null

  function init(_nest)
  {
    if (!::checkObj(_nest))
      return

    scene = _nest
    guiScene = scene.getScene()
    listObj = scene.findObject("hud_enemy_damage")

    minAliveCrewCount = getMinAliveCrewCount()

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

    if (::checkObj(listObj))
      listObj.pos = ::get_option_xray_kill() ? listObj.posHitcamOn : listObj.posHitcamOff
  }

  function resetTargetData()
  {
    lastTargetId = null
    lastTargetVersion = null
    lastTargetType = ::ES_UNIT_TYPE_INVALID
    lastTargetKilled = false
    lastTargetCrew = -1

    partsConfig = {}
    foreach (sectionIdx, section in partsOrder)
      if (!::getTblValue("isStatus", section, false))
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
    if (!::check_obj(listObj))
      return

    local markup = ""
    foreach (sectionIdx, section in partsOrder)
    {
      local isStatus = ::getTblValue("isStatus", section, false)
      foreach (partId in section.parts)
        markup += ::handyman.renderCached(("gui/hud/hudEnemyDamage"), {
          id = partId
          text = isStatus ? "" : ::loc("dmg_msg_short/" + partId)
        })
    }
    guiScene.replaceContentFromText(listObj, markup, markup.len(), this)
  }

  function resetWidgets()
  {
    foreach (sectionIdx, section in partsOrder)
      foreach (partId in section.parts)
        hidePart(partId)
  }

  function onEnemyPartDamage(data)
  {
    if (!enabled || !::checkObj(listObj))
      return

    /*
    data {
      unitId - unique unit number
      unitVersion - unit respawn counter
      unitType - unit economic type
      partNo - decimal index of part
      partDmName - string with dm name
      partName - string with localization name
      partHpCur - float of 0..1 calculated as hp/maxHp (may be absent)
      partDmg - float in range of 0..1 with applied damage
      partDead - bool flag indicating that part was dead before the shot occured
      partKilled - bool flag, true if part was kiled by current shot
      crewAliveCount - integer, alive crew members count
      crewTotalCount - integer, total crew members count
    }

    data {
      unitId - unique unit number
      unitVersion - unit respawn counter
      unitType - unit economic type
      unitKilled - bool, true if target has been killed by the current player
    }
    */

    local targetId = ::getTblValue("unitId", data)
    local targetVersion = ::getTblValue("unitVersion", data)
    if (targetId != lastTargetId || targetVersion != lastTargetVersion)
    {
      if (!isAllAnimationsFinished())
        resetWidgets()

      resetTargetData()
      lastTargetId = targetId
      lastTargetVersion = targetVersion
      lastTargetType = ::getTblValue("unitType", data, ::ES_UNIT_TYPE_INVALID)
      lastTargetKilled = ::getTblValue("unitKilled", data, false)
    }
    else
    {
      lastTargetKilled = ::getTblValue("unitKilled", data, lastTargetKilled)
    }

    local partName = ::getTblValue("partName", data)
    if (partName && (partName in partsConfig))
    {
      local cfg = partsConfig[partName]
      if (!(data.partDmName in cfg.dmParts))
        cfg.dmParts[data.partDmName] <- data
      else
      {
        local prevData = cfg.dmParts[data.partDmName]
        foreach (i, v in data)
          prevData[i] <- v
      }

      local showHp = 1.0
      foreach(dmPart in cfg.dmParts)
      {
        local partDead   = ::getTblValue("partDead", dmPart, false)
        local partKilled = ::getTblValue("partKilled", dmPart, false)
        local partHpCur  = ::getTblValue("partHpCur", dmPart, 1.0)
        dmPart.partHp <- (partDead || partKilled) ? 0.0 : partHpCur
        showHp = min(showHp, dmPart.partHp)
      }

      local partKilled = ::getTblValue("partKilled", data, false)
      local partDmg = ::getTblValue("partDmg", data, 0.0)
      local isHit = partKilled || partDmg > 0
      cfg.show = isHit && showHp < thresholdShowHealthBelow

      if (cfg.show)
      {
        local value = 1.0 / thresholdShowHealthBelow * showHp
        local hue =  showHp ? (hueHpMin + (hueHpMax - hueHpMin) * value) : hueKill
        local brightness =  showHp ? (brightnessHpMin - (brightnessHpMin - brightnessHpMax) * value) : brightnessKill
        local color = ::format("#%s", ::get_color_from_hsv(hue, 1, brightness))
        showPart(partName, color, !showHp)
      }

      minAliveCrewCount = ::getTblValue("crewAliveMin", data, minAliveCrewCount)
      local crewCount = ::getTblValue("crewAliveCount", data, -1)
      local crewCountTotal = ::getTblValue("crewTotalCount", data, -1)
      local isCrewChanged = crewCount != -1 && lastTargetCrew != crewCount
      local isShowCrew = !lastTargetKilled && isCrewChanged
        && (lastTargetType == ::ES_UNIT_TYPE_SHIP
          || (!::has_feature("HitCameraTargetStateIconsTank") && cfg.section == "crew" && cfg.show && partKilled))

      if (isShowCrew)
      {
        lastTargetCrew = crewCount

        showPart("crew_count", "#FFFFFF", true)
        local obj = listObj.findObject("crew_count")
        if (::check_obj(obj))
        {
          local text = ::colorize("commonTextColor", ::loc("mainmenu/btnCrew") + ::loc("ui/colon")) +
            ::colorize(crewCount <= minAliveCrewCount ? "warningTextColor" : "activeTextColor", crewCount)
          if (crewCountTotal > 0)
            text += ::colorize("commonTextColor", ::loc("ui/slash")) + ::colorize("activeTextColor", crewCountTotal)
          obj.setValue(text)
        }
      }
    }

    if (lastTargetKilled || lastTargetCrew < minAliveCrewCount)
      hidePart("crew_count")
  }

  function onHitcamTargetKilled(params)
  {
    if (::is_multiplayer() || lastTargetKilled)
      return

    local unitId      = ::getTblValue("unitId", params)
    local unitVersion = ::getTblValue("unitVersion", params)
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
    if (!::checkObj(listObj))
      return
    local obj = listObj.findObject(partId)
    if (!::checkObj(obj))
      return
    obj.color = color
    obj.partKilled = isKilled ? "yes" : "no"
    obj._blink = "yes"
  }

  function hidePart(partId)
  {
    if (!::checkObj(listObj))
      return
    local obj = listObj.findObject(partId)
    if (::checkObj(obj) && obj?._blink != "no")
      obj._blink = "no"
  }

  function onEnemyDamageAnimationFinish(obj)
  {
    if (!::checkObj(obj))
      return
    if (!(obj?.id in partsConfig))
      return

    local cfg = partsConfig[obj.id]
    cfg.show = false
  }

  function isAllAnimationsFinished()
  {
    foreach (partName, cfg in partsConfig)
      if (cfg.show)
        return false
    return true
  }

  function getMinAliveCrewCount()
  {
    local diffCode = ::get_mission_difficulty_int()
    local settingsName = ::g_difficulty.getDifficultyByDiffCode(diffCode).settingsName
    local path = "difficulty_settings/baseDifficulty/" + settingsName + "/changeCrewTime"
    local changeCrewTime = get_blk_value_by_path(::dgs_get_game_params(), path)
    return changeCrewTime != null ? 1 : 2
  }
}
