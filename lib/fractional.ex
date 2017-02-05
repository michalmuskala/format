defprotocol Format.Fractional do
  @spec format(term, atom, Format.t) :: {:ok, Format.chardata} | {:error, float()}
  def format(value, type, format)
end

defimpl Format.Fractional, for: Float do
  def format(value, _type, _format) do
    {:error, value}
  end
end
