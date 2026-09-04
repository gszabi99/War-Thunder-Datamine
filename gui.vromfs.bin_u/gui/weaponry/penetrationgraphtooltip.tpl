weaponTooltipBlock {
  size:t='994@sf/@pf, 720@sf/@pf'
  flow:t='vertical'

  weaponPresetTooltipHeader {
    width:t='pw'
    background-color:t='@frameHeaderBackgroundColor'

    textareaNoTab {
      width:t='pw'
      padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
      text:t='<<bulletNameTxt>>'
      normalFont:t='yes'
    }
  }

  tdiv {
    id:t='graph_nest'
    size:t='pw, fh'
    behaviour:t='darg'
  }
}
