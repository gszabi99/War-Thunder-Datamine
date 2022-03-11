local enums = require("sqStdLibs/helpers/enums.nut")
::g_top_menu_sections <- {
  template = {
    name = "unknown"
    visualStyle = "noFrame"
    onClick = "onDropDownToggle"
    hoverMenuPos = "0"
    getText = function(totalSections = 0) { return null }
    getImage = function(totalSections = 0) { return null }
    getWinkImage = function() { return null }
    btnName = null
    buttons = null
    mergeIndex = -1
    haveTmDiscount = false
    forceHoverWidth = null
    isWide = false

    getTopMenuButtonDivId = function() { return "topmenu_" + name }
    getTopMenuDiscountId = function() { return getTopMenuButtonDivId() + "_discount" }
  }
}

g_top_menu_sections.isSeparateTab <- function isSeparateTab(section, totalSections)
{
  return section? section.mergeIndex < totalSections : true
}

g_top_menu_sections.getSectionsOrder <- function getSectionsOrder(sectionsStructure, maxSectionsCount)
{
  local sections = []
  foreach (idx, section in sectionsStructure.types)
  {
    if (!isSeparateTab(section, maxSectionsCount))
      continue

    local result = clone section
    result.buttons = _proceedButtonsArray(section.buttons, maxSectionsCount, sectionsStructure)
    sections.append(result)
  }

  foreach (section in sections)
    clearEmptyColumns(section.buttons)

  return sections
}

g_top_menu_sections._proceedButtonsArray <- function _proceedButtonsArray(itemsArray, maxSectionsCount, sectionsStructure)
{
  local result = []
  foreach (idx, column in itemsArray)
  {
    result.append([])
    foreach (item in column)
    {
      if (::u.isTable(item))
      {
        result[result.len() - 1].append(item)
        continue
      }

      local newSection = sectionsStructure.getSectionByName(item)
      if (isSeparateTab(newSection, maxSectionsCount))
        continue

      local newSectionResult = _proceedButtonsArray(newSection.buttons, maxSectionsCount, sectionsStructure)
      foreach (columnEx in newSectionResult)
        if (columnEx)
          result[result.len() - 1].extend(columnEx)
    }
  }
  return result
}

g_top_menu_sections.clearEmptyColumns <- function clearEmptyColumns(itemsArray)
{
  for (local i = itemsArray.len()-1; i >= 0; i--)
  {
    if (::u.isEmpty(itemsArray[i]))
      itemsArray.remove(i)
    else if (::u.isArray(itemsArray[i]))
      clearEmptyColumns(itemsArray[i])
  }
}

g_top_menu_sections.getSectionByName <- function getSectionByName(name)
{
  return enums.getCachedType("name", name, cache.byName, this, template)
}
