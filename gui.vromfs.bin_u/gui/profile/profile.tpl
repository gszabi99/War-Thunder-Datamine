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
            top:t='1@maxAccountHeaderHeight'
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
          css-hier-invalidate:t='yes'

          tdiv {
            behavior:t='button'
            position:t='root'
            id:t='profile_widget_bg'
            pos:t='(sw-w)/2, 1@maxAccountHeaderHeight + 3@sf/@pf'
            size:t='1@accountHeaderWidth, <<scale>>*((sh - @frameFooterHeight - @maxAccountHeaderHeight) $min 924@sf/@pf)'
            background-image:t='!ui/images/profile/widget_bg'
            background-color:t='#FFFFFF'
            skip-navigation:t='yes'
            on_click:t='onProfileEditBtn'
          }

          tdiv {
            id:t='favorite_top'
            position:t='relative'
            left:t='(pw-w)/2'
            padding-bottom:t='21@sf/@pf'
            width:t='@accountHeaderWidth'
            css-hier-invalidate:t='yes'
            <<^isSmallSize>>
            min-height:t='190@sf/@pf'
            <</isSmallSize>>
            <<#isSmallSize>>
            min-height:t='<<scale>>*130@sf/@pf'
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
          css-hier-invalidate:t='yes'
          include "%gui/profile/profileRecords.blk"
        }

        profileContent {
          id:t='medals-container'
          padding-top:t='3@blockInterval'
          flow:t='horizontal'

          profileContentLeft {
            listbox {
              id:t='medals_list'
              size:t='pw, ph'
              position:t='relative'
              flow-align:t='left'
              isBigSizeList:t='yes'
              beyondScrollbar:t='yes'
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

        profileContent {
          id:t='decals-container'
          padding-top:t='3@blockInterval'

          profileContentLeft {
            listbox {
              id:t = 'decals_group_list'
              position:t='relative'
              size:t='pw, ph'
              flow:t = 'vertical'
              padding-top:t='10@sf/@pf'

              isBigSizeList:t='yes'
              beyondScrollbar:t='yes'
              navigatorShortcuts:t='yes'
              move-only-hover:t='yes'
              on_select:t = 'onDecalCategorySelect'
            }
          }

          profileContentSeparator{}

          profileContentRight {
            flow:t='vertical'

            tdiv {
              id:t='decal_info'
              position:t='relative'
              width:t='pw'
              flow:t='horizontal'
              padding-top:t='5@sf/@pf'

              profileContentBigIcon {
                position:t='relative'
                top:t='(ph-h)/2'
                img {
                  id:t='decalImage'
                  size:t='pw, ph'
                  position:t='relative'
                  background-svg-size:t='w, h'
                  background-repeat:t='aspect-ratio'
                }
              }

              tdiv {
                width:t='fw'
                flow:t='vertical'
                padding-top:t='10@sf/@pf'
                profilePageTitle {
                  id:t='decalTitle'
                  text:t=''
                  max-width:t='pw'
                  pare-text:t='yes'
                  overlayTextColor:t='unlockHeader'
                }
                profilePageText{
                  id:t='decalDesc'
                  width:t='pw'
                  overflow:t='hidden'
                  text:t=''
                  margin-top:t='2@dp'
                  color:t='@profilePageTextColor'
                }
                challengeDescriptionProgress {
                  id:t='decalProgress'
                  isProfileDecalsProgress:t='yes'
                  value:t=''
                  display:t='hide'
                }
                profilePageText {
                  id:t='decalMainCond'
                  width:t='pw'
                  overflow:t='hidden'
                  text:t=''
                  margin-top:t='1@blockInterval'
                  color:t='@profilePageTextColor'
                }
                profilePageText{
                  id:t='decalMultDecs'
                  width:t='pw'
                  overflow:t='hidden'
                  text:t=''
                  margin-top:t='1@blockInterval'
                  color:t='@profilePageTextColor'
                }
                profilePageText {
                  id:t='decalConds'
                  width:t='pw'
                  overflow:t='hidden'
                  text:t=''
                  margin-top:t='1@blockInterval'
                  color:t='@profilePageTextColor'
                }
                profilePageText {
                  id:t='decalPrice'
                  width:t='pw'
                  text:t=''
                  margin-top:t='1@blockInterval'
                  color:t='@profilePageTextColor'
                }
                tdiv {
                  position:t='relative'
                  flow:t='horizontal'
                  left:t='-1@buttonTextPadding'
                  padding:t='0, 18@sf/@pf'

                  Button_text {
                    id:t='btn_buy_decorator'
                    btnName:t='X'
                    on_click:t='onBuyDecorator'
                    display:t='hide'
                    text:t='#mainmenu/btnOrder'
                    hideText:t='yes'
                    showButtonImageOnConsole:t='no'
                    visualStyle:t='purchase'
                    buttonWink {}
                    buttonGlance {}
                    ButtonImg {}
                    textarea {
                      id:t='btn_buy_decorator_text'
                      class:t='buttonText'
                    }
                  }
                  Button_text {
                    id:t='btn_use_decorator'
                    visualStyle:t='secondary'
                    btnName:t='L3'
                    _on_click:t='onDecalUse'
                    display:t='hide'
                    text:t='#decorator/use/decal'
                    ButtonImg {}
                    buttonWink {}
                  }
                  Button_text {
                    id:t='btn_preview'
                    visualStyle:t='secondary'
                    btnName:t='L3'
                    _on_click:t='onDecalPreview'
                    display:t='hide'
                    text:t='#mainmenu/btnPreview'
                    showButtonImageOnConsole:t='no'
                    class:t='image'
                    img { background-image:t='#ui/gameuiskin#btn_preview.svg' }
                    ButtonImg {}
                    buttonWink {}
                  }
                  Button_text {
                    id:t='btn_go_to_collection'
                    btnName:t='R3'
                    on_click:t='onGotoCollection'
                    display:t='hide'
                    visualStyle:t='secondary'
                    text:t='#collection/go_to_collection'
                    showButtonImageOnConsole:t='no'
                    class:t='image'
                    buttonWink {}
                    img { background-image:t='#ui/gameuiskin#collection.svg' }
                    ButtonImg {}
                  }
                  Button_text {
                    id:t='btn_marketplace_find_coupon'
                    btnName:t='X'
                    on_click:t='onMarketplaceFindCoupon'
                    display:t='hide'
                    text:t='#msgbox/btn_find_on_marketplace'
                    showButtonImageOnConsole:t='no'
                    visualStyle:t='secondary'
                    class:t='image'
                    buttonWink {}
                    img { background-image:t='#ui/gameuiskin#gc.svg' }
                    ButtonImg {}
                  }
                  Button_text {
                    id:t='btn_marketplace_consume_coupon'
                    btnName:t='X'
                    on_click:t='onMarketplaceConsumeCoupon'
                    display:t='hide'
                    text:t='#item/consume/coupon'
                    showButtonImageOnConsole:t='no'
                    visualStyle:t='secondary'
                    class:t='image'
                    buttonWink {}
                    img { background-image:t='#ui/gameuiskin#gc.svg' }
                    ButtonImg {}
                  }
                  Button_text {
                    id:t="checkbox_favorites"
                    position:t='relative'
                    text:t=''
                    tooltip:t=''
                    on_click:t='unlockToFavorites'
                    unlockId:t=''
                    btnName:t='LT'
                    ButtonImg {}
                    buttonWink {}
                    visualStyle:t='secondary'
                    isChecked:t='no'
                  }
                }
              }
            }

            tdiv {
              id:t='decals_separator'
              position:t='relative'
              size:t='pw, 2@sf/@pf'
              background-color:t='#4B4F53'
              margin:t='0, 6@sf/@pf, 0, 19@sf/@pf'
            }

            medalsList {
              medalsListContent {
                id:t='decals_zone'
                on_select:t='onDecalSelect'
              }
            }
          }
        }

        profileContent {
          id:t='skins-container'
          size:t='pw, fh'
          padding-top:t='3@blockInterval'
          flow:t='horizontal'

          profileContentLeft {
            page:t='skins'

            listbox {
              id:t='skins_group_list'
              size:t='pw, ph'
              padding-top:t='10@sf/@pf'
              position:t='relative'
              flow:t = 'vertical'
              isBigSizeList:t='yes'
              beyondScrollbar:t='yes'

              navigatorShortcuts:t='cancel'
              on_dbl_click:t='onGroupCollapse'
              on_cancel_edit:t='onGroupCancel'
              on_select:t = 'onUnlockGroupSelect'
              move-only-hover:t='yes'
            }
          }

          profileContentSeparator{}

          profileContentRight {
            position:t='relative'
            size:t='@profilePageRightPartWidth, ph'
            flow:t='vertical'

            tdiv{
              flow:t='vertical'
              width:t = 'pw'

              tdiv {
                position:t='relative'
                width:t='pw'
                flow:t='horizontal'
                background-color:t='#11111111'

                tdiv {
                  position:t='relative'
                  width:t='fw'
                  flow:t='h-flow'

                  HorizontalListBox {
                    position:t='relative'
                    id:t='pages_list'
                    class:t='countries_small'
                    type:t='transparent'
                    navigatorShortcuts:t='yes'
                    move-only-hover:t='yes'
                    margin-right:t='4@framePadding'
                    on_select:t = 'onPageChange'
                  }

                  HorizontalListBox {
                    position:t='relative'
                    id:t='unit_type_list'
                    padding-right:t='0'
                    class:t='countries_small'
                    type:t='transparent'
                    navigatorShortcuts:t='yes'
                    move-only-hover:t='yes'
                    on_select:t = 'onSubPageChange'
                  }
                }

                tdiv {
                  position:t='relative'
                  height:t='1@countriesSmallListHeight'
                  top:t='ph-h'
                  padding-right:t='15@sf/@pf'

                  CheckBox {
                    position:t='relative'
                    pos:t='pw-w, (ph-h)/2'
                    id:t='checkbox_only_for_bought'
                    text:t='#profile/only_for_bought'
                    tooltip:t='#profile/only_for_bought/hint'
                    on_change_value:t='onOnlyForBoughtCheck'
                    btnName:t='X'
                    ButtonImg{}
                    CheckBoxImg{}
                  }
                }
              }

              tdiv {
                id:t='skin_desc'
                flow:t='vertical'
                size:t= 'pw, fh'
                margin-top:t = '1@blockInterval'
              }
            }
          }
        }

        profileContent {
          id:t='unlocks-container'
          size:t='pw, fh'
          padding-top:t='3@blockInterval'
          flow:t='horizontal'

          profileContentLeft {
            listbox {
              id:t='unlocks_group_list'
              size:t='pw, ph'
              position:t='relative'
              flow:t = 'vertical'
              padding-top:t='10@sf/@pf'
              isBigSizeList:t='yes'
              beyondScrollbar:t='yes'

              navigatorShortcuts:t='cancel'
              on_dbl_click:t='onGroupCollapse'
              on_cancel_edit:t='onGroupCancel'
              on_select:t = 'onUnlockGroupSelect'
              move-only-hover:t='yes'
            }
          }

          profileContentSeparator{}

          profileContentRight {
            position:t='relative'
            size:t='@profilePageRightPartWidth, ph'
            flow:t='vertical'

            listbox {
              id:t='unlocks_list'
              margin-top:t='5@sf/@pf'
              isProfileUnlocksList:t='yes'
              flow:t = 'vertical'
              size:t='pw, fh'
              overflow:t='auto'

              itemInterval:t='@unlocksListboxItemInterval'
              navigatorShortcuts:t='yes'
              scrollbarShortcuts:t='yes'
              on_dbl_click:t='unlockToFavoritesByActivateItem'
              on_select:t='onUnlockSelect'
            }

            tdiv {
              position:t='absolute'
              top:t='ph-h'
              size:t='pw, 36@sf/@pf'
              background-image:t='#!ui/images/profile/wnd_gradient.svg'
              background-color:t='#FF111922'
              background-repeat:t='expand-svg'
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
