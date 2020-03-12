::PS4_IGNORE_INVITE_STRING <- "#ignore#"

::sendInvitationPsn <- function sendInvitationPsn(config)
{
  local inviteType = ::getTblValue("inviteType", config, "")

  local blk = ::DataBlock()
  local dataNameLocId = "ps4/invitation/" + inviteType + "/name"
  local dataDescriptionLocId = "ps4/invitation/" + inviteType + "/detail"

  blk.userMessage = ""
  local targetAccountId = ::getTblValue("targetAccountId", config, 0)
  if (targetAccountId != 0)
    blk.target = targetAccountId
  else
    blk.target = ::getTblValue("targetOnlineId", config, "")
  blk.dataName = ::loc(dataNameLocId)
  blk.dataDetail = ::loc(dataDescriptionLocId)

  local localizedNameTable = ::get_localized_text_with_abbreviation(dataNameLocId)
  local localizedDetailTable = ::get_localized_text_with_abbreviation(dataDescriptionLocId)

  if (localizedNameTable.len() > 0 && localizedDetailTable.len() > 0)
  {
    local locNames = ::DataBlock()
    local locDetails = ::DataBlock()
    foreach (abbrev, nameText in localizedNameTable)
    {
      local descrText = ::getTblValue(abbrev, localizedDetailTable, "")
      if (descrText == "")
      {
        ::dagor.debug("Not found abbreviation '" + abbrev + "' in descriptionTable, locId - " + dataDescriptionLocId)
        debugTableData(localizedNameTable)
        debugTableData(localizedDetailTable)
        continue
      }
      local n = ::DataBlock()
      local d = ::DataBlock()
      n.language <- abbrev
      d.language <- abbrev

      n.str <- nameText
      d.str <- descrText

      locNames.loc <- n
      locDetails.loc <- d
    }
    blk.locNames = locNames
    blk.locDetails = locDetails
  }

  blk.expireMinutes = ::getTblValue("expireMinutes", config, 10) //60*24*7; //week
  blk.data = ::PS4_IGNORE_INVITE_STRING + ::my_user_name //::get_player_user_id_str()
  blk.imagePath = "ui/images/invite_small.jpg"

  return ::ps4_send_message(blk)
}

