local { getLastWeapon, setLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")

class ::gui_handlers.unitWeaponsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  unit = null
  parentHandlerWeak = null
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
  isPrimaryFocus = false

  function initScreen()
  {
    if (parentHandlerWeak)
      parentHandlerWeak = parentHandlerWeak.weakref() //we are miss weakref on assigning from params table

    bulletsManager = ::UnitBulletsManager(unit)
    updateShowItemParams()
    setUnit(unit, true)
  }

  function checkInitWidth()
  {
    if (!needRecountWidth || !scene.isVisible() || scene.getSize()[0] <= 0)
      return

    local sizes = ::g_dagui_utils.countSizeInItems(scene, "@modCellWidth", "@modCellHeight", 0, 0)
    modsInRow = sizes.itemsCountX
    scene.width = modsInRow + "@modCellWidth"
    needRecountWidth = false
  }

  function updateShowItemParams()
  {
    showItemParams = {
      useGenericTooltip = true
      canShowPrice = canShowPrice
      canShowStatusImage = false
      selectBulletsByManager = (canChangeWeaponry && canChangeBulletsAmount) ? bulletsManager : null
      hasMenu = false
      isForceHidePlayerInfo = isForcedAvailable && !::isUnitUsable(unit)
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
    local unitType = ::get_es_unit_type(unit)
    if (::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER]))
      columnsConfig = getColumnsAircraft()
    else if (unitType == ::ES_UNIT_TYPE_TANK || unitType == ::ES_UNIT_TYPE_SHIP)
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
    local view = {
      bgBlocks = []
      weaponryList = ""
    }

    local itemWidth = config.itemWidth
    local columns = config.columns

    local isLineEmpty = false
    local lineOffset = 0.0
    local lastBgBlock = null
    local line = 0
    for(; !isLineEmpty; line++)
    {
      isLineEmpty = true
      local needHeader = false
      local bgBlock = getBgBlockBaseTemplate(itemWidth * columns.len())

      local cellsRow = array(columns.len(), null)
      foreach(idx, column in columns)
      {
        local cell = ::getTblValue(line, column)
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

    scene.height = (lineOffset + line) + "@modCellHeight"
    if (!needRecountWidth)
      scene.width = (itemWidth * columns.len()) + "@modCellWidth"
    local data = ::handyman.renderCached("gui/weaponry/weaponry", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)
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
    local params = {
      posX = 0
      posY = offsetY
      useGenericTooltip = true
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
        res += ::weaponVisual.createItemLayout(cell.id, item, cell.itemType, params)
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
    local res = getEmptyColumnsConfig()
    if (::isAirHaveSecondaryWeapons(unit))
      res.columns.append([getCellConfig(weaponItemId, ::g_weaponry_types.WEAPON.getHeader(unit), weaponsItem.weapon)])

    local groups = bulletsManager.getBulletsGroups(isForcedAvailable)
    local offset = res.columns.len() < modsInRow ? res.columns.len() : 0
    local totalColumns = ::min(offset + groups.len(), modsInRow)
    for(local i = res.columns.len(); i < totalColumns; i++)
      res.columns.append([])

    foreach(gIdx, bulGroup in groups)
    {
      local col = offset + (gIdx % (totalColumns - offset))
      res.columns[col].append(getCellConfig(getBulletsItemId(gIdx), bulGroup.getHeader(), weaponsItem.modification, gIdx))
    }

    return res
  }

  function getColumnsTank()
  {
    local groups = bulletsManager.getBulletsGroups(isForcedAvailable)
    local gunsCount = bulletsManager.getGunTypesCount()
    if (!gunsCount)
      return null

    local res = getEmptyColumnsConfig()
    if (canChangeBulletsAmount)
      res.itemWidth = 1.5
    if (gunsCount == 1)
    {
      local totalMods = bulletsManager.getActiveBulGroupsAmount()
      local totalColumns = 0

      if (totalMods > 0)
      {
        local totalRows = ::ceil(totalMods.tofloat() / modsInRow * res.itemWidth).tointeger()
        totalColumns = ::ceil(totalMods.tofloat() / totalRows).tointeger()
      }

      for(local i = res.columns.len(); i < totalColumns; i++)
        res.columns.append([])
      foreach(gIdx, bulGroup in groups)
      {
        if (!bulGroup.active || bulGroup.shouldHideBullet())
          continue
        local col = gIdx % totalColumns
        local header = !gIdx ? bulGroup.getHeader() : null
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
      local col = bulGroup.getGunIdx()
      local header = !res.columns[col].len() ? bulGroup.getHeader() : null
      res.columns[col].append(getCellConfig(getBulletsItemId(gIdx), header, weaponsItem.modification, gIdx))
    }

    local maxColumns = (modsInRow / res.itemWidth) || 1
    if (gunsCount == 3 && maxColumns == 2)
    {
      local newColumns = [[], []]
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
    if (!::isAirHaveSecondaryWeapons(unit))
      return colData

    local weaponCell = getCellConfig(weaponItemId, ::g_weaponry_types.WEAPON.getHeader(unit), weaponsItem.weapon)
    local maxColumns = (modsInRow / colData.itemWidth) || 1
    if (colData.columns.len() < maxColumns)
      colData.columns.insert(0, [weaponCell])
    else
      foreach(idx, column in colData.columns)
        column.insert(0, idx ? null : weaponCell)
    return colData
  }

  function clearScene()
  {
    scene.height = "0"
    guiScene.replaceContentFromText(scene, "", 0, this)
  }

  function getCurWeapon()
  {
    local defWeapon = null
    local weaponName = getLastWeapon(unit.name)
    foreach(weapon in unit.weapons)
    {
      local found = weapon.name == weaponName
      //no point to check all weapons visibility and counts when we need only one
      if (!found && defWeapon)
        continue

      if (!isForcedAvailable &&
          (!::is_weapon_visible(unit, weapon) || !::is_weapon_enabled(unit, weapon)))
        continue

      if (found)
        return weapon

      if (!defWeapon)
        defWeapon = weapon
    }
    if (defWeapon) //validate selected weapon
      setLastWeapon(unit.name, defWeapon.name)
    return defWeapon
  }

  function hasWeaponsToChooseFrom()
  {
    local count = 0
    local hasOnlyBought = !::is_in_flight() || !::g_mis_custom_state.getCurMissionRules().isWorldWar
    foreach(weapon in unit.weapons)
    {
      if (!isForcedAvailable && !::is_weapon_visible(unit, weapon, hasOnlyBought))
        continue

      count++
      if (count > 1)
        return true
    }
    return false
  }

  function getBulletGroupByIndex(groupIdx)
  {
    return ::getTblValue(groupIdx, bulletsManager.getBulletsGroups(isForcedAvailable))
  }

  function getCurBullet(groupIdx)
  {
    local bulGroup = getBulletGroupByIndex(groupIdx)
    return bulGroup && bulGroup.getSelBullet()
  }

  function updateWeapon()
  {
    if (!::isAirHaveSecondaryWeapons(unit))
      return

    local itemObj = scene.findObject(weaponItemId)
    if (!::checkObj(itemObj))
      return

    showItemParams.hasMenu <- canChangeWeaponry && hasWeaponsToChooseFrom()
    local curWeapon = getCurWeapon()
    itemObj.show(curWeapon)
    if (!curWeapon)
      return

    ::weaponVisual.updateItem(unit, curWeapon, itemObj, false, this, showItemParams)
    showItemParams.hasMenu = false
  }

  function updateBullets()
  {
    local groups = bulletsManager.getBulletsGroups(isForcedAvailable)
    foreach(gIdx, bulGroup in groups)
    {
      local itemObj = scene.findObject(getBulletsItemId(gIdx))
      if (!::checkObj(itemObj))
        continue

      showItemParams.visualDisabled <- !bulGroup.active
      showItemParams.hasMenu <- canChangeWeaponry && bulGroup.bullets.values.len() > 1
      ::weaponVisual.updateItem(unit, bulGroup.getSelBullet(), itemObj, false, this, showItemParams)
    }
    showItemParams.visualDisabled <- false
    showItemParams.hasMenu <- false
  }

  function updateBulletCountSlider(bulGroup, groupIdx)
  {
    local itemObj = scene.findObject(getBulletsItemId(groupIdx))
    if (::checkObj(itemObj))
      ::weaponVisual.updateItemBulletsSlider(itemObj, bulletsManager, bulGroup)
  }

  //included to updateBullets but much faster than full bullets update
  function updateAllBulletCountSliders()
  {
    local groups = bulletsManager.getBulletsGroups(isForcedAvailable)
    foreach(gIdx, bulGroup in groups)
      updateBulletCountSlider(bulGroup, gIdx)
  }

  function updateAllItems()
  {
    updateWeapon()
    updateBullets()
  }

  function onEventUnitWeaponChanged(p)
  {
    updateAllItems()
  }

  function onEventBulletsGroupsChanged(p)
  {
    updateBullets()
  }

  function onEventBulletsCountChanged(p)
  {
    updateAllBulletCountSliders()
  }

  function getSelectionItemParams()
  {
    local res = clone showItemParams
    delete res.selectBulletsByManager
    return res
  }

  function getBulletGroupByItemId(id)
  {
    local idxStr = ::g_string.cutPrefix(id, bulletsIdPrefix, -1)
    return getBulletGroupByIndex(::to_integer_safe(idxStr, -1))
  }

  function openChangeWeaponryMenu(obj)
  {
    if (!canChangeWeaponry || !::checkObj(obj))
      return

    local id = obj.holderId
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

    local group = getBulletGroupByItemId(id)
    if (!group)
      return

    if (group.active)
    {
      if (group.bullets.values.len() > 1)
        bulletsManager.openChooseBulletsWnd(group.groupIndex, getSelectionItemParams(), obj)
    } else
      ::showInfoMsgBox(::loc("msg/secondaryWeaponrequired"))
  }

  function onModItemClick(obj)
  {
    openChangeWeaponryMenu(obj)
  }

  function onWeaponryActivate(obj)
  {
    local value = obj.getValue()
    if (0 <= value && value <= obj.childrenCount())
      openChangeWeaponryMenu(obj.getChild(value).findObject("centralBlock"))
  }

  function onModChangeBulletsSlider(obj)
  {
    if (!::checkObj(obj))
      return
    local groupIndex = ::to_integer_safe(obj?.groupIdx ?? "", -1)
    local bulGroup= getBulletGroupByIndex(groupIndex)
    if (!bulGroup)
      return

    if (!bulletsManager.changeBulletsCount(bulGroup, obj.getValue()))
      updateBulletCountSlider(bulGroup, groupIndex) //move back current slider when value not changed
  }

  function wrapNextSelect(obj = null, dir = 0)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak))
      parentHandlerWeak.wrapNextSelect(obj, dir)
  }

  function onWrapLeft(obj)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak)
        && ::u.isFunction(parentHandlerWeak.onWrapLeft))
      parentHandlerWeak.onWrapLeft(obj)
  }

  function onWrapRight(obj)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak)
        && ::u.isFunction(parentHandlerWeak.onWrapRight))
      parentHandlerWeak.onWrapRight(obj)
  }

  function getMainFocusObj()
  {
    return scene.findObject("weaponry_list")
  }

  function onChangeBullets(diff = 1) //gamepad shortcut - search selected
  {
    if (!bulletsManager.canChangeBulletsCount())
      return
    local listObj = scene.findObject("weaponry_list")
    if (!::checkObj(listObj) || !listObj.isFocused())
      return
    local idx = listObj.getValue()
    if (idx < 0 || listObj.childrenCount() <= idx)
      return

    local itemObj = listObj.getChild(idx)
    local id = ::g_string.cutPrefix(itemObj.id, bulletsIdPrefix, -1)
    local groupIdx = ::to_integer_safe(id, -1)
    local group = getBulletGroupByIndex(groupIdx)
    if (!group)
      return

    local step = ::max(group.getGunMaxBullets() / 20, 1).tointeger()
    bulletsManager.changeBulletsCount(group, group.bulletsCount + diff * step)
  }

  function onBulletsDecrease() { onChangeBullets(-1) }
  function onBulletsIncrease() { onChangeBullets(1) }

  function onModChangeBullets(obj, diff = 1) //real button, can be called not for selected mod, but have holderId
  {
    local group = getBulletGroupByItemId(obj.holderId)
    if (group)
      bulletsManager.changeBulletsCount(group, group.bulletsCount + diff)
  }

  function onModDecreaseBullets(obj) { onModChangeBullets(obj, -1) }
  function onModIncreaseBullets(obj) { onModChangeBullets(obj, 1) }
}
