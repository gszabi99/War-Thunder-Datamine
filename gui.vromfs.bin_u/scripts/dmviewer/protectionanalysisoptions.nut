//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")
let enums = require("%sqStdLibs/helpers/enums.nut")
let stdMath = require("%sqstd/math.nut")
let { WEAPON_TYPE, TRIGGER_TYPE,
        getLinkedGunIdx,
        getWeaponNameByBlkPath } = require("%scripts/weaponry/weaponryInfo.nut")
let { getBulletsList,
        getBulletsSetData,
        getBulletsSearchName,
        getBulletsGroupCount,
        getLastFakeBulletsIndex,
        getModificationBulletsEffect } = require("%scripts/weaponry/bulletsInfo.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { UNIT } = require("%scripts/utils/genericTooltipTypes.nut")
let { SINGLE_WEAPON, MODIFICATION, SINGLE_BULLET } = require("%scripts/weaponry/weaponryTooltips.nut")
let { hasUnitAtRank } = require("%scripts/airInfo.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isCountryHaveUnitType } = require("%scripts/shop/shopUnitsInfo.nut")
let { getUnitWeapons, getWeaponBlkParams } = require("%scripts/weaponry/weaponryPresets.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

local options = {
  types = []
  cache = {
    bySortId = {}
  }

  nestObj = null
  isSaved = false
  targetUnit = null
  setParams = @(unit) this.targetUnit = unit
}

let function updateParamsByUnit(unit, handler, scene) {
  handler.guiScene.setUpdatesEnabled(false, false)
    for (local i = 1; ; i++) {
      let option = options.getBySortId(i)
      if (option == options.UNKNOWN)
        break
      option.updateParamsByUnit(unit, handler, scene)
    }
  handler.guiScene.setUpdatesEnabled(true, true)
}

let targetTypeToThreatTypes = {
  [ES_UNIT_TYPE_AIRCRAFT]   = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER ],
  [ES_UNIT_TYPE_HELICOPTER] = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER ],
  [ES_UNIT_TYPE_TANK] = [ ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_HELICOPTER ],
  [ES_UNIT_TYPE_SHIP] = [ ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_AIRCRAFT ],
  [ES_UNIT_TYPE_BOAT] = [ ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_AIRCRAFT ],
}

let function getThreatEsUnitTypes() {
  let targetUnitType = options.targetUnit.esUnitType
  let res = targetTypeToThreatTypes?[targetUnitType] ?? [ targetUnitType ]
  return res.filter(@(e) unitTypes.getByEsUnitType(e).isAvailable())
}

let function updateDistanceNativeUnitsText(obj) {
  let descObj = obj.findObject("distanceNativeUnitsText")
  if (!checkObj(descObj))
    return
  let distance = options.DISTANCE.value
  let desc = ::g_measure_type.DISTANCE.getMeasureUnitsText(distance)
  descObj.setValue(desc)
}

let function updateArmorPiercingText(obj) {
  let descObj = obj.findObject("armorPiercingText")
  if (!checkObj(descObj))
    return
  local desc = loc("ui/mdash")

  let bullet   = options.BULLET.value
  let distance = options.DISTANCE.value

  if (bullet?.bulletParams?.armorPiercing) {
    local pMin
    local pMax

    for (local i = 0; i < bullet.bulletParams.armorPiercing.len(); i++) {
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

    if (pMin && pMax) {
      let armor = stdMath.lerp(pMin.dist, pMax.dist, pMin.armor, pMax.armor, distance)
      desc = stdMath.round(armor).tointeger() + " " + loc("measureUnits/mm")
    }
  }

  descObj.setValue(desc)
}

local isBulletAvailable = @() options?.BULLET.value != null

let create_empty_combobox = @() "option{pare-text:t='yes' selected:t = 'yes' optiontext{text:t = '#shop/search/global/notFound'}}"

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

  getLabel = @() this.labelLocId && loc(this.labelLocId)
  getControlMarkup = function() {
    return ::create_option_combobox(this.id, [], -1, "onChangeOption", true,
      { controlStyle = this.controlStyle })
  }
  getInfoRows = @() null

  onChange = function(handler, scene, obj) {
    this.value = this.getValFromObj(obj)
    this.afterChangeFunc?(obj)
    this.updateDependentOptions(handler, scene)
    options.setAnalysisParams()
  }

  filterByName = @(_handler, _scene, _name) null

  isVisible = @() true
  needDisabledOnSearch = @() false
  getValFromObj = @(obj) checkObj(obj) ? this.values?[obj.getValue()] : null
  afterChangeFunc = null

  updateDependentOptions = function(handler, scene) {
    handler.guiScene.setUpdatesEnabled(false, false)
    for (local i = this.sortId + 1; ; i++) {
      let option = options.getBySortId(i)
      if (option == options.UNKNOWN)
        break
      option.update(handler, scene)
    }
    handler.guiScene.setUpdatesEnabled(true, true)
  }

  updateParams = @(_handler, _scene) null

  updateParamsByUnit = @(_unit, _handler, _scene) null

  updateView = function(handler, scene) {
    let idx = this.values.indexof(this.value) ?? -1
    let markup = ::create_option_combobox(null, this.items, idx, null, false)
    let obj = scene.findObject(this.id)
    if (checkObj(obj))
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
  }

  update = function(handler, scene, needReset = true) {
    if (needReset)
      this.updateParams(handler, scene)
    this.updateView(handler, scene)
    this.afterChangeFunc?(scene.findObject(this.id))
  }
}

options.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable, null, "id")
  this.types.sort(@(a, b) a.sortId <=> b.sortId)
}

let function addParamsToBulletSet(bSet, bData) {
  foreach (param in ["explosiveType", "explosiveMass"])
    bSet[param] <- bData?[param]

  return bSet
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
    needDisabledOnSearch = @() this.isVisible()

    updateParams = function(_handler, _scene) {
      let esUnitTypes = getThreatEsUnitTypes()
      let types = esUnitTypes.map(@(e) unitTypes.getByEsUnitType(e))
      this.values = esUnitTypes
      this.items  = types.map(@(t) { text = "{0} {1}".subst(t.fontIcon, t.getArmyLocName()) })
      let preferredEsUnitType = this.value ?? options.targetUnit.esUnitType
      this.value = this.values.indexof(preferredEsUnitType) != null ? preferredEsUnitType
        : (this.values?[0] ?? ES_UNIT_TYPE_INVALID)
    }

    updateParamsByUnit = function(unit, _handler, _scene){
      this.value = unit.esUnitType
    }
  }
  COUNTRY = {
    sortId = sortIdCount++
    controlStyle = "iconType:t='small';"
    getLabel = @() options.UNITTYPE.isVisible() ? null : loc("mainmenu/threat")
    needDisabledOnSearch = @() this.isVisible()

    updateParams = function(_handler, _scene) {
      let unitType = options.UNITTYPE.value
      this.values = shopCountriesList.filter(@(c) isCountryHaveUnitType(c, unitType))
      this.items  = this.values.map(@(c) { text = loc(c), image = getCountryIcon(c) })
      let preferredCountry = this.value ?? options.targetUnit.shopCountry
      this.value = this.values.indexof(preferredCountry) != null ? preferredCountry
        : (this.values?[0] ?? "")
    }

    updateParamsByUnit = function(unit, handler, scene){
      if (!this.values.contains(unit.shopCountry)) {
        this.updateParams(handler, scene)
      }
      this.value = unit.shopCountry
    }
  }
  RANK = {
    sortId = sortIdCount++
    needDisabledOnSearch = @() this.isVisible()

    updateParams = function(_handler, _scene) {
      let unitType = options.UNITTYPE.value
      let country = options.COUNTRY.value
      this.values = []
      for (local rank = 1; rank <= ::max_country_rank; rank++)
        if (hasUnitAtRank(rank, unitType, country, true, false))
          this.values.append(rank)
      this.items = this.values.map(@(r) {
        text = format(loc("conditions/unitRank/format"), get_roman_numeral(r))
      })
      let preferredRank = this.value ?? options.targetUnit.rank
      this.value = this.values?[::find_nearest(preferredRank, this.values)] ?? 0
    }

    updateParamsByUnit = function(unit, handler, scene){
      if (!this.values.contains(unit.rank)) {
        this.updateParams(handler, scene)
      }
      this.value = unit.rank
    }
  }
  UNIT = {
    sortId = sortIdCount++

    updateParams = function(_handler, _scene) {
      let unitType = options.UNITTYPE.value
      let rank = options.RANK.value
      let country = options.COUNTRY.value
      let ediff = ::get_current_ediff()
      local list = ::get_units_list(@(unit) unit.esUnitType == unitType
        && unit.shopCountry == country && unit.rank == rank && unit.isVisibleInShop())
      list = list.map(@(unit) { unit, id = unit.name, br = unit.getBattleRating(ediff) })
      list.sort(@(a, b) a.br <=> b.br)
      this.values = list.map(@(v) v.unit)
      this.items = list.map(@(v) {
        text  = format("[%.1f] %s", v.br, getUnitName(v.id))
        image = ::image_for_air(v.unit)
        addDiv = UNIT.getMarkup(v.id, { showLocalState = false })
      })
      let targetUnitId = options.targetUnit.name
      let preferredUnitId = this.value?.name ?? targetUnitId
      this.value = this.values.findvalue(@(v) v.name == preferredUnitId) ??
        this.values.findvalue(@(v) v.name == targetUnitId) ??
        this.values?[0]

      if (this.value == null) // This combination of unitType/country/rank shouldn't be selectable
        script_net_assert_once("protection analysis units list empty", "Protection analysis: Units list empty")
    }

    updateParamsByUnit = function(unit, handler, scene){
      this.updateParams(handler, scene)
      this.value = unit
    }

    filterByName = function(handler, scene, searchStr) {
      let threats = options.UNITTYPE.values
      let list = shopSearchCore.findUnitsByLocName(searchStr)
        .filter(@(unit) threats.contains(unit.esUnitType))
        .map(@(unit) { unit, id = unit.name, unitType = unit.unitType,
          br = unit.getBattleRating(::get_current_ediff()) })
        .sort(@(a, b) a.unitType <=> b.unitType || a.br <=> b.br)
      this.values = list.map(@(v) v.unit)
      this.items = list.map(@(v) {
        text = format("[%.1f] %s", v.br, getUnitName(v.id))
        image = ::image_for_air(v.unit)
        addDiv = UNIT.getMarkup(v.id, { showLocalState = false })
      })
      let targetUnitId = options.targetUnit.name
      let preferredUnitId = this.value?.name ?? targetUnitId
      this.value = this.values.findvalue(@(v) v.name == preferredUnitId) ??
        this.values.findvalue(@(v) v.name == targetUnitId) ??
        this.values?[0]

      this.updateView(handler, scene)
      this.updateDependentOptions(handler, scene)
      options.setAnalysisParams()
    }

    updateView = function(handler, scene) {
      let obj = scene.findObject(this.id)
      if (!checkObj(obj))
        return
      let idx = this.values.indexof(this.value) ?? -1
      let markup = this.items.len() > 0 ? ::create_option_combobox(null, this.items, idx, null, false)
        : create_empty_combobox()
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
    }
  }
  BULLET = {
    sortId = sortIdCount++
    labelLocId = "mainmenu/shell"
    visibleTypes = [ WEAPON_TYPE.GUNS, WEAPON_TYPE.ROCKETS, WEAPON_TYPE.AGM ]

    updateParams = function(_handler, _scene) {
      let unit = options.UNIT.value
      this.values = []
      this.items = []
      let bulletSetData = []
      let bulletNamesSet = []

      local curGunIdx = -1
      let groupsCount = getBulletsGroupCount(unit)

      // Offensive Armament
      for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(unit); groupIndex++) {
        let gunIdx = getLinkedGunIdx(groupIndex, groupsCount, unit.unitType.bulletSetsQuantity, false)
        if (gunIdx == curGunIdx)
          continue

        let bulletsList = getBulletsList(unit.name, groupIndex, {
          needCheckUnitPurchase = false, needOnlyAvailable = false, needTexts = true
        })
        if (bulletsList.values.len())
          curGunIdx = gunIdx

        foreach (i, value in bulletsList.values) {
          let bulletsSet = getBulletsSetData(unit, value)
          let weaponBlkName = bulletsSet?.weaponBlkName
          let isBulletBelt = bulletsSet?.isBulletBelt ?? true

          if (!weaponBlkName)
            continue
          if (this.visibleTypes.indexof(bulletsSet?.weaponType) == null)
            continue

          let searchName = getBulletsSearchName(unit, value)
          let useDefaultBullet = searchName != value
          let bulletParameters = calculate_tank_bullet_parameters(unit.name,
            (useDefaultBullet && weaponBlkName) || getModificationBulletsEffect(searchName),
            useDefaultBullet, false)

          let bulletNames = isBulletBelt ? [] : (bulletsSet?.bulletNames ?? [])
          if (isBulletBelt)
            foreach (t, _data in bulletsSet.bulletDataByType)
              bulletNames.append(t)

          foreach (idx, bulletName in bulletNames) {
            local locName = bulletsList.items[i].text
            local bulletParams = bulletParameters[idx]
            local isDub = false
            if (isBulletBelt) {
              locName = " ".concat(format(loc("caliber/mm"), bulletsSet.caliber),
                loc($"{bulletName}/name/short"))
              let bulletType = bulletName
              bulletParams = bulletParameters.findvalue(@(p) p.bulletType == bulletType)
              // Find bullet dub by params
              isDub = bulletSetData.findvalue(@(p) p.bulletType == bulletType
                && p.mass == bulletParams.mass && p.speed == bulletParams.speed
                && p.armorPiercing[0][0] == bulletParams.armorPiercing[0][0])
              if (!isDub)
                bulletSetData.append(bulletParams)
              // Need change name for the same bullet type but different params
              if (isInArray(locName, bulletNamesSet))
                locName = "".concat(loc($"{bulletName}/name/short"), bulletsList.items[i].text)
            }
            else
              isDub = isInArray(locName, bulletNamesSet)

            if (isDub)
              continue

            local addDiv = ""

            if (isBulletBelt) {
              let bData = bulletsSet.bulletDataByType[bulletName]
              local bSet = bulletsSet.__merge({
                bullets = [bulletName]
                bulletAnimations = bData.bulletAnimations
              })
              addParamsToBulletSet(bSet, bData)

              addDiv = SINGLE_BULLET.getMarkup(unit.name, bulletName, {
                modName = value,
                bSet,
                bulletParams })
            }
            else
              addDiv = MODIFICATION.getMarkup(unit.name, value, { hasPlayerInfo = false })

            bulletNamesSet.append(locName)
            this.values.append({
              bulletName = bulletName || ""
              weaponBlkName = weaponBlkName
              bulletParams = bulletParams
            })

            this.items.append({
              text = locName
              addDiv = addDiv
            })
          }
        }
      }

      // Secondary weapons
      let specialBulletTypes = [ "rocket", "bullet" ]
      if(hasFeature("ProtectionAnalysisShowTorpedoes"))
        specialBulletTypes.append("torpedo")
      if(hasFeature("ProtectionAnalysisShowBombs"))
        specialBulletTypes.append("bomb")

      let unitBlk = unit ? ::get_full_unit_blk(unit.name) : null
      let weapons = getUnitWeapons(unitBlk)
      let knownWeapBlkArray = []

      foreach (weap in weapons) {
        if (!weap?.blk || weap?.dummy || weap.trigger == TRIGGER_TYPE.COUNTERMEASURES
          || isInArray(weap.blk, knownWeapBlkArray))
          continue
        knownWeapBlkArray.append(weap.blk)

        let { weaponBlk, weaponBlkPath } = getWeaponBlkParams(weap.blk, {})
        local curBlk
        local curType

        foreach (t in specialBulletTypes)
          if (weaponBlk?[t]) {
            curBlk = weaponBlk?[t]
            curType = t
            break
          }

        let isBullet = curType == "bullet"
        let locName = utf8ToUpper(
          loc("weapons/{0}".subst(getWeaponNameByBlkPath(weaponBlkPath))), 1)
        if (!curBlk || isInArray(locName, bulletNamesSet))
          continue

        bulletNamesSet.append(locName)
        let bulletParams = calculate_tank_bullet_parameters(unit.name, weaponBlkPath, true, false)?[0]
        this.values.append({
          bulletName = isBullet ? curBlk.bulletType : ""
          weaponBlkName = weaponBlkPath
          bulletParams
          sortVal = curBlk?.caliber ?? 0
        })

        local bSet
        if (isBullet)
          bSet = addParamsToBulletSet({}, curBlk).__merge({
            caliber = (curBlk?.caliber ?? 0) * 1000
            bullets = weaponBlk % "bullet"
            cartridge = 0
            bulletAnimations = [curBlk?.shellAnimation ?? ""]
          })

        this.items.append({
          text = locName
          addDiv = isBullet
            ? SINGLE_BULLET.getMarkup(unit.name, curBlk.bulletType, {
              bSet
              bulletParams
            })
            : SINGLE_WEAPON.getMarkup(unit.name, {
              blkPath = weaponBlkPath
              tType = weap.trigger
              presetName = weap.presetId
            })

        })
      }

      this.value = this.values?[0]
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
      return handyman.renderCached("%gui/dmViewer/distanceSlider.tpl", {
        containerId = "container_" + this.id
        id = this.id
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
        valueWidth = this.valueWidth
        label = loc("bullet_properties/armorPiercing") + loc("ui/colon")
      }]

      if (::g_measure_type.DISTANCE.isMetricSystem() == false)
        res.insert(0, {
        valueId = "distanceNativeUnitsText"
        valueWidth = "fw"
        label = ""
      })

      return res
    }

    getValFromObj = @(obj) checkObj(obj) ? obj.getValue() : 0

    afterChangeFunc = function(obj) {
      let parentObj = obj.getParent().getParent()
      parentObj.findObject("value_" + this.id).setValue(this.value + loc("measureUnits/meters_alt"))
      ::enableBtnTable(parentObj, {
        buttonInc = this.value < this.maxValue
        buttonDec = this.value > this.minValue
      })
      updateDistanceNativeUnitsText(options.nestObj)
      updateArmorPiercingText(options.nestObj)
    }

    updateParams = function(_handler, _scene) {
      this.minValue = 0
      this.maxValue = options.UNIT.value?.isShipOrBoat() ? 15000 : 2000
      this.step     = 100
      let preferredDistance = this.value >= 0 ? this.value
        : (options.UNIT.value?.isShipOrBoat() ? 2000 : 500)
      this.value = clamp(preferredDistance, this.minValue, this.maxValue)
    }

    updateView = function(_handler, scene) {
      let obj = scene.findObject(this.id)
      if (!obj?.isValid())
        return
      let parentObj = obj.getParent().getParent()
      if (isBulletAvailable()) {
        obj.max = this.maxValue
        obj.optionAlign = this.step
        obj.setValue(this.value)
      }
      parentObj.display = isBulletAvailable() ? "show" : "hide"
    }
  }
  //



















































































































})

options.init <- function(handler, scene) {
  this.nestObj = scene
  let needReinit = !this.isSaved
    || !targetTypeToThreatTypes[this.targetUnit.esUnitType].contains(this.UNITTYPE.value)
    || this.UNIT.value == null

  if (needReinit)
    this.types.each(@(o) o.value = o.defValue)
  else
    updateParamsByUnit(this.UNIT.value, handler, scene)

  this.types.each(@(o) o.update(handler, scene, needReinit))
  this.setAnalysisParams()
}


options.setAnalysisParams <- function() {
  let bullet   = options.BULLET.value
  let distance = options.DISTANCE.value
  //




  ::set_protection_checker_params(bullet?.weaponBlkName ?? "", bullet?.bulletName ?? "", distance, 0, 0)
  //
}

options.get <- @(id) this?[id] ?? this.UNKNOWN

options.getBySortId <- function(idx) {
  return enums.getCachedType("sortId", idx, this.cache.bySortId, this, this.UNKNOWN)
}

return options
