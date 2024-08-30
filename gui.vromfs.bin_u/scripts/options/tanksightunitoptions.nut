from "%scripts/dagui_library.nut" import *
let enums = require("%sqStdLibs/helpers/enums.nut")
let { format } = require("string")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { hasUnitAtRank, get_units_list } = require("%scripts/airInfo.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isCountryHaveUnitType } = require("%scripts/shop/shopUnitsInfo.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { hangar_get_current_unit_name } = require("hangar")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { create_option_combobox, image_for_air } = require("%scripts/options/optionsExt.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")

local sightUnitOptions = {
  types = []

  function addTypes(typesTable) {
    enums.addTypes(this, typesTable, null, "id")
    this.types.sort(@(a, b) a.order <=> b.order)
  }
}

sightUnitOptions.template <-  {
  id = ""
  order = 0
  options = []
  value = null

  updateOptions = @() null
  getControlMarkup = @() create_option_combobox(this.id, [], -1, "onChangeUnitOption", false)
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
        .filter(@(c) isCountryHaveUnitType(c, ES_UNIT_TYPE_TANK))
        .map(@(country) {
          value = country
          text = loc(country)
          image = getCountryIcon(country)
        })
      if (this.value == null) {
        let curCountry = profileCountrySq.value
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
      this.options = array(MAX_COUNTRY_RANK)
        .map(@(_, idx) idx + 1)
        .filter(@(rank) hasUnitAtRank(rank, ES_UNIT_TYPE_TANK, country, true, true))
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
        .sort(@(a, b) a.br <=> b.br)
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
  let unitName = hangar_get_current_unit_name()
  let unit = getAircraftByName(unitName) ?? getPlayerCurUnit()
  let canSelectCurUnit = unit?.esUnitType == ES_UNIT_TYPE_TANK
  if (canSelectCurUnit) {
    this.UNIT.value = unitName
    this.COUNTRY.value = unit.shopCountry
    this.RANK.value = unit.rank
  }
  this.types.each(@(o) o.update(handler, scene))
}

return sightUnitOptions

