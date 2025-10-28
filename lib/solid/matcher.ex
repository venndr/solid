defprotocol Solid.Matcher do
  @fallback_to_any true
  @doc "Assigns context to values"
  def match(_, _)
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
          def match(data, []), do: {:ok, data}

          def match(data, ["first"]), do: {:ok, Enum.at(data, 0)}
          def match(data, ["last"]), do: {:ok, Enum.at(data, -1)}
          def match(data, ["size"]), do: {:ok, Enum.count(data)}

          def match(data, [key | keys]) when is_integer(key) do
            case Enum.fetch(data, key) do
              {:ok, value} -> @protocol.match(value, keys)
              _ -> {:error, :not_found}
            end
          end

          def match(_data, _) do
            {:error, :not_found}
          end
        end
      end

      if :map in unquote(included) do
        defimpl Solid.Matcher, for: Map do
          def match(data, []) do
            {:ok, data}
          end

          # Maps are not ordered so these are here just for consistency with the Liquid implementation
          # as we must return something

          def match(data, [key | keys]) do
            case Map.fetch(data, key) do
              {:ok, value} ->
                @protocol.match(value, keys)

              _ ->
                # Check if the key is a special case
                case key do
                  "first" -> @protocol.match(Enum.at(data, 0), keys)
                  "size" -> @protocol.match(map_size(data), keys)
                  _ -> {:error, :not_found}
                end
            end
          end
        end
      end

      if :string in unquote(included) do
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

      if :tuple in unquote(included) do
        defimpl Solid.Matcher, for: Tuple do
          def match(data, []), do: {:ok, data}

          def match(data, ["size"]) do
            {:ok, tuple_size(data)}
          end

          def match(data, [key | keys]) when is_integer(key) do
            try do
              elem(data, key)
              |> @protocol.match(keys)
            rescue
              ArgumentError -> {:error, :not_found}
            end
          end
        end
      end

      if :atom in unquote(included) do
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

      if :any in unquote(included) do
        defimpl Solid.Matcher, for: Any do
          def match(data, []), do: {:ok, data}

          def match(_, _), do: {:error, :not_found}
        end
      end
    end
  end
end
