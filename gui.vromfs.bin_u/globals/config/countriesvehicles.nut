from "%scripts/dagui_library.nut" import *

let recomendedCountriesByUnitType = {
  [ES_UNIT_TYPE_AIRCRAFT] = ["country_usa", "country_germany", "country_ussr", "country_britain", "country_japan"],
  [ES_UNIT_TYPE_TANK] = ["country_usa", "country_germany", "country_ussr", "country_china"],
  [ES_UNIT_TYPE_SHIP] = ["country_usa", "country_germany", "country_ussr", "country_japan"],
  [ES_UNIT_TYPE_BOAT] = ["country_usa", "country_germany", "country_ussr", "country_britain"]
}

let unlockLaterVehicles = {
  country_usa = {
    army = ["us_m1a2_sep2_abrams", "us_hstv_l"]
    aviation = ["fa_18e_block_2", "f_15c_golden_eagle"]
    ships = ["us_battleship_iowa_class_iowa", "us_battlecruiser_alaska_class"]
    boats = ["us_frigate_buckley_class_coolbaugh", "us_frigate_dealey"]
  }
  country_germany = {
    army = ["germ_leopard_2a7v", "germ_schutzenpanzer_puma_vjtf"]
    aviation = ["ef_2000_aesa", "fa_18c_late_switzerland"]
    ships = ["germ_battleship_bismarck", "germ_battleship_scharnhorst"]
    boats = ["germ_frigate_koln", "germ_pr_206"]
  }
  country_ussr = {
    army = ["ussr_t_90m_2020", "ussr_t_80bvm"]
    aviation = ["su_30sm2", "su_34"]
    ships = ["ussr_battleship_pr23_sovetskij_soyuz", "ussr_battlecruiser_stalingrad"]
    boats = ["ussr_pr_206m", "ussr_mpk_pr_1124"]
  }
  country_britain = {
    army = ["uk_challenger_2_lep", "uk_ajax"]
    aviation = ["ef_2000_typhoon_aesa", "fa_18f_block_2_raaf"]
    ships = ["uk_battleship_vanguard", "uk_battleship_prince_of_wales"]
    boats = ["uk_frigate_leopard", "uk_corvette_peacock"]
  }
  country_japan = {
    army = []
    aviation = ["f_2a", "su_30mkm"]
    ships = ["jp_battleship_yamato", "jp_battleship_musashi"]
    boats = []
  }
  country_china = {
    army = ["cn_ztz_99a", "cn_vt_4b"]
    aviation = []
    ships = []
    boats = []
  }
  country_italy = {
    army = []
    aviation = ["ef_2000a_aesa", "saab_jas39c_hungary"]
    ships = ["it_battleship_littorio_class_roma", "it_battleship_littorio_class_littorio"]
    boats = ["it_p494_saetta", "it_albatros_class_f543"]
  }
  country_france = {
    army = []
    aviation = []
    ships = []
    boats = ["fr_p730_combattante", "fr_frigate_corse_class_brestois"]
  }
  country_sweden = {
    army = ["sw_cv_90120", "sw_strv_122b_plus"]
    aviation = []
    ships = []
    boats = []
  }
}


let getRecomendedCountries = @(esUnitType) recomendedCountriesByUnitType?[esUnitType] ?? recomendedCountriesByUnitType[ES_UNIT_TYPE_TANK]


return {
  unlockLaterVehicles
  getRecomendedCountries
}