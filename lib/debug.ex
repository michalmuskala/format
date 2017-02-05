defprotocol Format.Debug do
  @spec fmt(term, Format.t) :: Format.chardata
  def fmt(value, format)
end

# TODO: how this should work?
