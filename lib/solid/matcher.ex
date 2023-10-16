defprotocol Solid.Matcher do
  @fallback_to_any true
  @doc "Assigns context to values"
  def match(_, _)
end

defimpl Solid.Matcher, for: Any do
  def match(data, []), do: {:ok, data}

  def match(_, _), do: {:error, :not_found}
end

defimpl Solid.Matcher, for: BitString do
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

defimpl Solid.Matcher, for: Atom do
  def match(current, []) when is_nil(current), do: {:ok, nil}
  def match(data, []), do: {:ok, data}
  def match(nil, _), do: {:error, :not_found}

  @doc """
  Matches all remaining cases
  """
  def match(_current, [key]) when is_binary(key), do: {:error, :not_found}
end
