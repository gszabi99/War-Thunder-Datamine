#allow-root-table
return{
  isDmgIndicatorVisible = @() getroottable()?["is_dmg_indicator_visible"]() ?? false
}
