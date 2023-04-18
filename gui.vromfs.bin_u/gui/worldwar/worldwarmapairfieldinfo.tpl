activeText {
  id:t='label_airfield'
  text:t='#worldwar/airfield'
  mediumFont:t='yes'
  pos:t='50%pw-50%w, 1@framePadding'
  position:t='relative'
}

tdiv {
  pos:t='pw/2 - w/2, 0'
  position:t='relative'
  padding:t='0, 1@framePadding'
  tdiv {
    id:t='airfield_column_1'
    width:t='fw'
    flow:t='vertical'
    margin:t='0.01@scrn_tgt, 0'
    textarea {
      id:t='text_airfield_name_1'
      pos:t='50%pw-50%w, 0';
      position:t='relative'
    }
    table {
      id:t='table_airfield_side_1'
      pos:t='50%pw-50%w, 0.01@scrn_tgt'
      position:t='relative'
    }
    textarea {
      id:t='text_airfield_empty_side_1'
      pos:t='50%pw-50%w, 0';
      position:t='relative'
      text:t='#worldwar/noUnits'
    }
  }
  tdiv {
    id:t='airfield_column_2'
    width:t='fw'
    flow:t='vertical'
    margin:t='0.01@scrn_tgt, 0'
    textarea {
      id:t='text_airfield_name_2'
      pos:t='50%pw-50%w, 0';
      position:t='relative'
      text:t='#worldwar/airfieldStrenght/other'
    }
    table {
      id:t='table_airfield_side_2'
      pos:t='50%pw-50%w, 0.01@scrn_tgt'
      position:t='relative'
    }
    textarea {
      id:t='text_airfield_empty_side_2'
      pos:t='50%pw-50%w, 0';
      position:t='relative'
      text:t='#worldwar/noUnits'
    }
  }
}
