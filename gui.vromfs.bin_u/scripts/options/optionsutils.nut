local { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")

local checkArgument = function(id, arg, varType) {
  if (typeof arg == varType)
    return true

  local msg = "[ERROR] Wrong argument type supplied for option item '" + id + ".\n"
  msg += "Value = " + ::toString(arg) + ".\n"
  msg += "Expected '" + varType + "' found '" + typeof arg + "'."

  ::script_net_assert_once(id, msg)
  return false
}

local createDefaultOption = function() {
  return {
    type = -1
    id = ""
    title = null //"options/" + descr.id
    hint = null  //"guiHints/" + descr.id
    value = null
    controlType = optionControlType.LIST

    context = null
    cb = null
    items = null
    values = null
    needShowValueText = false
    diffCode = null

    getTrId = @() id + "_tr"

    getTitle = @() title || ::loc("options/" + id)

    getCurrentValueLocText = @() getValueLocText(value)

    getValueLocText = function(val) {
      switch(controlType)
      {
        case optionControlType.CHECKBOX:
          if (val == true)
            return ::loc("options/yes")
          else if (val == false)
            return ::loc("options/no")
          break

        case optionControlType.LIST:
          local result = ::getTblValue(values.indexof(val), items)
          local locKey = (::u.isString(result)) ? result : ::getTblValue("text", result, "")
          if (::g_string.startsWith(locKey, "#"))
            locKey = locKey.slice(1)
          return ::loc(locKey)

        case optionControlType.SLIDER:
        case optionControlType.EDITBOX:
        case optionControlType.BIT_LIST:
        default:
          if(val != null)
            return val.tostring()
          break
      }
      return ""
    }

    onChangeCb = null
  }
}

local fillBoolOption = function(descr, id, optionIdx)
{
  descr.id = id
  descr.controlType = optionControlType.CHECKBOX
  descr.controlName <- "switchbox"
  descr.value = ::get_option_bool(optionIdx)
  descr.boolOptionIdx <- optionIdx
}

local setHSVOption_ThermovisionColor = function(desrc, value)
{
  ::set_thermovision_index(value)
}

local fillHSVOption_ThermovisionColor = function(descr)
{
  descr.id = "color_picker_hue_tank_tv"
  descr.items = []
  descr.values = []

  local idx = 0
  foreach( it in ::thermovision_colors )
  {
    descr.items.append( {rgb = it.menu_rgb} )
    descr.values.append( idx )
    idx++
  }

  descr.value = ::get_thermovision_index()
}

local fillHueOption = function(descr, id, defHue = null, curHue = null, customItems = null)
{
  local hueStep = 22.5
  if (curHue==null)
    curHue = ::get_gui_option(descr.type)
  if (!::is_numeric(curHue))
    curHue = -1

  descr.id = id
  descr.items = []
  descr.values = []
  if (defHue != null)
  {
    descr.items.append({ hue = defHue, text = ::loc("options/hudDefault")})
    descr.values.append(defHue)
  }

  if (customItems == null)
  {
    //default palette
    local even = false
    for(local hue = 0.0001; hue < 360.0 - 0.5*hueStep; hue += hueStep)
    {
      local h = hue + (even ? 360.0 : 0)
      descr.items.append({ hue = h })
      descr.values.append(h)
      h = hue + (even ? 0 : 360.0)
      descr.items.append({ hue = h })
      descr.values.append(h)
      even = !even
    }
  }
  else
  {
    //custom items in option list
    foreach(item in customItems)
    {
      descr.items.append({ hue = item })
      descr.values.append(item)
    }
  }

  local valueIdx = ::find_nearest(curHue, descr.values)
  if (curHue == -1)
    valueIdx = 0 // defValue
  if (valueIdx >= 0)
    descr.value = valueIdx
}

local fillDynMapOption = function(descr)
{
  local curMap = getTblValue("layout", ::mission_settings)
  local dynLayouts = ::get_dynamic_layouts()
  foreach(layout in dynLayouts)
  {
    if (::get_game_mode() == ::GM_BUILDER)
    {
      local db = blkFromPath(layout.mis_file)
      local tags = db.mission_settings.mission.tags % "tag"
      local airTags = ::show_aircraft.tags
      local skip = false
      foreach (tag in tags)
      {
        local found = false
        foreach (atag in airTags)
          if (atag == tag)
          {
            found = true
            break
          }
        if (!found)
        {
          skip = true
          dagor.debug("SKIP "+layout.name+" because of tag "+tag)
          break
        }
      }
      if (skip)
        continue
    }
    descr.items.append("#dynamic/" + layout.name)
    local map = layout.mis_file
    descr.values.append(map)
    if (map == curMap)
      descr.value <- descr.values.len() - 1
  }

  if (descr.items.len() == 0 && dynLayouts.len() > 0)
  {
    dagor.debug("[WARNING] All dynamic layouts are skipped due to tags of current aircraft. Adding '" +
      dynLayouts[0].name + "' to avoid empty list.")

    // must be at least one dynamic layout in USEROPT_DYN_MAP
    descr.items.append("#dynamic/" + dynLayouts[0].name)
    descr.values.append(dynLayouts[0].mis_file)
  }
}

return {
  checkArgument = checkArgument

  createDefaultOption = createDefaultOption
  fillBoolOption = fillBoolOption
  fillHueOption = fillHueOption
  fillDynMapOption = fillDynMapOption
  setHSVOption_ThermovisionColor = setHSVOption_ThermovisionColor
  fillHSVOption_ThermovisionColor = fillHSVOption_ThermovisionColor
}