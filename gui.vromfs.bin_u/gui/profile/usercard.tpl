root {
  bgrStyle:t='fullScreenWnd'

  blur_foreground {
    filledDark:t='yes'
  }

  include "%gui/profile/profileHeaderBg.blk"

  frame {
    id:t='wnd_frame'
    width:t='1@rw'
    height:t='1@rh'
    pos:t='0.5pw-0.5w, (ph-h)/2'
    max-width:t='1@maxProfileFrameWidth'
    position:t='absolute'
    class:t='wndNav'
    profilePage:t='yes'
    fullScreenSize:t='yes'
    needShortSeparators:t='yes'
    css-hier-invalidate:t='yes'

    frame_header {
      smallSize:t='yes'

      Breadcrumb {
        normalFont:t='yes'
        Button_text {
          _on_click:t='goBack'
          visualStyle:t='noBgr'
          img {}
          btnText { id:t='back_scene_name' }
          text { text:t=' | ' }
          textareaNoTab {
            id:t='breadcrumb_title'
            text:t='#mainmenu/btnProfile'
          }
        }
      }
      Button_close { id:t = 'btn_back' }
    }

    tdiv {
      position:t='relative'
      width:t='pw'
      css-hier-invalidate:t='yes'
      min-height:t='1@frameHeaderHeight'

      frameSeparator {
        position:t='absolute'
        top:t='ph-h'
        left:t='(pw-w)/2'
      }
      HorizontalListBox {
        id:t='profile_sheet_list'
        height:t='1@frameHeaderHeight'
        class:t='header'
        activeAccesskeys:t='RS'
        normalFont:t="yes"
        on_select:t = 'onSheetChange'
      }
    }

    //vertical list box
    tdiv {
      size:t='pw, fh'
      flow:t='vertical'

      tdiv {
        id:t='profile_header'
        flow:t='vertical'
        position:t='relative'
        pos:t='(pw-w)/2, 0'
        padding:t='1@profileHeaderPadding, 1@profileHeaderTopPadding, 1@profileHeaderPadding, 1@profileHeaderBottomPadding'
        css-hier-invalidate:t='yes'

        frameSeparator {
          position:t='root'
          top:t='1@maxAccountHeaderHeight'
        }

        include "%gui/profile/profileHeader.blk"
      }

      chatPopupNest {
        id:t='chatPopupNest'
        position:t='absolute'
        pos:t='pw-w, 0'
      }

      profilePage {
        id:t='pages_container'
        size:t='pw, fh'
        flow:t='vertical'
        input-transparent:t='yes'

        tdiv {
          position:t='root'
          size:t='sw, 392@sf/@pf'
          max-width:t='1@maxProfileFrameWidth'
          pos:t='(sw-w)/2, sh - h'
          background-image:t='!ui/images/profile/smoke_bg'
          background-color:t='#FFFFFF'
        }

        tdiv {
          id:t='usercard-container'
          size:t='pw, fh'
          flow:t="vertical"

          tdiv {
            position:t='root'
            pos:t='(sw-w)/2, 1@maxAccountHeaderHeight + 3@sf/@pf'
            size:t='1@accountHeaderWidth, <<scale>>*((sh - @frameFooterHeight - @maxAccountHeaderHeight) $min 924@sf/@pf)'
            background-image:t='!ui/images/profile/widget_bg'
            background-color:t='#FFFFFF'
          }

          tdiv {
            id:t='favorite_top'
            position:t='relative'
            left:t='(pw-w)/2'
            width:t='@accountHeaderWidth'
            css-hier-invalidate:t='yes'
            <<^isSmallSize>>
            min-height:t='190@sf/@pf'
            <</isSmallSize>>
            <<#isSmallSize>>
            min-height:t='<<scale>>*130@sf/@pf'
            <</isSmallSize>>

            tdiv {
              id:t='showcase_title_nest'
              position:t='relative'
              width:t='pw'
              flow:t='vertical'
              top:t='(ph-h)/2'
              css-hier-invalidate:t='yes'
              showInEditMode:t='no'
            }
          }
          tdiv {
            id:t='showcase_mid_nest'
            position:t='relative'
            flow:t='vertical'
            left:t='(pw-w)/2'
            width:t='@accountHeaderWidth'
          }
          tdiv {
            id:t='favorite_bottom_nest'
            position:t='relative'
            flow:t='vertical'
            left:t='(pw-w)/2'
            css-hier-invalidate:t='yes'
            width:t='@accountHeaderWidth - 30@sf/@pf'
            padding-top:t='25@sf/@pf'
          }
        }

        tdiv {
          id:t='stats-container'
          size:t='pw, fh'
          padding-top:t='4@blockInterval'
          total-input-transparent:t='yes'
          display:t='hide'

          tdiv {
            position:t='root'
            pos:t='(sw-w)/2, 1@maxAccountHeaderHeight + 3@sf/@pf'
            size:t='1@accountHeaderWidth, <<scale>>*((sh - @frameFooterHeight - @maxAccountHeaderHeight) $min 924@sf/@pf)'
            background-image:t='!ui/images/profile/widget_bg'
            background-color:t='#FFFFFF'
          }
          include "%gui/profile/profileStats.blk"
        }

        profileContent {
          id:t='records-container'
          flow:t='vertical'
          padding-top:t='4@blockInterval'
          total-input-transparent:t='yes'
          include "%gui/profile/profileRecords.blk"
          display:t='hide'
        }

        profileContent {
          id:t='medals-container'
          padding-top:t='3@blockInterval'
          flow:t='horizontal'
          display:t='hide'

          profileContentLeft {
            listbox {
              id:t='medals_list'
              size:t='pw, ph'
              position:t='relative'
              flow-align:t='left'
              isBigSizeList:t='yes'
              navigator:t='posNavigator'
              moveX:t='linear'
              moveY:t='closest'
              navigatorShortcuts:t='yes'
              move-only-hover:t='yes'
              on_select:t='onMedalsCountrySelect'
            }
          }

          profileContentSeparator{}

          profileContentRight {
            size:t='@profilePageRightPartWidth, ph'
            position:t='relative'
            flow:t='vertical'

            tdiv {
              id:t='medals_info'
              position:t='relative'
              flow:t='vertical'
              overflow-y:t='auto'
              total-input-transparent:t='yes'
              width:t='pw'

              tdiv {
                id:t='medals_desc'
                flow:t='horizontal'
                width:t='pw'
                margin-top:t='16@sf/@pf'
                margin-bottom:t='1@profilePagePartsMargin'
              }
            }

            tdiv {
              position:t='relative'
              size:t='pw, 2@sf/@pf'
              background-color:t='#4B4F53'
              margin:t='0, 6@sf/@pf, 0, 19@sf/@pf'
            }

            medalsList {
              medalsListContent {
                id:t='medals_zone'
                on_select:t='onMedalSelect'
              }
            }
          }
        }

        frameSeparator {
          position:t='absolute'
          top:t='ph'
          left:t='(pw-w)/2'
        }
      }
    }

    navBar {
      min-height:t='10@sf/@pf + 1@frameFooterHeight'

      navRight{
        Button_text {
          id:t = 'btn_friendChangeNick'
          text:t = '#mainmenu/addCustomNick'
          btnName:t='RT'
          on_click:t = 'onFriendChangeNick'
          ButtonImg {}
        }
        Button_text {
          id:t = 'btn_friendAdd'
          text:t = '#contacts/friendlist/add'
          on_click:t = 'onFriendAdd'
          btnName:t='X';
          ButtonImg{}
        }
        Button_text {
          id:t = 'btn_friendRemove'
          text:t = '#contacts/friendlist/remove'
          on_click:t = 'onFriendRemove'
          btnName:t='X';
          ButtonImg{}
        }
        Button_text {
          id:t = 'btn_blacklistAdd'
          text:t = '#contacts/blacklist/add'
          on_click:t = 'onBlacklistAdd'
          btnName:t='Y';
          ButtonImg{}
        }
        Button_text {
          id:t = 'btn_blacklistRemove'
          text:t = '#contacts/blacklist/remove'
          on_click:t = 'onBlacklistRemove'
          btnName:t='Y';
          ButtonImg{}
        }
        Button_text {
          id:t='btn_moderatorBan'
          text:t='#contacts/moderator_ban'
          on_click:t='onBlacklistBan'
          btnName:t='L3';
          ButtonImg{}
        }
        Button_text {
          id:t = 'btn_complain'
          text:t = '#mainmenu/btnComplain'
          btnName:t='RB'
          _on_click:t = 'onComplain'
          ButtonImg {}
        }
        Button_text {
          id:t = 'btn_xbox_profile'
          text:t = '#mainmenu/btnXboxProfile'
          btnName:t='LB'
          on_click:t = 'onOpenXboxProfile'
          display:t='hide'
          ButtonImg {}
        }
        Button_text {
          id:t = 'btn_psn_profile'
          text:t = '#mainmenu/btnPsnProfile'
          btnName:t='LB'
          on_click:t = 'onOpenPSNProfile'
          display:t='hide'
          ButtonImg {}
        }
        Button_text {
          id:t = 'btn_leaderboard'
          text:t = '#mainmenu/btnLeaderboards'
          btnName:t='RB'
          on_click:t = 'onLeaderboard'
          ButtonImg {}
          display:t='hide'
          enable:t='no'
        }
        Button_text {
          id:t = 'btn_achievements_url'
          text:t = '#mainmenu/compareAchievements'
          btnName:t='R3'
          on_click:t = 'onOpenAchievementsUrl'
          display:t='hide'
          externalLink:t='yes'
          hideText:t='yes'

          ButtonImg {}
          btnText {
            id:t="btn_achievements_url_text"
            text:t='#mainmenu/compareAchievements'
            underline{}
          }
        }
      }

      navMiddle{
        id:t='paginator_place'
      }
    }
  }
}