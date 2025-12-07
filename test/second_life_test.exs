#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLifeTest do
  use ExUnit.Case

  describe "source directory" do
    setup do
      source_dir = "./priv/fixtures/source_dir"
      source_file = "mix.exs"
      sub_dir = "sub_dir"
      sub_dir_file = ".gitignore"

      {
        :ok,
        source_dir: source_dir, source_file: source_file, sub_dir: sub_dir, sub_dir_file: sub_dir_file
      }
    end

    test "fetches the source directory filenames", ctx do
      %{
        source_dir: source_dir,
        source_file: source_file,
        sub_dir: sub_dir_name,
        sub_dir_file: sub_dir_file
      } = ctx

      assert {:ok, [_ | _] = names} = SecondLife.fetch_source_filenames(source_dir)
      assert source_file in names
      assert sub_dir_name in names
      refute sub_dir_file in names
    end

    test "fetches the source directory paths", ctx do
      %{
        source_dir: source_dir,
        source_file: source_file,
        sub_dir: sub_dir_name
      } = ctx

      expanded = Path.expand(source_dir)
      sub_dir = Path.join(expanded, sub_dir_name)
      test_file = Path.join(expanded, source_file)
      assert {:ok, [_ | _] = paths} = SecondLife.fetch_source_paths(source_dir)
      assert test_file in paths
      refute File.dir?(test_file)
      assert sub_dir in paths
      assert File.dir?(sub_dir)
    end

    test "creates archive file in source directory", ctx do
      %{
        source_dir: source_dir
      } = ctx

      on_exit(fn ->
        # Clean up any rogue archive files
        source_dir
        |> File.ls!()
        |> Enum.filter(&(Path.extname(&1) == ".zip"))
        |> Enum.each(&File.rm!(Path.join(source_dir, &1)))
      end)

      assert {:ok, archive} =
               source_dir
               |> SecondLife.fetch_source_filenames!()
               |> SecondLife.archive(source_dir)

      assert match?(%File.Stat{type: :regular}, File.stat!(archive))
      assert ".zip" == Path.extname(archive)
      assert Path.expand(source_dir) == Path.dirname(archive)
    end

    test "handles non_existent source directory" do
      assert {:error, reason} = SecondLife.fetch_source_paths("non_existent_dir")
      assert reason =~ ~r/Failed to fetch source contents:/
      assert reason =~ ~r/does not exist/
    end
  end
end
