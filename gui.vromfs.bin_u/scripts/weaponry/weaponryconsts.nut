enum weaponsItem {
  primaryWeapon
  weapon  //secondary, weapon presets
  modification
  bullets          //bullets are modifications too, uses only in filling tab panel
  expendables
  spare
  bundle
  nextUnit
  curUnit
  skin
  unknown
}

enum INFO_DETAIL { //text detalization level. for weapons and modifications names and descriptions
  LIMITED_11 //must to fit in 11 symbols
  SHORT      //short info, like name. mostly in a single string.
  FULL       //full description
  EXTENDED   //full description + addtitional info for more detailed tooltip
}

return {
  UNIT_WEAPONS_ZERO    = 0
  UNIT_WEAPONS_WARNING = 1
  UNIT_WEAPONS_READY   = 2
  SAVE_WEAPON_JOB_DIGIT = 321

  INFO_DETAIL

  weaponsItem
}