return {
  getShortAppName = @() ::get_settings_blk()?["game"] ?? "wt"
  getAppName = @() ::get_settings_blk()?["game"] ?? "WarThunder"
}
