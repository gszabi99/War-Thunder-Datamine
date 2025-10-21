from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem

let { format } = require("string")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { countSizeInItems } = require("%sqDagui/daguiUtil.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { updateModItem, createModItemLayout, updateItemBulletsSlider
} = require("%scripts/weaponry/weaponryVisual.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { ceil } = require("math")
let { getLastWeapon, setLastWeapon, isWeaponEnabled, isWeaponVisible,
  isDefaultTorpedoes, getOverrideBullets } = require("%scripts/weaponry/weaponryInfo.nut")
let { isUnitHaveSecondaryWeapons } = require("%scripts/unit/unitWeaponryInfo.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { checkShowShipWeaponsTutor } = require("%scripts/weaponry/shipWeaponsTutor.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { isInFlight } = require("gameplayBinding")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { guiStartChooseUnitWeapon } = require("%scripts/weaponry/weaponrySelectModal.nut")
let UnitBulletsManager = require("%scripts/weaponry/unitBulletsManager.nut")
let { weaponryTypes } = require("%scripts/weaponry/weaponryTypes.nut")
let { bulletsAmountState } = require("%scripts/weaponry/ammoInfo.nut")

let unitTypesWithMainWeaponsFromPresets = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER
  



]
let unitTypesWithMainWeaponsFromBulletsGroup =
  [ES_UNIT_TYPE_TANK, ES_UNIT_TYPE_SHIP, ES_UNIT_TYPE_BOAT]

gui_handlers.unitWeaponsHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM

  unit = null
  canShowPrice = false
  canChangeWeaponry = true

  weaponItemId = "secondary_weapon"
  bulletsIdPrefix = "bullets_"
  headerOffset = 0.3

  bulletsManager = null
  modsInRow = 3
  needRecountWidth = true

  isForcedAvailable = false
  forceShowDefaultTorpedoes = false

  needCheckTutor = true

  getCurrentEdiff = null

  function initScreen() {
    this.bulletsManager = UnitBulletsManager(this.unit, { isForcedAvailable = this.isForcedAvailable })
    this.setUnit(this.unit, true)
  }

  function checkInitWidth() {
    if (!this.needRecountWidth || !this.scene.isVisible() || this.scene.getSize()[0] <= 0)
      return

    let sizes = countSizeInItems(this.scene, "@modCellWidth", "@modCellHeight", 0, 0)
    this.modsInRow = sizes.itemsCountX
    this.scene.width =$"{this.modsInRow}@modCellWidth"
    this.needRecountWidth = false
  }

  getShowItemParams = @() {
    canShowPrice = this.canShowPrice
    canShowStatusImage = false
    needSliderButtons = true
    hasMenu = false
    needTotalSpawnScoreCost = false
    isForceHidePlayerInfo = this.isForcedAvailable || this.forceShowDefaultTorpedoes
    canModifyCustomPrests = false
    curEdiff = this.getCurrentEdiff?()
  }

  getShowSelectorItemParams = @()
    this.getShowItemParams().__update({needTotalSpawnScoreCost = this.canShowPrice && isInFlight()})

  getShowItemParamsForBullets = @() this.getShowItemParams().__update({
    selectBulletsByManager = this.canChangeWeaponry ? this.bulletsManager : null
  })

  function setUnit(newUnit, forceUpdate = false) {
    if (!forceUpdate && this.unit == newUnit)
      return

    this.checkInitWidth()
    this.unit = newUnit
    this.bulletsManager.setUnit(this.unit, forceUpdate)

    local columnsConfig = null
    let unitType = getEsUnitType(this.unit)
    if (unitTypesWithMainWeaponsFromPresets.contains(unitType))
      columnsConfig = this.getColumnsAircraft()
    else if (unitTypesWithMainWeaponsFromBulletsGroup.contains(unitType))
      columnsConfig = this.getColumnsTank()

    if (!columnsConfig) {
      this.clearScene()
      return
    }

    this.fillWeaponryByColumnsConfig(columnsConfig)
    this.updateAllItems()

    if (this.needCheckTutor) {
      this.guiScene.performDelayed(this, @() checkShowShipWeaponsTutor(this, columnsConfig))
      this.needCheckTutor = false
    }
  }

  function setCanChangeWeaponry(newValue, forceUpdate) {
    if (newValue == this.canChangeWeaponry && !forceUpdate)
      return

    this.canChangeWeaponry = newValue
    if (!this.unit)
      return

    this.updateAllItems()
  }

  














  function fillWeaponryByColumnsConfig(config) {
    let view = {
      bgBlocks = []
      weaponryList = ""
    }

    let itemWidth = config.itemWidth
    let columns = config.columns

    local isLineEmpty = false
    local lineOffset = 0.0
    local lastBgBlock = null
    local line = 0
    let showItemParams = this.getShowItemParamsForBullets()
    for (; !isLineEmpty; line++) {
      isLineEmpty = true
      local needHeader = false
      local bgBlock = this.getBgBlockBaseTemplate(itemWidth * columns.len())

      let cellsRow = array(columns.len(), null)
      foreach (idx, column in columns) {
        let cell = getTblValue(line, column)
        if ((!cell || !cell.header) && bgBlock.columnsList.len())
          bgBlock.columnsList[bgBlock.columnsList.len() - 1].width += itemWidth

        if (!cell || cell.itemType == weaponsItem.unknown)
          continue

        cellsRow[idx] = cell

        isLineEmpty = false
        if (!needHeader)
          bgBlock.offsetX = itemWidth * idx
        needHeader = needHeader || cell.header != null

        if (cell.header)
          bgBlock.columnsList.append(this.getColumnConfig(cell.id, cell.header, bgBlock.columnsList.len() > 0, itemWidth))
      }

      if (isLineEmpty)
        break

      if (needHeader) {
        lineOffset += this.headerOffset
        bgBlock.offsetY = lineOffset + line
        view.bgBlocks.append(bgBlock)
        lastBgBlock = bgBlock
      }
      else if (lastBgBlock) {
        bgBlock = lastBgBlock
        bgBlock.height++
      }

      bgBlock.rows.append(
      {
        width = itemWidth * columns.len() - bgBlock.offsetX
        top = bgBlock.rows.len()
      })

      view.weaponryList = "".concat(view.weaponryList,
        this.addItemsByCellsRow(cellsRow, lineOffset + line, itemWidth, showItemParams))
    }

    this.scene.height = $"{lineOffset + line}@modCellHeight"
    if (!this.needRecountWidth)
      this.scene.width = $"{itemWidth * columns.len()}@modCellWidth"
    let data = handyman.renderCached("%gui/weaponry/weaponry.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
  }

  function getBgBlockBaseTemplate(width) {
    return {
      width = width
      height = 1
      offsetX = 0
      offsetY = 0
      headerClass = "tiny"
      columnsList = []
      rows = []
    }
  }

  function getColumnConfig(id, header, needDivLine = false, width = 1) {
    return {
      id
      name = header
      needDivLine = needDivLine
      width = width
      isSmallFont = true
    }
  }

  function addItemsByCellsRow(cellsRow, offsetY, itemWidth, showItemParams) {
    let res = []
    let params = {
      posX = 0
      posY = offsetY
      itemWidth = itemWidth
      needSliderButtons = true
      wideItemWithSlider = itemWidth > 1
    }.__update(showItemParams)
    foreach (idx, cell in cellsRow) {
      if (!cell)
        continue

      params.posX = itemWidth * idx
      local item = null
      if (cell.itemType == weaponsItem.weapon)
        item = this.getCurWeapon()
      else if (cell.itemType == weaponsItem.modification)
        item = this.getCurBullet(cell.bulGroupIdx)

      if (item)
        res.append(createModItemLayout(cell.id, this.unit, item, cell.itemType, params))
    }
    return "".join(res)
  }

  function getBulletsItemId(groupIdx) {
    return $"{this.bulletsIdPrefix}{groupIdx}"
  }

  function getCellConfig(id = "", header = null, item_type = weaponsItem.unknown, bulGroupIdx = 0) {
    return {
      id
      header
      itemType = item_type
      bulGroupIdx
    }
  }

  function getEmptyColumnsConfig() {
    return {
      itemWidth = 1
      columns = []
    }
  }

  function getColumnsAircraft() {
    let res = this.getEmptyColumnsConfig()
    if (isUnitHaveSecondaryWeapons(this.unit))
      res.columns.append([this.getCellConfig(this.weaponItemId, weaponryTypes.WEAPON.getHeader(this.unit), weaponsItem.weapon)])

    let groups = this.getBulletsGroups()
    local hasPairBulletsGroup = false
    local activeGroupsId = []
    foreach (gIdx, bulGroup in groups) {
      if (!bulGroup.active || bulGroup.shouldHideBullet())
        continue
      let isPairBulletsGroup = bulGroup.isPairBulletsGroup()
      if (isPairBulletsGroup && (bulGroup.bullets.value != 0))
        continue
      hasPairBulletsGroup = hasPairBulletsGroup || isPairBulletsGroup
      activeGroupsId.append(gIdx)
    }
    if (hasPairBulletsGroup)
      res.itemWidth = 1.5

    let maxColumns = max((this.modsInRow / res.itemWidth), 1)
    let offset = res.columns.len() < maxColumns ? res.columns.len() : 0
    let totalColumns = min(offset + activeGroupsId.len(), maxColumns)
    for (local i = res.columns.len(); i < totalColumns; i++)
      res.columns.append([])

    local currHeader = null
    foreach (idx, gIdx in activeGroupsId) {
      let bulGroup = groups[gIdx]
      let col = offset + (idx % (totalColumns - offset))
      let header = bulGroup.getHeader()
      res.columns[col].append(this.getCellConfig(this.getBulletsItemId(gIdx), header != currHeader ? header : null, weaponsItem.modification, gIdx))
      currHeader = header
    }
    return res
  }

  function getColumnsTank() {
    let groups = this.getBulletsGroups()
    let gunsCount = this.bulletsManager.getGunTypesCount()
    if (gunsCount == 0)
      return null

    let res = this.getEmptyColumnsConfig()
    res.itemWidth = 1.5
    if (gunsCount == 1) {
      let totalMods = this.bulletsManager.getActiveBulGroupsAmount()
      local totalColumns = 0

      if (totalMods > 0) {
        let totalRows = ceil(totalMods.tofloat() / this.modsInRow * res.itemWidth).tointeger()
        totalColumns = ceil(totalMods.tofloat() / totalRows).tointeger()
      }

      for (local i = res.columns.len(); i < totalColumns; i++)
        res.columns.append([])
      local isHeaderSet = false
      foreach (gIdx, bulGroup in groups) {
        if (!bulGroup.active || bulGroup.shouldHideBullet())
          continue
        let col = gIdx % totalColumns
        let header = isHeaderSet ? null : bulGroup.getHeader()
        isHeaderSet = true
        res.columns[col].append(this.getCellConfig(this.getBulletsItemId(gIdx), header, weaponsItem.modification, gIdx))
      }
      return this.addSecondaryWeaponToTankColumns(res)
    }

    local totalColumns = gunsCount
    for (local i = res.columns.len(); i < totalColumns; i++)
      res.columns.append([])
    foreach (gIdx, bulGroup in groups) {
      if (!bulGroup.active || bulGroup.shouldHideBullet())
        continue
      let col = bulGroup.getGunIdx()
      let header = !res.columns[col].len() ? bulGroup.getHeader() : null
      res.columns[col].append(this.getCellConfig(this.getBulletsItemId(gIdx), header, weaponsItem.modification, gIdx))
    }

    res.columns = res.columns.filter(@(v) v.len() > 0) 
    totalColumns = res.columns.len()

    let maxColumns = max((this.modsInRow / res.itemWidth), 1)
    if (gunsCount == 3 && maxColumns == 2) {
      let newColumns = [[], []]
      local singleItemIdx = -1
      foreach (idx, column in res.columns) {
        if (column.len() > 1) {
          newColumns[0].append(column[0])
          newColumns[1].append(column[1])
        }
        else if (singleItemIdx == -1 && column.len() != 0) {
          newColumns[0].append(column[0])
          newColumns[1].append(null)
          singleItemIdx = idx
        }
        else if (column.len() != 0)
          newColumns[1][singleItemIdx] = column[0]
      }
      res.columns = newColumns
      totalColumns = 2
    }

    if (maxColumns < totalColumns)
      for (local i = res.columns.len() - 1; i >= maxColumns; i--) {
        res.columns[i % maxColumns].extend(res.columns[i])
        res.columns.remove(i)
      }

    return this.addSecondaryWeaponToTankColumns(res)
  }

  function addSecondaryWeaponToTankColumns(colData) {
    if (!isUnitHaveSecondaryWeapons(this.unit))
      return colData

    let weaponCell = this.getCellConfig(this.weaponItemId, weaponryTypes.WEAPON.getHeader(this.unit), weaponsItem.weapon)
    let maxColumns = max((this.modsInRow / colData.itemWidth), 1)
    if (colData.columns.len() < maxColumns)
      colData.columns.insert(0, [weaponCell])
    else
      foreach (idx, column in colData.columns)
        column.insert(0, idx ? null : weaponCell)
    return colData
  }

  function clearScene() {
    this.scene.height = "0"
    this.guiScene.replaceContentFromText(this.scene, "", 0, this)
  }

  function getCurWeapon() {
    local defWeapon = null
    let weaponName = getLastWeapon(this.unit.name)
    foreach (weapon in this.unit.getWeapons()) {
      let found = weapon.name == weaponName
      
      if (!found && defWeapon)
        continue

      if (!this.isForcedAvailable
          && (!this.forceShowDefaultTorpedoes || !isDefaultTorpedoes(weapon))
          && (!isWeaponVisible(this.unit, weapon) || !isWeaponEnabled(this.unit, weapon)))
        continue

      if (found)
        return weapon

      if (!defWeapon)
        defWeapon = weapon
    }
    if (defWeapon) 
      this.setWeapon(defWeapon.name)
    return defWeapon
  }

  function setWeapon(name) {
    setLastWeapon(this.unit.name, name)
  }

  function hasWeaponsToChooseFrom() {
    local count = 0
    let hasOnlySelectable = !isInFlight() || !getCurMissionRules().isWorldWar
    foreach (weapon in this.unit.getWeapons()) {
      if (!this.isForcedAvailable
          && (!this.forceShowDefaultTorpedoes || !isDefaultTorpedoes(weapon))
          && !isWeaponVisible(this.unit, weapon, hasOnlySelectable))
        continue

      count++
      if (count > 1)
        return true
    }
    return false
  }

  getBulletsGroups = @() this.bulletsManager.getBulletsGroups()

  canChangeBulletsCount = @() this.bulletsManager.canChangeBulletsCount()

  getBulletGroupByIndex = @(groupIdx) this.getBulletsGroups()?[groupIdx]

  function getCurBullet(groupIdx) {
    let bulGroup = this.getBulletGroupByIndex(groupIdx)
    return bulGroup && bulGroup.getSelBullet()
  }

  function updateWeapon() {
    if (!isUnitHaveSecondaryWeapons(this.unit))
      return

    let itemObj = this.scene.findObject(this.weaponItemId)
    let curWeapon = this.getCurWeapon()
    if (!checkObj(itemObj))
      return

    itemObj.show(curWeapon)
    if (!curWeapon)
      return

    let showItemParams = this.getShowItemParams().__update({
      hasMenu = this.canChangeWeaponry && this.hasWeaponsToChooseFrom() })
    updateModItem(this.unit, curWeapon, itemObj, false, this, showItemParams)
  }

  function updateBullets() {
    let groups = this.getBulletsGroups()
    let showItemParams = this.getShowItemParamsForBullets()
    foreach (gIdx, bulGroup in groups) {
      let itemObj = this.scene.findObject(this.getBulletsItemId(gIdx))
      if (!checkObj(itemObj))
        continue

      showItemParams.visualDisabled <- !bulGroup.active
      showItemParams.hasMenu <- this.canChangeWeaponry && bulGroup.canChangeBullet()
      updateModItem(this.unit, bulGroup.getSelBullet(), itemObj, false, this, showItemParams)
    }
  }

  function updateBulletCountSlider(bulGroup, groupIdx) {
    if (bulGroup.gunInfo?.isBulletBelt)
      return
    let itemObj = this.scene.findObject(this.getBulletsItemId(groupIdx))
    if (checkObj(itemObj))
      updateItemBulletsSlider(itemObj, this.bulletsManager, bulGroup)
  }

  
  function updateAllBulletCountSliders() {
    let groups = this.getBulletsGroups()
    foreach (gIdx, bulGroup in groups)
      this.updateBulletCountSlider(bulGroup, gIdx)
  }

  function updateAllItems() {
    this.updateWeapon()
    this.updateBullets()
  }

  function onEventUnitWeaponChanged(_p) {
    this.setUnit(this.unit, true)
  }

  function onEventBulletsGroupsChanged(_p) {
    this.updateBullets()
  }

  function onEventBulletsCountChanged(_p) {
    this.updateAllBulletCountSliders()
  }

  function onEventModificationChanged(_p) {
    this.setUnit(this.unit, true)
  }

  getBulletGroupIdxByItemId = @(id) to_integer_safe(cutPrefix(id, this.bulletsIdPrefix, -1), -1)

  function openChangeWeaponryMenu(obj) {
    if (!this.canChangeWeaponry || !checkObj(obj))
      return

    let id = obj.holderId
    if (id == this.weaponItemId) {
      if (this.hasWeaponsToChooseFrom())
        guiStartChooseUnitWeapon(this.unit, null, {
          itemParams = this.getShowSelectorItemParams()
          alignObj = obj
          isForcedAvailable = this.isForcedAvailable
          forceShowDefaultTorpedoes = this.forceShowDefaultTorpedoes
        })
      return
    }

    let groupIdx = this.getBulletGroupIdxByItemId(id)
    let group = this.getBulletGroupByIndex(groupIdx)
    if (!group)
      return

    if (group.active) {
      if (group.canChangeBullet())
        this.bulletsManager.openChooseBulletsWnd(group.groupIndex, this.getShowSelectorItemParams(), obj)
    }
    else
      showInfoMsgBox(loc("msg/secondaryWeaponrequired"))
  }

  function onModItemClick(obj) {
    this.openChangeWeaponryMenu(obj)
  }

  function onWeaponryActivate(obj) {
    let value = obj.getValue()
    if (0 <= value && value < obj.childrenCount())
      this.openChangeWeaponryMenu(obj.getChild(value).findObject("centralBlock"))
  }

  function onModChangeBulletsSlider(obj) {
    if (!checkObj(obj))
      return
    let groupIndex = to_integer_safe(obj?.groupIdx ?? "", -1)
    let bulGroup = this.getBulletGroupByIndex(groupIndex)
    if (!bulGroup)
      return

    if (!this.bulletsManager.changeBulletsCount(bulGroup, obj.getValue()))
      this.updateBulletCountSlider(bulGroup, groupIndex) 
  }

  function onChangeBullets(diff = 1) { 
    if (!this.canChangeBulletsCount())
      return
    let listObj = this.scene.findObject("weaponry_list")
    if (!checkObj(listObj) || !listObj.isFocused())
      return
    let idx = listObj.getValue()
    if (idx < 0 || listObj.childrenCount() <= idx)
      return

    let itemObj = listObj.getChild(idx)
    let groupIdx = this.getBulletGroupIdxByItemId(itemObj.id)
    let group = this.getBulletGroupByIndex(groupIdx)
    if (!group)
      return

    let step = max(group.getGunMaxBullets() / 20, 1).tointeger()
    this.bulletsManager.changeBulletsCount(group, group.bulletsCount + diff * step)
  }

  function onBulletsDecrease() { this.onChangeBullets(-1) }
  function onBulletsIncrease() { this.onChangeBullets(1) }

  function onModChangeBullets(obj, diff = 1) { 
    let groupIdx = this.getBulletGroupIdxByItemId(obj.holderId)
    let group = this.getBulletGroupByIndex(groupIdx)
    if (group)
      this.bulletsManager.changeBulletsCount(group, group.bulletsCount + diff)
  }

  function onModDecreaseBullets(obj) { this.onModChangeBullets(obj, -1) }
  function onModIncreaseBullets(obj) { this.onModChangeBullets(obj, 1) }

  function checkChosenBulletsCount(applyFunc = null) {
    if (getOverrideBullets(this.unit))
      return true
    let readyCounts = this.bulletsManager.checkBulletsCountReady()
    if (readyCounts.status != bulletsAmountState.LOW_AMOUNT)
      return true

    let msg = format(loc("multiplayer/notEnoughBullets"), colorize("activeTextColor", readyCounts.required.tostring()))
    loadHandler(gui_handlers.WeaponWarningHandler,
      {
        parentHandler = this
        message = msg
        list = ""
        showCheckBoxBullets = false
        ableToStartAndSkip = false
        onStartPressed = applyFunc
      })

    return false
  }
}
