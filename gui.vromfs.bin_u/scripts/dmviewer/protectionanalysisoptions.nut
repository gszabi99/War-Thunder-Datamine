local { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
local enums = require("sqStdLibs/helpers/enums.nut")
local stdMath = require("std/math.nut")
local { WEAPON_TYPE,
        getLinkedGunIdx,
        getWeaponNameByBlkPath } = require("scripts/weaponry/weaponryInfo.nut")
local { getBulletsList,
        getBulletsSetData,
        getBulletsSearchName,
        getBulletsGroupCount,
        getLastFakeBulletsIndex,
        getModificationBulletsEffect } = require("scripts/weaponry/bulletsInfo.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { UNIT } = require("scripts/utils/genericTooltipTypes.nut")
local { WEAPON, MODIFICATION } = require("scripts/weaponry/weaponryTooltips.nut")
local { hasUnitAtRank } = require("scripts/airInfo.nut")

local options = {
  types = []
  cache = {
    bySortId = {}
  }

  nestObj = null
  isSaved = false
  targetUnit = null
  setParams = @(unit) targetUnit = unit
}

local targetTypeToThreatTypes = {
  [::ES_UNIT_TYPE_AIRCRAFT]   = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
  [::ES_UNIT_TYPE_HELICOPTER] = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
  [::ES_UNIT_TYPE_TANK] = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
  [::ES_UNIT_TYPE_SHIP] = [ ::ES_UNIT_TYPE_SHIP, ::ES_UNIT_TYPE_BOAT ],
  [::ES_UNIT_TYPE_BOAT] = [ ::ES_UNIT_TYPE_SHIP, ::ES_UNIT_TYPE_BOAT ],
}

local function getThreatEsUnitTypes()
{
  local targetUnitType = options.targetUnit.esUnitType
  local res = targetTypeToThreatTypes?[targetUnitType] ?? [ targetUnitType ]
  return res.filter(@(e) unitTypes.getByEsUnitType(e).isAvailable())
}

local function updateDistanceNativeUnitsText(obj) {
  local descObj = obj.findObject("distanceNativeUnitsText")
  if (!::check_obj(descObj))
    return
  local distance = options.DISTANCE.value
  local desc = ::g_measure_type.DISTANCE.getMeasureUnitsText(distance)
  descObj.setValue(desc)
}

local function updateArmorPiercingText(obj) {
  local descObj = obj.findObject("armorPiercingText")
  if (!::check_obj(descObj))
    return
  local desc = ::loc("ui/mdash")

  local bullet   = options.BULLET.value
  local distance = options.DISTANCE.value

  if (bullet?.bulletParams?.armorPiercing)
  {
    local pMin
    local pMax

    for (local i = 0; i < bullet.bulletParams.armorPiercing.len(); i++)
    {
      local v = {
        armor = bullet.bulletParams.armorPiercing[i]?[0] ?? 0,
        dist  = bullet.bulletParams.armorPiercingDist[i],
      }
      if (!pMin)
        pMin = { armor = v.armor, dist = 0 }
      if (!pMax)
        pMax = pMin
      if (v.dist <= distance)
        pMin = v
      pMax = v
      if (v.dist >= distance)
        break
    }
    if (pMax && pMax.dist < distance)
      pMax.dist = distance

    if (pMin && pMax)
    {
      local armor = stdMath.lerp(pMin.dist, pMax.dist, pMin.armor, pMax.armor, distance)
      desc = stdMath.round(armor).tointeger() + " " + ::loc("measureUnits/mm")
    }
  }

  descObj.setValue(desc)
}

options.template <- {
  id = "" //used from type name
  sortId = 0
  labelLocId = null
  controlStyle = ""
  items  = []
  values = []
  value = null
  defValue = null
  valueWidth = null

  getLabel = @() labelLocId && ::loc(labelLocId)
  getControlMarkup = function() {
    return ::create_option_combobox(id, [], -1, "onChangeOption", true,
      { controlStyle = controlStyle })
  }
  getInfoRows = @() null

  onChange = function(handler, scene, obj) {
    value = getValFromObj(obj)
    afterChangeFunc?(obj)
    updateDependentOptions(handler, scene)
    options.setAnalysisParams()
  }

  isVisible = @() true
  getValFromObj = @(obj) ::check_obj(obj) ? values?[obj.getValue()] : null
  afterChangeFunc = null

  updateDependentOptions = function(handler, scene) {
    handler.guiScene.setUpdatesEnabled(false, false)
    for (local i = sortId + 1;; i++) {
      local option = options.getBySortId(i)
      if (option == options.UNKNOWN)
        break
      option.update(handler, scene)
    }
    handler.guiScene.setUpdatesEnabled(true, true)
  }

  updateParams = @(handler, scene) null

  updateView = function(handler, scene) {
    local idx = values.indexof(value) ?? -1
    local markup = ::create_option_combobox(null, items, idx, null, false)
    local obj = scene.findObject(id)
    if (::check_obj(obj))
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
  }

  update = function(handler, scene, needReset = true) {
    if (needReset)
      updateParams(handler, scene)
    updateView(handler, scene)
    afterChangeFunc?(scene.findObject(id))
  }
}

options.addTypes <- function(typesTable)
{
  enums.addTypes(this, typesTable, null, "id")
  types.sort(@(a, b) a.sortId <=> b.sortId)
}

local sortId = 0
options.addTypes({
  UNKNOWN = {
    sortId = sortId++
    isVisible = @() false
  }
  UNITTYPE = {
    sortId = sortId++
    labelLocId = "mainmenu/threat"
    isVisible = @() getThreatEsUnitTypes().len() > 1

    updateParams = function(handler, scene)
    {
      local esUnitTypes = getThreatEsUnitTypes()
      local types = esUnitTypes.map(@(e) unitTypes.getByEsUnitType(e))
      values = esUnitTypes
      items  = ::u.map(types, @(t) { text = "{0} {1}".subst(t.fontIcon, t.getArmyLocName()) })
      local preferredEsUnitType = value ?? options.targetUnit.esUnitType
      value = values.indexof(preferredEsUnitType) != null ? preferredEsUnitType
        : (values?[0] ?? ::ES_UNIT_TYPE_INVALID)
    }
  }
  COUNTRY = {
    sortId = sortId++
    controlStyle = "iconType:t='small';"
    getLabel = @() options.UNITTYPE.isVisible() ? null : ::loc("mainmenu/threat")

    updateParams = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      values = ::u.filter(::shopCountriesList, @(c) ::isCountryHaveUnitType(c, unitType))
      items  = ::u.map(values, @(c) { text = ::loc(c), image = ::get_country_icon(c) })
      local preferredCountry = value ?? options.targetUnit.shopCountry
      value = values.indexof(preferredCountry) != null ? preferredCountry
        : (values?[0] ?? "")
    }
  }
  RANK = {
    sortId = sortId++

    updateParams = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      local country = options.COUNTRY.value
      values = []
      for (local rank = 1; rank <= ::max_country_rank; rank++)
        if (hasUnitAtRank(rank, unitType, country, true, false))
          values.append(rank)
      items = ::u.map(values, @(r) {
        text = ::format(::loc("conditions/unitRank/format"), get_roman_numeral(r))
      })
      local preferredRank = value ?? options.targetUnit.rank
      value = values?[::find_nearest(preferredRank, values)] ?? 0
    }
  }
  UNIT = {
    sortId = sortId++

    updateParams = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      local rank = options.RANK.value
      local country = options.COUNTRY.value
      local ediff = ::get_current_ediff()
      local list = ::get_units_list(@(u) u.esUnitType == unitType
        && u.shopCountry == country && u.rank == rank && u.isVisibleInShop())
      list = ::u.map(list, @(u) { unit = u, id = u.name, br = u.getBattleRating(ediff) })
      list.sort(@(a, b) a.br <=> b.br)
      values = ::u.map(list, @(v) v.unit)
      items = ::u.map(list, @(v) {
        text  = ::format("[%.1f] %s", v.br, ::getUnitName(v.id))
        image = ::image_for_air(v.unit)
        addDiv = UNIT.getMarkup(v.id, { showLocalState = false })
      })
      local targetUnitId = options.targetUnit.name
      local preferredUnitId = value?.name ?? targetUnitId
      value = values.findvalue(@(v) v.name == preferredUnitId) ??
        values.findvalue(@(v) v.name == targetUnitId) ??
        values?[0]
    }
  }
  BULLET = {
    sortId = sortId++
    labelLocId = "mainmenu/shell"
    visibleTypes = [ WEAPON_TYPE.GUNS, WEAPON_TYPE.ROCKETS, WEAPON_TYPE.AGM ]

    updateParams = function(handler, scene)
    {
      local unit = options.UNIT.value
      values = []
      items = []
      local bulletNamesSet = []

      local curGunIdx = -1
      local groupsCount = getBulletsGroupCount(unit)
      local shouldSkipBulletBelts = false

      for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(unit); groupIndex++)
      {
        local gunIdx = getLinkedGunIdx(groupIndex, groupsCount, unit.unitType.bulletSetsQuantity, false)
        if (gunIdx == curGunIdx)
          continue

        local bulletsList = getBulletsList(unit.name, groupIndex, {
          needCheckUnitPurchase = false, needOnlyAvailable = false, needTexts = true
        })
        if (bulletsList.values.len())
          curGunIdx = gunIdx

        foreach(i, value in bulletsList.values)
        {
          local bulletsSet = getBulletsSetData(unit, value)
          local weaponBlkName = bulletsSet?.weaponBlkName
          local isBulletBelt = bulletsSet?.isBulletBelt ?? true

          if (!weaponBlkName)
            continue
          if (visibleTypes.indexof(bulletsSet?.weaponType) == null)
            continue

          if (shouldSkipBulletBelts && isBulletBelt)
            continue
          shouldSkipBulletBelts = shouldSkipBulletBelts || !isBulletBelt

          local searchName = getBulletsSearchName(unit, value)
          local useDefaultBullet = searchName != value
          local bulletParameters = ::calculate_tank_bullet_parameters(unit.name,
            (useDefaultBullet && weaponBlkName) || getModificationBulletsEffect(searchName),
            useDefaultBullet, false)

          local bulletNames = isBulletBelt ? [] : (bulletsSet?.bulletNames ?? [])
          if (isBulletBelt)
            foreach (params in bulletParameters)
              bulletNames.append(params?.bulletType ?? "")

          local bulletName
          local bulletParams
          local maxPiercing = 0
          foreach (idx, params in bulletParameters)
          {
            local curPiercing = params?.armorPiercing?[0]?[0] ?? 0
            if (maxPiercing < curPiercing)
            {
              bulletName   = bulletNames?[idx]
              bulletParams = params
              maxPiercing  = curPiercing
            }
          }

          local locName = bulletsList.items[i].text
          if(::isInArray(locName, bulletNamesSet))
            continue
          bulletNamesSet.append(locName)

          values.append({
            bulletName = bulletName || ""
            weaponBlkName = weaponBlkName
            bulletParams = bulletParams
          })

          items.append({
            text = bulletsList.items[i]
            addDiv = MODIFICATION.getMarkup(unit.name, value,
              { hasPlayerInfo = false })
          })
        }
      }

      // Collecting special shells
      local specialBulletTypes = [ "rocket" ]
      local unitBlk = ::get_full_unit_blk(unit.name)
      if (unitBlk?.weapon_presets != null)
      {
        local knownWeapBlkArray = []
        foreach (block in (unitBlk.weapon_presets % "preset"))
        {
          local presetName = block.name
          local presetBlk = blkFromPath(block.blk)
          foreach (weap in (presetBlk % "Weapon"))
          {
            if (!weap?.blk || weap?.dummy || ::isInArray(weap.blk, knownWeapBlkArray))
              continue
            knownWeapBlkArray.append(weap.blk)

            local weaponBlkPath = weap.blk
            local weaponBlk = blkFromPath(weaponBlkPath)
            local bulletBlk = null
            foreach (t in specialBulletTypes)
              bulletBlk = bulletBlk ?? weaponBlk?[t]
            if (!bulletBlk)
              continue

            values.append({
              bulletName = ""
              weaponBlkName = weaponBlkPath
              bulletParams = ::calculate_tank_bullet_parameters(unit.name, weaponBlkPath, true, false)?[0]
              sortVal = bulletBlk?.caliber ?? 0
            })

            items.append({
              text = ::g_string.utf8ToUpper(::loc("weapons/{0}".subst(getWeaponNameByBlkPath(weaponBlkPath))), 1)
              addDiv = WEAPON.getMarkup(unit.name, presetName, {
                hasPlayerInfo = false,
                weaponBlkPath = weaponBlkPath,
                shouldShowEffects = false
              })
            })
          }
        }
      }

      value = values?[0]
    }

    afterChangeFunc = function(obj) {
      updateArmorPiercingText(options.nestObj)
    }
  }
  DISTANCE = {
    sortId = sortId++
    labelLocId = "distance"
    value = -1
    defValue = -1
    minValue = -1
    maxValue = -1
    step = 0
    valueWidth = "@dmInfoTextWidth"

    getControlMarkup = function() {
      return ::handyman.renderCached("gui/dmViewer/distanceSlider", {
        containerId = "container_" + id
        id = id
        min = 0
        max = 0
        value = 0
        step = 0
        width = "fw"
        btnOnDec = "onButtonDec"
        btnOnInc = "onButtonInc"
        onChangeSliderValue = "onChangeOption"
      })
    }

    getInfoRows = function() {
      local res = [{
        valueId = "armorPiercingText"
        valueWidth = valueWidth
        label = ::loc("bullet_properties/armorPiercing") + ::loc("ui/colon")
      }]

      if (::g_measure_type.DISTANCE.isMetricSystem() == false)
        res.insert(0, {
        valueId = "distanceNativeUnitsText"
        valueWidth = "fw"
        label = ""
      })

      return res
    }

    getValFromObj = @(obj) ::check_obj(obj) ? obj.getValue() : 0

    afterChangeFunc = function(obj) {
      local parentObj = obj.getParent().getParent()
      parentObj.findObject("value_" + id).setValue(value + ::loc("measureUnits/meters_alt"))
      ::enableBtnTable(parentObj, {
        buttonInc = value < maxValue
        buttonDec = value > minValue
      })
      updateDistanceNativeUnitsText(options.nestObj)
      updateArmorPiercingText(options.nestObj)
    }

    updateParams = function(handler, scene) {
      minValue = 0
      maxValue = options.UNIT.value?.isShipOrBoat() ? 15000 : 5000
      step     = 100
      local preferredDistance = value >= 0 ? value
        : (options.UNIT.value?.isShipOrBoat() ? 2000 : 500)
      value = ::clamp(preferredDistance, minValue, maxValue)
    }

    updateView = function(handler, scene) {
      local obj = scene.findObject(id)
      if (::check_obj(obj))
      {
        obj.max = maxValue
        obj.optionAlign = step
        obj.setValue(value)
      }
    }
  }
})

options.init <- function(handler, scene) {
  nestObj = scene
  local needReinit = !isSaved
    || !targetTypeToThreatTypes[targetUnit.esUnitType].contains(UNITTYPE.value)

  if (needReinit)
    types.each(@(o) o.value = o.defValue)

  types.each(@(o) o.update(handler, scene, needReinit))
  setAnalysisParams()
}

options.setAnalysisParams <- function() {
  local bullet   = options.BULLET.value
  local distance = options.DISTANCE.value
  ::set_protection_checker_params(bullet?.weaponBlkName ?? "", bullet?.bulletName ?? "", distance)
}

options.get <- @(id) this?[id] ?? UNKNOWN

options.getBySortId <- function(idx) {
  return enums.getCachedType("sortId", idx, cache.bySortId, this, UNKNOWN)
}

return options
