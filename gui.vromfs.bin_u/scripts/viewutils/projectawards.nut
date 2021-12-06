::setProjectAwards <- function setProjectAwards(handler)
{
  local guiScene = ::get_cur_gui_scene()
  local awardsObj = guiScene && guiScene["project-awards"]
  if (! ::checkObj(awardsObj)) return
  local blk = ::configs.GUI.get()
  if (!blk?.project_awards?.en) return

  local lang = ::loc("current_lang")
  lang = blk.project_awards?[lang] ? lang : "en"
  local set = blk.project_awards[lang] % "i"
  local data = ""
  for (local i=0; i<set.len(); i++)
  {
    local item = set[i]
    local img = ("img" in item) ? item.img : ""
    local title = ("title" in item) ? ::loc(item.title) : ""
    local desc = ("desc" in item) ? ::loc(item.desc) : ""
    local margin_bottom = ((i < set.len() - 1) && ("margin_bottom" in item)) ? item.margin_bottom : "16%h"
    local tooltipData = format("title:t='$tooltipObj' tooltipObj { display:t='hide' on_tooltip_open:t='onProjectawardTooltipOpen' on_tooltip_close:t='onTooltipObjClose'" +
      " img:t='%s' title:t='%s' desc:t='%s' }", img, title, desc)
    data += format("img { background-image:t='%s'; margin-bottom:t='%s' %s }", img, margin_bottom, tooltipData)
  }
  guiScene.replaceContentFromText(awardsObj, data, data.len(), handler)
}