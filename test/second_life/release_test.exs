#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife.ReleaseTest do
  use ExUnit.Case, async: true

  alias SecondLife.Release

  @moduletag :unit

  describe "parse_args/1" do
    test "returns default values when no args provided" do
      config = Release.parse_args([])

      assert config.source_dir == "~/Downloads"
      assert config.keep_files? == false
      assert config.timeout == 600_000
      assert String.starts_with?(config.target_dir, "/Volumes/Second Life/")
      assert String.contains?(config.nas_path, "/Volumes/The Crag/Second Life/")
    end

    test "parses --source-dir argument" do
      config = Release.parse_args(["--source-dir", "/custom/source"])

      assert config.source_dir == "/custom/source"
    end

    test "parses --target-dir argument" do
      config = Release.parse_args(["--target-dir", "/custom/target"])

      assert config.target_dir == "/custom/target"
    end

    test "parses --nas-path argument" do
      config = Release.parse_args(["--nas-path", "/custom/nas"])

      assert config.nas_path == "/custom/nas"
    end

    test "parses --keep-files as true" do
      config = Release.parse_args(["--keep-files"])

      assert config.keep_files? == true
    end

    test "parses --keep-files=true" do
      config = Release.parse_args(["--keep-files", "true"])

      assert config.keep_files? == true
    end

    test "parses --no-keep-files for false" do
      config = Release.parse_args(["--no-keep-files"])

      assert config.keep_files? == false
    end

    test "parses --timeout argument" do
      config = Release.parse_args(["--timeout", "300000"])

      assert config.timeout == 300_000
    end

    test "parses multiple arguments" do
      config =
        Release.parse_args([
          "--source-dir",
          "/src",
          "--target-dir",
          "/tgt",
          "--nas-path",
          "/nas",
          "--keep-files",
          "--timeout",
          "120000"
        ])

      assert config.source_dir == "/src"
      assert config.target_dir == "/tgt"
      assert config.nas_path == "/nas"
      assert config.keep_files? == true
      assert config.timeout == 120_000
    end

    test "ignores unknown arguments" do
      config = Release.parse_args(["--unknown", "value", "--source-dir", "/custom"])

      assert config.source_dir == "/custom"
    end

    test "default target_dir contains today's date" do
      config = Release.parse_args([])
      today = to_string(Date.utc_today())

      assert String.contains?(config.target_dir, today)
    end

    test "default nas_path contains machine name and today's date" do
      config = Release.parse_args([])
      today = to_string(Date.utc_today())
      {:ok, hostname} = :inet.gethostname()
      machine_name = to_string(hostname)

      assert String.contains?(config.nas_path, machine_name)
      assert String.contains?(config.nas_path, today)
    end

    test "returns a Release struct" do
      config = Release.parse_args([])

      assert %Release{} = config
    end
  end

  describe "run_workflow/1" do
    setup do
      tmp_dir = Path.join(System.tmp_dir!(), "second_life_release_test_#{:rand.uniform(100_000)}")
      source_dir = Path.join(tmp_dir, "source")
      target_dir = Path.join(tmp_dir, "target")
      nas_path = Path.join(tmp_dir, "nas")

      File.mkdir_p!(source_dir)
      File.mkdir_p!(target_dir)

      on_exit(fn ->
        File.rm_rf!(tmp_dir)
      end)

      {:ok, tmp_dir: tmp_dir, source_dir: source_dir, target_dir: target_dir, nas_path: nas_path}
    end

    test "archives source and duplicates to NAS", ctx do
      %{source_dir: source_dir, target_dir: target_dir, nas_path: nas_path} = ctx

      # Create test files in source
      File.write!(Path.join(source_dir, "file1.txt"), "content 1")
      File.write!(Path.join(source_dir, "file2.txt"), "content 2")

      config = %Release{
        source_dir: source_dir,
        target_dir: target_dir,
        nas_path: nas_path,
        keep_files?: false,
        timeout: 60_000
      }

      assert :ok = Release.run_workflow(config)

      # Verify archive exists in target
      {:ok, target_files} = File.ls(target_dir)
      assert Enum.any?(target_files, &(Path.extname(&1) == ".zip"))

      # Verify archive was duplicated to NAS
      {:ok, nas_files} = File.ls(nas_path)
      assert Enum.any?(nas_files, &(Path.extname(&1) == ".zip"))
    end

    test "returns error when archive already exists", ctx do
      %{source_dir: source_dir, target_dir: target_dir, nas_path: nas_path} = ctx

      # Create test file in source
      File.write!(Path.join(source_dir, "file.txt"), "content")

      # Pre-create the archive in target
      archive_name = "#{Base.encode32(Path.expand(source_dir))}.zip"
      File.write!(Path.join(target_dir, archive_name), "existing archive")

      config = %Release{
        source_dir: source_dir,
        target_dir: target_dir,
        nas_path: nas_path,
        keep_files?: false,
        timeout: 60_000
      }

      assert {:error, :archive_exists} = Release.run_workflow(config)
    end

    test "keeps source files when keep_files? is true", ctx do
      %{source_dir: source_dir, target_dir: target_dir, nas_path: nas_path} = ctx

      # Create test files in source
      File.write!(Path.join(source_dir, "file1.txt"), "content 1")

      config = %Release{
        source_dir: source_dir,
        target_dir: target_dir,
        nas_path: nas_path,
        keep_files?: true,
        timeout: 60_000
      }

      assert :ok = Release.run_workflow(config)

      # Verify source files still exist
      assert File.exists?(Path.join(source_dir, "file1.txt"))
    end

    test "removes source files when keep_files? is false", ctx do
      %{source_dir: source_dir, target_dir: target_dir, nas_path: nas_path} = ctx

      # Create test files in source
      File.write!(Path.join(source_dir, "file1.txt"), "content 1")

      config = %Release{
        source_dir: source_dir,
        target_dir: target_dir,
        nas_path: nas_path,
        keep_files?: false,
        timeout: 60_000
      }

      assert :ok = Release.run_workflow(config)

      # Verify source files were removed
      {:ok, source_files} = File.ls(source_dir)
      assert source_files == []
    end

    test "can rollback to start if NAS directory has no access", ctx do
      %{source_dir: source_dir, target_dir: target_dir} = ctx

      # Create test files in source
      File.write!(Path.join(source_dir, "file4.txt"), "content 4")
      File.write!(Path.join(source_dir, "file44.txt"), "content 44")

      config = %Release{
        source_dir: source_dir,
        target_dir: target_dir,
        nas_path: "/does/not/exist",
        keep_files?: false,
        timeout: 60_000
      }

      assert :ok = Release.run_workflow(config)

      refute File.exists?(target_dir)
      assert MapSet.new(File.ls!(source_dir)) == MapSet.new(["file4.txt", "file44.txt"])
    end
  end

  describe "struct defaults" do
    test "has correct default values" do
      config = %Release{}

      assert config.keep_files? == false
      assert config.timeout == 600_000
      assert config.nas_path == nil
      assert config.source_dir == nil
      assert config.target_dir == nil
    end
  end
end
