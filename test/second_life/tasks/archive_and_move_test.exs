#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife.Tasks.ArchiveAndMoveTest do
  use ExUnit.Case, async: true

  alias SecondLife.Tasks.ArchiveAndMove

  @moduletag :unit

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "second_life_test_#{:rand.uniform(100_000)}")
    source_dir = Path.join(tmp_dir, "source")
    target_dir = Path.join(tmp_dir, "target")

    File.mkdir_p!(source_dir)
    File.mkdir_p!(target_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir, source_dir: source_dir, target_dir: target_dir}
  end

  describe "execute/2" do
    test "archives source directory and moves to target", ctx do
      %{source_dir: source_dir, target_dir: target_dir} = ctx

      # Create test files in source
      File.write!(Path.join(source_dir, "file1.txt"), "content 1")
      File.write!(Path.join(source_dir, "file2.txt"), "content 2")

      assert :ok = ArchiveAndMove.execute(source_dir, target_dir)

      # Verify archive exists in target
      {:ok, target_files} = File.ls(target_dir)
      assert Enum.any?(target_files, &(Path.extname(&1) == ".zip"))
    end

    test "cleans up source files after archiving", ctx do
      %{source_dir: source_dir, target_dir: target_dir} = ctx

      # Create test files in source
      File.write!(Path.join(source_dir, "file1.txt"), "content 1")
      File.write!(Path.join(source_dir, "file2.txt"), "content 2")

      assert :ok = ArchiveAndMove.execute(source_dir, target_dir)

      # Verify source files are removed
      {:ok, source_files} = File.ls(source_dir)
      assert source_files == []
    end

    test "cleans up source subdirectories after archiving", ctx do
      %{source_dir: source_dir, target_dir: target_dir} = ctx

      # Create test files and subdirectory in source
      sub_dir = Path.join(source_dir, "subdir")
      File.mkdir_p!(sub_dir)
      File.write!(Path.join(source_dir, "file.txt"), "content")
      File.write!(Path.join(sub_dir, "nested.txt"), "nested content")

      assert :ok = ArchiveAndMove.execute(source_dir, target_dir)

      # Verify source directory is empty
      {:ok, source_files} = File.ls(source_dir)
      assert source_files == []
    end

    test "returns error if archive already exists in target", ctx do
      %{source_dir: source_dir, target_dir: target_dir} = ctx

      # Create test file in source
      File.write!(Path.join(source_dir, "file.txt"), "content")

      # Pre-create the archive in target
      archive_name = "#{Base.encode32(Path.expand(source_dir))}.zip"
      File.write!(Path.join(target_dir, archive_name), "existing archive")

      assert {:error, :archive_exists} = ArchiveAndMove.execute(source_dir, target_dir)

      # Verify source file still exists (not cleaned up due to error)
      assert File.exists?(Path.join(source_dir, "file.txt"))
    end

    test "creates archive with base32-encoded name", ctx do
      %{source_dir: source_dir, target_dir: target_dir} = ctx

      # Create test file in source
      File.write!(Path.join(source_dir, "file.txt"), "content")

      assert :ok = ArchiveAndMove.execute(source_dir, target_dir)

      # Verify archive name is base32-encoded source path
      expected_name = "#{Base.encode32(Path.expand(source_dir))}.zip"
      assert File.exists?(Path.join(target_dir, expected_name))
    end

    test "archive contains source files", ctx do
      %{source_dir: source_dir, target_dir: target_dir} = ctx

      # Create test files in source
      File.write!(Path.join(source_dir, "file1.txt"), "content 1")
      File.write!(Path.join(source_dir, "file2.txt"), "content 2")

      assert :ok = ArchiveAndMove.execute(source_dir, target_dir)

      # Find and extract the archive
      {:ok, [archive_name]} = File.ls(target_dir)
      archive_path = Path.join(target_dir, archive_name)

      {:ok, file_list} = :zip.list_dir(String.to_charlist(archive_path))

      # file_list contains {:zip_comment, _} and {:zip_file, name, ...} tuples
      filenames =
        file_list
        |> Enum.filter(&match?({:zip_file, _, _, _, _, _}, &1))
        |> Enum.map(fn {:zip_file, name, _, _, _, _} -> to_string(name) end)

      assert "file1.txt" in filenames
      assert "file2.txt" in filenames
    end
  end
end
