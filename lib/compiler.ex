defmodule Format.Compiler do
  def compile(format_string) do
    {fragments, mode} = compile(format_string, [], nil)
    {fragments, format_string, mode || :seq}
  end

  defp compile("", fragments, mode) do
    {Enum.reverse(fragments), mode}
  end
  defp compile("{{" <> rest, fragments, mode) do
    {fragment, rest} = read_text(rest, "{")
    compile(rest, [fragment | fragments], mode)
  end
  defp compile("{" <> rest, fragments, mode) do
    {argument, format, rest} = read_argument(rest, "")
    {argument, mode} = compile_argument(argument, mode)
    format = compile_format(format, argument)
    compile(rest, [{argument, format} | fragments], mode)
  end
  defp compile("}}" <> rest, fragments, mode) do
    {fragment, rest} = read_text(rest, "}")
    compile(rest, [fragment | fragments], mode)
  end
  defp compile("}" <> _rest, _fragments, _mode) do
    raise "unexpected end of argument marker"
  end
  defp compile(<<char::1-binary, rest::binary>>, fragments, mode) do
    {fragment, rest} = read_text(rest, char)
    compile(rest, [fragment | fragments], mode)
  end

  ## Readers

  defp read_argument("", _acc) do
    raise "argument not finished"
  end
  defp read_argument("}}" <> rest, acc) do
    read_argument(rest, acc <> "}")
  end
  defp read_argument("}" <> rest, acc) do
    {acc, "", rest}
  end
  defp read_argument("{{" <> rest, acc) do
    read_argument(rest, acc <> "{")
  end
  defp read_argument("{" <> _rest, _acc) do
    raise "nested arguments are not supported"
  end
  defp read_argument(":" <> rest, acc) do
    {format, rest} = read_format(rest, "")
    {acc, format, rest}
  end
  defp read_argument(<<char::1-binary, rest::binary>>, acc) do
    read_argument(rest, acc <> char)
  end

  defp read_format("", _acc) do
    raise "argument not finished"
  end
  defp read_format("}}" <> rest, acc) do
    read_format(rest, acc <> "}")
  end
  defp read_format("}" <> rest, acc) do
    {acc, rest}
  end
  defp read_format("{{" <> rest, acc) do
    read_format(rest, acc <> "{")
  end
  defp read_format("{" <> _rest, _acc) do
    raise "nested arguments are not supported"
  end
  defp read_format(<<char::1-binary, rest::binary>>, acc) do
    read_format(rest, acc <> char)
  end

  defp read_text("{{" <> rest, acc) do
    read_text(rest, acc <> "{")
  end
  defp read_text("}}" <> rest, acc) do
    read_text(rest, acc <> "}")
  end
  defp read_text("{" <> _ = rest, acc) do
    {acc, rest}
  end
  defp read_text("", acc) do
    {acc, ""}
  end
  defp read_text(<<char::1-binary, rest::binary>>, acc) do
    read_text(rest, acc <> char)
  end

  ## Compilers

  @digits '0123456789'

  defp compile_argument("", mode) when mode in [nil, :index, :seq] do
    {:next, mode || :seq}
  end
  defp compile_argument(<<digit, _::binary>> = arg, mode)
      when digit in @digits and mode in [nil, :index, :seq] do
    case Integer.parse(arg) do
      {int, ""} ->
        {int, :index}
      _ ->
        raise "invalid integer argument: #{inspect arg}"
    end
  end
  defp compile_argument(<<digit, _::binary>>, :named) when digit in @digits do
    raise "named arguments cannot be mixed with positional ones"
  end
  defp compile_argument(name, mode) when name != "" and mode in [nil, :named] do
    {String.to_atom(name), :named}
  end
  defp compile_argument(_arg, _mode) do
    raise "named arguments cannot be mixed with positional ones"
  end

  defp compile_format(format, argument) do
    {fill, align, rest} = compile_align(format)
    {sign, rest} = compile_sign(rest)
    {alternate, rest} = compile_alternate(rest)
    {sign, fill, rest} = compile_zero(rest, sign, fill)
    {width, rest} = compile_width(rest)
    {grouping, rest} = compile_grouping(rest)
    {precision, rest} = compile_precision(rest, argument)
    {type, rest} = compile_type(rest)
    assert_done(rest)
    %Format.Specification{fill: fill, align: align, sign: sign,
                          alternate: alternate, width: width, grouping: grouping,
                          precision: precision, type: type}
  end

  @types [debug: "?", decimal: "d", octal: "o", hex: "x", upper_hex: "X",
          char: "c", float: "f", exponent: "e", upper_exponent: "E",
          general: "g", upper_general: "G", string: "s", display: ""]

  defp compile_grouping("_" <> rest),
    do: {:_, rest}
  defp compile_grouping("," <> rest),
    do: {:",", rest}
  defp compile_grouping(rest),
    do: {nil, rest}

  for {name, char} <- @types do
    defp compile_type(unquote(char) <> rest),
      do: {unquote(name), rest}
  end
  defp compile_type("%" <> _ = custom),
    do: {{:custom, custom}, ""}
  defp compile_type(type),
    do: raise(ArgumentError, "unknown type: #{inspect type}")

  defp assert_done(""),
    do: :ok
  defp assert_done(_),
    do: raise(ArgumentError, "invalid format")

  defp compile_width(format) do
    case Integer.parse(format) do
      {int, "$" <> rest} ->
        {{:argument, int}, rest}
      {int, rest} ->
        {int, rest}
      :error ->
        {nil, format}
    end
  end

  defp compile_precision(".*" <> rest, :next) do
    {:next, rest}
  end
  defp compile_precision(".*" <> rest, int) when is_integer(int) and int > 1 do
    {int - 1, rest}
  end
  defp compile_precision(".*" <> _rest, arg) do
    raise ArgumentError, "cannot read precision preceding argument #{inspect arg}"
  end
  defp compile_precision("." <> format, _arg) do
    case Integer.parse(format) do
      {int, "$" <> rest} ->
        {{:argument, int}, rest}
      {int, rest} ->
        {int, rest}
      :error ->
        raise ArgumentError, "invalid precision specification"
    end
  end
  defp compile_precision(rest, _arg) do
    {nil, rest}
  end

  defp compile_alternate("#" <> rest), do: {true, rest}
  defp compile_alternate(rest),        do: {false, rest}

  defp compile_zero("0" <> rest, nil, ?\s),
    do: {true, ?0, rest}
  defp compile_zero("0" <> _rest, _sign, _fill),
    do: raise(ArgumentError, "the 0 option cannot be combined with +, - or fill character")
  defp compile_zero(rest, sign, fill),
    do: {sign, fill, rest}

  defp compile_sign("+" <> rest), do: {:+, rest}
  defp compile_sign("-" <> rest), do: {:-, rest}
  defp compile_sign(rest),        do: {nil, rest}

  @align [left: ?<, center: ?^, right: ?>]

  for {name, char} <- @align do
    defp compile_align(<<char::utf8, unquote(char), rest::binary>>),
      do: {char, unquote(name), rest}
    defp compile_align(<<unquote(char), rest::binary>>),
      do: {?\s, unquote(name), rest}
  end
  defp compile_align(rest),
    do: {?\s, nil, rest}

end
