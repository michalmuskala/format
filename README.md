# Format

---

**WARNING**: This library is of alpha quality. There's a lot of missing features and bugs should be expected.

---

Alternative string formatter for Elixir inspired by Python and Rust.

```elixir
iex> use Format
iex> Format.fmt(~F"{} {}", [1, "foo"])
[[[[]] | "1"], " ", "foo"]]
iex> Format.string(~F"{} {}", [1, "foo"])
"1 foo"
iex> Format.puts(~F"{} {}", [1, "foo"])
1 foo
:ok

iex> Format.string(~F"{foo} {bar}", bar: 1, foo: 3)
"3 1"
iex> Format.string(~F"{foo:.3f} {foo:.5f}", foo: 3.2)
"3.200 3.20000"
iex> Format.string(~F"{0:^10d}|{0:<10x}|{0:>10b}", [100])
"   100    |        64|1100100   "
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `format` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:format, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/format](https://hexdocs.pm/format).

