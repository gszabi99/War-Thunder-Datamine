return {
  addOptionMode       = @(modeName) ::add_option_mode?(modeName)
  addUserOption       = @(option) ::add_user_option?(option)
  setGuiOptionsMode   = @(mode) ::set_gui_options_mode?(mode)
  getGuiOptionsMode   = @() ::get_gui_options_mode?()
  setCdOption         = @(optionId, value) ::set_cd_option?(optionId, value)
  getCdOption         = @(optionId) ::get_cd_option?(optionId)
  getCdBaseDifficulty = @() ::get_cd_base_difficulty?()
  clearUnitOption    = @(unitName, optionId) null
}
