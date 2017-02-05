defprotocol Format.Display do
  @spec fmt(term, Format.t) :: Format.chardata
  def fmt(value, format)

  @spec fmt(term, String.t, Format.t) :: {:ok, Format.chardata} | :error
  def fmt(value, custom, format)
end

# TODO: protocol implementations
