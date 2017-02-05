defprotocol Format.Fractional do
  @spec fmt(term, atom, Format.t) :: {:ok, Format.chardata} | {:error, float()}
  def fmt(value, type, format)
end

defimpl Format.Fractional, for: Float do
  def fmt(value, _type, _format) do
    {:error, value}
  end
end

defimpl Format.Fractional, for: Integer do
  def fmt(value, _type, _format) do
    {:error, value + 0.0}
  end
end
