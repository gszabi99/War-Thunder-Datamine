let graphColorList = [
  {
    int = 0xFF1E7FFF, 
    hex = "FF1E7FFF"
  }
  {
    int = 0xFF21B34A, 
    hex = "FF21B34A"
  }
  {
    int = 0xFFD03F29, 
    hex = "FFD03F29"
  }
  {
    int = 0xFFDCAA54, 
    hex = "FFDCAA54"
  }
  {
    int = 0xFFD34FE2, 
    hex = "FFD34FE2"
  }
]

let getBulletCacheSaveId = @(bullet) $"{bullet.weaponBlkName}_{bullet.bulletName}"

return {
  graphColorList
  getBulletCacheSaveId
}
