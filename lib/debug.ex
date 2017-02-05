defprotocol Format.Debug do
  @spec debug(term, Format.t) :: Format.chardata
  def debug(value, format)
end
