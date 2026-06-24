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
  {
    int = 0xFF39B3BC, 
    hex = "FF39B3BC"
  }
  {
    int = 0xFFDA6900, 
    hex = "FFDA6900"
  }
  {
    int = 0xFF7F65FF, 
    hex = "FF7F65FF"
  }
  {
    int = 0xFFB7B7B7, 
    hex = "FFB7B7B7"
  }
  {
    int = 0xFF94D244, 
    hex = "FF94D244"
  }
]

let getBulletCacheSaveId = @(bullet) $"{bullet.weaponBlkName}_{bullet.bulletName}"

return {
  graphColorList
  getBulletCacheSaveId
}
