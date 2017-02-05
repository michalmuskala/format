defprotocol Format.Integral do
  @spec format(term, atom, Format.t) :: {:ok, Format.chardata} | {:error, integer()}
  def format(value, type, format)
end

defimpl Format.Integral, for: Integer do
  def format(value, _type, _format) do
    {:error, value}
  end
end
