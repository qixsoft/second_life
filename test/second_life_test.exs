#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLifeTest do
  use ExUnit.Case
  doctest SecondLife

  test "greets the world" do
    assert SecondLife.hello() == :world
  end
end
