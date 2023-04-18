<<#playerListItem>>
contactItem {
  id:t='<<blockID>>';
  contact_buttons_contact_uid:t='<<contactUID>>';
  on_click:t='onPlayerRClick'

  contactStatusImg {
    id:t='statusImg';
    background-image:t=''
    background-color:t='@transparent'
    pos:t='pw - w, ph/2 - h/2'; position:t='absolute'
  }

  cardAvatar {
    id:t='pilotIconImg'
    value:t='<<pilotIcon>>'
  }

  tdiv {
    flow:t='vertical'
    position:t='relative'
    top:t='ph/2 - h/2'

    text {
      id:t='contactName'
      input-transparent:t='yes'
      playerName:t='yes'
    }
    textareaNoTab {
      id:t='contactPresence'
      input-transparent:t='yes'
      contact_presence:t='yes'
      playerPresence:t='yes'
      padding-left:t='6'
    }
  }

  on_r_click:t = 'onPlayerRClick';
  title:t='$tooltipObj';

  <<#needHoverButtons>>
  contact_buttons_holder {
    id:t='contact_buttons_holder';
    position:t='absolute';
    pos:t='pw - w - @sIco, 0.5ph-0.5h';
    display:t='hide';

    Button_text {
      id:t='btn_friendAdd';
      tooltip:t='#contacts/friendlist/add';
      on_click:t='onFriendAdd';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_friend_add.svg';
      }
    }

    Button_text {
      id:t='btn_friendRemove';
      tooltip:t='#contacts/friendlist/remove';
      on_click:t='onFriendRemove';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_friend_remove.svg';
      }
    }

    Button_text {
      id:t='btn_blacklistAdd';
      tooltip:t='#contacts/blacklist/add';
      on_click:t='onBlacklistAdd';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_blacklist_add.svg';
      }
    }

    Button_text {
      id:t='btn_blacklistRemove';
      tooltip:t='#contacts/blacklist/remove';
      on_click:t='onBlacklistRemove';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_blacklist_remove.svg';
      }
    }
    <<#hasMenuChatPrivate>>
    Button_text {
      id:t='btn_message';
      tooltip:t='#contacts/message';
      on_click:t='onPlayerMsg';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      enable:t='no';
      img {
        background-image:t='#ui/gameuiskin#btn_send_private_message.svg';
      }
    }
    <</hasMenuChatPrivate>>
    Button_text {
      id:t='btn_squadInvite';
      tooltip:t='#contacts/invite';
      on_click:t='onSquadInvite';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      enable:t='no';
      img {
        background-image:t='#ui/gameuiskin#btn_invite.svg';
      }
    }

    Button_text {
      id:t='btn_usercard';
      tooltip:t='#mainmenu/btnUserCard';
      on_click:t='onUsercard';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      enable:t='no';
      img {
        background-image:t='#ui/gameuiskin#btn_usercard.svg';
      }
    }

    Button_text {
      id:t='btn_ww_invite'
      tooltip:t='#worldwar/inviteToOperation'
      on_click:t='onWwOperationInvite'
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes'
      enable:t='no'
      display:t='hide'

      btnText {
        style:t='font:@fontSmall'
        pos:t='0.5pw-0.5w, 0.5ph-0.5h'
        position:t='absolute'
        text:t='#icon/worldWar'
      }
    }

    /*Button_text {
      id:t='btn_steamFriends';
      tooltip:t='#mainmenu/btnSteamFriendsAdd';
      on_click:t='onSteamFriendsAdd';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_steam_friends_add.svg';
      }
    }

    Button_text {
      id:t='btn_facebookFriends';
      tooltip:t='#mainmenu/btnFacebookFriendsAdd';
      on_click:t='onFacebookFriendsAdd';
      class:t='image'
      imgSize:t='small'
      showConsoleImage:t='no'
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_facebook_friends_add';
      }
    }*/
  }
  <</needHoverButtons>>

  tooltipObj {
    id:t='tooltip';
    uid:t='';
    on_tooltip_open:t='onContactTooltipOpen';
    on_tooltip_close:t='onTooltipObjClose';
    display:t='hide';
  }
}
<</playerListItem>>

<<#playerButton>>
buttonPlayer {
  tooltip:t='<<tooltip>>';
  on_click:t='<<callback>>';
  isButton:t='yes'
  btnText {
    text:t='<<name>>';
  }
  img {
    background-image:t='<<icon>>';
  }
}
<</playerButton>>

<<#totalContacts>>
textareaNoTab {
  width:t='pw'
  padding:t='0, 12@sf/@pf, 6@sf/@pf, 0'
  text:t='<<totalContacts>>'
  smallFont:t='yes'
  color:t='@commonTextColor'
  color-factor:t='180'
  talign:t='right'
}
<</totalContacts>>

<<#searchAdviceID>>
textarea {
  id:t='<<searchAdviceID>>';
  text:t='#contacts/search_advice';
  display:t='hide';
  width:t='pw';
  removeParagraphIndent:t='yes';
}
<</searchAdviceID>>
