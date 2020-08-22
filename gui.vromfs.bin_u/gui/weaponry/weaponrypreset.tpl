<<#presets>>
weaponryPreset {
  id:t='preset'
  presetId:t='<<presetId>>'
  width:t='pw'
  padding:t='0, 1@blockInterval'
  showOrNoneOn:t='selectedOnConsole'
  ButtonImg {}
  <<#isCollapsable>>
  height:t='@buttonHeight'
  collapse_header:t='yes'
  collapsed:t='no'
  collapsing:t='no'
  on_click:t='onCollapse'
  btnName:t='A'
  <</isCollapsable>>
  <<^isCollapsable>>
  height:t='@tierIconSize'
  on_click:t='onPresetClick'
  btnName:t='Y'
  <</isCollapsable>>

  tdiv {
    width:t='pw'
    overflow:t='hidden'
    position:t='absolute'
    <<#isShowConsoleBtn>>
    pos:t='@cIco, 0'
    <</isShowConsoleBtn>>
    <<#weaponryItem>>
    tdiv {
      id:t='tiersNest'
      flow:t='horizontal'
      <<#isSelected>>
      selected:t='yes'
      <</isSelected>>
      behaviour:t='posNavigator'
      showSelect:t='always'
      navigatorShortcuts:t='yes'
      css-hier-invalidate:t='yes'
      total-input-transparent:t='yes'
      on_select:t='onTierSelect'
      presetHeader {
        id:t='presetHeader'
        presetId:t='<<presetId>>'
        size:t='<<presetTextWidth>>, @tierIconSize'
        behaviour:t='button'
        css-hier-invalidate:t='yes'
        on_click:t='onPresetClick'
        on_dbl_click:t='onModItemDblClick'
        <<^hideWarningIcon>>
        warning_icon{
          position:t='relative'
          size:t='@cIco, @cIco'
          background-image:t='#ui/gameuiskin#new_icon'
          bgcolor:t='#FFFFFF'
        }
        <</hideWarningIcon>>
        textareaNoTab {
          width:t='pw<<^hideWarningIcon>>-1@cIco<</hideWarningIcon>>'
          position:t='relative'
          pos:t='0, 30@sf/@pf-0.5h'
          text:t='<<nameText>>'
          text-align:t='left'
          style:t='color:@<<itemTextColor>>;'
          smallFont:t='yes'
          <<#hideWarningIcon>>
          padding:t='1@blockInterval, 0'
          <</hideWarningIcon>>
        }
        img{
          id:t='image'
          size:t='pw-2@weaponIconPadding, ph-2@weaponIconPadding'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'

          <<@modUpgradeIcon>>
          upgradeImg {
            id:t='upgrade_img'
            upgradeStatus:t=''
          }
        }
        focus_border {}
      }
      <<#tiers>>
      weaponryTier{
        id:t='tier'
        tierId:t='<<tierId>>'
        size:t='@tierIconSize, @tierIconSize'
        on_click:t='onTierClick'
        on_dbl_click:t='onModItemDblClick'
        img {
          size:t='pw, ph'
          position:t='relative'
          background-image:t='<<#img>><<img>><</img>>'
          background-repeat:t='expand'
        }
        title:t='$tooltipObj'
        tooltipObj {
          id:t='tierTooltip'
          tooltipId:t='<<tierTooltipId>>'
          on_tooltip_open:t='onGenericTooltipOpen'
          on_tooltip_close:t='onTooltipObjClose'
          display:t='hide'
        }
        focus_border {}
      }
      <</tiers>>
    }
    <</weaponryItem>>
  }

  <<#isCollapsable>>
  fullSizeCollapseBtn {
    size:t='pw, ph'
    total-input-transparent:t='yes'
    css-hier-invalidate:t='yes'
    activeText{}
    ButtonImg {}
    text {
      position:t='relative'
      pos:t='<<chapterPos>>-0.5w-1@sIco, 0'
      text:t='<<chapterName>>'
    }
  }
  <</isCollapsable>>
  focus_border {}
}
<</presets>>