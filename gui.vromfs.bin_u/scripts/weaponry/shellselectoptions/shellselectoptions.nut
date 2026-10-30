import "%sqStdLibs/helpers/enums.nut" as enums
import "%scripts/shop/shopSearchCore.nut" as shopSearchCore
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "string" import format
from "unitCalculcation" import calculate_tank_bullet_parameters
from "%sqstd/string.nut" import utf8Capitalize
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/utils_sa.nut" import findNearest
from "%scripts/options/optionsCtors.nut" import create_option_combobox, create_empty_combobox
from "%scripts/unit/unitInfo.nut" import getUnitName, image_for_air
from "%scripts/weaponry/weaponryInfo.nut" import WEAPON_TYPE, TRIGGER_TYPE, getWeaponNameByBlkPath
from "%scripts/weaponry/bulletsInfo.nut" import getBulletsList, getLinkedGunIdx, getBulletsSetData,
  getBulletsSearchName, getBulletsGroupCount, getLastFakeBulletsIndex, getModificationBulletsEffect, hasNestedRocket
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/weaponry/weaponryTooltips.nut" import SINGLE_WEAPON, MODIFICATION, SINGLE_BULLET
from "%scripts/shop/shopCountriesList.nut" import shopCountriesList
from "%scripts/shop/shopCountryInfo.nut" import isCountryHaveUnitType, hasUnitAtRank, get_units_list
from "%scripts/weaponry/weaponryPresets.nut" import getUnitWeapons, getWeaponBlkParams
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/unit/unitParams.nut" import getFullUnitBlk
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%scripts/ranks.nut" import maxCountryRank
from "%scripts/weaponry/bulletsVisual.nut" import getBulletsIconView
from "%scripts/options/consoleMode.nut" import showConsoleButtons

let unitTypes = require("%scripts/unit/unitTypesList.nut")

function addParamsToBulletSet(bSet, bData) {
  foreach (param in ["explosiveType", "explosiveMass"])
    bSet[param] <- bData?[param]

  return bSet
}

function hasSameBullet(bulletSetData, bulletType, mass, speed, explosiveMass, armorPiercing = null) {
  return bulletSetData.findvalue(@(p) p.bulletType == bulletType
    && p.mass == mass && p.speed == speed && p.explosiveMass == explosiveMass
    && (armorPiercing == null || p.armorPiercing[0][0] == armorPiercing)) != null
}

function getSecondaryWeaponType(shellType, shellBlk, trigger) {
  if (shellType == "rocket")
    return trigger == TRIGGER_TYPE.AGM || trigger == TRIGGER_TYPE.ATGM ? WEAPON_TYPE.AGM
      : trigger == TRIGGER_TYPE.AAM ? WEAPON_TYPE.AAM
      : WEAPON_TYPE.ROCKETS
  if (shellType == "bomb")
    return shellBlk?.guidanceType ? WEAPON_TYPE.GUIDED_BOMBS : WEAPON_TYPE.BOMBS
  if (shellType == "torpedo")
    return WEAPON_TYPE.TORPEDOES
  return WEAPON_TYPE.GUNS
}


function mkShellSelectOptions(config) {
  let {
    getThreatEsUnitTypes 
    getSecondaryShellTypes 
    isReinitNeeded 
    onValuesChanged = null 
    isSaved = null 
  } = config

  let options = {
    types = []
    cache = {
      bySortId = {}
    }

    nestObj = null
    targetUnit = null
    targetAmmo = null
    targetDistance = null
    structure = null
    bulletsFilter = null

    function setParams(unit, ammo = null, distance = null) {
      this.targetUnit = unit
      this.targetAmmo = ammo
      this.targetDistance = distance
    }

    get = @(id) this?[id] ?? this.UNKNOWN
    getBySortId = @(idx) enums.getCachedType("sortId", idx, this.cache.bySortId, this, this.UNKNOWN)

    function addTypes(typesTable) {
      enums.addTypes(this, typesTable, null, "id")
      this.types.sortby(@(a) a.sortId)
    }

    function updateParamsByUnit(unit, handler) {
      handler.guiScene.setUpdatesEnabled(false, false)
      for (local i = 1; ; i++) {
        let option = this.getBySortId(i)
        if (option == this.UNKNOWN)
          break
        option.updateParamsByUnit(unit)
      }
      handler.guiScene.setUpdatesEnabled(true, true)
    }

    function init(handler, scene, structure = null, bulletsFilter = null) {
      this.nestObj = scene
      this.structure = structure
      this.bulletsFilter = bulletsFilter

      let needReinit = isReinitNeeded(this)
      if (needReinit)
        this.types.each(@(o) o.value = o.defValue)
      else
        this.updateParamsByUnit(this.UNIT.value, handler)

      this.types.each(@(o) o.update(handler, scene, needReinit))
      onValuesChanged?(this)
    }
  }

  if (isSaved != null)
    options.isSaved <- isSaved

  options.template <- {
    id = "" 
    sortId = 0
    labelLocId = null
    items  = []
    values = []
    value = null
    defValue = null
    valueWidth = null
    controlMarkupParams = null

    getLabel = @() this.labelLocId && loc(this.labelLocId)
    function getControlMarkup() {
      return create_option_combobox(this.id, [], -1, "onChangeOption", true,
        this.controlMarkupParams ?? {})
    }
    getInfoRows = @() null

    function onChange(handler, scene, obj) {
      this.value = this.getValFromObj(obj)
      this.afterChangeFunc?(obj)
      this.updateDependentOptions(handler, scene)
      onValuesChanged?(options)
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
      this.afterChangeFunc?(scene.findObject(this.id))
    }
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
      isVisible = @() getThreatEsUnitTypes(options.targetUnit).len() > 1
      needDisabledOnSearch = @() this.isVisible()

      function updateParams() {
        let { structure } = options
        let threatEsUnitTypes = getThreatEsUnitTypes(options.targetUnit)
        let esUnitTypes = structure == null ? clone threatEsUnitTypes
          : threatEsUnitTypes.filter(@(uType) uType in structure)
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
      controlMarkupParams = { controlStyle = "iconType:t='country_small';" }
      getLabel = @() options.UNITTYPE.isVisible() ? null : loc("mainmenu/threat")
      needDisabledOnSearch = @() this.isVisible()

      function updateParams() {
        let unitType = options.UNITTYPE.value
        let structure = options.structure == null ? null : options.structure?[unitType] ?? {}
        this.values = structure == null
          ? shopCountriesList.filter(@(c) isCountryHaveUnitType(c, unitType))
          : shopCountriesList.filter(@(c) isCountryHaveUnitType(c, unitType) && c in structure)
        this.items  = this.values.map(@(c) { text = loc(c), image = getCountryIcon(c) })
        let preferredCountry = this.value ?? options.targetUnit.shopCountry
        this.value = this.values.indexof(preferredCountry) != null ? preferredCountry
          : (this.values?[0] ?? "")
      }

      function updateParamsByUnit(unit) {
        if (!this.values.contains(unit.shopCountry))
          this.updateParams()
        this.value = unit.shopCountry
      }
    }
    RANK = {
      sortId = sortIdCount++
      needDisabledOnSearch = @() this.isVisible()

      function updateParams() {
        let unitType = options.UNITTYPE.value
        let country = options.COUNTRY.value
        let structure = options.structure == null ? null
          : options.structure?[unitType][country] ?? {}
        this.values = []
        let maxRank = maxCountryRank.get()
        for (local rank = 1; rank <= maxRank; rank++) {
          if (structure != null && rank not in structure)
            continue
          if (hasUnitAtRank(rank, unitType, country, true, false))
            this.values.append(rank)
        }
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
      controlMarkupParams = { beforeSelectCb = "onBeforeSelectComboboxValue", tooltipOnHold = @() showConsoleButtons.get() }

      function applyUnitsList(list) {
        this.values = list.map(@(v) v.unit)

        let tooltipOnHold = showConsoleButtons.get()
        this.items = list.map(@(v) {
          text  = format("[%.1f] %s", v.br, getUnitName(v.id))
          image = image_for_air(v.unit)
          addDiv = tooltipOnHold ? null
            : getTooltipType("UNIT").getMarkup(v.id, { showLocalState = false })
          tooltipId = tooltipOnHold ? getTooltipType("UNIT").getTooltipId(v.id, { showLocalState = false }) : ""
          tooltipOnHold
        })
        let targetUnitId = options.targetUnit.name
        let preferredUnitId = this.value?.name ?? targetUnitId
        this.value = this.values.findvalue(@(v) v.name == preferredUnitId)
          ?? this.values.findvalue(@(v) v.name == targetUnitId)
          ?? this.values?[0]
      }

      function updateParams() {
        let unitType = options.UNITTYPE.value
        let rank = options.RANK.value
        let country = options.COUNTRY.value
        let ediff = getCurrentGameModeEdiff()
        let structure = options.structure == null ? null
          : options.structure?[unitType][country][rank] ?? {}

        local list = get_units_list(@(unit) unit.esUnitType == unitType
          && unit.shopCountry == country
          && unit.rank == rank
          && unit.isVisibleInShop()
        )
        if (structure != null)
          list = list.filter(@(unit) unit.name in structure)
        list = list.map(@(unit) { unit, id = unit.name, br = unit.getBattleRating(ediff) })
        list.sortby(@(a) a.br)
        this.applyUnitsList(list)

        if (this.value == null) 
          script_net_assert_once("shell select units list empty", "Shell select options: Units list empty")
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
        this.applyUnitsList(list)

        this.updateView(handler, scene)
        this.updateDependentOptions(handler, scene)
        onValuesChanged?(options)
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
      controlMarkupParams = {
        beforeSelectCb = "onBeforeSelectComboboxValue"
        tooltipOnHold = @() showConsoleButtons.get()
        hasInteractiveTooltip = true
      }

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
        let { bulletsFilter = null } = options

        let unit = options.UNIT.value
        this.values = []
        this.items = []
        let bulletSetData = []

        if (unit == null) {
          this.value = null
          return
        }

        let unitName = unit.name
        local curGunIdx = -1
        local selectedIndex = 0
        let groupsCount = getBulletsGroupCount(unit)
        let isTooltipOnHold = showConsoleButtons.get()

        
        let bulletNamesSet = []
        for (local bulletSetIdx = 0; bulletSetIdx < getLastFakeBulletsIndex(unit); bulletSetIdx++) {
          let gunIdx = getLinkedGunIdx(bulletSetIdx, groupsCount, unit.unitType.bulletSetsQuantity,
            unit, null, false)
          if (gunIdx == curGunIdx)
            continue

          let bulletsList = getBulletsList(unitName, bulletSetIdx, {
            needCheckUnitPurchase = false, needOnlyAvailable = false, needTexts = true
          })
          if (bulletsList.values.len())
            curGunIdx = gunIdx

          foreach (i, value in bulletsList.values) {
            let bulletsSet = getBulletsSetData(unit, value)
            let { weaponType = null, weaponBlkName = null, isBulletBelt = true,
              hasNestedRocketBlk = false } = bulletsSet

            if (weaponType == null
                || weaponBlkName == null
                || this.visibleTypes.indexof(weaponType) == null)
              continue

            let searchName = getBulletsSearchName(unit, value)
            let useDefaultBullet = searchName != value
            let bulletParameters = calculate_tank_bullet_parameters(bulletsSet?.supportUnitName ?? unitName,
              (useDefaultBullet && weaponBlkName) || getModificationBulletsEffect(searchName),
              useDefaultBullet, false)

            let bulletNames = isBulletBelt ? [] : (bulletsSet?.bulletNames ?? [])
            if (isBulletBelt)
              foreach (t, _data in bulletsSet.bulletDataByType)
                bulletNames.append(t)

            foreach (idx, bulletName in bulletNames) {
              local locName = bulletsList.items[i].text
              local bulletParams = bulletParameters?[idx]

              if (bulletsFilter != null && !bulletsFilter(weaponType, bulletParams?.bulletType, hasNestedRocketBlk))
                continue

              local isDuplicated = false
              if (isBulletBelt) {
                locName = " ".concat(format(loc("caliber/mm"), bulletsSet.caliber),
                  loc($"{bulletName}/name/short"))
                let bulletType = bulletName
                bulletParams = bulletParameters.findvalue(@(p) p.bulletType == bulletType)
                if (bulletParams == null)
                  continue
                let explosiveMass = bulletsSet.bulletDataByType[bulletName]?.explosiveMass ?? 0
                
                isDuplicated = hasSameBullet(bulletSetData, bulletType, bulletParams.mass, bulletParams.speed,
                  explosiveMass, bulletParams.armorPiercing[0][0])
                if (!isDuplicated)
                  bulletSetData.append(bulletParams.__merge({ explosiveMass }))
                
                if (isInArray(locName, bulletNamesSet))
                  locName = "".concat(loc($"{bulletName}/name/short"), bulletsList.items[i].text)
              }
              else
                isDuplicated = bulletNamesSet.contains(locName)

              if (isDuplicated)
                continue

              local bSet
              
              local ammoName = bulletName
              if (isBulletBelt) {
                let bData = bulletsSet.bulletDataByType[bulletName]
                ammoName = bData.bulletName ?? ammoName
                bSet = bulletsSet.__merge({
                  bullets = [bulletName]
                  bulletAnimations = bData.bulletAnimations
                })
                addParamsToBulletSet(bSet, bData)
              }

              let tooltipId = isBulletBelt
                ? SINGLE_BULLET.getTooltipId(unitName, bulletName,
                  { modName = value, bSet, bulletParams })
                : MODIFICATION.getTooltipId(bulletsSet?.supportUnitName ?? unitName, value,
                  { hasPlayerInfo = false })

              bulletNamesSet.append(locName)
              this.values.append({
                esUnitType = unit.esUnitType
                bulletName = ammoName
                weaponBlkName
                weaponType
                bulletParams
                hasNestedRocketBlk
                locName
                tooltipId
                layeredIconData = getBulletsIconView(bulletsSet)
              })

              if (ammoName == options.targetAmmo || bulletName == options.targetAmmo)
                selectedIndex = this.values.len() - 1

              this.items.append({
                text = locName
                addDiv = isTooltipOnHold ? null
                  : isBulletBelt ? SINGLE_BULLET.getMarkup(unitName, bulletName,
                    { modName = value, bSet, bulletParams })
                  : MODIFICATION.getMarkup(bulletsSet?.supportUnitName ?? unitName, value,
                    { hasPlayerInfo = false })
                tooltipId = isTooltipOnHold ? tooltipId : ""
                tooltipOnHold = isTooltipOnHold
              })
            }
          }
        }

        
        let weaponKeysSet = []
        let secondaryShellTypes = getSecondaryShellTypes()
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
          local curShellDesc
          foreach (shellDesc in secondaryShellTypes) {
            let { shellType, paramToCheck = null } = shellDesc
            let shellBlk = weaponBlk?[shellType]
            if (shellBlk && (paramToCheck == null || shellBlk?[paramToCheck])) {
              curBlk = shellBlk
              curShellDesc = shellDesc
              break
            }
          }
          if (!curBlk)
            continue

          let { shellType, hasBulletParams = false, isNamedByWeapon = false } = curShellDesc
          let isBullet = shellType == "bullet"
          let isRocket = shellType == "rocket"
          
          
          let weaponKey = (
              isRocket ? curBlk?.bulletName
              : isBullet ? $"{curBlk.bulletType}_{curBlk?.caliber}_{curBlk?.mass}_{curBlk?.speed}"
              : null)
            ?? weaponBlkPath.tolower().replace("_default.blk", ".blk")
          if (weaponKeysSet.contains(weaponKey)
              || (isBullet && hasSameBullet(bulletSetData, curBlk.bulletType, curBlk?.mass, curBlk?.speed,
                curBlk?.explosiveMass ?? 0)))
            continue
          weaponKeysSet.append(weaponKey)

          let shellName = getWeaponNameByBlkPath(weaponBlkPath)
          let caliber = curBlk?.caliber
          let locName = !isBullet ? utf8Capitalize(loc("weapons/{0}/short".subst(shellName)))
            : caliber == null ? loc($"{curBlk.bulletType}/name/short")
            : " ".concat(format(loc("caliber/mm"), caliber * 1000), loc($"{curBlk.bulletType}/name/short"))

          local bSet
          if (isBullet)
            bSet = addParamsToBulletSet({}, curBlk).__merge({
              caliber = (curBlk?.caliber ?? 0) * 1000
              bullets = (weaponBlk % "bullet").map(@(v) v.bulletType)
              cartridge = 0
              bulletAnimations = [curBlk?.shellAnimation ?? ""]
              cumulativeDamage = curBlk?.cumulativeDamage.armorPower ?? 0
              cumulativeByNormal = curBlk?.cumulativeByNormal ?? false
            })

          let bulletParams = !hasBulletParams ? null
            : calculate_tank_bullet_parameters(unitName, weaponBlkPath, true, false)?[0]

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

          let iconType = curBlk?.iconType ?? weaponBlk?.iconType ?? weap?.iconType
          let weapType = getSecondaryWeaponType(shellType, curBlk, weap.trigger)
          let hasNestedRocketBlk = hasNestedRocket(curBlk)
          if (bulletsFilter != null && !bulletsFilter(weapType, bulletParams?.bulletType, hasNestedRocketBlk))
            continue

          this.items.append({
            text = locName
            addDiv = isTooltipOnHold ? null
              : isBullet ? SINGLE_BULLET.getMarkup(unitName, curBlk.bulletType, {
                bSet
                bulletParams
              })
              : SINGLE_WEAPON.getMarkup(unitName, {
                blkPath = weaponBlkPath
                tType = weap.trigger
                presetName = weap.presetId
              })
            tooltipId = isTooltipOnHold ? tooltipId : ""
            tooltipOnHold = isTooltipOnHold
          })

          let btName = isBullet ? curBlk.bulletType
            : isRocket ? (curBlk?.bulletName ?? curBlk?.weaponName ?? "")
            : isNamedByWeapon ? shellName
            : ""
          this.values.append({
            esUnitType = unit.esUnitType
            bulletName = btName
            weaponBlkName = weaponBlkPath
            weaponType = weapType
            bulletParams
            hasNestedRocketBlk
            locName
            tooltipId
            layeredIconData = isBullet ? getBulletsIconView(bSet)
              : iconType != null ? { addIco = { img = $"#ui/gameuiskin#{iconType}" } }
              : {}
          })

          if (btName == options.targetAmmo)
            selectedIndex = this.values.len() - 1
        }

        let locNameCounts = {}
        foreach (v in this.values)
          locNameCounts[v.locName] <- (locNameCounts?[v.locName] ?? 0) + 1
        foreach (idx, v in this.values)
          if (v.weaponType == WEAPON_TYPE.GUNS && locNameCounts[v.locName] > 1) {
            v.locName = $"{v.locName} ({loc($"weapons/{getWeaponNameByBlkPath(v.weaponBlkName)}/short")})"
            this.items[idx].text = v.locName
          }

        this.value = this.values?[selectedIndex]
      }

      function afterChangeFunc(obj) {
        let parentObj = obj.getParent().getParent()
        if (!parentObj?.isValid())
          return

        parentObj.display = this.value != null ? "show" : "hide"
      }
    }
  })

  return options
}

return {
  mkShellSelectOptions
}
