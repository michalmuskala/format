defmodule Format.Compile do
  def compile(format_string) do
    {fragments, mode} = compile(format_string, [], :seq)
    {fragments, escape(format_string), mode}
  end

  defp escape(string) do
    String.replace(string, "]", "\\]")
  end

  defp compile("", fragments, mode) do
    {Enum.reverse(fragments), mode}
  end
  defp compile("{{" <> rest, fragments, mode) do
    {fragment, rest} = compile_text(rest, "}")
    compile(rest, [fragment | fragments], mode)
  end
  defp compile("{" <> rest, fragments, mode) do
    {fragment, rest, mode} = compile_argument(rest, mode)
    compile(rest, [fragment | fragments], mode)
  end
  defp compile("}}" <> rest, fragments, mode) do
    {fragment, rest} = compile_text(rest, "}")
    compile(rest, [fragment | fragments], mode)
  end
  defp compile("}" <> _, _fragments, _mode) do
    raise "unexpected end of argument marker"
  end
  defp compile(<<char::utf8, rest::binary>>, fragments, mode) do
    {fragment, rest} = compile_text(rest, <<char::utf8>>)
    compile(rest, [fragment | fragments], mode)
  end

  defp compile_argument(":" <> rest, mode) do
    {format, rest} = compile_format(rest)
    {format, rest, mode}
  end
  defp compile_argument("}" <> rest, mode) do
    {:to_string, rest, mode}
  end

  defp compile_format("}" <> rest) do
    {:to_string, rest}
  end
  defp compile_format("?}" <> rest) do
    {:inspect, rest}
  end

  defp compile_text("{{" <> rest, acc) do
    compile_text(rest, acc <> "{")
  end
  defp compile_text("}}" <> rest, acc) do
    compile_text(rest, acc <> "}")
  end
  defp compile_text("{" <> _ = rest, acc) do
    {acc, rest}
  end
  defp compile_text("", acc) do
    {acc, ""}
  end
  defp compile_text(<<char, rest::binary>>, acc) do
    compile_text(rest, acc <> <<char>>)
  end
end
