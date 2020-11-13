<<#showAllCheckBoxEnabled>>
CheckBox {
  id:t='checkbox_show_all_promo_blocks'
  pos:t='pw - 1@bw - w, 0'
  position:t='relative'
  on_change_value:t='onShowAllCheckBoxChange'

  <<#showAllCheckBoxValue>>
  value:t='yes'
  <</showAllCheckBoxValue>>

  <<^showAllCheckBoxValue>>
  value:t='no'
  <</showAllCheckBoxValue>>

  ButtonImg{}
  textarea {
    position:t='relative'
    pos:t='0, 50%ph-50%h'
    style:t='wrap-indent:0; paragraph-indent:0;'
    smallFont:t='yes'
    text:t='#promo/showAllPromoBlocks'
    input-transparent:t='yes'
  }
  CheckBoxImg{}
}
<</showAllCheckBoxEnabled>>

<<#promoButtons>>
promoButton {
  id:t = '<<id>>'
  type:t= '<<type>>'
  <<^show>>display:t='hide'<</show>>
  <<^show>>enable:t='no'<</show>>
  <<#hasSafeAreaPadding>>hasSafeAreaPadding:t='<<hasSafeAreaPadding>>'<</hasSafeAreaPadding>>
  <<#inputTransparent>>
    input-transparent:t='yes'
    invisibleHover:t='yes'
  <</inputTransparent>>
  collapsed:t='<<collapsed>>'

  bgGradientRight {}

  <<#isMultiblock>>
  behavior:t = 'Timer'
  timer_handler_func:t = 'selectNextBlock'
  timer_interval_msec:t='1000'
  <</isMultiblock>>

  <<#timerFunc>>
  behavior:t = 'Timer'
  timer_handler_func:t = '<<timerFunc>>'
  timer_interval_msec:t='1000'
  <</timerFunc>>

  <<#image>>
  class:t='withImage'
  <</image>>

  uncollapsedContainer {
    <<#isMultiblock>>
      <<@aspect_ratio>>
    <</isMultiblock>>

    <<#fillBlocks>>
    fillBlock {
      id:t = '<<blockId>>'
      <<#isMultiblock>>
      animation:t='<<#blockShow>>show<</blockShow>><<^blockShow>>hide<</blockShow>>'
      _transp-timer:t='<<#blockShow>>1<</blockShow>><<^blockShow>>0<</blockShow>>'
      <</isMultiblock>>

      <<@aspect_ratio>>

      <<#link>> link:t='<<link>>' <</link>>

      <<#action>> on_click:t='<<action>>' <</action>>

      <<#image>>
        imageFade {
          <<@aspect_ratio>>
          img {
            background-image:t='<<image>>';
          }
        }
      <</image>>

      textareaFade {

        <<#isMultiblock>>
        RadioButtonList {
          id:t='multiblock_radiobuttons_list'
          blockId:t='<<id>>'
          position:t='absolute'
          pos:t='pw/2-w/2, -h - 1@framePadding'
          on_select:t='switchBlock'
          on_click:t='manualSwitchBlock'
          class:t='promo'
          <<#radiobuttons>>
            RadioButton {
              <<#selected>>selected:t='yes'<</selected>>
              RadioButtonImg {}
            }
          <</radiobuttons>>
        }
        <</isMultiblock>>

        <<^showTextShade>>display:t='hide'<</showTextShade>>
        textarea {
          id:t='<<id>>_text'
          text:t='<<text>>'
          <<#needTextShade>>textShade:t='yes'<</needTextShade>>

          <<#link>>
            underline{}
          <</link>>

          <<#notifyNew>>
          newIconWidget {
            id:t='<<id>>_new_icon_widget_container';
            position:t='absolute'
            pos:t='-w, 50%ph-50%h'
          }
          <</notifyNew>>

          <<#unseenIcon>>
          unseenIcon {
            position:t='absolute'
            pos:t='-w-1@blockInterval, 50%ph-50%h'
            value:t='<<unseenIcon>>'
            unseenText {}
          }
          <</unseenIcon>>
        }
      }
      <<^showTextShade>>
      <<#notifyNew>>
      newIconWidget {
        id:t='<<id>>_new_icon_widget_container';
        position:t='absolute'
        pos:t='-w, 50%ph-50%h'
      }
      <</notifyNew>>

      <<#unseenIcon>>
      unseenIcon {
        position:t='absolute'
        pos:t='-w-1@blockInterval, 50%ph-50%h'
        value:t='<<unseenIcon>>'
        unseenText {}
      }
      <</unseenIcon>>
      <</showTextShade>>
    }
    <</fillBlocks>>
  }

  collapsedContainer {
    <<^isMultiblock>>
      <<#collapsedAction>> on_click:t='<<collapsedAction>>Collapsed' <</collapsedAction>>
    <</isMultiblock>>

    shortInfoBlock {
      shortHeaderText {
        id:t='<<id>>_collapsed_text'
        text:t='<<collapsedText>>'
        <<#needTextShade>>textShade:t='yes'<</needTextShade>>

        <<#needCollapsedTextAnimSwitch>>
        animation:t='show'
        _transp-timer:t='1'
        color-factor:t='255'
        <</needCollapsedTextAnimSwitch>>
      }

      <<#needCollapsedTextAnimSwitch>>
      shortHeaderText {
        id:t='<<id>>_collapsed_text2'
        text:t='<<collapsedText>>'
        <<#needTextShade>>textShade:t='yes'<</needTextShade>>

        animation:t='hide'
        _transp-timer:t='0'
        color-factor:t='0'
      }

      animSizeObj {
        id:t='<<id>>_collapsed_size_obj'
        animation:t='hide'
        width-base:t='0' //updated from script by text1 width
        width-end:t='0' //updated from script by text2 width
        width:t='0'
        _size-timer:t='0' //hidden by default
      }
      <</needCollapsedTextAnimSwitch>>

      shortHeaderIcon {
        text:t='<<collapsedIcon>>'
        <<#needTextShade>>textShade:t='yes'<</needTextShade>>
      }
    }
  }
  baseToggleButton {
    id:t='<<id>>_toggle'
    on_click:t='onToggleItem'
    type:t='right'

    <<#needNavigateToCollapseButtton>>
    behaviour:t='wrapBroadcast'
    navigatorShortcuts:t='SpaceA'
    on_wrap_up:t='onWrapUp'
    on_wrap_down:t='onWrapDown'
    on_wrap_right:t='onWrapRight'
    on_wrap_left:t='onWrapLeft'
    <</needNavigateToCollapseButtton>>

    directionImg {}
  }
}
<</promoButtons>>
