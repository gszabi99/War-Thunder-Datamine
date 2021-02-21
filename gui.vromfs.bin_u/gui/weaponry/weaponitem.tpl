weaponry_item {
  id:t='<<id>>'
  height:t='1@modItemHeight'
  width:t='<<itemWidth>>@modItemWidth'
  pos:t='(<<posX>> + 0.5 * <<itemWidth>>) * 1@modCellWidth - 0.5w, (<<posY>> + 0.5) * 1@modCellHeight - 0.5h'
  position:t='absolute'
  <<#isBundle>>
  isBundle='yes'
  <</isBundle>>
  flow:t='vertical'
  total-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  equipped:t='<<optEquipped>>'
  status:t= '<<optStatus>>'
  <<#wideItemWithSlider>>wideItemWithSlider:t='yes'<</wideItemWithSlider>>
  <<#isTooltipByHold>>
  tooltipId:t='<<tooltipId>>'
  tooltip:t=''
  <</isTooltipByHold>>

  tdiv {
    id:t='modItem_discount'
    pos:t='pw-w, -1@discountBoxDownHeight + 10@sf/@pf'
    position:t='absolute'
    <<^isShowDiscount>>
    display:t='hide'
    <</isShowDiscount>>
    discount{
      id:t='discount'
      type:t='weaponryItem'
      tooltip:t='<<discountTooltip>>'
      text:t='<<discountText>>'
    }
  }
  weaponBody {
    id:t='centralBlock'
    holderId:t='<<id>>'
    size:t='pw, ph'
    pos:t='50%pw-50%w, 0'
    position:t='absolute'
    behaviour:t='button'
    on_click:t='onModItemClick'
    on_dbl_click:t = 'onModItemDblClick'

    <<#isTooltipByHold>>
    tooltipId:t='<<tooltipId>>'
    on_pushed:t='::gcb.delayedTooltipPush'
    on_hold_start:t='::gcb.delayedTooltipHoldStart'
    on_hold_stop:t='::gcb.delayedTooltipHoldStop'
    on_hover:t='::gcb.delayedTooltipHover'
    on_unhover:t='::gcb.delayedTooltipHover'
    <</isTooltipByHold>>

    <<#wideItemWithSlider>>
    behaviour:t='wrapBroadcast'
    horizontalByShifts:t='yes'
    on_wrap_right:t='onModIncreaseBullets'
    on_wrap_left:t='onModDecreaseBullets'
    <</wideItemWithSlider>>

    topLine {}
    wallpaper {
      size:t='pw, ph'
      position:t='absolute'
      css-hier-invalidate:t='yes'
      pattern {}
    }

    include "gui/weaponry/weaponIcon"
    itemWinkBlock { buttonWink { _transp-timer:t='0' } }
    hoverHighlight {}

    img {
      id:t='status_icon'
      size:t='1@weaponStatusIconSize, 1@weaponStatusIconSize'
      pos:t='1@weaponIconPadding, 1@weaponIconPadding'
      position:t='absolute'
      background-image:t='<<statusIconImg>>'
      background-svg-size:t='1@weaponStatusIconSize, 1@weaponStatusIconSize'
    }

    tdiv {
      size:t='fw, ph'
      pos:t='0,50%ph-50%h'
      position:t='relative'
      padding:t='1@dp, 2@dp'
      flow:t='vertical'
      css-hier-invalidate:t='yes'

      tdiv {
        size:t='pw, fh'
        css-hier-invalidate:t='yes'
        textareaNoTab {
          id:t='name'
          width:t='fw'
          height:t='ph'
          smallFont:t='yes'
          pare-text:t='yes'
          position:t='relative'
          text:t='<<nameText>>'
        }

        <<#wideItemWithSlider>>
        textareaNoTab {
          id:t='price'
          smallFont:t='yes'
          text:t='<<priceText>>'
          hideEmptyText:t='yes'
          padding-right:t='3@sf/@pf'
          <<^isShowPrice>>display:t='hide'<</isShowPrice>>
        }
        tdiv{
          id:t='modItem_statusBlock'
          pos:t='0,0'
          position:t='relative'
          css-hier-invalidate:t='yes'
          <<#hideStatus>>display:t='hide'<</hideStatus>>
          statusImg {
            id:t='status_image'
            holderId:t='<<id>>'
            size:t='1@modStatusHeight, 1@modStatusHeight'
            pos:t='0,0'
            position:t='relative'
            behaviour:t='button'
            on_click:t='onModCheckboxClick'
            <<^isShowStatusImg>>display:t='hide'<</isShowStatusImg>>
          }
        }
        <</wideItemWithSlider>>
      }
      tdiv {
        id:t='bullets_amount_choice_block'
        width:t='pw'
        padding-bottom:t='1@dp'
        flow:t='vertical'
        css-hier-invalidate:t='yes'
        <<#hideBulletsChoiceBlock>>
        display:t='hide'
        enable:t='no'
        <</hideBulletsChoiceBlock>>

        textAreaCentered {
          id:t='bulletsCountText'
          pos:t='50%pw-50%w, 0'
          position:t='relative'
          tinyFont:t='yes'
          text:t='<<bulletsCountText>>'
        }

        tdiv {
          width:t='pw'
          padding:t='1@dp, 0'
          css-hier-invalidate:t='yes'

          <<#needSliderButtons>>
          Button_text {
            id:t='buttonDec'
            holderId:t='<<id>>'
            pos:t='0, 50%ph - 50%h'
            position:t='relative'
            class:t='sliderValueButton'
            type:t='weaponryAmount'
            text:t='-'
            skip-navigation:t='yes'
            tooltip:t='#unit/bulletsDecrease'
            btnName:t='LB'
            bulletsLimit:t='<<decBulletsLimit>>'
            on_click:t='onModDecreaseBullets'

            ButtonImg{}
          }
          <</needSliderButtons>>

          invisSlider {
            id:t='invisBulletsSlider'
            size:t='fw, 2@scrn_tgt/100.0'
            margin:t='0.5@sliderThumbWidth, 0'
            pos:t='0, 50%ph-50%h'
            position:t='relative'
            value:t='<<invSliderValue>>'
            min:t='0'
            max:t='<<invSliderMax>>'
            on_change_value:t='onModChangeBulletsSlider'
            groupIdx:t = '<<sliderGroupIdx>>'
            horizontalByShifts:t='yes'
            skip-navigation:t='yes'

            expProgress {
              id:t='bulletsSlider'
              width:t='pw'
              pos:t='50%pw-50%w, 50%ph-50%h'
              position:t="absolute"
              type:t='new'
              value:t='<<sliderValue>>'
              max:t='<<sliderMax>>'
            }

            sliderButton {
              type:t='various'
              img{}
            }
          }

          <<#needSliderButtons>>
          Button_text {
            id:t='buttonInc'
            holderId:t='<<id>>'
            pos:t='0, 50%ph - 50%h'
            position:t='relative'
            class:t='sliderValueButton'
            type:t='weaponryAmount'
            text:t='+'
            tooltip:t='#unit/bulletsIncrease'
            btnName:t='RB'
            skip-navigation:t='yes'
            bulletsLimit:t='<<incBulletsLimit>>'
            on_click:t='onModIncreaseBullets'

            ButtonImg{}
          }
          <</needSliderButtons>>
        }
      }
      tdiv{
        pos:t='pw-w, 0'
        position:t='relative'
        max-width:t='pw'
        css-hier-invalidate:t='yes'
        tdiv {
          id:t='mod_research_block'
          width:t='p.p.w - 4@dp'
          pos:t='pw-w-1@dp, ph-h-3@dp'
          position:t='relative'
          flow:t='vertical'
          <<#hideProgressBlock>>display:t='hide'<</hideProgressBlock>>

          textareaNoTab {
            id:t='mod_research_text'
            pos:t='0.5pw - 0.5w, 0'
            position:t='relative'
            tinyFont:t='yes'
            text:t=''
          }
          tdiv {
            width:t='pw'

            modResearchProgress {
              id:t='mod_research_progress'
              value:t='<<researchProgress>>'
              type:t='<<progressType>>'
              paused:t='<<progressPaused>>'
            }
            modResearchProgress {
              id:t='mod_research_progress_old'
              type:t='old'
              position:t='absolute'
              value:t='<<oldResearchProgress>>'
              paused:t='<<progressPaused>>'
              <<#isShowOldResearchProgress>>display:t='hide'<</isShowOldResearchProgress>>
            }
          }
        }
        <<^wideItemWithSlider>>
        textareaNoTab {
          id:t='price'
          smallFont:t='yes'
          text:t='<<priceText>>'
          pos:t='0, ph-h'
          position:t='relative'
          hideEmptyText:t='yes'
          padding-right:t='3@sf/@pf'
          <<^isShowPrice>>display:t='hide'<</isShowPrice>>
        }
        tdiv{
          id:t='modItem_statusBlock'
          pos:t='0,0'
          position:t='relative'
          css-hier-invalidate:t='yes'
          <<#hideStatus>>
          display:t='hide'
          <</hideStatus>>
          statusImg {
            id:t='status_image'
            holderId:t='<<id>>'
            size:t='1@modStatusHeight, 1@modStatusHeight'
            pos:t='0,0'
            position:t='relative'
            behaviour:t='button'
            on_click:t='onModCheckboxClick'
            skip-navigation:t='yes'
            <<^isShowStatusImg>>
            display:t='hide'
            <</isShowStatusImg>>
          }
          RadioButton {
            id:t='status_radio'
            <<#hideStatusRadio>>
            display:t='hide'
            <</hideStatusRadio>>
            RadioButtonImg {
              holderId:t='<<id>>'
              on_click:t='onModCheckboxClick'
            }
          }
        }
        <</wideItemWithSlider>>
      }
    }
    tdiv{
      id:t='modItem_visualHasMenu'
      size:t='19@sf/@pf, 10@sf/@pf'
      position:t='absolute'
      pos:t='0.5pw - 0.5w, ph'
      <<#hideVisualHasMenu>>display:t='hide'<</hideVisualHasMenu>>

      background-repeat:t='expand'
      background-position:t='0, 0'
      background-image:t='#ui/gameuiskin#drop_menu_arrow_bg.svg'
      background-svg-size:t='19@sf/@pf, 10@sf/@pf'
      background-color:t='@dropMenuArrowColor'
    }
  }

  <<^isTooltipByHold>>
  title:t='$tooltipObj'
  tooltip-float:t='horizontal'
  tooltipObj {
    id:t='tooltip_<<id>>'
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
  <</isTooltipByHold>>

  modSlotButtonsNest {
    display:t='hide'
    Button_text{
      id:t='altActionBtn'
      holderId:t='<<id>>'
      class:t='additional'
      text:t=''
      canShow:t='<<altBtnCanShow>>'
      tooltip:t='<<altBtnTooltip>>'
      btnName:t='X'
      on_click:t='onAltModAction'
      visualStyle:t='purchase'
      skip-navigation:t='yes'
      buttonWink {}
      buttonGlance{}
      textarea {
        id:t='altBtnBuyText'
        text:t='<<altBtnBuyText>>'
        class:t='buttonText'
        text-align:t='center'
        smallFont:t='yes'
      }
      ButtonImg {}
    }

    Button_text{
      id:t='actionBtn'
      holderId:t='<<id>>'
      class:t='additional'
      canShow:t='<<actionBtnCanShow>>'
      visualStyle:t='common'
      skip-navigation:t='yes'
      text:t='<<actionBtnText>>'
      on_click:t='onModActionBtn'
      <<#isTooltipByHold>>
      on_pushed:t='::gcb.delayedTooltipChildPush'
      on_hold_start:t='::gcb.delayedTooltipChildHoldStart'
      on_hold_stop:t='::gcb.delayedTooltipChildHoldStop'
      <</isTooltipByHold>>
      btnName:t='A'
      hasIncreasedTopMargin:t='yes'
      ButtonImg {}
    }

    <<#isTooltipByHold>>
    dummy {
      id:t='actionHoldDummy'
      behavior:t='accesskey'
      btnName:t='A'
      on_pushed:t='::gcb.delayedTooltipChildPush'
      on_hold_start:t='::gcb.delayedTooltipChildHoldStart'
      on_hold_stop:t='::gcb.delayedTooltipChildHoldStop'
    }
    <</isTooltipByHold>>
  }

  <<#shortcutIcon>>
  ButtonImg{
    btnName:t='<<shortcutIcon>>'
    showOnSelect:t='yes'
  }
  <</shortcutIcon>>
}
