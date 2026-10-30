import "%sqStdLibs/helpers/enums.nut" as enums
from "%scripts/shop/shopCountryInfo.nut" import hasUnitAtRank, get_units_list
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%scripts/ranks.nut" import maxCountryRank
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/unit/unitInfo.nut" import getUnitName, image_for_air
from "%scripts/slotbar/playerCurUnit.nut" import getPlayerCurUnit
from "string" import format
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_combobox

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

local sightUnitOptions = {
  types = []

  function addTypes(typesTable) {
    enums.addTypes(this, typesTable, null, "id")
    this.types.sortby(@(a) a.order)
  }
}

sightUnitOptions.template <-  {
  id = ""
  order = 0
  options = []
  value = null
  controlMarkupParams = null

  updateOptions = @() null
  getControlMarkup = @() create_option_combobox(this.id, [], -1, "onChangeUnitOption",
    false, this.controlMarkupParams ?? {})
  getValFromObj = @(obj) obj?.isValid() ? this.options?[obj.getValue()].value : null
  afterChangeFunc = null

  function updateView(handler, scene) {
    let obj = scene.findObject(this.id)
    if (!obj?.isValid())
      return
    let { value } = this
    let idx = this.options.findindex(@(opt) opt.value == value) ?? 0
    let opts = this.options.map(@(o) {
      text = o.text
      image = o?.image
      addDiv = o?.addDiv
    })
    let markup = create_option_combobox(this.id, opts, idx, null, false)
    obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
  }

  function update(handler, scene) {
    this.updateOptions()
    this.updateView(handler, scene)
  }

  function onChange(handler, scene, obj) {
    this.value = this.getValFromObj(obj)
    this.afterChangeFunc?(handler, scene)
  }
}

local orderCount = 0
sightUnitOptions.addTypes({
  COUNTRY = {
    order = orderCount++

    function afterChangeFunc(handler, scene) {
      sightUnitOptions.RANK.update(handler, scene)
      sightUnitOptions.UNIT.update(handler, scene)
    }

    function updateOptions() {
      this.options = shopCountriesList
        .filter(@(c) hasUnitAtRank(0, ES_UNIT_TYPE_TANK, c, false, false))
        .map(@(country) {
          value = country
          text = loc(country)
          image = getCountryIcon(country)
        })
      if (this.value == null || !this.options.contains(this.value)) {
        let curCountry = profileCountrySq.get()
        let isCurCountryAvailable = this.options.findvalue(@(opt) opt.value == curCountry) != null

        this.value =  isCurCountryAvailable ? curCountry : this.options[0].value
      }
    }
  }

  RANK = {
    order = orderCount++

    function afterChangeFunc (handler, scene) {
      sightUnitOptions.UNIT.update(handler, scene)
    }

    function updateOptions() {
      let country = sightUnitOptions.COUNTRY.value
      this.options = array(maxCountryRank.get())
        .map(@(_, idx) idx + 1)
        .filter(@(rank) hasUnitAtRank(rank, ES_UNIT_TYPE_TANK, country, true, false))
        .map(@(rank) {
          value = rank
          text = format(loc("conditions/unitRank/format"), get_roman_numeral(rank))
        })
      let  { value } = this
      let isCurRankAvailable = this.options.findvalue(@(opt) opt.value == value) != null
      if (this.value == null || !isCurRankAvailable)
        this.value = this.options[0].value
    }
  }

  UNIT = {
    order = orderCount++
    controlMarkupParams = { beforeSelectCb = "onBeforeSelectComboboxValue" }

    updateOptions = function() {
      let rank = sightUnitOptions.RANK.value
      let country = sightUnitOptions.COUNTRY.value
      let ediff = getCurrentGameModeEdiff()
      let units = get_units_list(@(unit) unit.esUnitType == ES_UNIT_TYPE_TANK
        && unit.shopCountry == country && unit.rank == rank && unit.isVisibleInShop())
      this.options = units
        .map(@(unit) {
          unit
          br = unit.getBattleRating(ediff)
        })
        .sortby(@(a) a.br)
        .map(@(v) {
          value = v.unit.name
          text  = format("[%.1f] %s", v.br, getUnitName(v.unit.name))
          image = image_for_air(v.unit)
          addDiv = getTooltipType("UNIT").getMarkup(v.unit.name, { showLocalState = false })
        })

      let selectAllUnitsOption = { value = "", text = loc("units_all") }
      this.options.insert(0, selectAllUnitsOption)
      let { value } = this
      let isCurUnitAvailable = this.options.findvalue(@(opt) opt.value == value) != null
      if (this.value == null || !isCurUnitAvailable)
        this.value = this.options[0].value
    }
  }
})

sightUnitOptions.init <- function(handler, scene) {
  let unit = getPlayerCurUnit()
  let canSelectCurUnit = unit?.esUnitType == ES_UNIT_TYPE_TANK
  if (canSelectCurUnit) {
    this.UNIT.value = unit.name
    this.COUNTRY.value = unit.shopCountry
    this.RANK.value = unit.rank
  }
  this.types.each(@(o) o.update(handler, scene))
}

return sightUnitOptions
