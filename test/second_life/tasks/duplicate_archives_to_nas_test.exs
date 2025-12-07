#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife.Tasks.DuplicateArchivesToNasTest do
  use ExUnit.Case, async: true

  alias SecondLife.Tasks.DuplicateArchivesToNas

  @moduletag :unit

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "second_life_test_#{:rand.uniform(100_000)}")
    archive_path = Path.join(tmp_dir, "archives")
    nas_path = Path.join(tmp_dir, "nas")

    File.mkdir_p!(archive_path)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir, archive_path: archive_path, nas_path: nas_path}
  end

  describe "execute/2" do
    test "copies zip files to NAS", ctx do
      %{archive_path: archive_path, nas_path: nas_path} = ctx

      # Create a test zip file
      zip_file = Path.join(archive_path, "test.zip")
      File.write!(zip_file, "test content")

      assert :ok = DuplicateArchivesToNas.execute(archive_path, nas_path)

      # Verify file was copied
      nas_file = Path.join(nas_path, "test.zip")
      assert File.exists?(nas_file)
      assert File.read!(nas_file) == "test content"
    end

    test "creates NAS directory if not present", ctx do
      %{archive_path: archive_path, nas_path: nas_path} = ctx

      nested_nas = Path.join(nas_path, "nested/deep/path")

      refute File.exists?(nested_nas)

      assert :ok = DuplicateArchivesToNas.execute(archive_path, nested_nas)

      assert File.dir?(nested_nas)
    end

    test "skips non-zip files", ctx do
      %{archive_path: archive_path, nas_path: nas_path} = ctx

      # Create non-zip files
      txt_file = Path.join(archive_path, "readme.txt")
      tar_file = Path.join(archive_path, "archive.tar.gz")
      File.write!(txt_file, "text content")
      File.write!(tar_file, "tar content")

      assert :ok = DuplicateArchivesToNas.execute(archive_path, nas_path)

      # Verify non-zip files were not copied
      refute File.exists?(Path.join(nas_path, "readme.txt"))
      refute File.exists?(Path.join(nas_path, "archive.tar.gz"))
    end

    test "skips zip files that already exist with same size", ctx do
      %{archive_path: archive_path, nas_path: nas_path} = ctx

      File.mkdir_p!(nas_path)

      # Create identical files in both locations
      content = "identical content"
      zip_file = Path.join(archive_path, "existing.zip")
      nas_file = Path.join(nas_path, "existing.zip")
      File.write!(zip_file, content)
      File.write!(nas_file, content)

      # Get original mtime
      {:ok, %{mtime: original_mtime}} = File.stat(nas_file)

      # Small delay to ensure mtime would change if file was modified
      Process.sleep(10)

      assert :ok = DuplicateArchivesToNas.execute(archive_path, nas_path)

      # Verify file was not overwritten (mtime unchanged)
      {:ok, %{mtime: new_mtime}} = File.stat(nas_file)
      assert original_mtime == new_mtime
    end

    test "re-copies zip files if size differs", ctx do
      %{archive_path: archive_path, nas_path: nas_path} = ctx

      File.mkdir_p!(nas_path)

      # Create files with different sizes
      zip_file = Path.join(archive_path, "changed.zip")
      nas_file = Path.join(nas_path, "changed.zip")
      File.write!(zip_file, "new larger content here")
      File.write!(nas_file, "old content")

      assert :ok = DuplicateArchivesToNas.execute(archive_path, nas_path)

      # Verify file was overwritten with new content
      assert File.read!(nas_file) == "new larger content here"
    end

    test "copies multiple zip files", ctx do
      %{archive_path: archive_path, nas_path: nas_path} = ctx

      # Create multiple zip files
      for i <- 1..3 do
        File.write!(Path.join(archive_path, "archive#{i}.zip"), "content #{i}")
      end

      assert :ok = DuplicateArchivesToNas.execute(archive_path, nas_path)

      # Verify all files were copied
      for i <- 1..3 do
        nas_file = Path.join(nas_path, "archive#{i}.zip")
        assert File.exists?(nas_file)
        assert File.read!(nas_file) == "content #{i}"
      end
    end

    test "handles empty archive directory", ctx do
      %{archive_path: archive_path, nas_path: nas_path} = ctx

      assert :ok = DuplicateArchivesToNas.execute(archive_path, nas_path)
      assert File.dir?(nas_path)
    end
  end
end
