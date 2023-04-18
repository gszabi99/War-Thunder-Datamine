changeAmount {
  behaviour:t='basicPos'
  behaviour:t='basicTransparency'

  <<#is_increment>>
  increase_amount:t='yes'
  text:t='+<<delta_amount>>'
  <</is_increment>>

  <<^is_increment>>
  increase_amount:t='no'
  text:t='<<delta_amount>>'
  <</is_increment>>
}
