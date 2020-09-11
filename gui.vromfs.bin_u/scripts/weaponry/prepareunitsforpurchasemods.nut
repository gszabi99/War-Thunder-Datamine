local { getAllModsCost } = require("scripts/weaponry/itemInfo.nut")

local unitsTable = {} //unitName - unitBlock

local function clear() { unitsTable = {} }
local function haveUnits() { return unitsTable.len() > 0 }

local function addUnit(unit)
{
  if (!unit)
    return

  unitsTable[unit.name] <- unit
}

local purchaseModifications = @(unitsArray) null
purchaseModifications = function(unitsArray)
{
  if (unitsArray.len() == 0)
  {
    clear()
    ::showInfoMsgBox(::loc("msgbox/all_researched_modifications_bought"), "successfully_bought_mods")
    return
  }

  local curUnit = unitsArray.remove(0)
  ::WeaponsPurchase(
    curUnit,
    {
      afterSuccessfullPurchaseCb = ::Callback(@() purchaseModifications(unitsArray), this),
      silent = true
    }
  )
}

local checkUnboughtMods = @(silent = false) null
checkUnboughtMods = function(silent = false)
{
  if (!haveUnits())
    return

  local cost = ::Cost()
  local unitsWithNBMods = []
  local stringOfUnits = []

  foreach(unitName, unit in unitsTable)
  {
    local modsCost = getAllModsCost(unit)
    if (modsCost.isZero())
      continue

    cost += modsCost
    unitsWithNBMods.append(unit)
    stringOfUnits.append(::colorize("userlogColoredText", ::getUnitName(unit, true)))
  }

  if (unitsWithNBMods.len() == 0)
    return

  if (silent)
  {
    if (::check_balance_msgBox(cost, null, silent))
      purchaseModifications(unitsWithNBMods)
    return
  }

  ::scene_msg_box("buy_all_available_mods", null,
    ::loc("msgbox/buy_all_researched_modifications",
      { unitsList = ::g_string.implode(stringOfUnits, ","), cost = cost.getTextAccordingToBalance() }),
    [["yes", (@(cost, unitsWithNBMods) function() {
        if (!::check_balance_msgBox(cost, @()checkUnboughtMods()))
          return

        purchaseModifications(unitsWithNBMods)
      })(cost, unitsWithNBMods)],
     ["no", @()clear() ]],
      "yes", { cancel_fn = @()clear()})
}

return {
  haveUnits         = haveUnits
  addUnit           = addUnit
  checkUnboughtMods = checkUnboughtMods
}
