defmodule Format.Interpreter do
  def named(fragments, args) when is_list(args),
    do: do_named(fragments, Map.new(args))
  def named(fragments, args) when is_map(args),
    do: do_named(fragments, args)

  defp do_named([text | rest], args) when is_binary(text),
    do: [text | do_named(rest, args)]
  defp do_named([{name, format} | rest], args),
    do: [format(format, Map.fetch!(args, name), &Map.fetch!(args, &1)) | do_named(rest, args)]
  defp do_named([], _args),
    do: []

  def positional(fragments, args) when is_list(args),
    do: do_positional(fragments, List.to_tuple(args))
  def positional(_fragments, args) when is_map(args),
    do: raise(ArgumentError)

  defp do_positional([text | rest], args) when is_binary(text),
    do: [text | do_positional(rest, args)]
  defp do_positional([{idx, format} | rest], args),
    do: [format(format, elem(args, idx), &elem(args, &1)) | do_positional(rest, args)]
  defp do_positional([], _args),
    do: []

  defp format(%{precision: {:argument, precision}} = format, arg, fetch_arg) do
    format(%{format | precision: fetch_arg.(precision)}, arg, fetch_arg)
  end
  defp format(%{width: {:argument, width}} = format, arg, fetch_arg) do
    format(%{format | width: fetch_arg.(width)}, arg, fetch_arg)
  end
  defp format(format, arg, _fetch_arg) do
    dispatch_format(format.type, format, arg)
  end

  defp dispatch_format(:debug, format, value),
    do: Format.Debug.debug(value, format)
  defp dispatch_format({:integral, type}, format, value),
    do: format_integral(value, type, format)
  defp dispatch_format({:fractional, type}, format, value),
    do: format_fractional(value, type, format)
  defp dispatch_format(:string, format, value),
    do: format_string(value, format)
  defp dispatch_format(:display, format, value),
    do: Format.Display.default(value, format)
  defp dispatch_format({:display, custom}, format, value),
      do: custom_display(value, custom, format)

  defp format_string(value, format) when is_binary(value) or is_list(value) do
    %{fill: fill, align: align, width: width, precision: precision} = format
    format_string(value, width, precision, fill, align)
  end
  defp format_string(value, format) when is_atom(value) do
    %{fill: fill, align: align, width: width, precision: precision} = format
    value = Atom.to_string(value)
    format_string(value, width, precision, fill, align)
  end

  defp format_string(value, width, precision, fill, align) do
    if width || precision do
      value = :unicode.characters_to_binary(value)
      trimmed = trim(value, precision)
      length = precision || String.length(trimmed)
      pad(trimmed, length, width, fill, align || :left)
    else
      value
    end
  end

  defp trim(value, nil), do: value
  defp trim(value, len), do: String.slice(value, 0, len)

  defp pad(value, _length, nil, _fill, _align),
    do: value
  defp pad(value, length, width, fill, align) when length < width,
    do: pad(value, String.duplicate(fill, width - length), width - length, align)
  defp pad(value, length, width, _fill, _align) when length >= width,
    do: value

  defp pad(value, pad, _pad_len, :left), do: [pad | value]
  defp pad(value, pad, _pad_len, :right), do: [value | pad]
  defp pad(value, pad, pad_len, :center) do
    {left, right} = String.split_at(pad, div(pad_len, 2))
    [left, value | right]
  end

  defp format_integral(value, type, format) do
    case Format.Integral.chardata(value, type, format) do
      {:ok, chardata} ->
        chardata
      {:error, integer} ->
        format_integral(integer, type, format)
    end
  end

  defp format_fractional(value, type, format) do
    case Format.Fractional.chardata(value, type, format) do
      {:ok, chardata} ->
        chardata
      {:error, float} ->
        format_fractional(float, type, format)
    end
  end

  defp custom_display(value, custom, format) do
    case Format.Display.custom(value, custom, format) do
      {:ok, chardata} ->
        chardata
      :error ->
        raise ArgumentError, "#{inspect value} does not support custom formatting"
    end
  end
end
