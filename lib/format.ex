defmodule Format do
  alias Format.{Compiler, Interpreter}

  defstruct [:fragments, :original, :mode, newline: false]

  defmodule Specification do
    defstruct [:fill, :align, :sign, :alternate, :width,
               :grouping, :precision, :type]
  end

  @type chardata :: :unicode.chardata
  @type align :: :left | :right | :center | nil
  @type sign :: :+ | :- | nil
  @type count :: pos_integer | {:argument, pos_integer}
  @type integral :: :decimal | :octal | :hex | :upper_hex | :char
  @type fractional :: :float | :exponent | :upper_exponent | :general | :upper_general
  @type type :: :display | {:display, String.t} | :debug | :string
              | {:integral, integral} | {:fractional, fractional}
  @type spec :: %Specification{align: align, fill: String.t,
                               sign: sign, alternate: boolean, width: count,
                               grouping: String.t, precision: count, type: type}
  @type t :: %__MODULE__{fragments: [spec], original: String.t,
                         mode: :positional | :named, newline: boolean}

  defmacro __using__(_) do
    quote do
      import Format, only: [sigil_F: 2]
      require Format
    end
  end

  ## Public interface

  def compile(format) when is_binary(format) do
    {fragments, original, mode} = Compiler.compile(format)
    %__MODULE__{fragments: fragments, original: original, mode: mode}
  end

  defmacro sigil_F({:<<>>, _, [format]}, _modifiers) when is_binary(format) do
    Macro.escape(compile(format))
  end

  def fmt(%__MODULE__{fragments: fragments, mode: mode} = format, args)
      when is_list(args) or is_map(args) do
    [apply(Interpreter, mode, [fragments, args]) | newline(format)]
  end

  def string(format, args) do
    :unicode.characters_to_binary(fmt(format, args))
  end

  def puts(device \\ :stdio, format, args) do
    format = append_newline(format)
    request(device, {:write, format, args}, :puts)
  end

  def write(device \\ :stdio, format, args) do
    request(device, {:write, format, args}, :write)
  end

  def binwrite(device \\ :stdio, format, args) do
    request(device, {:binwrite, format, args}, :binwrite)
  end

  ## Formatting

  defp newline(%{newline: true}), do: [?\n]
  defp newline(_), do: []

  defp append_newline(format), do: %{format | newline: true}

  ## IO protocol handling

  defp request(device, request, func) do
    case request(device, request) do
      {:error, reason} ->
        [_name | args] = Tuple.to_list(request)
        try do
          throw(:error)
        catch
          :throw, :error ->
            [_current, stack] = System.stacktrace()
            new_stack = [{__MODULE__, func, [device | args]} | stack]
            reraise_convert(reason, new_stack)
        end
      other ->
        other
    end
  end

  # TODO: handle errors better
  defp reraise_convert(:arguments, stack) do
    reraise ArgumentError, stack
  end
  defp reraise_convert(:terminated, stack) do
    reraise "io device terminated during request", stack
  end
  defp reraise_convert({:no_translation, from, to}, stack) do
    reraise "couldn't encode from #{from} to #{to}", stack
  end
  defp reraise_convert(other, stack) do
    reraise ArgumentError, "error printing: #{inspect other}", stack
  end

  defp request(:stdio, request) do
    request(Process.group_leader(), request)
  end
  defp request(:stderr, request) do
    request(:standard_error, request)
  end
  defp request(pid, request) when is_pid(pid) do
    # Support only modern io servers that speak unicode
    true = :net_kernel.dflag_unicode_io(pid)
    execute_request(pid, io_request(pid, request))
  end
  defp request(name, request) when is_atom(name) do
    case Process.whereis(name) do
      nil ->
        {:error, :arguments}
      pid ->
        request(pid, request)
    end
  end

  defp execute_request(pid, request) do
    ref = Process.monitor(pid)
    send(pid, {:io_request, self(), ref, request})
    receive do
      {:io_reply, ^ref, reply} ->
        Process.demonitor(ref, [:flush])
        reply
      {:DOWN, ^ref, _, _, _} ->
        receive do
          {:EXIT, ^pid, _} ->
            true
        after
          0 ->
            true
        end
        {:error, :terminated}
    end
  end

  defp io_request(pid, {:write, format, args}) when node(pid) == node() do
    data = string(format, args)
    {:put_chars, :unicode, data}
  end
  defp io_request(_pid, {:write, format, args}) do
    {:put_chars, :unicode, __MODULE__, :fmt, [format, args]}
  end
  defp io_request(pid, {:binwrite, format, args}) when node(pid) == node() do
    data = IO.iodata_to_binary(fmt(format, args))
    {:put_chars, :latin1, data}
  end
  defp io_request(_pid, {:binwrite, format, args}) do
    {:put_chars, :latin1, __MODULE__, :fmt, [format, args]}
  end
end

defimpl Inspect, for: Format do
  def inspect(format, _opts) do
    "~F" <> Kernel.inspect(format.original, binaries: :as_strings)
  end
end
