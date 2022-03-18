let { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
let enums = require("sqStdLibs/helpers/enums.nut")
let stdMath = require("std/math.nut")
let { WEAPON_TYPE,
        getLinkedGunIdx,
        getWeaponNameByBlkPath } = require("scripts/weaponry/weaponryInfo.nut")
let { getBulletsList,
        getBulletsSetData,
        getBulletsSearchName,
        getBulletsGroupCount,
        getLastFakeBulletsIndex,
        getModificationBulletsEffect } = require("scripts/weaponry/bulletsInfo.nut")
let unitTypes = require("scripts/unit/unitTypesList.nut")
let { UNIT } = require("scripts/utils/genericTooltipTypes.nut")
let { WEAPON, MODIFICATION, SINGLE_BULLET } = require("scripts/weaponry/weaponryTooltips.nut")
let { hasUnitAtRank } = require("scripts/airInfo.nut")
let { shopCountriesList } = require("scripts/shop/shopCountriesList.nut")
let { isCountryHaveUnitType } = require("scripts/shop/shopUnitsInfo.nut")
let { getUnitWeapons } = require("scripts/weaponry/weaponryPresets.nut")

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

let targetTypeToThreatTypes = {
  [::ES_UNIT_TYPE_AIRCRAFT]   = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
  [::ES_UNIT_TYPE_HELICOPTER] = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
  [::ES_UNIT_TYPE_TANK] = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
  [::ES_UNIT_TYPE_SHIP] = [ ::ES_UNIT_TYPE_SHIP, ::ES_UNIT_TYPE_BOAT ],
  [::ES_UNIT_TYPE_BOAT] = [ ::ES_UNIT_TYPE_SHIP, ::ES_UNIT_TYPE_BOAT ],
}

let function getThreatEsUnitTypes()
{
  let targetUnitType = options.targetUnit.esUnitType
  let res = targetTypeToThreatTypes?[targetUnitType] ?? [ targetUnitType ]
  return res.filter(@(e) unitTypes.getByEsUnitType(e).isAvailable())
}

let function updateDistanceNativeUnitsText(obj) {
  let descObj = obj.findObject("distanceNativeUnitsText")
  if (!::check_obj(descObj))
    return
  let distance = options.DISTANCE.value
  let desc = ::g_measure_type.DISTANCE.getMeasureUnitsText(distance)
  descObj.setValue(desc)
}

let function updateArmorPiercingText(obj) {
  let descObj = obj.findObject("armorPiercingText")
  if (!::check_obj(descObj))
    return
  local desc = ::loc("ui/mdash")

  let bullet   = options.BULLET.value
  let distance = options.DISTANCE.value

  if (bullet?.bulletParams?.armorPiercing)
  {
    local pMin
    local pMax

    for (local i = 0; i < bullet.bulletParams.armorPiercing.len(); i++)
    {
      let v = {
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
      let armor = stdMath.lerp(pMin.dist, pMax.dist, pMin.armor, pMax.armor, distance)
      desc = stdMath.round(armor).tointeger() + " " + ::loc("measureUnits/mm")
    }
  }

  descObj.setValue(desc)
}

local isBulletAvailable = @() options?.BULLET.value != null

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
      let option = options.getBySortId(i)
      if (option == options.UNKNOWN)
        break
      option.update(handler, scene)
    }
    handler.guiScene.setUpdatesEnabled(true, true)
  }

  updateParams = @(handler, scene) null

  updateView = function(handler, scene) {
    let idx = values.indexof(value) ?? -1
    let markup = ::create_option_combobox(null, items, idx, null, false)
    let obj = scene.findObject(id)
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

local sortIdCount = 0
options.addTypes({
  UNKNOWN = {
    sortId = sortIdCount++
    isVisible = @() false
  }
  UNITTYPE = {
    sortId = sortIdCount++
    labelLocId = "mainmenu/threat"
    isVisible = @() getThreatEsUnitTypes().len() > 1

    updateParams = function(handler, scene)
    {
      let esUnitTypes = getThreatEsUnitTypes()
      let types = esUnitTypes.map(@(e) unitTypes.getByEsUnitType(e))
      values = esUnitTypes
      items  = ::u.map(types, @(t) { text = "{0} {1}".subst(t.fontIcon, t.getArmyLocName()) })
      let preferredEsUnitType = value ?? options.targetUnit.esUnitType
      value = values.indexof(preferredEsUnitType) != null ? preferredEsUnitType
        : (values?[0] ?? ::ES_UNIT_TYPE_INVALID)
    }
  }
  COUNTRY = {
    sortId = sortIdCount++
    controlStyle = "iconType:t='small';"
    getLabel = @() options.UNITTYPE.isVisible() ? null : ::loc("mainmenu/threat")

    updateParams = function(handler, scene)
    {
      let unitType = options.UNITTYPE.value
      values = ::u.filter(shopCountriesList, @(c) isCountryHaveUnitType(c, unitType))
      items  = ::u.map(values, @(c) { text = ::loc(c), image = ::get_country_icon(c) })
      let preferredCountry = value ?? options.targetUnit.shopCountry
      value = values.indexof(preferredCountry) != null ? preferredCountry
        : (values?[0] ?? "")
    }
  }
  RANK = {
    sortId = sortIdCount++

    updateParams = function(handler, scene)
    {
      let unitType = options.UNITTYPE.value
      let country = options.COUNTRY.value
      values = []
      for (local rank = 1; rank <= ::max_country_rank; rank++)
        if (hasUnitAtRank(rank, unitType, country, true, false))
          values.append(rank)
      items = ::u.map(values, @(r) {
        text = ::format(::loc("conditions/unitRank/format"), get_roman_numeral(r))
      })
      let preferredRank = value ?? options.targetUnit.rank
      value = values?[::find_nearest(preferredRank, values)] ?? 0
    }
  }
  UNIT = {
    sortId = sortIdCount++

    updateParams = function(handler, scene)
    {
      let unitType = options.UNITTYPE.value
      let rank = options.RANK.value
      let country = options.COUNTRY.value
      let ediff = ::get_current_ediff()
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
      let targetUnitId = options.targetUnit.name
      let preferredUnitId = value?.name ?? targetUnitId
      value = values.findvalue(@(v) v.name == preferredUnitId) ??
        values.findvalue(@(v) v.name == targetUnitId) ??
        values?[0]

      if (value == null) // This combination of unitType/country/rank shouldn't be selectable
        ::script_net_assert_once("protection analysis units list empty", "Protection analysis: Units list empty")
    }
  }
  BULLET = {
    sortId = sortIdCount++
    labelLocId = "mainmenu/shell"
    visibleTypes = [ WEAPON_TYPE.GUNS, WEAPON_TYPE.ROCKETS, WEAPON_TYPE.AGM ]

    updateParams = function(handler, scene)
    {
      let unit = options.UNIT.value
      values = []
      items = []
      let bulletSetData = []
      let bulletNamesSet = []

      local curGunIdx = -1
      let groupsCount = getBulletsGroupCount(unit)

      for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(unit); groupIndex++)
      {
        let gunIdx = getLinkedGunIdx(groupIndex, groupsCount, unit.unitType.bulletSetsQuantity, false)
        if (gunIdx == curGunIdx)
          continue

        let bulletsList = getBulletsList(unit.name, groupIndex, {
          needCheckUnitPurchase = false, needOnlyAvailable = false, needTexts = true
        })
        if (bulletsList.values.len())
          curGunIdx = gunIdx

        foreach(i, value in bulletsList.values)
        {
          let bulletsSet = getBulletsSetData(unit, value)
          let weaponBlkName = bulletsSet?.weaponBlkName
          let isBulletBelt = bulletsSet?.isBulletBelt ?? true

          if (!weaponBlkName)
            continue
          if (visibleTypes.indexof(bulletsSet?.weaponType) == null)
            continue

          let searchName = getBulletsSearchName(unit, value)
          let useDefaultBullet = searchName != value
          let bulletParameters = ::calculate_tank_bullet_parameters(unit.name,
            (useDefaultBullet && weaponBlkName) || getModificationBulletsEffect(searchName),
            useDefaultBullet, false)

          let bulletNames = isBulletBelt ? [] : (bulletsSet?.bulletNames ?? [])
          if (isBulletBelt)
            foreach(t, data in bulletsSet.bulletDataByType)
              bulletNames.append(t)

          foreach (idx, bulletName in bulletNames)
          {
            local locName = bulletsList.items[i].text
            local bulletParams = bulletParameters[idx]
            local isDub = false
            if (isBulletBelt)
            {
              locName = " ".concat(::format(::loc("caliber/mm"), bulletsSet.caliber),
                ::loc($"{bulletName}/name/short"))
              let bulletType = bulletName
              bulletParams = bulletParameters.findvalue(@(p) p.bulletType == bulletType)
              // Find bullet dub by params
              isDub = bulletSetData.findvalue(@(p) p.bulletType == bulletType && p.mass == bulletParams.mass
                && p.speed == bulletParams.speed)
              if(!isDub)
                bulletSetData.append(bulletParams)
              // Need change name for the same bullet type but different params
              if(::isInArray(locName, bulletNamesSet))
                locName = $"{locName}{bulletsList.items[i].text}"
            }
            else
              isDub = ::isInArray(locName, bulletNamesSet)

            if (isDub)
              continue

            let addDiv = isBulletBelt
              ? SINGLE_BULLET.getMarkup(unit.name, bulletName, {
                modName = value,
                //Generate set of identical bullets by getting rid of all bullets excluding current.
                bSet = (clone bulletsSet).map(
                  @(val, p) p == "bullets"
                    ? [bulletName]
                    : (p != "bulletNames" && p != "bulletDataByType"
                      && p != "explosiveType" && p != "explosiveMass")
                        ? val
                        : bulletsSet.bulletDataByType[bulletName]?[p]).filter(@(p) p != null),
                bulletParams })
              : MODIFICATION.getMarkup(unit.name, value, { hasPlayerInfo = false })

            bulletNamesSet.append(locName)
            values.append({
              bulletName = bulletName || ""
              weaponBlkName = weaponBlkName
              bulletParams = bulletParams
            })

            items.append({
              text = locName
              addDiv = addDiv
            })
          }
        }
      }

      // Collecting special shells
      let specialBulletTypes = [ "rocket" ]
      let unitBlk = unit ? ::get_full_unit_blk(unit.name) : null
      let weapons = getUnitWeapons(unitBlk)
      let knownWeapBlkArray = []
      foreach (weap in weapons)
      {
        if (!weap?.blk || weap?.dummy || ::isInArray(weap.blk, knownWeapBlkArray))
          continue
        knownWeapBlkArray.append(weap.blk)

        let weaponBlkPath = weap.blk
        let weaponBlk = blkFromPath(weaponBlkPath)
        local bulletBlk = null
        foreach (t in specialBulletTypes)
          bulletBlk = bulletBlk ?? weaponBlk?[t]

        let locName = ::g_string.utf8ToUpper(
          ::loc("weapons/{0}".subst(getWeaponNameByBlkPath(weaponBlkPath))), 1)
        if (!bulletBlk || ::isInArray(locName, bulletNamesSet))
          continue

        bulletNamesSet.append(locName)
        values.append({
          bulletName = ""
          weaponBlkName = weaponBlkPath
          bulletParams = ::calculate_tank_bullet_parameters(unit.name, weaponBlkPath, true, false)?[0]
          sortVal = bulletBlk?.caliber ?? 0
        })

        items.append({
          text = locName
          addDiv = WEAPON.getMarkup(unit.name, weap.presetId, {
            hasPlayerInfo = false,
            weaponBlkPath = weaponBlkPath,
            shouldShowEffects = false
          })
        })
      }

      value = values?[0]
    }

    afterChangeFunc = function(obj) {
      updateArmorPiercingText(options.nestObj)
      let parentObj = obj.getParent().getParent()
      if (!parentObj?.isValid())
        return

      parentObj.display = isBulletAvailable() ? "show" : "hide"
    }
  }
  DISTANCE = {
    sortId = sortIdCount++
    labelLocId = "distance"
    value = -1
    defValue = -1
    minValue = -1
    maxValue = -1
    step = 0
    valueWidth = "@dmInfoTextWidth"

    getControlMarkup = function() {
      return ::handyman.renderCached("%gui/dmViewer/distanceSlider", {
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
      let res = [{
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
      let parentObj = obj.getParent().getParent()
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
      let preferredDistance = value >= 0 ? value
        : (options.UNIT.value?.isShipOrBoat() ? 2000 : 500)
      value = ::clamp(preferredDistance, minValue, maxValue)
    }

    updateView = function(handler, scene) {
      let obj = scene.findObject(id)
      if (!obj?.isValid())
        return
      let parentObj = obj.getParent().getParent()
      if (isBulletAvailable()) {
        obj.max = maxValue
        obj.optionAlign = step
        obj.setValue(value)
      }
      parentObj.display = isBulletAvailable() ? "show" : "hide"
    }
  }
})

options.init <- function(handler, scene) {
  nestObj = scene
  let needReinit = !isSaved
    || !targetTypeToThreatTypes[targetUnit.esUnitType].contains(UNITTYPE.value)

  if (needReinit)
    types.each(@(o) o.value = o.defValue)

  types.each(@(o) o.update(handler, scene, needReinit))
  setAnalysisParams()
}

options.setAnalysisParams <- function() {
  let bullet   = options.BULLET.value
  let distance = options.DISTANCE.value
  ::set_protection_checker_params(bullet?.weaponBlkName ?? "", bullet?.bulletName ?? "", distance)
}

options.get <- @(id) this?[id] ?? UNKNOWN

options.getBySortId <- function(idx) {
  return enums.getCachedType("sortId", idx, cache.bySortId, this, UNKNOWN)
}

return options
