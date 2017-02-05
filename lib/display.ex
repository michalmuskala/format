defprotocol Format.Display do
  @spec default(term, Format.t) :: Format.chardata
  def default(value, format)

  @spec custom(term, String.t, Format.t) :: {:ok, Format.chardata} | :error
  def custom(value, custom, format)
end
