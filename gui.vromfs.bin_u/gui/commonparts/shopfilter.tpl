<<#items>>
  shopFilter {
    <<#id>>
      id:t='<<id>>'
    <</id>>

    tooltip:t='<<tooltip>>'

    <<@params>>
    <<@objects>>

    <<#disabled>>
      enable:t='no'
    <</disabled>>
    <<^disabled>>
      <<#selected>>
        selected:t='yes'
      <</selected>>
    <</disabled>>

    <<#inactive>>
      inactive:t='yes'
    <</inactive>>

    <<#newIconWidget>>
    tdiv {
      id:t='filter_new_icon_widget'
      padding-top:t='-2@dp'
      valign:t='center'
      <<@newIconWidget>>
    }
    <</newIconWidget>>

    <<#unseenIcon>>
    unseenIcon {
      <<#unseenIconId>>id:t='<<unseenIconId>>'<</unseenIconId>>
      valign:t='center'
      value:t='<<unseenIcon>>'
      unseenText {}
    }
    <</unseenIcon>>

    <<#image>>
      shopFilterImg {
        id:t='<<id>>_icon'
        background-image:t='<<image>>'
        <<@imageParams>>
      }
    <</image>>

    <<#autoScrollText>>
      autoScrollText:t='yes'
      tdiv {
        width:t='fw'
        position:t='relative'
        top:t='50%ph-50%h'
        overflow:t='hidden'
        css-hier-invalidate:t='yes'
        shopFilterText {
          text:t='<<text>>'
          hideEmptyText:t='yes'
          behaviour:t='OverflowScroller'
          move-pixel-per-sec:t='20*@scrn_tgt/100.0'
          move-sleep-time:t='1000'
          move-delay-time:t='1000'
        }
      }
    <</autoScrollText>>

    <<^autoScrollText>>
      shopFilterText {
        text:t='<<text>>'
        id:t='<<id>>_text'
        hideEmptyText:t='yes'
      }
    <</autoScrollText>>

    <<#navigationImage>>
      <<@navigationImage>>
    <</navigationImage>>

    <<#discountNotification>>
      discount_notification {
        <<#id>>
          id:t='<<id>>_discount'
        <</id>>
        type:t='<<type>>'
        text:t=''
      }
    <</discountNotification>>
  }
<</items>>
