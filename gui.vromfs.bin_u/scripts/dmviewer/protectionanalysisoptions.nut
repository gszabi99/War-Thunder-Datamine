local enums = ::require("sqStdlibs/helpers/enums.nut")
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

local options = {
  types = []
  cache = {
    bySortId = {}
  }

  nestObj = null
  targetUnit = null
  setParams = @(unit) targetUnit = unit
}

local targetTypeToThreatTypes = {
  [::ES_UNIT_TYPE_AIRCRAFT]   = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
  [::ES_UNIT_TYPE_HELICOPTER] = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
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
  shouldInit = false
  shouldInitNext = true
  shouldSetParams = false
  items  = []
  values = []
  value = null
  defValue = null
  valueWidth = null

  isNeedInit = @() shouldInit
  getLabel = @() labelLocId && ::loc(labelLocId)
  getControlMarkup = function() {
    return ::create_option_combobox(id, [], -1, "onChangeOption", true,
      { controlStyle = controlStyle })
  }
  getInfoRows = @() null

  onChange = function(handler, scene, obj) {
    value = getValFromObj(obj)
    if (afterChangeFunc)
      afterChangeFunc(obj)
    if (shouldSetParams)
      options.setAnalysisParams()
    if (shouldInitNext)
      options.getBySortId(sortId + 1).reinit(handler, scene)
  }

  isVisible = @() true
  getValFromObj = @(obj) ::check_obj(obj) ? values?[obj.getValue()] : null
  afterChangeFunc = null
  reinit = @(handler, scene) null

  update = function(handler, scene) {
    local idx = values.indexof(value) ?? -1
    local markup = ::create_option_combobox(null, items, idx, null, false)
    local obj = scene.findObject(id)
    if (::check_obj(obj))
    {
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
      onChange(handler, scene, obj)
    }
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
    shouldInitNext = false
  }
  UNITTYPE = {
    sortId = sortId++
    labelLocId = "mainmenu/threat"
    shouldInit = true
    isVisible = @() getThreatEsUnitTypes().len() > 1

    reinit = function(handler, scene)
    {
      local esUnitTypes = getThreatEsUnitTypes()
      local types = esUnitTypes.map(@(e) unitTypes.getByEsUnitType(e))
      values = esUnitTypes
      items  = ::u.map(types, @(t) { text = "{0} {1}".subst(t.fontIcon, t.getArmyLocName()) })
      local preferredEsUnitType = value ?? options.targetUnit.esUnitType
      value = values.indexof(preferredEsUnitType) != null ? preferredEsUnitType
        : (values?[0] ?? ::ES_UNIT_TYPE_INVALID)
      update(handler, scene)
    }
  }
  COUNTRY = {
    sortId = sortId++
    controlStyle = "iconType:t='small';"
    isNeedInit = @() !options.UNITTYPE.isVisible()
    getLabel = @() options.UNITTYPE.isVisible() ? null : ::loc("mainmenu/threat")

    reinit = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      values = ::u.filter(::shopCountriesList, @(c) ::isCountryHaveUnitType(c, unitType))
      items  = ::u.map(values, @(c) { text = ::loc(c), image = ::get_country_icon(c) })
      local preferredCountry = value ?? options.targetUnit.shopCountry
      value = values.indexof(preferredCountry) != null ? preferredCountry
        : (values?[0] ?? "")
      update(handler, scene)
    }
  }
  RANK = {
    sortId = sortId++

    reinit = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      local country = options.COUNTRY.value
      values = []
      for (local rank = 1; rank <= ::max_country_rank; rank++)
        if (::get_units_count_at_rank(rank, unitType, country, true, false))
          values.append(rank)
      items = ::u.map(values, @(r) {
        text = ::format(::loc("conditions/unitRank/format"), get_roman_numeral(r))
      })
      local preferredRank = value ?? options.targetUnit.rank
      value = values?[::find_nearest(preferredRank, values)] ?? 0
      update(handler, scene)
    }
  }
  UNIT = {
    sortId = sortId++

    reinit = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      local rank = options.RANK.value
      local country = options.COUNTRY.value
      local ediff = ::get_current_ediff()
      local list = ::get_units_list(@(u) u.isVisibleInShop() &&
        u.esUnitType == unitType && u.rank == rank && u.shopCountry == country)
      list = ::u.map(list, @(u) { unit = u, id = u.name, br = u.getBattleRating(ediff) })
      list.sort(@(a, b) a.br <=> b.br)
      values = ::u.map(list, @(v) v.unit)
      items = ::u.map(list, @(v) {
        text  = ::format("[%.1f] %s", v.br, ::getUnitName(v.id))
        image = ::image_for_air(v.unit)
        addDiv = ::g_tooltip_type.UNIT.getMarkup(v.id, { showLocalState = false })
      })
      local targetUnitId = options.targetUnit.name
      local preferredUnitId = value?.name ?? targetUnitId
      value = values.findvalue(@(v) v.name == preferredUnitId) ??
        values.findvalue(@(v) v.name == targetUnitId) ??
        values?[0]
      update(handler, scene)
    }
  }
  BULLET = {
    sortId = sortId++
    labelLocId = "mainmenu/shell"
    shouldSetParams = true
    visibleTypes = [ WEAPON_TYPE.GUNS, WEAPON_TYPE.ROCKETS, WEAPON_TYPE.AGM ]

    reinit = function(handler, scene)
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
            addDiv = ::g_tooltip_type.MODIFICATION.getMarkup(unit.name, value,
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
          local presetBlk = ::DataBlock(block.blk)
          foreach (weap in (presetBlk % "Weapon"))
          {
            if (!weap?.blk || weap?.dummy || ::isInArray(weap.blk, knownWeapBlkArray))
              continue
            knownWeapBlkArray.append(weap.blk)

            local weaponBlkPath = weap.blk
            local weaponBlk = ::DataBlock(weaponBlkPath)
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
              addDiv = ::g_tooltip_type.WEAPON.getMarkup(unit.name, presetName, {
                hasPlayerInfo = false,
                weaponBlkPath = weaponBlkPath,
                shouldShowEffects = false
              })
            })
          }
        }
      }

      value = values?[0]
      update(handler, scene)
    }

    afterChangeFunc = function(obj) {
      updateArmorPiercingText(options.nestObj)
    }
  }
  DISTANCE = {
    sortId = sortId++
    labelLocId = "distance"
    shouldInit = true
    shouldInitNext = false
    shouldSetParams = true
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

    reinit = function(handler, scene) {
      minValue = 0
      maxValue = options.UNIT.value?.isShip() ? 15000 : 5000
      step     = 100
      local preferredDistance = value >= 0 ? value
        : (options.UNIT.value?.isShip() ? 2000 : 500)
      value = ::clamp(preferredDistance, minValue, maxValue)
      update(handler, scene)
    }

    update = function(handler, scene) {
      local obj = scene.findObject(id)
      if (::check_obj(obj))
      {
        obj.max = maxValue
        obj.optionAlign = step
        obj.setValue(value)
        onChange(handler, scene, obj)
      }
    }
  }
})

options.init <- function(handler, scene) {
  nestObj = scene
  foreach (o in options.types)
    o.value = o.defValue
  foreach (o in options.types)
    if (o.isNeedInit())
      o.reinit(handler, scene)
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
