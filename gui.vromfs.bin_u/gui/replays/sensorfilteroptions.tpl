tdiv {
  id:t='sensorFiltersPages'
  position:t='relative'

  tdiv {
    position:t='absolute'
    width:t='pw'
    top:t='-h'
    height:t='@mIco'
    bgcolor:t='#CC111821'
    overflow:t='hidden'
    input-transparent:t='yes'
    textarea {
      id:t='sensorsFiltersLabel'
      auto-scroll:t='medium'
      position:t='relative'
      pos:t='(pw - w)/2, (ph-h)/2'
      text:t='sensorsFiltersLabel'
    }
  }

  <<#pages>>
  tdiv {
    padding-top:t='1@blockInterval'
    width:t='1.25@spectatorTableWidth'
    flow:t='vertical'
    position:t='relative'

    id:t='<<id>>'
    <<#options>>
      tdiv {
        padding-top:t='1@blockInterval'
        padding-bottom:t='1@blockInterval'
        padding-left:t='1@blockInterval'
        width:t='pw'
        position:t='relative'
        tdiv {
          position:t='relative'
          <<#switchBox>>
            width:t='pw - 1@switchBoxWidth - 3@blockInterval'
          <</switchBox>>

          <<#comboBox>>
            width:t='pw - 2@switchBoxWidth - 3@blockInterval'
          <</comboBox>>
          textarea {
            class:t='parInvert'
            text:t='<<optName>>'
            smallFont:t='yes'
            width:t='pw'
          }
        }

        <<#switchBox>>
          SwitchBox {
            position:t='absolute'
            pos:t='pw - w - 2@blockInterval, 0'
            filterId:t='<<fid>>'
            <<#id>>
              id:t='<<id>>'
            <</id>>
            value:t='<<makeValue>>'
            textChecked:t='#options/yes'
            textUnchecked:t='#options/no'
            needSmallText:t='yes'
            on_change_value:t='doFilterChange'
            SwitchSliderBg { SwitchSliderBgOn {} SwitchSlider {} }
          }
        <</switchBox>>

        <<#comboBox>>
          ComboBox{
            id:t='<<id>>'
            measureType:t='<<measureType>>'
            size:t='2@switchBoxWidth, 0.5@switchBoxHeight'
            pos:t='pw - w - 2@blockInterval, 0'
            position:t='absolute'
            on_select:t='onSensorMeasureSelect'
            min-height:t='0'

            <<#measures>>
             option{
                re-type:t='9rect'
                size:t='pw, ph'
                display:t='none'
                color:t='#FFeeeeee'
                overflow:t='hidden'
                input-transparent:t='yes'
                css-hier-invalidate:t='yes'
                textareaNoTab {
                  position:t='relative'
                  text:t='<<label>>'
                  pos:t='0, ph-h'
                }
             }
            <</measures>>
          }
        <</comboBox>>
      }
    <</options>>
  }
  <</pages>>
}

toggleButton {
  id:t='btnToggleSensorFilters'
  position:t='absolute'
  attachSide:t='right'
  toggled:t='yes'
  toggleObj:t='sensorFiltersPages'
  pos:t='pw - w, -1@mIco'
  bgcolor:t='#CC111821'
  on_click:t='onToggleButtonClick'

  icon {}
}

VerticalListBox {
  id:t = 'filtersButtons'
  position:t='relative';
  flow:t = 'vertical'
  overflow-y:t='auto'
  clearOnFocusLost:t='no'
  navigator:t='posNavigator'
  navigatorShortcuts:t='yes'
  noPadding:t='yes'
  on_select:t = 'onSensorFilterPageSelect'

  <<#items>>
    shopFilter {
      size:t='1@mIco, 1@mIco'
      margin-left:t='0'
      margin-top:t='0'
      margin-bottom:t='0'
      <<#tooltip>>
        tooltip:t='<<tooltip>>'
      <</tooltip>>
      <<#iconText>>
        fontSize:t='big'
        text:t='<<iconText>>'
      <</iconText>>
      <<#imgBg>>
        shopFilterImg {
          background-image:t='<<imgBg>>'
        }
      <</imgBg>>
    }
  <</items>>
}
