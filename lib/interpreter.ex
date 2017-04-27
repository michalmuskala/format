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
    do: Format.Debug.fmt(value, format)
  defp dispatch_format({:integral, type}, format, value),
    do: format_integral(value, type, format)
  defp dispatch_format({:fractional, type}, format, value),
    do: format_fractional(value, type, format)
  defp dispatch_format(:string, format, value),
    do: format_string(value, format)
  defp dispatch_format(:display, format, value),
    do: dispatch_display(value, format, [value, format])
  defp dispatch_format({:display, custom}, format, value),
    do: dispatch_display(value, format, [value, custom, format])

  defp dispatch_display(value, format, _args) when is_integer(value),
    do: format_integral(value, :decimal, format)
  defp dispatch_display(value, format, _args) when is_float(value),
    do: format_fractional(value, :float, format)
  defp dispatch_display(value, format, _args) when is_binary(value) or is_list(value),
    do: format_string(value, format)
  defp dispatch_display(_value, _format, args),
    do: apply(Format.Display, :fmt, args)

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

  defp format_integral(value, type, format) when is_integer(value) do
    format_integer(value, type, format)
  end
  defp format_integral(value, type, format) do
    case Format.Integral.fmt(value, type, format) do
      {:ok, chardata} ->
        chardata
      {:error, integer} ->
        format_integer(integer, type, format)
    end
  end

  defp format_integer(value, type, format) do
    %{fill: fill, align: align, width: width,
      sign: sign, grouping: grouping, alternate: alternate} = format
    base_prefix = integer_base_prefix(alternate, type)
    base = integer_base(type)
    sign_prefix = sign_prefix(sign, value >= 0)
    prefix = [base_prefix | sign_prefix]
    value =
      value
      |> abs
      |> Integer.to_string(base)
      |> maybe_downcase(type == :hex)
      |> group(grouping)
    formatted = [prefix | value]
    if width do
      pad(formatted, IO.iodata_length(formatted), width, fill, align || :right)
    else
      formatted
    end
  end

  defp group(value, nil), do: value
  defp group(value, char) do
    first_len = rem(byte_size(value), 3)
    first_len = if first_len == 0, do: 3, else: first_len
    <<first_part::binary-size(first_len), rest::binary>> = value
    [first_part | do_group(rest, char)]
  end

  defp do_group("", _char), do: []
  defp do_group(<<left::binary-3, rest::binary>>, char) do
    [char, left | do_group(rest, char)]
  end

  defp integer_base(:hex), do: 16
  defp integer_base(:upper_hex), do: 16
  defp integer_base(:octal), do: 8
  defp integer_base(:binary), do: 2
  defp integer_base(:decimal), do: 10

  defp integer_base_prefix(true, :hex), do: '0x'
  defp integer_base_prefix(true, :upper_hex), do: '0x'
  defp integer_base_prefix(true, :octal), do: '0o'
  defp integer_base_prefix(true, :binary), do: '0b'
  defp integer_base_prefix(_, _), do: ''

  defp sign_prefix(:plus, true), do: '+'
  defp sign_prefix(:plus, false), do: '-'
  defp sign_prefix(:minus, true), do: ''
  defp sign_prefix(:minus, false), do: '-'
  defp sign_prefix(:space, true), do: ' '
  defp sign_prefix(:space, false), do: '-'

  defp format_fractional(value, type, format) when is_float(value) do
    format_float(value, type, format)
  end
  defp format_fractional(value, type, format) when is_integer(value) do
    format_float(value + 0.0, type, format)
  end
  defp format_fractional(value, type, format) do
    case Format.Fractional.fmt(value, type, format) do
      {:ok, chardata} ->
        chardata
      {:error, float} ->
        format_float(float, type, format)
    end
  end

  # TODO: reimplement float printing & don't rely on erlang
  defp format_float(value, type, format) do
    %{fill: fill, align: align, width: width, precision: precision, sign: sign} = format
    erlang_format = erlang_format_float(type, precision)
    formatted = :io_lib.format(erlang_format, [abs(value)])

    sign_prefix = sign_prefix(sign, value >= 0)
    formatted = maybe_upcase(formatted, type in [:upper_exponent, :upper_general])
    formatted = [sign_prefix | formatted]
    if width do
      pad(formatted, IO.iodata_length(formatted), width, fill, align || :right)
    else
      formatted
    end
  end

  defp erlang_format_float(:float, nil),
    do: '~f'
  defp erlang_format_float(:float, prec),
    do: '~.#{prec}f'
  defp erlang_format_float(type, nil) when type in [:exponent, :upper_exponent],
    do: '~e'
  defp erlang_format_float(type, prec) when type in [:exponent, :upper_exponent],
    do: '~.#{prec}e'
  defp erlang_format_float(type, nil) when type in [:general, :upper_general],
    do: '~g'
  defp erlang_format_float(type, prec) when type in [:general, :upper_general],
    do: '~.#{prec}g'

  defp maybe_downcase(binary, true), do: downcase(binary, "")
  defp maybe_downcase(binary, false), do: binary

  defp downcase(<<>>, acc),
    do: acc
  defp downcase(<<char, rest::binary>>, acc) when char in ?A..?Z,
    do: downcase(rest, acc <> <<char - ?A + ?a>>)
  defp downcase(<<char, rest::binary>>, acc),
    do: downcase(rest, acc <> <<char>>)

  defp maybe_upcase(charlist, true), do: upcase(charlist)
  defp maybe_upcase(charlist, false), do: charlist

  defp upcase([]),
    do: []
  defp upcase([char | rest]) when char in ?a..?z,
    do: [char - ?a + ?A | upcase(rest)]
  defp upcase([nested | rest]) when is_list(nested),
    do: [upcase(nested) | upcase(rest)]
  defp upcase([char | rest]),
    do: [char | upcase(rest)]
end
