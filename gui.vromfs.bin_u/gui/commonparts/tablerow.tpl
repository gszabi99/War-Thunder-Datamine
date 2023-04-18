tr {
  id:t='<<row_id>>'
  <<#even>> even:t='yes' <</even>>
  <<@trParams>>

  <<#cell>>
  td {
    <<#params>>
      <<#id>>id:t='<<id>>'<</id>>
      <<#active>> active:t='yes' <</active>>
      <<#display>>display:t='<<display>>'<</display>>
      <<#cellType>> cellType:t='<<cellType>>' <</cellType>>
      <<#width>>
        width:t='<<width>>'
        <<#autoScrollText>>
          autoScrollText:t='<<autoScrollText>>'
          overflow:t='hidden'
        <</autoScrollText>>
      <</width>>
      <<#tdalign>> tdalign:t='<<tdalign>>' <</tdalign>>
      <<#tooltipId>>tooltip:t='$tooltipObj'<</tooltipId>>
      <<^tooltipId>>
        <<#tooltip>> tooltip:t='<<tooltip>>' <</tooltip>>
      <</tooltipId>>
      <<@rawParam>>

      <<#callback>>
        behaviour:t='button'
        on_click:t='<<callback>>'
      <</callback>>

      <<#needText>>
        <<@textType>> {
          id:t='txt_<<id>>'
          <<#width>>
            <<^autoScrollText>>
              width:t='fw'
              pare-text:t='yes'
            <</autoScrollText>>
          <</width>>
          text:t='<<text>>'
          <<@textRawParam>>
        }
      <</needText>>

      <<#image>>
        <<@imageType>> {
          id:t='img_<<id>>'
          top:t='50%ph-50%h'; position:t='relative'
          background-image:t='<<image>>'
          input-transparent:t='yes'
          <<@imageRawParams>>
        }
      <</image>>
      <<^image>>
        <<#fontIcon>>
        <<@fontIconType>> {
          fonticon { text:t='<<fontIcon>>' }
        }
        <</fontIcon>>
      <</image>>

    <</params>>
    <<^params>>
      activeText {
        <<#width>>
          width:t='pw'
          pare-text:t='yes'
        <</width>>
        text:t='<<text>>'
      }
    <</params>>

    <<#tooltipId>>
    tooltipObj {
      tooltipId:t='<<tooltipId>>'
      display:t='hide'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
    }
    <</tooltipId>>
  }
  <</cell>>
}
