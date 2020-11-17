<<#presets>>
weaponryPreset {
  id:t='preset'
  presetId:t='<<presetId>>'
  width:t='pw'
  padding:t='0, 1@blockInterval'
  chosen:t='<<chosen>>'
  <<#isCollapsable>>
  height:t='@buttonHeight'
  collapse_header:t='yes'
  collapsed:t='no'
  collapsing:t='no'
  <</isCollapsable>>
  <<^isCollapsable>>
  height:t='@tierIconSize'
  <</isCollapsable>>

  tdiv {
    width:t='pw'
    overflow:t='hidden'
    position:t='absolute'
    <<#isShowConsoleBtn>>
    pos:t='@cIco, 0'
    <</isShowConsoleBtn>>
    <<#weaponryItem>>
    DummyButton {
      presetId:t='<<presetId>>'
      size:t='pw-@cIco, @tierIconSize'
      position:t='absolute'
      skip-navigation:t='yes'
      on_click:t='onPresetSelect'
      _on_dbl_click:t='onModItemDblClick'
    }
    tdiv {
      id:t='tiersNest_<<presetId>>'
      presetId:t='<<presetId>>'
      flow:t='horizontal'
      behaviour:t='posNavigator'
      showSelect:t='always'
      canSelectNone:t='yes'
      navigatorShortcuts:t='yes'
      css-hier-invalidate:t='yes'
      total-input-transparent:t='yes'
      on_select:t='onCellSelect'
      _on_dbl_click:t='onModItemDblClick'
      on_unhover:t='onPresetUnhover'
      presetHeader {
        id:t='presetHeader_<<presetId>>'
        presetId:t='<<presetId>>'
        size:t='<<presetTextWidth>>, @tierIconSize'
        css-hier-invalidate:t='yes'
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
          text:t='<<nameTextWithPrice>>'
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
        <<^isActive>>enable:t='no'<</isActive>>
        img {
          size:t='pw, ph'
          position:t='relative'
          background-image:t='<<#img>><<img>><</img>>'
          background-repeat:t='expand'
        }
        <<#tierTooltipId>>
        title:t='$tooltipObj'
        tooltip-float:t='horizontal'
        tooltipObj {
          id:t='tierTooltip'
          tooltipId:t='<<tierTooltipId>>'
          on_tooltip_open:t='onGenericTooltipOpen'
          on_tooltip_close:t='onTooltipObjClose'
          display:t='hide'
        }
        <</tierTooltipId>>
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
    input-transparent:t='no'
    css-hier-invalidate:t='yes'
    on_click:t='onCollapse'
    activeText{}
    ButtonImg {}
    text {
      position:t='relative'
      pos:t='<<chapterPos>>-0.5w-1@sIco, 0'
      text:t='<<chapterName>>'
    }
  }
  <</isCollapsable>>
}
<</presets>>