from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { updateModItem,
        createModItemLayout,
        updateItemBulletsSlider } = require("%scripts/weaponry/weaponryVisual.nut")
        let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { ceil } = require("math")

let { getLastWeapon,
        setLastWeapon,
        isWeaponEnabled,
        isWeaponVisible } = require("%scripts/weaponry/weaponryInfo.nut")
let { isUnitHaveSecondaryWeapons } = require("%scripts/unit/unitStatus.nut")

::gui_handlers.unitWeaponsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  unit = null
  canShowPrice = false
  canChangeWeaponry = true
  canChangeBulletsAmount = true

  weaponItemId = "secondary_weapon"
  bulletsIdPrefix = "bullets_"
  headerOffset = 0.3

  bulletsManager = null
  modsInRow = 3
  needRecountWidth = true

  showItemParams = null
  isForcedAvailable = false

  function initScreen()
  {
    bulletsManager = ::UnitBulletsManager(unit, { isForcedAvailable = isForcedAvailable })
    updateShowItemParams()
    setUnit(unit, true)
  }

  function checkInitWidth()
  {
    if (!needRecountWidth || !this.scene.isVisible() || this.scene.getSize()[0] <= 0)
      return

    let sizes = ::g_dagui_utils.countSizeInItems(this.scene, "@modCellWidth", "@modCellHeight", 0, 0)
    modsInRow = sizes.itemsCountX
    this.scene.width = modsInRow + "@modCellWidth"
    needRecountWidth = false
  }

  function updateShowItemParams()
  {
    showItemParams = {
      canShowPrice = canShowPrice
      canShowStatusImage = false
      selectBulletsByManager = (canChangeWeaponry && canChangeBulletsAmount) ? bulletsManager : null
      needSliderButtons = canChangeBulletsAmount
      hasMenu = false
      isForceHidePlayerInfo = isForcedAvailable
    }
  }

  function setUnit(newUnit, forceUpdate = false)
  {
    if (!forceUpdate && unit == newUnit)
      return

    checkInitWidth()
    unit = newUnit
    bulletsManager.setUnit(unit)

    local columnsConfig = null
    let unitType = ::get_es_unit_type(unit)
    if (isInArray(unitType, [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER]))
      columnsConfig = getColumnsAircraft()
    else if (unitType == ES_UNIT_TYPE_TANK || unitType == ES_UNIT_TYPE_SHIP || unitType == ES_UNIT_TYPE_BOAT)
      columnsConfig = getColumnsTank()

    if (!columnsConfig)
    {
      clearScene()
      return
    }

    fillWeaponryByColumnsConfig(columnsConfig)
    updateAllItems()
  }

  function setCanChangeWeaponry(newValue, forceUpdate)
  {
    if (newValue == canChangeWeaponry && !forceUpdate)
      return

    canChangeWeaponry = newValue
    updateShowItemParams()
    if(!unit)
      return

    updateAllItems()
  }

  /*
    columnsConfig = {
      itemWidth = 1
      columns = [  //len <= modsInRow / width
        [
          { id = "string"
            header = "string"  //optional
            itemType = weaponsItem.unknown
            bulGroupIdx = int  //only for bullets
          }
        ]
        ...
      ]
    }
  */
  function fillWeaponryByColumnsConfig(config)
  {
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
    for(; !isLineEmpty; line++)
    {
      isLineEmpty = true
      local needHeader = false
      local bgBlock = getBgBlockBaseTemplate(itemWidth * columns.len())

      let cellsRow = array(columns.len(), null)
      foreach(idx, column in columns)
      {
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
          bgBlock.columnsList.append(getColumnConfig(cell.header, bgBlock.columnsList.len() > 0, itemWidth))
      }

      if (isLineEmpty)
        break

      if (needHeader)
      {
        lineOffset += headerOffset
        bgBlock.offsetY = lineOffset + line
        view.bgBlocks.append(bgBlock)
        lastBgBlock = bgBlock
      } else if (lastBgBlock)
      {
        bgBlock = lastBgBlock
        bgBlock.height++
      }

      bgBlock.rows.append(
      {
        width = itemWidth * columns.len() - bgBlock.offsetX
        top = bgBlock.rows.len()
      })

      view.weaponryList += addItemsByCellsRow(cellsRow, lineOffset + line, itemWidth)
    }

    this.scene.height = (lineOffset + line) + "@modCellHeight"
    if (!needRecountWidth)
      this.scene.width = (itemWidth * columns.len()) + "@modCellWidth"
    let data = ::handyman.renderCached("%gui/weaponry/weaponry", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
  }

  function getBgBlockBaseTemplate(width)
  {
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

  function getColumnConfig(header, needDivLine = false, width = 1)
  {
    return {
      name = header
      needDivLine = needDivLine
      width = width
      isSmallFont = true
    }
  }

  function addItemsByCellsRow(cellsRow, offsetY, itemWidth = 1)
  {
    local res = ""
    let params = {
      posX = 0
      posY = offsetY
      itemWidth = itemWidth
      needSliderButtons = true
      wideItemWithSlider = itemWidth > 1
    }
    foreach(idx, cell in cellsRow)
    {
      if (!cell)
        continue

      params.posX = itemWidth * idx
      local item = null
      if (cell.itemType == weaponsItem.weapon)
        item = getCurWeapon()
      else if (cell.itemType == weaponsItem.modification)
        item = getCurBullet(cell.bulGroupIdx)

      if (item)
        res += createModItemLayout(cell.id, unit, item, cell.itemType, params)
    }
    return res
  }

  function getBulletsItemId(groupIdx)
  {
    return bulletsIdPrefix + groupIdx
  }

  function getCellConfig(id = "", header = null, itemType = weaponsItem.unknown, bulGroupIdx = 0)
  {
    return {
      id = id
      header = header
      itemType = itemType
      bulGroupIdx = bulGroupIdx
    }
  }

  function getEmptyColumnsConfig()
  {
    return {
      itemWidth = 1
      columns = []
    }
  }

  function getColumnsAircraft()
  {
    let res = getEmptyColumnsConfig()
    if (isUnitHaveSecondaryWeapons(unit))
      res.columns.append([getCellConfig(weaponItemId, ::g_weaponry_types.WEAPON.getHeader(unit), weaponsItem.weapon)])

    let groups = getBulletsGroups()
    let offset = res.columns.len() < modsInRow ? res.columns.len() : 0
    let totalColumns = min(offset + groups.len(), modsInRow)
    for(local i = res.columns.len(); i < totalColumns; i++)
      res.columns.append([])

    foreach(gIdx, bulGroup in groups)
    {
      let col = offset + (gIdx % (totalColumns - offset))
      res.columns[col].append(getCellConfig(getBulletsItemId(gIdx), bulGroup.getHeader(), weaponsItem.modification, gIdx))
    }

    return res
  }

  function getColumnsTank()
  {
    let groups = getBulletsGroups()
    let gunsCount = bulletsManager.getGunTypesCount()
    if (!gunsCount)
      return null

    let res = getEmptyColumnsConfig()
    if (canChangeBulletsAmount)
      res.itemWidth = 1.5
    if (gunsCount == 1)
    {
      let totalMods = bulletsManager.getActiveBulGroupsAmount()
      local totalColumns = 0

      if (totalMods > 0)
      {
        let totalRows = ceil(totalMods.tofloat() / modsInRow * res.itemWidth).tointeger()
        totalColumns = ceil(totalMods.tofloat() / totalRows).tointeger()
      }

      for(local i = res.columns.len(); i < totalColumns; i++)
        res.columns.append([])
      foreach(gIdx, bulGroup in groups)
      {
        if (!bulGroup.active || bulGroup.shouldHideBullet())
          continue
        let col = gIdx % totalColumns
        let header = !gIdx ? bulGroup.getHeader() : null
        res.columns[col].append(getCellConfig(getBulletsItemId(gIdx), header, weaponsItem.modification, gIdx))
      }
      return addSecondaryWeaponToTankColumns(res)
    }

    local totalColumns = gunsCount
    for(local i = res.columns.len(); i < totalColumns; i++)
      res.columns.append([])
    foreach(gIdx, bulGroup in groups)
    {
      if (!bulGroup.active || bulGroup.shouldHideBullet())
        continue
      let col = bulGroup.getGunIdx()
      let header = !res.columns[col].len() ? bulGroup.getHeader() : null
      res.columns[col].append(getCellConfig(getBulletsItemId(gIdx), header, weaponsItem.modification, gIdx))
    }

    let maxColumns = (modsInRow / res.itemWidth) || 1
    if (gunsCount == 3 && maxColumns == 2)
    {
      let newColumns = [[], []]
      local singleItemIdx = -1
      foreach(idx, column in res.columns)
      {
        if (column.len() > 1)
        {
          newColumns[0].append(column[0])
          newColumns[1].append(column[1])
        } else if (singleItemIdx == -1)
        {
          newColumns[0].append(column[0])
          newColumns[1].append(null)
          singleItemIdx = idx
        } else if (column.len() != 0)
          newColumns[1][singleItemIdx] = column[0]
      }
      res.columns = newColumns
      totalColumns = 2
    }

    if (maxColumns < totalColumns)
      for(local i = res.columns.len() - 1; i >= maxColumns; i--)
      {
        res.columns[i % maxColumns].extend(res.columns[i])
        res.columns.remove(i)
      }

    return addSecondaryWeaponToTankColumns(res)
  }

  function addSecondaryWeaponToTankColumns(colData)
  {
    if (!isUnitHaveSecondaryWeapons(unit))
      return colData

    let weaponCell = getCellConfig(weaponItemId, ::g_weaponry_types.WEAPON.getHeader(unit), weaponsItem.weapon)
    let maxColumns = (modsInRow / colData.itemWidth) || 1
    if (colData.columns.len() < maxColumns)
      colData.columns.insert(0, [weaponCell])
    else
      foreach(idx, column in colData.columns)
        column.insert(0, idx ? null : weaponCell)
    return colData
  }

  function clearScene()
  {
    this.scene.height = "0"
    this.guiScene.replaceContentFromText(this.scene, "", 0, this)
  }

  function getCurWeapon()
  {
    local defWeapon = null
    let weaponName = getLastWeapon(unit.name)
    foreach(weapon in unit.getWeapons())
    {
      let found = weapon.name == weaponName
      //no point to check all weapons visibility and counts when we need only one
      if (!found && defWeapon)
        continue

      if (!isForcedAvailable &&
          (!isWeaponVisible(unit, weapon) || !isWeaponEnabled(unit, weapon)))
        continue

      if (found)
        return weapon

      if (!defWeapon)
        defWeapon = weapon
    }
    if (defWeapon) //validate selected weapon
      setWeapon(defWeapon.name)
    return defWeapon
  }

  function setWeapon(name) {
    setLastWeapon(unit.name, name)
  }

  function hasWeaponsToChooseFrom()
  {
    local count = 0
    let hasOnlySelectable = !::is_in_flight() || !::g_mis_custom_state.getCurMissionRules().isWorldWar
    foreach(weapon in unit.getWeapons())
    {
      if (!isForcedAvailable && !isWeaponVisible(unit, weapon, hasOnlySelectable))
        continue

      count++
      if (count > 1)
        return true
    }
    return false
  }

  getBulletsGroups = @() bulletsManager.getBulletsGroups()
  getBulletGroupByIndex = @(groupIdx) getBulletsGroups()?[groupIdx]

  function getCurBullet(groupIdx)
  {
    let bulGroup = getBulletGroupByIndex(groupIdx)
    return bulGroup && bulGroup.getSelBullet()
  }

  function updateWeapon()
  {
    if (!isUnitHaveSecondaryWeapons(unit))
      return

    let itemObj = this.scene.findObject(weaponItemId)
    if (!checkObj(itemObj))
      return

    showItemParams.hasMenu <- canChangeWeaponry && hasWeaponsToChooseFrom()
    let curWeapon = getCurWeapon()
    itemObj.show(curWeapon)
    if (!curWeapon)
      return

    updateModItem(unit, curWeapon, itemObj, false, this, showItemParams)
    showItemParams.hasMenu = false
  }

  function updateBullets()
  {
    let groups = getBulletsGroups()
    foreach(gIdx, bulGroup in groups)
    {
      let itemObj = this.scene.findObject(getBulletsItemId(gIdx))
      if (!checkObj(itemObj))
        continue

      showItemParams.visualDisabled <- !bulGroup.active
      showItemParams.hasMenu <- canChangeWeaponry && bulGroup.bullets.values.len() > 1
      updateModItem(unit, bulGroup.getSelBullet(), itemObj, false, this, showItemParams)
    }
    showItemParams.visualDisabled <- false
    showItemParams.hasMenu <- false
  }

  function updateBulletCountSlider(bulGroup, groupIdx)
  {
    let itemObj = this.scene.findObject(getBulletsItemId(groupIdx))
    if (checkObj(itemObj))
      updateItemBulletsSlider(itemObj, bulletsManager, bulGroup)
  }

  //included to updateBullets but much faster than full bullets update
  function updateAllBulletCountSliders()
  {
    let groups = getBulletsGroups()
    foreach(gIdx, bulGroup in groups)
      updateBulletCountSlider(bulGroup, gIdx)
  }

  function updateAllItems()
  {
    updateWeapon()
    updateBullets()
  }

  function onEventUnitWeaponChanged(_p)
  {
    updateAllItems()
  }

  function onEventBulletsGroupsChanged(_p)
  {
    updateBullets()
  }

  function onEventBulletsCountChanged(_p)
  {
    updateAllBulletCountSliders()
  }

  function getSelectionItemParams()
  {
    let res = clone showItemParams
    delete res.selectBulletsByManager
    return res
  }

  function getBulletGroupByItemId(id)
  {
    let idxStr = ::g_string.cutPrefix(id, bulletsIdPrefix, -1)
    return getBulletGroupByIndex(::to_integer_safe(idxStr, -1))
  }

  function openChangeWeaponryMenu(obj)
  {
    if (!canChangeWeaponry || !checkObj(obj))
      return

    let id = obj.holderId
    if (id == weaponItemId)
    {
      if (hasWeaponsToChooseFrom())
        ::gui_start_choose_unit_weapon(unit, null, {
          itemParams = getSelectionItemParams()
          alignObj = obj
          isForcedAvailable = isForcedAvailable
        })
      return
    }

    let group = getBulletGroupByItemId(id)
    if (!group)
      return

    if (group.active)
    {
      if (group.bullets.values.len() > 1)
        bulletsManager.openChooseBulletsWnd(group.groupIndex, getSelectionItemParams(), obj)
    } else
      ::showInfoMsgBox(loc("msg/secondaryWeaponrequired"))
  }

  function onModItemClick(obj)
  {
    openChangeWeaponryMenu(obj)
  }

  function onWeaponryActivate(obj)
  {
    let value = obj.getValue()
    if (0 <= value && value < obj.childrenCount())
      openChangeWeaponryMenu(obj.getChild(value).findObject("centralBlock"))
  }

  function onModChangeBulletsSlider(obj)
  {
    if (!checkObj(obj))
      return
    let groupIndex = ::to_integer_safe(obj?.groupIdx ?? "", -1)
    let bulGroup= getBulletGroupByIndex(groupIndex)
    if (!bulGroup)
      return

    if (!bulletsManager.changeBulletsCount(bulGroup, obj.getValue()))
      updateBulletCountSlider(bulGroup, groupIndex) //move back current slider when value not changed
  }

  function onChangeBullets(diff = 1) //gamepad shortcut - search selected
  {
    if (!bulletsManager.canChangeBulletsCount())
      return
    let listObj = this.scene.findObject("weaponry_list")
    if (!checkObj(listObj) || !listObj.isFocused())
      return
    let idx = listObj.getValue()
    if (idx < 0 || listObj.childrenCount() <= idx)
      return

    let itemObj = listObj.getChild(idx)
    let id = ::g_string.cutPrefix(itemObj.id, bulletsIdPrefix, -1)
    let groupIdx = ::to_integer_safe(id, -1)
    let group = getBulletGroupByIndex(groupIdx)
    if (!group)
      return

    let step = max(group.getGunMaxBullets() / 20, 1).tointeger()
    bulletsManager.changeBulletsCount(group, group.bulletsCount + diff * step)
  }

  function onBulletsDecrease() { onChangeBullets(-1) }
  function onBulletsIncrease() { onChangeBullets(1) }

  function onModChangeBullets(obj, diff = 1) //real button, can be called not for selected mod, but have holderId
  {
    let group = getBulletGroupByItemId(obj.holderId)
    if (group)
      bulletsManager.changeBulletsCount(group, group.bulletsCount + diff)
  }

  function onModDecreaseBullets(obj) { onModChangeBullets(obj, -1) }
  function onModIncreaseBullets(obj) { onModChangeBullets(obj, 1) }
}
