ExUnit.start()
ExUnit.configure(exclude: :skip, exclude: :integration)

{:module, _} = Code.ensure_compiled(Solid.CustomFilters)
