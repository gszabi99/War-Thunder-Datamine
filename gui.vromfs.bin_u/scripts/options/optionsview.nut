from "%scripts/dagui_library.nut" import *

let customWeatherLocIds = {
  thin_clouds = "options/weatherthinclouds"
  thunder = "options/weatherstorm"
}

let getWeatherLocName = @(weather)
  loc(customWeatherLocIds?[weather] ?? $"options/weather{weather}")

return {
  getWeatherLocName
}
