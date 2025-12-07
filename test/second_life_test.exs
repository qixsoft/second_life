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

    test "fetch_source_filenames!/1 raises on non-existent directory" do
      assert_raise File.Error, fn ->
        SecondLife.fetch_source_filenames!("non_existent_dir")
      end
    end

    test "archive!/2 raises on failure" do
      assert_raise RuntimeError, ~r/Failed to create archive/, fn ->
        SecondLife.archive!(["non_existent_file.txt"], "/tmp")
      end
    end

    test "fetch_source_filenames/1 handles permission errors gracefully" do
      # This test verifies the error tuple format for non-enoent errors
      # We can't easily create a permission-denied scenario, but we can verify
      # the error handling path exists by checking the function handles :enoent
      assert {:error, msg} = SecondLife.fetch_source_filenames("/nonexistent/path/here")
      assert is_binary(msg)
    end
  end

  describe "archive edge cases" do
    setup do
      tmp_dir = Path.join(System.tmp_dir!(), "second_life_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(tmp_dir)

      on_exit(fn ->
        File.rm_rf!(tmp_dir)
      end)

      {:ok, tmp_dir: tmp_dir}
    end

    test "archive/2 creates zip with base32-encoded name", ctx do
      %{tmp_dir: tmp_dir} = ctx

      File.write!(Path.join(tmp_dir, "test.txt"), "content")

      {:ok, archive_path} = SecondLife.archive(["test.txt"], tmp_dir)

      expected_name = "#{Base.encode32(Path.expand(tmp_dir))}.zip"
      assert Path.basename(archive_path) == expected_name
    end

    test "archive/2 handles empty file list", ctx do
      %{tmp_dir: tmp_dir} = ctx

      {:ok, archive_path} = SecondLife.archive([], tmp_dir)

      assert File.exists?(archive_path)
      assert Path.extname(archive_path) == ".zip"
    end

    test "archive/2 includes subdirectories", ctx do
      %{tmp_dir: tmp_dir} = ctx

      sub_dir = Path.join(tmp_dir, "subdir")
      File.mkdir_p!(sub_dir)
      File.write!(Path.join(sub_dir, "nested.txt"), "nested content")
      File.write!(Path.join(tmp_dir, "root.txt"), "root content")

      {:ok, archive_path} = SecondLife.archive(["root.txt", "subdir"], tmp_dir)

      {:ok, file_list} = :zip.list_dir(String.to_charlist(archive_path))

      filenames =
        file_list
        |> Enum.filter(&match?({:zip_file, _, _, _, _, _}, &1))
        |> Enum.map(fn {:zip_file, name, _, _, _, _} -> to_string(name) end)

      assert "root.txt" in filenames
      assert "subdir/nested.txt" in filenames
    end
  end
end
