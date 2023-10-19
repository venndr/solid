defmodule XXX do
  def two(), do: 2
end

Benchee.run(
  %{
    "with ensure loaded" => fn -> Code.ensure_loaded(XXX); XXX.two() end,
    "without ensure_loaded" => fn -> XXX.two() end
  },
  time: 30,
  memory_time: 2
)
