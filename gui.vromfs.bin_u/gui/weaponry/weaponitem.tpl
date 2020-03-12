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

  tdiv {
    id:t='modItem_discount';
    pos:t='pw-w, -1@discountBoxDownHeight + 8*@sf/@pf_outdated';
    position:t='absolute';
  }

  weaponBody{
    id:t='centralBlock'
    holderId:t='<<id>>'
    size:t='pw, 1@modItemHeight'
    pos:t='50%pw-50%w, 0';
    position:t='absolute'
    behaviour:t='button'
    on_click:t='onModItemClick'
    on_dbl_click:t = 'onModItemDblClick'

    include "gui/weaponry/weaponIcon"

    img {
      id:t='status_icon'
      size:t='1@weaponStatusIconSize, 1@weaponStatusIconSize'
      pos:t='1@weaponIconPadding, 1@weaponIconPadding'
      position:t='absolute'
      background-image:t=''
      background-svg-size:t='1@weaponStatusIconSize, 1@weaponStatusIconSize'
    }

    weaponInfoBg {
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
          id:t='name';
          width:t='fw'
          height:t='ph'
          smallFont:t='yes'
          pare-text:t='yes'
          position:t='relative'
        }

        <<#wideItemWithSlider>>
        textareaNoTab {
          id:t='price';
          smallFont:t='yes'
          text:t='';
          hideEmptyText:t='yes'
          padding-right:t='2*@sf/@pf_outdated'
        }
        tdiv{
          id:t='modItem_statusBlock';
          pos:t='0,0'
          position:t='relative'
          css-hier-invalidate:t='yes'
          <<#hideStatus>>display:t='hide'<</hideStatus>>
          statusImg {
            id:t='status_image'
            holderId:t='<<id>>'
            size:t='1@modStatusHeight, 1@modStatusHeight';
            pos:t='0,0'
            position:t='relative'
            behaviour:t='button'
            on_click:t='onModCheckboxClick'
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

        display:t='hide'
        enable:t='no'

        textAreaCentered {
          id:t='bulletsCountText'
          pos:t='50%pw-50%w, 0';
          position:t='relative'
          tinyFont:t='yes'
          text:t='12 / <color=@red>7</color>'
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
            tooltip:t='#unit/bulletsDecrease'
            btnName:t='LB'
            bulletsLimit:t='no'
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
            value:t='300'; min:t='0'; max:t='1000'
            on_change_value:t='onModChangeBulletsSlider'
            groupIdx:t = '-1'

            expProgress {
              id:t='bulletsSlider'
              width:t='pw'
              pos:t='50%pw-50%w, 50%ph-50%h';
              position:t="absolute"
              type:t='new'
              value:t='100'
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
            bulletsLimit:t='no'
            on_click:t='onModIncreaseBullets'

            ButtonImg{}
          }
          <</needSliderButtons>>
        }
      }

      tdiv{
        pos:t='pw-w, 0';
        position:t='relative';
        max-width:t='pw'
        css-hier-invalidate:t='yes'

        tdiv {
          id:t='mod_research_block';
          width:t='p.p.w - 4@dp'
          pos:t='pw-w-1@dp, ph-h-3@dp';
          position:t='relative';
          flow:t='vertical';

          textareaNoTab {
            id:t='mod_research_text';
            pos:t='0.5pw - 0.5w, 0';
            position:t='relative';
            tinyFont:t='yes'
            text:t=''
          }
          tdiv {
            width:t='pw'

            modResearchProgress {
              id:t='mod_research_progress';
              paused:t='no';
            }
            modResearchProgress {
              id:t='mod_research_progress_old';
              type:t='old'
              position:t='absolute'
              value:t='500'
              paused:t='no';
            }
          }
        }
        <<^wideItemWithSlider>>
        textareaNoTab {
          id:t='price';
          smallFont:t='yes'
          text:t='';
          pos:t='0, ph-h';
          position:t='relative'
          hideEmptyText:t='yes'
          padding-right:t='2*@sf/@pf_outdated'
        }
        tdiv{
          id:t='modItem_statusBlock';
          pos:t='0,0'
          position:t='relative'
          css-hier-invalidate:t='yes'
          <<#hideStatus>>display:t='hide'<</hideStatus>>
          statusImg {
            id:t='status_image'
            holderId:t='<<id>>'
            size:t='1@modStatusHeight, 1@modStatusHeight';
            pos:t='0,0'
            position:t='relative'
            behaviour:t='button'
            on_click:t='onModCheckboxClick'
          }
          RadioButton {
            id:t='status_radio'
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
      size:t='19, 10';
      position:t='absolute';
      pos:t='0.5pw - 0.5w, ph';
      <<^isBundle>>display:t='hide'<</isBundle>>

      background-repeat:t='expand'
      background-position:t='0, 0'
      background-image:t='#ui/gameuiskin#drop_menu_arrow_black_bg';
      background-color:t='@white';

      tdiv{
        size:t='11*@sf/@pf_outdated, 8*@sf/@pf_outdated'
        pos:t='50%pw-50%w, -1*@sf/@pf_outdated'
        position:t='absolute'
        background-repeat:t='expand'
        background-image:t='#ui/gameuiskin#drop_menu_icon.svg'
        background-svg-size:t='11*@sf/@pf_outdated, 8*@sf/@pf_outdated'
        background-color:t='@gray';
      }
    }
  }

  title:t='$tooltipObj';
  tooltipObj {
    id:t='tooltip_<<id>>'
    <<^useGenericTooltip>>
    on_tooltip_open:t='onModificationTooltipOpen'
    <</useGenericTooltip>>
    <<#useGenericTooltip>>
    tooltipId:t=''
    on_tooltip_open:t='onGenericTooltipOpen'
    <</useGenericTooltip>>
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide';
  }

  modSlotButtonsNest {
    Button_text{
      id:t='altActionBtn'
      holderId:t='<<id>>'
      class:t='additional'
      text:t='';
      display:t='hide'
      canShow:t='no'
      btnName:t='X'
      on_click:t='onAltModAction'
      visualStyle:t='purchase'
      buttonWink {}
      buttonGlance{}
      textarea {
        id:t='item_buy_text'
        text:t='';
        class:t='buttonText';
        text-align:t='center';
        smallFont:t='yes'
      }
      ButtonImg {}
    }

    Button_text{
      id:t='actionBtn'
      holderId:t='<<id>>'
      class:t='additional'
      visualStyle:t='common'
      text:t='#weaponry/research';
      on_click:t='onModActionBtn'
      display:t='hide'
      btnName:t='A'
      hasIncreasedTopMargin:t='yes'
      ButtonImg {}
    }
  }

  <<#shortcutIcon>>
  ButtonImg{
    btnName:t='<<shortcutIcon>>'
    showOnSelect:t='yes'
  }
  <</shortcutIcon>>
}
