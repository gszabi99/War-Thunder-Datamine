from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import findNearest
from "%scripts/options/optionsCtors.nut" import create_option_combobox, create_empty_combobox

let { getUnitName, image_for_air } = require("%scripts/unit/unitInfo.nut")
let { format } = require("string")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { WEAPON_TYPE, TRIGGER_TYPE, getWeaponNameByBlkPath
} = require("%scripts/weaponry/weaponryInfo.nut")
let { getBulletsList, getLinkedGunIdx, getBulletsSetData, getBulletsSearchName,
  getBulletsGroupCount, getLastFakeBulletsIndex, getModificationBulletsEffect
} = require("%scripts/weaponry/bulletsInfo.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { SINGLE_WEAPON, MODIFICATION, SINGLE_BULLET } = require("%scripts/weaponry/weaponryTooltips.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isCountryHaveUnitType, hasUnitAtRank, get_units_list } = require("%scripts/shop/shopCountryInfo.nut")
let { getUnitWeapons, getWeaponBlkParams } = require("%scripts/weaponry/weaponryPresets.nut")
let { utf8Capitalize } = require("%sqstd/string.nut")
let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { getBulletsIconView } = require("%scripts/weaponry/bulletsVisual.nut")

let options = {
  types = []
  cache = {
    bySortId = {}
  }

  nestObj = null
  targetUnit = null
  targetAmmo = null
  function setParams(unit, ammo = null, _distance = null) {
    this.targetUnit = unit
    this.targetAmmo = ammo
  }

  get = @(id) this?[id] ?? this.UNKNOWN
  getBySortId = @(idx) enums.getCachedType("sortId", idx, this.cache.bySortId, this, this.UNKNOWN)

  function addTypes(typesTable) {
    enums.addTypes(this, typesTable, null, "id")
    this.types.sort(@(a, b) a.sortId <=> b.sortId)
  }
}

function updateParamsByUnit(unit, handler) {
  handler.guiScene.setUpdatesEnabled(false, false)
  for (local i = 1; ; i++) {
    let option = options.getBySortId(i)
    if (option == options.UNKNOWN)
      break
    option.updateParamsByUnit(unit)
  }
  handler.guiScene.setUpdatesEnabled(true, true)
}

let threatEsUnitTypes = [ ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT, ES_UNIT_TYPE_HELICOPTER, ES_UNIT_TYPE_AIRCRAFT ]

let isBulletAvailable = @() options?.BULLET.value != null

options.template <- {
  id = "" 
  sortId = 0
  labelLocId = null
  controlStyle = ""
  items  = []
  values = []
  value = null
  defValue = null
  valueWidth = null

  getLabel = @() this.labelLocId && loc(this.labelLocId)
  function getControlMarkup() {
    return create_option_combobox(this.id, [], -1, "onChangeOption", true,
      { controlStyle = this.controlStyle })
  }
  getInfoRows = @() null

  function onChange(handler, scene, obj) {
    this.value = this.getValFromObj(obj)
    this.afterChangeFunc?(scene, obj)
    this.updateDependentOptions(handler, scene)
  }

  filterByName = @(_handler, _scene, _name) null

  isVisible = @() true
  needDisabledOnSearch = @() false
  getValFromObj = @(obj) obj?.isValid() ? this.values?[obj.getValue()] : null
  afterChangeFunc = null

  function updateDependentOptions(handler, scene) {
    handler.guiScene.setUpdatesEnabled(false, false)
    for (local i = this.sortId + 1; ; i++) {
      let option = options.getBySortId(i)
      if (option == options.UNKNOWN)
        break
      option.update(handler, scene)
    }
    handler.guiScene.setUpdatesEnabled(true, true)
  }

  updateParams = @() null

  updateParamsByUnit = @(_unit) null

  function updateView(handler, scene) {
    let idx = this.values.indexof(this.value) ?? -1
    let markup = create_option_combobox(null, this.items, idx, null, false)
    let obj = scene.findObject(this.id)
    if (obj?.isValid())
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
  }

  function update(handler, scene, needReset = true) {
    if (needReset)
      this.updateParams()
    this.updateView(handler, scene)
    this.afterChangeFunc?(scene, scene.findObject(this.id))
  }
}

function addParamsToBulletSet(bSet, bData) {
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
    needDisabledOnSearch = @() this.isVisible()

    function updateParams() {
      let esUnitTypes = clone threatEsUnitTypes
      let types = esUnitTypes.map(@(e) unitTypes.getByEsUnitType(e))
      this.values = esUnitTypes
      this.items  = types.map(@(t) { text = "{0} {1}".subst(t.fontIcon, t.getArmyLocName()) })
      let preferredEsUnitType = this.value ?? options.targetUnit.esUnitType
      this.value = this.values.indexof(preferredEsUnitType) != null ? preferredEsUnitType
        : (this.values?[0] ?? ES_UNIT_TYPE_INVALID)
    }

    updateParamsByUnit = @(unit) this.value = unit.esUnitType
  }
  COUNTRY = {
    sortId = sortIdCount++
    controlStyle = "iconType:t='country_small';"
    getLabel = @() options.UNITTYPE.isVisible() ? null : loc("mainmenu/threat")
    needDisabledOnSearch = @() this.isVisible()

    function updateParams() {
      let unitType = options.UNITTYPE.value
      this.values = shopCountriesList.filter(@(c) isCountryHaveUnitType(c, unitType))
      this.items  = this.values.map(@(c) { text = loc(c), image = getCountryIcon(c) })
      let preferredCountry = this.value ?? options.targetUnit.shopCountry
      this.value = this.values.indexof(preferredCountry) != null ? preferredCountry
        : (this.values?[0] ?? "")
    }

    function updateParamsByUnit(unit) {
      if (!this.values.contains(unit.shopCountry)) {
        this.updateParams()
      }
      this.value = unit.shopCountry
    }
  }
  RANK = {
    sortId = sortIdCount++
    needDisabledOnSearch = @() this.isVisible()

    function updateParams() {
      let unitType = options.UNITTYPE.value
      let country = options.COUNTRY.value
      this.values = []
      for (local rank = 1; rank <= MAX_COUNTRY_RANK; rank++)
        if (hasUnitAtRank(rank, unitType, country, true, false))
          this.values.append(rank)
      this.items = this.values.map(@(r) {
        text = format(loc("conditions/unitRank/format"), get_roman_numeral(r))
      })
      let preferredRank = this.value ?? options.targetUnit.rank
      this.value = this.values?[findNearest(preferredRank, this.values)] ?? 0
    }

    function updateParamsByUnit(unit) {
      if (!this.values.contains(unit.rank))
        this.updateParams()
      this.value = unit.rank
    }
  }
  UNIT = {
    sortId = sortIdCount++

    function updateParams() {
      let unitType = options.UNITTYPE.value
      let rank = options.RANK.value
      let country = options.COUNTRY.value
      let ediff = getCurrentGameModeEdiff()
      local list = get_units_list(@(unit) unit.esUnitType == unitType
        && unit.shopCountry == country && unit.rank == rank && unit.isVisibleInShop())
      list = list.map(@(unit) { unit, id = unit.name, br = unit.getBattleRating(ediff) })
      list.sort(@(a, b) a.br <=> b.br)
      this.values = list.map(@(v) v.unit)
      this.items = list.map(@(v) {
        text  = format("[%.1f] %s", v.br, getUnitName(v.id))
        image = image_for_air(v.unit)
        addDiv = getTooltipType("UNIT").getMarkup(v.id, { showLocalState = false })
      })
      let targetUnitId = options.targetUnit.name
      let preferredUnitId = this.value?.name ?? targetUnitId
      this.value = this.values.findvalue(@(v) v.name == preferredUnitId)
        ?? this.values.findvalue(@(v) v.name == targetUnitId)
        ?? this.values?[0]

      if (this.value == null) 
        script_net_assert_once("protection analysis units list empty", "Protection analysis: Units list empty")
    }

    function updateParamsByUnit(unit) {
      this.updateParams()
      this.value = unit
    }

    function filterByName(handler, scene, searchStr) {
      let threats = options.UNITTYPE.values
      let list = shopSearchCore.findUnitsByLocName(searchStr)
        .filter(@(unit) threats.contains(unit.esUnitType))
        .map(@(unit) { unit, id = unit.name, unitType = unit.unitType.esUnitType,
          br = unit.getBattleRating(getCurrentGameModeEdiff()) })
        .sort(@(a, b) a.unitType <=> b.unitType || a.br <=> b.br)
      this.values = list.map(@(v) v.unit)
      this.items = list.map(@(v) {
        text = format("[%.1f] %s", v.br, getUnitName(v.id))
        image = image_for_air(v.unit)
        addDiv = getTooltipType("UNIT").getMarkup(v.id, { showLocalState = false })
      })
      let targetUnitId = options.targetUnit.name
      let preferredUnitId = this.value?.name ?? targetUnitId
      this.value = this.values.findvalue(@(v) v.name == preferredUnitId)
        ?? this.values.findvalue(@(v) v.name == targetUnitId)
        ?? this.values?[0]

      this.updateView(handler, scene)
      this.updateDependentOptions(handler, scene)
    }

    function updateView(handler, scene) {
      let obj = scene.findObject(this.id)
      if (!obj?.isValid())
        return
      let idx = this.values.indexof(this.value) ?? -1
      let markup = this.items.len() > 0 ? create_option_combobox(null, this.items, idx, null, false)
        : create_empty_combobox()
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
    }
  }
  BULLET = {
    sortId = sortIdCount++
    labelLocId = "mainmenu/shell"
    visibleTypes = [ WEAPON_TYPE.GUNS, WEAPON_TYPE.ROCKETS, WEAPON_TYPE.AGM ]

    function updateView(handler, scene) {
      let obj = scene.findObject(this.id)
      if (!obj?.isValid())
        return

      let idx = this.values.indexof(this.value) ?? -1
      let markup = create_option_combobox(null, this.items, idx, null, false)

      obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)

      let needShowControlTooltip = this.items.len() == 1
      let tooltip = this.items?[0].addDiv
      let parent = obj.getParent()

      if (needShowControlTooltip && tooltip) {
        scene.getScene().prependWithBlk(parent, tooltip, handler)
        parent.title="$tooltipObj"
      }
      else
        parent.title = ""
    }

    function updateParams() {
      let unit = options.UNIT.value
      this.values = []
      this.items = []
      let bulletSetData = []
      let bulletNamesSet = []

      if (unit == null) {
        this.value = null
        return
      }

      local curGunIdx = -1
      local selectedIndex = 0
      let groupsCount = getBulletsGroupCount(unit)

      
      for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(unit); groupIndex++) {
        let gunIdx = getLinkedGunIdx(groupIndex, groupsCount, unit.unitType.bulletSetsQuantity, unit, false)
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
          let bulletParameters = calculate_tank_bullet_parameters(bulletsSet?.supportUnitName ?? unit.name,
            (useDefaultBullet && weaponBlkName) || getModificationBulletsEffect(searchName),
            useDefaultBullet, false)

          let bulletNames = isBulletBelt ? [] : (bulletsSet?.bulletNames ?? [])
          if (isBulletBelt)
            foreach (t, _data in bulletsSet.bulletDataByType)
              bulletNames.append(t)

          foreach (idx, bulletName in bulletNames) {
            local locName = bulletsList.items[i].text
            local bulletParams = bulletParameters?[idx]
            local isDub = false
            if (isBulletBelt) {
              locName = " ".concat(format(loc("caliber/mm"), bulletsSet.caliber),
                loc($"{bulletName}/name/short"))
              let bulletType = bulletName
              bulletParams = bulletParameters.findvalue(@(p) p.bulletType == bulletType)
              
              isDub = bulletSetData.findvalue(@(p) p.bulletType == bulletType
                && p.mass == bulletParams.mass && p.speed == bulletParams.speed
                && p.armorPiercing[0][0] == bulletParams.armorPiercing[0][0])
              if (!isDub)
                bulletSetData.append(bulletParams)
              
              if (isInArray(locName, bulletNamesSet))
                locName = "".concat(loc($"{bulletName}/name/short"), bulletsList.items[i].text)
            }
            else
              isDub = isInArray(locName, bulletNamesSet)

            if (isDub)
              continue

            local addDiv = ""
            local tooltipId = ""

            if (isBulletBelt) {
              let bData = bulletsSet.bulletDataByType[bulletName]
              local bSet = bulletsSet.__merge({
                bullets = [bulletName]
                bulletAnimations = bData.bulletAnimations
              })
              addParamsToBulletSet(bSet, bData)

              tooltipId = SINGLE_BULLET.getTooltipId(unit.name, bulletName, {
                modName = value,
                bSet,
                bulletParams })
              addDiv = SINGLE_BULLET.mkMarkup(tooltipId)
            }
            else {
              tooltipId = MODIFICATION.getTooltipId(bulletsSet?.supportUnitName ?? unit.name, value, { hasPlayerInfo = false })
              addDiv = MODIFICATION.mkMarkup(tooltipId)
            }

            bulletNamesSet.append(locName)
            let btName = bulletName ?? ""
            this.values.append({
              unitName = unit.name
              bulletName = btName
              weaponBlkName = weaponBlkName
              bulletParams = bulletParams
              locName
              tooltipId
              layeredIconData = getBulletsIconView(bulletsSet)
            })

            if (btName == options.targetAmmo)
              selectedIndex = this.values.len() - 1

            this.items.append({
              text = locName
              addDiv = addDiv
            })
          }
        }
      }

      
      let specialBulletTypes = [ "rocket", "bullet" ]
      let unitName = unit.name
      let unitBlk = getFullUnitBlk(unitName)
      let weapons = getUnitWeapons(unitName, unitBlk)
      let knownWeapBlkArray = []

      foreach (weap in weapons) {
        if (!weap?.blk || weap?.dummy || weap.trigger == TRIGGER_TYPE.COUNTERMEASURES
          || isInArray(weap.blk, knownWeapBlkArray))
          continue
        knownWeapBlkArray.append(weap.blk)

        let { weaponBlk, weaponBlkPath } = getWeaponBlkParams(unitName, weap.blk)
        local curBlk
        local curType

        foreach (t in specialBulletTypes)
          if (weaponBlk?[t]) {
            curBlk = weaponBlk?[t]
            curType = t
            break
          }

        let isBullet = curType == "bullet"
        let locName = utf8Capitalize(loc("weapons/{0}".subst(getWeaponNameByBlkPath(weaponBlkPath))))
        if (!curBlk || isInArray(locName, bulletNamesSet))
          continue

        bulletNamesSet.append(locName)
        let bulletParams = calculate_tank_bullet_parameters(unitName, weaponBlkPath, true, false)?[0]
        let btName = isBullet ? curBlk.bulletType : ""
        local bSet
        if (isBullet)
          bSet = addParamsToBulletSet({}, curBlk).__merge({
            caliber = (curBlk?.caliber ?? 0) * 1000
            bullets = weaponBlk % "bullet"
            cartridge = 0
            bulletAnimations = [curBlk?.shellAnimation ?? ""]
            cumulativeDamage = curBlk?.cumulativeDamage.armorPower ?? 0
            cumulativeByNormal = curBlk?.cumulativeByNormal ?? false
          })

        let tooltipId = isBullet
          ? SINGLE_BULLET.getTooltipId(unitName, curBlk.bulletType, {
              bSet
              bulletParams
            })
          : SINGLE_WEAPON.getTooltipId(unitName, {
              blkPath = weaponBlkPath
              tType = weap.trigger
              presetName = weap.presetId
          })
        this.items.append({
          text = locName
          addDiv = isBullet
            ? SINGLE_BULLET.mkMarkup(tooltipId)
            : SINGLE_WEAPON.mkMarkup(tooltipId)
        })

        let iconType = curBlk?.iconType ?? weaponBlk?.iconType ?? weap?.iconType
        this.values.append({
          unitName = unit.name
          bulletName = btName
          weaponBlkName = weaponBlkPath
          bulletParams
          sortVal = curBlk?.caliber ?? 0
          locName
          tooltipId
          layeredIconData = isBullet ? getBulletsIconView(bSet)
            : iconType != null ? { addIco = { img = $"#ui/gameuiskin#{iconType}" } }
            : {}
        })

        if (btName == options.targetAmmo)
          selectedIndex = this.values.len() - 1
      }

      this.value = this.values?[selectedIndex]
    }

    function afterChangeFunc(_nestObj, obj) {
      let parentObj = obj.getParent().getParent()
      if (!parentObj?.isValid())
        return

      parentObj.display = isBulletAvailable() ? "show" : "hide"
    }
  }
})

options.init <- function(handler, scene) {
  this.nestObj = scene
  let needReinit = this.UNIT.value == null || this.UNIT.value != this.targetUnit
    || this.BULLET.value?.bulletName != this.targetAmmo
  if (needReinit)
    this.types.each(@(o) o.value = o.defValue)
  else
    updateParamsByUnit(this.UNIT.value, handler)

  this.types.each(@(o) o.update(handler, scene, needReinit))
}

return options
