::gui_start_change_role_wnd <- function gui_start_change_role_wnd(contact, clanData)
{
  if (!::clan_get_admin_editor_mode())
  {
    local myClanRights = ::g_clans.getMyClanRights()
    local leadersCount = ::g_clans.getLeadersCount(clanData)
    if (contact.name == ::my_user_name
        && ::isInArray("LEADER", myClanRights)
        && leadersCount <= 1)
      return ::g_popups.add("", ::loc("clan/leader/cant_change_my_role"))
  }

  local changeRolePlayer = {
    uid = contact.uid,
    name = contact.name,
    rank = ::g_clans.getClanMemberRank(clanData, contact.name)
  }

  ::gui_start_modal_wnd(::gui_handlers.clanChangeRoleModal,
    {
      changeRolePlayer = changeRolePlayer,
      owner = this,
      clanType = clanData.type
    })
}

class ::gui_handlers.clanChangeRoleModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/clans/clanChangeRoleWindow.blk"
  changeRolePlayer = null
  roles = []
  adminMode = false
  clanType = ::g_clan_type.UNKNOWN

  function initScreen()
  {
    roles = [];
    adminMode = ::clan_get_admin_editor_mode()
    local roleOptions = "";
    local roleListObj = scene.findObject("change_role_list");
    local titleObj = scene.findObject("title_text");
    local myRole = adminMode? ::ECMR_CLANADMIN : ::clan_get_my_role()
    local myRank = ::clan_get_role_rank(myRole)

    if (titleObj) titleObj.setValue(::loc("clan/changeRoleTitle")+" "+changeRolePlayer.name);

    for (local role = 0; role<::ECMR_MAX_TOTAL; role++)
    {
       local roleName = ::clan_get_role_name(role);
       if (!roleName)
         continue;
       local rank = ::clan_get_role_rank(role);
       if (rank != 0 && (role != ::ECMR_LEADER || adminMode)
           && !::isInArray("HIDDEN", ::clan_get_role_rights(role))
           && clanType.isRoleAllowed(role))
         roles.append({
           name = roleName,
           rank = rank,
           id = role,
           current = rank == changeRolePlayer.rank,
           enabled = rank < myRank || adminMode
         })
    }
    roles.sort(sortRoles)

    local curIdx = 0
    foreach(idx, role in roles)
    {
      roleOptions += format("shopFilter { id:t='role_%d'; shopFilterText { id:t='text'; width:t='pw'; %s } %s } \n",
        idx,
        role.current? "style:t='color:@mainPlayerColor'; ": "",
        role.enabled? "" : "enable:t='no'; "
      )
      if (role.current)
        curIdx = idx
    }

    guiScene.replaceContentFromText(roleListObj, roleOptions, roleOptions.len(), this)
    foreach(idx, role in roles)
    {
      local option = scene.findObject("role_"+idx)
      option.findObject("text").setValue(::loc("clan/"+role.name))
      option.tooltip = (role.current? (::loc("clan/currentRole")+"\n\n") : "") + g_lb_data_type.ROLE.getPrimaryTooltipText(role.id)
    }
    roleListObj.setValue(curIdx)
    roleListObj.select()
  }

  function sortRoles(role1, role2)
  {
    local rank1 = ::getTblValue("rank", role1, -1)
    local rank2 = ::getTblValue("rank", role2, -1)
    if (rank1 != rank2)
      return rank1 > rank2 ? 1 : -1
    return 0
  }

  function onApply()
  {
    local roleListObj = scene.findObject("change_role_list");
    local newRoleIdx = roleListObj.getValue();

    if (!(newRoleIdx in roles))
      return;

    if (roles[newRoleIdx].current)
    {
      goBack();
      return;
    }

    local msg = ::loc("clan/roleChanged") + " " + ::loc("clan/"+roles[newRoleIdx].name)
    local taskId = ::clan_request_change_member_role(changeRolePlayer.uid, roles[newRoleIdx].name)

    if (taskId >= 0 && !adminMode)
      ::sync_handler_simulate_signal("clan_info_reload")

    local onTaskSuccess = function() {
      ::broadcastEvent("ClanMemberRoleChanged")
      ::g_popups.add(null, msg)
    }

    ::g_tasker.addTask(taskId, {showProgressBox = true}, onTaskSuccess)
    goBack()
  }
}
