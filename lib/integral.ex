defprotocol Format.Integral do
  @spec fmt(term, atom, Format.t) :: {:ok, Format.chardata} | {:error, integer()}
  def fmt(value, type, format)
end

defimpl Format.Integral, for: Integer do
  def fmt(value, _type, _format) do
    {:error, value}
  end
end
