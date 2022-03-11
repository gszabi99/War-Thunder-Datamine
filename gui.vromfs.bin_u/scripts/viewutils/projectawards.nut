let { GUI } = require("scripts/utils/configs.nut")

::setProjectAwards <- function setProjectAwards(handler)
{
  let guiScene = ::get_cur_gui_scene()
  let awardsObj = guiScene && guiScene["project-awards"]
  if (! ::checkObj(awardsObj)) return
  let blk = GUI.get()
  if (!blk?.project_awards?.en) return

  local lang = ::loc("current_lang")
  lang = blk.project_awards?[lang] ? lang : "en"
  let set = blk.project_awards[lang] % "i"
  local data = ""
  for (local i=0; i<set.len(); i++)
  {
    let item = set[i]
    let img = ("img" in item) ? item.img : ""
    let title = ("title" in item) ? ::loc(item.title) : ""
    let desc = ("desc" in item) ? ::loc(item.desc) : ""
    let margin_bottom = ((i < set.len() - 1) && ("margin_bottom" in item)) ? item.margin_bottom : "16%h"
    let tooltipData = format("title:t='$tooltipObj' tooltipObj { display:t='hide' on_tooltip_open:t='onProjectawardTooltipOpen' on_tooltip_close:t='onTooltipObjClose'" +
      " img:t='%s' title:t='%s' desc:t='%s' }", img, title, desc)
    data += format("img { background-image:t='%s'; margin-bottom:t='%s' %s }", img, margin_bottom, tooltipData)
  }
  guiScene.replaceContentFromText(awardsObj, data, data.len(), handler)
}