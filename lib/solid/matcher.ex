defprotocol Solid.Matcher do
  @fallback_to_any true
  @doc "Assigns context to values"
  def match(_, _)
end

defmodule Solid.Matcher.Builtins do
  @doc """
  Solid comes with built-in matchers for the List, Map, BitString and Atom types, as well as the
  fallback matcher for the Any type.

  The using macro supports options to selectively include (`only`) and exclude (`omit`) individual
  matchers.

  The full list of available matchers is :any, :atom, :string, :list, :map

  Examples:

  # include all built-in matchers
  use Solid.Matcher.Builtins

  # selectively include only a subset
  use Solid.Matcher.Builtins, only: [:any, :list]

  # selectively exclude a subset
  use Solid.Matcher.Builtins, omit: [:map, :atom]
  """

  @all_matchers [:any, :atom, :bit_string, :list, :map]
  @type matcher :: :any | :atom | :bit_string | :list | :map
  @type option :: {:only, list(matcher())} | {:omit, list(matcher())}
  @type options :: list(option())
  @spec __using__(options()) :: Macro.t()
  defmacro __using__(opts) do
    excluded = Keyword.get(opts, :omit, [])

    included =
      opts
      |> Keyword.get(:only, @all_matchers)
      |> Enum.reject(fn m -> m in excluded end)

    if :any in included do
      defimpl Solid.Matcher, for: Any do
        def match(data, []), do: {:ok, data}

        def match(_, _), do: {:error, :not_found}
      end
    end

    if :list in included do
      defimpl Solid.Matcher, for: List do
        def match(data, []), do: {:ok, data}

        def match(data, ["size"]) do
          {:ok, Enum.count(data)}
        end

        def match(data, [key | keys]) when is_integer(key) do
          case Enum.fetch(data, key) do
            {:ok, value} -> @protocol.match(value, keys)
            _ -> {:error, :not_found}
          end
        end
      end
    end

    if :map in included do
      defimpl Solid.Matcher, for: Map do
        def match(data, []) do
          {:ok, data}
        end

        def match(data, ["size"]) do
          {:ok, Map.get(data, "size", Enum.count(data))}
        end

        def match(data, [key | []]) do
          case Map.fetch(data, key) do
            {:ok, value} -> {:ok, value}
            _ -> {:error, :not_found}
          end
        end

        def match(data, [key | keys]) do
          case Map.fetch(data, key) do
            {:ok, value} -> @protocol.match(value, keys)
            _ -> {:error, :not_found}
          end
        end
      end
    end

    if :string in included do
      defimpl Solid.Matcher, for: [BitString, String] do
        def match(current, []), do: {:ok, current}

        def match(data, ["size"]) do
          {:ok, String.length(data)}
        end

        def match(_data, [i | _]) when is_integer(i) do
          {:error, :not_found}
        end

        def match(_data, [i | _]) when is_binary(i) do
          {:error, :not_found}
        end
      end
    end

    if :atom in included do
      quote do
        defimpl Solid.Matcher, for: Atom do
          def match(current, []) when is_nil(current), do: {:ok, nil}
          def match(data, []), do: {:ok, data}
          def match(nil, _), do: {:error, :not_found}

          @doc """
          Matches all remaining cases
          """
          def match(_current, [key]) when is_binary(key), do: {:error, :not_found}
        end
      end
    end
  end
end
