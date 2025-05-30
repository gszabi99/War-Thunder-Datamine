root {
  isEditModeEnabled:t='no'
  css-hier-invalidate:t='yes'
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
          on_click:t='goBack'
          visualStyle:t='noBgr'
          img {}
          btnText { id:t='back_scene_name' }
          text { text:t=' | ' }
          textareaNoTab { text:t='#mainmenu/btnProfile' }
        }
      }
      Button_close {
        id:t = 'btn_back'
        have_shortcut:t='no'
      }
      dummy {
        on_click:t = 'onCloseOrCancelEditMode'
        btnName:t='B'
      }
    }

    tdiv {
      position:t='relative'
      width:t='pw'
      css-hier-invalidate:t='yes'

      HorizontalListBox {
        id:t='profile_sheet_list'
        height:t='1@frameHeaderHeight'
        class:t='header'
        activeAccesskeys:t='RS'
        normalFont:t="yes"
        on_select:t = 'onSheetChange'
      }
      tdiv {
        position:t='absolute'
        pos:t='pw-w, 0'

        Button_text {
          id:t='profile-warpoints'
          visualStyle:t='noFrame'
          tooltip:t='#mainmenu/warpoints'
          showBonusPersonal:t=''
          showBonusCommon:t=''
          _on_click:t='onOnlineShopLions'

          img {
            isFirstLeft:t='yes'
            position:t='relative'
            size:t='1@cIco, 1@cIco'
            background-image:t='#ui/gameuiskin#shop_warpoints.svg'
            background-svg-size:t='1@cIco, 1@cIco'
          }

          btnText {
            id:t='profile-balance'
            min-width:t='0.05@sf'
            pos:t='@blockInterval, 50%ph-50%h'
            position:t='relative'
            text-align:t='left'
          }

          BonusCorner {bonusType:t='personal'}
          BonusCorner {bonusType:t='common'}
        }

        Button_text {
          id:t='profile-eagles'
          visualStyle:t='noFrame'
          tooltip:t='#mainmenu/gold'
          _on_click:t='onOnlineShopEagles'

          img {
            isFirstLeft:t='yes'
            position:t='relative'
            size:t='1@cIco, 1@cIco'
            background-image:t='#ui/gameuiskin#shop_warpoints_premium.svg'
            background-svg-size:t='1@cIco, 1@cIco'
          }

          btnText {
            id:t='profile-gold'
            min-width:t='0.05@sf'
            pos:t='@blockInterval, 50%ph-50%h'
            position:t='relative'
            text-align:t='left'
          }
        }

        textareaNoTab {
          id:t='balance_text'
          pos:t='0, 0.5ph-0.5h'
          position:t='relative'
          hideEmptyText:t='yes'
          text:t=''
          tooltip:t=''
        }
        tdiv {
          id:t='sorting_block'
          width:t='1@subsetComboBoxWidth'
          position:t='relative'
          top:t='0.5ph-0.5h'
          margin-left:t='1@listboxPad'
          display:t='hide'
          tdiv {
            id:t='sorting_block_bg'
            width:t='pw'
            background-color:t='@rowHoverBackgroundColor'
            padding:t='1@dp'
          }
        }
      }
      chatPopupNest {
        id:t='chatPopupNest'
        position:t='absolute'
        pos:t='pw-w, ph'
      }
      frameSeparator {
        position:t='absolute'
        top:t='ph-h+1@sf/@pf'
        left:t='(pw-w)/2'
      }
    }

    //vertical list box
    tdiv {
      size:t='pw, fh'
      flow:t='vertical'
      css-hier-invalidate:t='yes'

      tdiv {
        width:t='pw'
        css-hier-invalidate:t='yes'
        tdiv {
          id:t = 'profile_header'
          flow:t="vertical"
          position:t='relative'
          pos:t='(pw-w)/2, 0'
          padding:t='1@profileHeaderPadding, 1@profileHeaderTopPadding, 1@profileHeaderPadding, 1@profileHeaderBottomPadding'
          css-hier-invalidate:t='yes'
          frameSeparator {
            position:t='root'
            top:t='1@maxAccountHeaderHeight + 1@bhInVr'
          }

          include "%gui/profile/profileHeader.blk"
        }

        Button_text {
          position:t='absolute'
          pos:t='pw - w - 5@sf/@pf, 0.5ph-0.5h'
          flow:t='horizontal'
          visualStyle:t='noFrame'
          isColoredImg:t='yes'
          btnName:t='R3'
          on_click:t='onHeaderBackgroundListSwitch'
          display:t='hide'
          showInEditMode:t='yes'
          ButtonImg {}
          text {
            position:t='relative'
            top:t='(ph-h)/2'
            text:t='#showcase/changeBg'
          }
          img {
            position:t='relative'
            background-image:t='!#ui/images/profile/ic_change.svg'
            size:t='1@cIco, 1@cIco'
            margin-left:t='1@buttonTextPadding'
            background-svg-size:t='@cIco, @cIco'
          }
        }
      }

      profilePage {
        id:t='pages_container'
        size:t='pw, fh'
        flow:t='vertical'
        input-transparent:t='yes'
        padding-top:t='6@sf/@pf'
        css-hier-invalidate:t='yes'

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
          interactive:t='yes'
          css-hier-invalidate:t='yes'

          tdiv {
            behavior:t='button'
            id:t='profile_widget_bg'
            position:t='root'
            overflow:t='hidden'
            pos:t='(sw-w)/2, 1@maxAccountHeaderHeight + 3@sf/@pf + 1@bhInVr'
            size:t='1@accountHeaderWidth, sh - 1@bh - 9@sf/@pf - 1@frameFooterHeight - 1@maxAccountHeaderHeight'
            skip-navigation:t='yes'
            on_click:t='onProfileEditBtn'

            tdiv {
              position:t='relative'
              size:t='pw, <<scale>>*((sh - @frameFooterHeight - @maxAccountHeaderHeight) $min 924@sf/@pf)'
              background-image:t='!ui/images/profile/widget_bg'
              background-color:t='#FFFFFF'
            }
          }

          tdiv {
            id:t='favorite_top'
            position:t='relative'
            left:t='(pw-w)/2'
            padding-bottom:t='21@sf/@pf'
            width:t='1@accountHeaderWidth'
            css-hier-invalidate:t='yes'
            <<^isSmallSize>>
            min-height:t='<<scale>>*1@profileHeaderH'
            <</isSmallSize>>
            <<#isSmallSize>>
            min-height:t='<<scale>>*1@smallProfileHeaderH'
            <</isSmallSize>>

            tdiv {
              id:t='showcase_edit'
              width:t='pw'
              position:t='absolute'
              top:t='(ph-h)/2'
              flow:t='vertical'
              css-hier-invalidate:t='yes'
              display:t='hide'
              showInEditMode:t='yes'
            }

            tdiv {
              id:t='showcase_title_nest'
              position:t='absolute'
              width:t='pw'
              top:t='(ph-h)/2'
              flow:t='vertical'
              css-hier-invalidate:t='yes'
              showInEditMode:t='no'
              total-input-transparent:t='yes'
            }
          }
          tdiv {
            id:t='showcase_mid_nest'
            position:t='relative'
            flow:t='vertical'
            left:t='(pw-w)/2'
            width:t='@accountHeaderWidth'
            css-hier-invalidate:t="yes"
            total-input-transparent:t='yes'
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

          tdiv {
            id:t='background_edit'
            width:t='1@sliderWidth + 1@blockInterval + 1@dmInfoTextWidth + 2@tablePad + 2@framePadding'
            pos:t='pw-w-4@blockInterval, 70@sf/@pf'
            position:t='absolute'
            flow:t='vertical'
            css-hier-invalidate:t='yes'
            display:t='hide'

            frame {
              id:t='wnd_frame'
              position:t='absolute'
              width:t='pw'
              class:t='wnd'
              type:t='big'
              invisibleSelection:t='yes'

              frame_header {
                activeText {
                  caption:t='yes'
                  text:t='#showcase/choose_header_screen'
                }
                Button_close {
                  on_click:t='onHeaderBackgroundListHide'
                }
              }

              EditBox {
                id:t='filter_header'
                noMargin:t='yes'
                width:t='pw'
                on_change_value:t='applyFilterBackground'
                on_cancel_edit:t='onFilterCancel'
                text:t=''
                edit-hint:t='#contacts/search_placeholder'
              }

              VerticalListBox {
                id:t='header_backgrounds_list'
                navigator:t='posNavigator'
                width:t='pw'
                max-height:t='sh - 1@maxAccountHeaderHeight - 70@sf/@pf - 1@frameFooterHeight - 1@frameHeaderHeight - 1@buttonHeight - 8@blockInterval'
                overflow-y:t='auto'
                on_select:t='onHeaderBackgroundSelect'
                clearOnFocusLost:t='no'
                css-hier-invalidate:t='yes'
                navigatorShortcuts:t='yes'
                scrollbarShortcuts:t='yes'
              }
            }
          }

          tdiv {
            id:t='chooseImage'
            position:t='root'
            pos:t='(sw-w)/2, 1@maxAccountHeaderHeight + 3@sf/@pf'
            width:t='0.75@rw'
            max-width:t='0.75@maxProfileFrameWidth'
            height:t='sh - 1@bh - 1@maxAccountHeaderHeight - 2*@buttonHeight - 4*@sf/@pf'
            display:t='hide'
          }
        }

        tdiv {
          id:t='stats-container'
          size:t='pw, fh'
          padding-top:t='4@blockInterval'
          total-input-transparent:t='yes'

          tdiv {
            position:t='root'
            overflow:t='hidden'
            pos:t='(sw-w)/2, 1@maxAccountHeaderHeight + 3@sf/@pf + 1@bhInVr'
            size:t='1@accountHeaderWidth, sh - 1@bh - 9@sf/@pf - 1@frameFooterHeight - 1@maxAccountHeaderHeight'

            tdiv {
              position:t='relative'
              size:t='pw, <<scale>>*((sh - @frameFooterHeight - @maxAccountHeaderHeight) $min 924@sf/@pf)'
              background-image:t='!ui/images/profile/widget_bg'
              background-color:t='#FFFFFF'
            }
          }
          include "%gui/profile/profileStats.blk"
        }

        profileContent {
          id:t='records-container'
          flow:t='vertical'
          total-input-transparent:t='yes'
          css-hier-invalidate:t='yes'
          include "%gui/profile/profileRecords.blk"
        }

        profileContent {
          id:t='medals-container'
          size:t='pw, fh'
        }

        profileContent {
          id:t='decals-container'
          size:t='pw, fh'
        }

        profileContent {
          id:t='skins-container'
          size:t='pw, fh'
        }

        profileContent {
          id:t='achievements-container'
          size:t='pw, fh'
        }

        profileContent {
          id:t='collections-container'
          size:t='pw, fh'
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

      navRight {
//-------------- PC Only buttons ---------

        Button_text {
          id:t = 'btn_changeName'
          text:t = '#mainmenu/btnChangeName'
          btnName:t='RB'
          on_click:t = 'onChangeName'
          ButtonImg {}
        }

        Button_text {
          id:t = 'btn_editPage'
          text:t = '#msgbox/btn_edit'
          btnName:t='LT'
          on_click:t = 'onProfileEditBtn'
          ButtonImg {}
        }

        Button_text {
          id:t = 'btn_applyEditPage'
          text:t = '#msgbox/btn_apply'
          btnName:t='LT'
          on_click:t = 'onProfileEditApplyBtn'
          ButtonImg {}
        }

        Button_text {
          id:t = 'btn_cancelEditPage'
          text:t = '#msgbox/btn_cancel'
          btnName:t='L3'
          on_click:t = 'onProfileEditCancelBtn'
          ButtonImg {}
        }

        Button_text {
          id:t = 'btn_changeAccount'
          text:t = '#mainmenu/btnChangePlayer'
          btnName:t='LB'
          on_click:t = 'onChangeAccount'
          ButtonImg {}
        }

        Button_text {
          id:t='btn_getLink'
          text:t='#mainmenu/btnGetLink'
          tooltip:t=''
          btnName:t='L3'
          _on_click:t='openViralAcquisitionWnd'
          ButtonImg {}
        }

        Button_text {
          id:t = 'btn_codeApp'
          btnName:t='R3'
          on_click:t='onCodeAppClick'
          externalLink:t='yes'
          hideText:t='yes'
          ButtonImg {}

          btnText {
            id:t = 'btn_codeApp_text'
            underline{}
          }
        }
//----------------------------------------

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
          id:t='btn_achievements_url'
          text:t='#mainmenu/showAchievements'
          btnName:t='R3'
          on_click:t='onOpenAchievementsUrl'
          display:t='hide'
          externalLink:t='yes'
          hideText:t='yes'

          ButtonImg {}
          btnText {
            id:t='btn_achievements_url_text'
            text:t='#mainmenu/showAchievements'
            underline{}
          }
        }

        Button_text {
          id:t='btn_EmailRegistration'
          text:t='#mainmenu/binding'
          tooltip:t='#mainmenu/PS4EmailRegistration/desc'
          btnName:t='L3'
          _on_click:t = 'onBindEmail'
          visualStyle:t='secondary'
          buttonGlance{}
          buttonWink{}
          ButtonImg {}
        }
      }
      navMiddle{
        id:t='paginator_place';
      }
      navLeft{
        Button_text {
          id:t='btn_store'
          btnName:t='X'
          on_click:t='onItemsShop'
          display:t='hide'
          text:t='#items/shop/emptyTab/toShopButton'
          showButtonImageOnConsole:t='no'
          visualStyle:t='secondary'
          class:t='image'
          buttonWink {}
          img { background-image:t='#ui/gameuiskin#store_icon.svg' }
          ButtonImg {}
        }
      }
    }
  }
}
