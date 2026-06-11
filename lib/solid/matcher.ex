defprotocol Solid.Matcher do
  @fallback_to_any true
  @doc """
  Assigns context to values.

  `opts` carries the render options passed to `Solid.render/3`, so custom
  matchers can reach data threaded through them (e.g. the full rendering
  context) without resorting to out-of-band lookups.
  """
  def match(_, _, _opts)
end

defmodule Solid.Matcher.Builtins do
  @doc """
  Solid comes with built-in matchers for the Atom, Map, List, and String/BitString types, as well
  as a fallback matcher for the Any type.

  The using macro supports options to selectively include (`:only`) and exclude (`:except`)
  individual matchers, should you wish to replace all or a subset with a custom matcher.

  The full list of available matchers is `:any`, `:atom`, `:list`, `:map`, `:string`, `:tuple`

  Examples:

  # include all built-in matchers
  use Solid.Matcher.Builtins

  # selectively include only a subset
  use Solid.Matcher.Builtins, only: [:any, :list]

  # selectively exclude a subset
  use Solid.Matcher.Builtins, except: [:map, :atom]
  """

  @all_matchers [:any, :atom, :string, :list, :map, :tuple]

  @type matcher :: :any | :atom | :list | :map | :string | :tuple
  @type option :: {:only, list(matcher())} | {:except, list(matcher())}
  @type options :: list(option())
  @spec __using__(options()) :: Macro.t()
  defmacro __using__(opts) do
    excluded = Keyword.get(opts, :except, [])

    included =
      opts
      |> Keyword.get(:only, @all_matchers)
      |> Enum.reject(fn m -> m in excluded end)

    quote do
      if :list in unquote(included) do
        defimpl Solid.Matcher, for: List do
          def match(data, [], _opts), do: {:ok, data}

          def match(data, ["size" | tail], opts),
            do: data |> Enum.count() |> @protocol.match(tail, opts)

          def match(data, [key | keys], opts) when is_integer(key) do
            case Enum.fetch(data, key) do
              {:ok, value} -> @protocol.match(value, keys, opts)
              _ -> {:error, :not_found}
            end
          end
        end
      end

      if :map in unquote(included) do
        defimpl Solid.Matcher, for: Map do
          def match(data, [], _opts) do
            {:ok, data}
          end

          def match(data, ["size" | tail], opts),
            do: data |> Map.get("size", Enum.count(data)) |> @protocol.match(tail, opts)

          def match(data, [head | []], _opts) do
            case Map.fetch(data, head) do
              {:ok, value} -> {:ok, value}
              _ -> {:error, :not_found}
            end
          end

          def match(data, [head | tail], opts) do
            case Map.fetch(data, head) do
              {:ok, value} -> @protocol.match(value, tail, opts)
              _ -> {:error, :not_found}
            end
          end
        end
      end

      if :string in unquote(included) do
        defimpl Solid.Matcher, for: [BitString, String] do
          def match(current, [], _opts), do: {:ok, current}

          def match(data, ["size" | tail], opts),
            do: data |> String.length() |> @protocol.match(tail, opts)

          def match(_data, [i | _], _opts) when is_integer(i) do
            {:error, :not_found}
          end

          def match(_data, [i | _], _opts) when is_binary(i) do
            {:error, :not_found}
          end
        end
      end

      if :tuple in unquote(included) do
        defimpl Solid.Matcher, for: Tuple do
          def match(data, [], _opts), do: {:ok, data}

          def match(data, ["size"], _opts) do
            {:ok, tuple_size(data)}
          end

          def match(data, [key | keys], opts) when is_integer(key) do
            try do
              elem(data, key)
              |> @protocol.match(keys, opts)
            rescue
              ArgumentError -> {:error, :not_found}
            end
          end
        end
      end

      if :atom in unquote(included) do
        defimpl Solid.Matcher, for: Atom do
          def match(current, [], _opts) when is_nil(current), do: {:ok, nil}
          def match(data, [], _opts), do: {:ok, data}
          def match(nil, _, _opts), do: {:error, :not_found}

          @doc """
          Matches all remaining cases
          """
          def match(_current, [key], _opts) when is_binary(key), do: {:error, :not_found}
        end
      end

      if :any in unquote(included) do
        defimpl Solid.Matcher, for: Any do
          def match(data, [], _opts), do: {:ok, data}

          def match(d, s, _opts), do: {:error, :not_found}
        end
      end
    end
  end
end
