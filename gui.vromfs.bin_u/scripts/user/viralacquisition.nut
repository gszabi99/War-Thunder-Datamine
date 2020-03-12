::show_viral_acquisition_wnd <- function show_viral_acquisition_wnd()
{
  if (!::has_feature("Invites"))
    return

  local linkString = ::format(::loc("msgBox/viralAcquisition"), ::my_user_id_str)
  ::copy_to_clipboard(linkString)

  local formatImg = "ui/images/%s.jpg?P1"
  local image = ::format(formatImg, "facebook_invite")
  local height = 400
  local guiBlk = ::configs.GUI.get()

  if (guiBlk?.invites_notification_window_images
      && guiBlk.invites_notification_window_images.paramCount() > 0)
  {
    local paramNum = ::math.rnd() % guiBlk.invites_notification_window_images.paramCount()
    local newHeight = guiBlk.invites_notification_window_images.getParamName(paramNum)
    local newImage = ::format(formatImg, guiBlk.invites_notification_window_images.getParamValue(paramNum))
    if (!regexp2(@"\D+").match(newHeight))
    {
      height = newHeight
      image = newImage
    }
  }

  local config = {
    name = ::loc("mainmenu/getLinkTitle")
    desc = ::loc("msgbox/linkCopied", {
      secondRankAward = ::Cost(70000).tostring(),
      thirdRankAward = ::Cost(0, 500).tostring(),
      fifthRankAward = ::Cost(0, 2500).tostring(),
      gift = ::Cost(0, 50).tostring(),
      link = linkString })
    descAlign = "center"
    popupImage = "#"+image
    ratioHeight = (height.tofloat() / 800).tostring()
    showSendEmail = true
    showPostLink = true
  }
  showUnlockWnd(config)
}
