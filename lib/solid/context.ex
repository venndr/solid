defmodule Solid.UndefinedVariableError do
  defexception [:variable]

  @impl true
  def message(exception), do: "Undefined variable #{exception.variable}"
end

defmodule Solid.UndefinedFilterError do
  defexception [:filter]

  @impl true
  def message(exception), do: "Undefined filter #{exception.filter}"
end

defmodule Solid.Context do
  defstruct vars: %{},
            counter_vars: %{},
            iteration_vars: %{},
            cycle_state: %{},
            errors: [],
            matcher_module: Solid.Matcher

  @type t :: %__MODULE__{
          vars: map,
          counter_vars: map,
          iteration_vars: %{optional(String.t()) => term},
          cycle_state: map,
          errors: list(Solid.UndefinedVariableError),
          matcher_module: module
        }
  @type scope :: :counter_vars | :vars | :iteration_vars

  def put_errors(context, errors) when is_list(errors) do
    %{context | errors: errors ++ context.errors}
  end

  def put_errors(context, error) do
    %{context | errors: [error | context.errors]}
  end

  @doc """
  Get data from context respecting the scope order provided.

  Possible scope values: :counter_vars, :vars or :iteration_vars

  `opts` is passed through to the matcher so it can reach data threaded
  via the render options.
  """
  @spec get_in(t(), [term()], [scope], keyword()) ::
          {:ok, term} | {:error, {:not_found, [term()]}}
  def get_in(context, key, scopes, opts \\ []) do
    resolved_key = resolve_references(context, key, scopes, opts)

    lookup_key(context, resolved_key, scopes, opts)
  end

  @doc """
  Find the current value that `cycle` must return
  """
  @spec run_cycle(t(), [values: [String.t()]] | [name: String.t(), values: [String.t()]]) ::
          {t(), String.t()}
  def run_cycle(%__MODULE__{cycle_state: cycle_state} = context, cycle) do
    name = Keyword.get(cycle, :name, cycle[:values])

    case cycle_state[name] do
      {current_index, cycle_map} ->
        limit = map_size(cycle_map)
        next_index = if current_index + 1 < limit, do: current_index + 1, else: 0

        {%{context | cycle_state: %{context.cycle_state | name => {next_index, cycle_map}}},
         cycle_map[next_index]}

      nil ->
        values = Keyword.fetch!(cycle, :values)
        cycle_map = cycle_to_map(values)
        current_index = 0

        {%{context | cycle_state: Map.put_new(cycle_state, name, {current_index, cycle_map})},
         cycle_map[current_index]}
    end
  end

  defp resolve_references(context, key, scopes, opts) do
    Enum.map(key, fn
      {:reference, reference} ->
        case lookup_key(context, [reference], scopes, opts) do
          {:ok, resolved} -> resolved
          {:error, _} -> reference
        end

      part ->
        part
    end)
  end

  # Scopes are tried in the order given; the first non-nil match wins and the
  # remaining scopes are never evaluated. An {:ok, nil} match is kept as a
  # fallback but can still be overridden by a non-nil match from a later scope.
  defp lookup_key(context, key, scopes, opts) do
    Enum.reduce_while(scopes, {:error, {:not_found, key}}, fn scope, acc ->
      case get_from_scope(context, scope, key, opts) do
        {:ok, nil} -> {:cont, {:ok, nil}}
        {:ok, _} = value -> {:halt, value}
        _error -> {:cont, acc}
      end
    end)
  end

  defp cycle_to_map(cycle) do
    cycle
    |> Enum.with_index()
    |> Enum.into(%{}, fn {value, index} -> {index, value} end)
  end

  defp get_from_scope(context, :vars, key, opts) do
    context.matcher_module.match(context.vars, key, opts)
  end

  defp get_from_scope(context, :counter_vars, key, opts) do
    context.matcher_module.match(context.counter_vars, key, opts)
  end

  defp get_from_scope(context, :iteration_vars, key, opts) do
    context.matcher_module.match(context.iteration_vars, key, opts)
  end
end
