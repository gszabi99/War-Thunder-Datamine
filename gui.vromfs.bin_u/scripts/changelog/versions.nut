/*
 Example: [{version="1.2.0.0",   type = "hotfix", platform="ps4,xboxOne"}]
 platform is optional
 type can be "hotfix" or "major"
 title can be text or table with localization title={english="Black Sun", Russian = "Черное солнце"}
 headerTitle can be text or table with localization headerTitle={english="Black Sun", Russian = "Черное солнце"}
   if headerTitle not exist, then is taken "title" parameter for window header.
*/

return [
  {version="1.99.0.03", type="major", title={
    english="Major Update 'Starfighters'"
    russian="Обновление 'Starfighters'"
  }}
  {version="1.99.0.02", type="hotfix", title={
    english="'Starfighters' — Locations and missions"
    russian="'Starfighters' - Локации и миссии"
  }}
  {version="1.99.0.01", type="hotfix", title={
    english="'Starfighters' — FM, DM, Economics"
    russian="'Starfighters' - ФМ, ДМ, Экономика"
  }}
  {version="1.99.0.00", type="hotfix", title={
    english="'Starfighters' — Game mechanics, sound and other"
    russian="'Starfighters' - Игровая механика, звук и другое"
  }}
]
