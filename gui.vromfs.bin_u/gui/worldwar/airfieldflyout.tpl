button {
  pos:t='0,0'
  position:t='root'
  size:t='pw,ph'
  background-color:t = '@modalShadeColor'
  on_click:t='goBack'
}

frame {
  id:t='airfield_body'
  pos:t = '40%pw - 50%w, 50%ph - 50%h'
  position:t='absolute'
  class:t='wndNav'

  max-width:t='1@rw'
  max-height:t='1@rh'
  largeNavBarHeight:t='yes'

  frame_header {
    HorizontalListBox {
      id:t='armies_tabs'
      height:t='ph'
      class:t='header'
      normalFont:t='yes'
      activeAccesskeys:t='RS'
      on_select:t = 'onTabSelect';
      <<@headerTabs>>
    }

    Button_close {}
  }

  modificationsBlock {
    id:t='unit_blocks_place'
    overflow-y:t='auto'
    flow:t='vertical'

    behavior:t='posNavigator'
    navigatorShortcuts:t='yes'
    moveY:t='linear'
    on_wrap_up:t='onWrapUp'
    on_wrap_down:t='onWrapDown'
    on_wrap_left:t='onUnitAmountDec'
    on_wrap_right:t='onUnitAmountInc'

    <<#unitString>>
      weaponry_item {
        id:t='<<unitName>>_<<armyGroupIdx>>'
        margin-top:t='1@framePadding'
        css-hier-invalidate:t='yes'

        textareaNoTab {
          pos:t='1@flyOutSliderWidth + 2@sliderButtonSquareHeight + 1@buttonWidth - w, 2@framePadding'
          position:t='absolute'
          smallFont:t='yes'
          tooltip:t='#worldwar/airfield/unit_fly_time'
          text:t='<<maxFlyTimeText>>'
        }

        tdiv {
          width:t='1@flyOutSliderWidth + 2@sliderButtonSquareHeight + 1@buttonWidth'
          pos:t='1@slot_interval, ph-h'
          position:t='relative'
          unitName:t='<<unitName>>'
          armyGroupIdx:t='<<armyGroupIdx>>'
          css-hier-invalidate:t='yes'
          <<#disable>>
            inactive:t='yes'
          <</disable>>

          include "gui/commonParts/progressBar"
        }
        tdiv {
          class:t='rankUpList'
          <<@unitItem>>
        }
        weaponsSelectorNest {
          id:t='secondary_weapon'
          width:t='<<#hasUnitsGroups>>1@roleArmyWidth<</hasUnitsGroups>><<^hasUnitsGroups>>1@modItemWidth<</hasUnitsGroups>>'
          height:t='1@modItemHeight'
          pos:t='0, 0.5ph-0.5h'
          position:t='relative'
          css-hier-invalidate:t='yes'

          <<#unitClassesView>>
          tdiv {
            width:t='pw'
            flow:t='vertical'
            css-hier-invalidate:t='yes'
            activeText {
              text:t='#mainmenu/unitRoleInArmy'
            }
            include "gui/commonParts/combobox"
          }
          <</unitClassesView>>
        }
        wwUnitClass {
          size:t='1@modItemHeight, 1@modItemHeight'

          classIcon {
            id:t='unit_class_icon_text'
            text:t='<<unitClassIconText>>'
            tooltip:t='<<unitClassTooltipText>>'
            unitType:t='<<unitClassName>>'
          }
        }
      }
    <</unitString>>
  }

  tdiv {
    width:t='<<#hasUnitsGroups>>1@wwFlyOutScreenInfoWidthByGroup<</hasUnitsGroups>><<^hasUnitsGroups>>1@wwFlyOutScreenInfoWidth<</hasUnitsGroups>>'
    left:t='0.5(pw-w)'
    position:t='relative'
    flow:t='vertical'

    textareaNoTab {
      id:t='armies_limit_text'
      width:t='pw'
      margin:t='2@blockInterval'
      text-align:t='center'
      text:t=''
      smallFont:t='yes'
    }

    tdiv {
      width:t='pw'
      padding:t='1@blockInterval'
      bgcolor:t='@objectiveHeaderBackground'

      textareaNoTab {
        id:t='army_info_text'
        width:t='fw'
        top:t='0.5(ph-h)'
        position:t='relative'
        text-align:t='center'
        text:t=''
        tooltip:t=''
        smallFont:t='yes'
      }

      <<#hintText>>
      cardImg {
        background-image:t='#ui/gameuiskin#btn_help.svg'
        tooltip:t='<<hintText>>'
      }
      <</hintText>>
    }

    tdiv {
      width:t='pw'
      position:t='relative'
      include "gui/worldWar/airfieldFlyOutUnitTypeInfo"
    }
  }

  navBar{}

  dummy {
    behavior:t='accesskey'
    accessKey:t = 'J:Y'
    on_click:t = 'onUnitAmountMax'
  }
  <<^hasUnitsGroups>>
  dummy {
    behavior:t='accesskey'
    accessKey:t = 'J:X'
    on_click:t = 'onOpenPresetsList'
  }
  <</hasUnitsGroups>>
}
