defmodule MatcherTest do
  use ExUnit.Case, async: true

  describe "custom matchers" do
    defmodule UserProfile do
      defstruct [:full_name]

      defimpl Solid.Matcher do
        def match(user_profile, ["full_name"]), do: {:ok, user_profile.full_name}
      end
    end

    defmodule User do
      defstruct [:email]

      def load_profile(%User{} = _user) do
        # implementation omitted
        %UserProfile{full_name: "John Doe"}
      end

      defimpl Solid.Matcher do
        def match(user, ["email"]), do: {:ok, user.email}

        def match(user, ["profile" | keys]),
          do: user |> User.load_profile() |> @protocol.match(keys)
      end
    end

    test "should render protocolized struct correctly" do
      template = ~s({{ user.email }}: {{ user.profile.full_name }})

      context = %{"user" => %User{email: "test@example.com"}}

      assert "test@example.com: John Doe" ==
               template |> Solid.parse!() |> Solid.render!(context) |> to_string()
    end
  end

  describe "built-in matchers" do
    use Solid.Matcher.Builtins

    test "for maps" do
      template = ~s({{ beep.boop }})

      context = %{"beep" => %{"boop" => "beep boop!"}}

      assert "beep boop!" ==
               template |> Solid.parse!() |> Solid.render!(context) |> to_string()
    end

    test "for strings" do
      template =
        ~s(How long is {{piece_of_string}}? {{piece_of_string | size}}.)

      context = %{"piece_of_string" => "a piece of string"}

      assert "How long is a piece of string? 17." ==
               template |> Solid.parse!() |> Solid.render!(context) |> to_string()
    end

    test "for lists" do
      template = ~s(This eagle is just {{items | size}} {{items[1]}}s in a trenchcoat.)

      context = %{
        "items" => ~w(This parrot has ceased to be.)
      }

      assert "This eagle is just 6 parrots in a trenchcoat." ==
               template |> Solid.parse!() |> Solid.render!(context) |> to_string()
    end

    test "for atom" do
      template = ~s({{molecule.atom.particle}})

      context = %{"molecule" => %{"atom" => %{"particle" => :neutron}}}

      assert "neutron" ==
               template |> Solid.parse!() |> Solid.render!(context) |> to_string()
    end
  end
end
