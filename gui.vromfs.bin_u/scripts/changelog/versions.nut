/*
 Example: [{version="1.2.0.0",   type = "hotfix", platform="ps4,xboxOne"}]
 platform is optional
 type can be "hotfix" or "major"
 title can be text or table with localization title={english="Black Sun", Russian = "Черное солнце"}
 headerTitle can be text or table with localization headerTitle={english="Black Sun", Russian = "Черное солнце"}
   if headerTitle not exist, then is taken "title" parameter for window header.

 Also, please remove the older changelogs, when tabs don't fit on 1280x1024 with Large UI scale
*/

return [
  {version="2.1.0.00", type="major", title={
    english="Update “New Power”"
    russian="Обновление “Новая сила”"
  }}
]
