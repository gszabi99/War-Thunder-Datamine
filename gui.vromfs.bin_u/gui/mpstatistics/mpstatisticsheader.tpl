tr {
  size:t = '<<trSize>>'

  <<#headerCells>>
  td {
    activeText {
      id:t='<<cellId>>'
      text:t='#multiplayer/<<cellText>>'
      pare-text:t='yes'
      width:t='fw'

      <<#hasCellBorder>>
      cellType:t = 'border'
      <</hasCellBorder>>
    }
  }
  <</headerCells>>
}
