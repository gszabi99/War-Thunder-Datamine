local { getStringWidthPx } = require("scripts/viewUtils/daguiFonts.nut")

class ::gui_handlers.popupFilter extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "gui/popup/popupFilter"

  stateList            = null
  isFilterVisible      = false
  iconNestObj          = null

  //init params
  filterTypes          = null
  btnTitle             = null
  onChangeFn           = null

  function getSceneTplView()
  {
    local rowsCount = 0
    local maxTextWidth = 0

    foreach (fType in filterTypes)
    {
      rowsCount = ::max(rowsCount, fType.checkbox.len())
      foreach (cb in fType.checkbox)
        if (cb?.text)
          maxTextWidth = ::max(maxTextWidth, getStringWidthPx(cb.text, "fontNormal"))
    }

    local columns = filterTypes.map(function(fType, idx) {
      local { checkbox } = fType
      if (!checkbox.len())
        return null

      local typeName = checkbox[checkbox.len()-1].id.split("_")[0]
      local params = $"pos:t='0, 1@popupFilterRowHeight-h'; type:t='rightSideCb'; typeName:t={typeName}"
      return fType.__merge({
        typeName
        isLast = false
        checkbox = checkbox.map(function(cb) {
          local isMultiple = cb.id == "all_items"
          return cb.__merge({
            isMultiple
            typeName
            funcName = isMultiple ? "onSelectAllChange" : "onCheckBoxChange"
            specialParams = params
            textWidth = maxTextWidth
          })
        })
      })
    }).filter(@(inst) inst != null)
    columns[columns.len()-1].isLast = true

    local imgItems = columns.reduce(@(res, inst)
      res.extend(inst.checkbox.filter(@(cb) !cb.isMultiple)), [])

    stateList = {}
    foreach( inst in imgItems)
      stateList[inst.id] <- inst

    return {
      rowsCount = rowsCount
      columns = columns
      btnTitle = btnTitle ?? ::loc("stats_filter_show")
      underPopupClick    = "onShowFilterBtnClick"
      underPopupDblClick = "onShowFilterBtnClick"
      items = imgItems
    }
  }

  function initScreen()
  {
    iconNestObj = scene.findObject("icon_nest")
  }

  function updateColumns(typeName)
  {
    local curList  = stateList.filter(@(inst) inst.typeName == typeName)
    local columnObj = scene.findObject($"{typeName}_column")
    if (!columnObj?.isValid())
      return

    for (local i = 0; i < columnObj.childrenCount(); i++)
    {
      local child = columnObj.getChild(i)
      if (child.id == "all_items")
        child.setValue(curList.findvalue(@(v) !v.value) == null)
      else
        child.setValue(curList[child.id].value)
    }
  }

  function onSelectAllChange(obj)
  {
    if (!onChangeFn)
      return

    local value    = obj.getValue()
    local curList  = stateList.filter(@(inst) inst.typeName == obj.typeName)
    if (value == (curList.findvalue(@(v) !v.value) == null))
      return

    foreach (inst in curList)
    {
      ::showBtn(inst.id, value, iconNestObj)
      inst.value = value
    }

    updateColumns(obj.typeName)
    onChangeFn(obj.id, obj.typeName, value)
  }

  function  onCheckBoxChange(obj)
  {
    if (!onChangeFn)
      return

    local value    = obj.getValue()
    local curInst = stateList[obj.id]
    if (value == curInst.value)
      return


    curInst.value = value
    ::showBtn(obj.id, value, iconNestObj)

    updateColumns(obj.typeName)
    onChangeFn(obj.id, obj.typeName, value)
  }

  function onShowFilterBtnClick(obj)
  {
    isFilterVisible = !isFilterVisible
    ::showBtn("filter_popup", isFilterVisible)
  }
}

return {
  open = function (scene, onChangeFn, filterTypes) {
    ::handlersManager.loadHandler(::gui_handlers.popupFilter,
      {
        scene = scene
        onChangeFn = onChangeFn
        filterTypes = filterTypes
      })
  }
}
