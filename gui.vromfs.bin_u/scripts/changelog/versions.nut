/*
 Example: [{version="1.2.0.0",   type = "hotfix", platform="ps4,xboxOne"}]
 platform is optional
 type can be "hotfix" or "major"
 title can be text or table with localization title={english="Black Sun", Russian = "Черное солнце"}
*/

return [
  {version="1.97.1.2", type="hotfix", title={
    english="'Viking Fury' (1.97.1.0)"
    russian="'Ярость викингов' - Остальное (1.97.1.0)"
  }}

  {version="1.97.1.1", type="hotfix", title={
    english="'Viking Fury' Missions (1.97.1.0)"
    russian="'Ярость викингов' - Миссии (1.97.1.0)"
  }}

  {version="1.97.1.0", type="major", title={
    english="'Viking Fury' Vehicles (1.97.1.0)"
    russian="'Ярость викингов' - Техника (1.97.1.0)"
  }}
]
