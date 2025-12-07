#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
# Benchmark file copy methods for NAS duplication
#
# Usage:
#   mix run bench/file_copy_bench.exs
#   mix run bench/file_copy_bench.exs -- --size 500         # 500MB test file
#   mix run bench/file_copy_bench.exs -- --dest /Volumes/NAS/test  # Test against NAS
#

defmodule FileCopyBench do
  @moduledoc false

  def current_stream_copy(in_file, out_file) do
    block_size = 1024 * 1024
    io_in = File.open!(in_file, [:read, :binary])
    raw_in = IO.binstream(io_in, block_size)

    raw_in |> Stream.into(File.stream!(out_file)) |> Stream.run()
    File.close(io_in)
  end

  def file_copy(in_file, out_file) do
    File.copy!(in_file, out_file)
  end

  def raw_copy(in_file, out_file, block_size) do
    {:ok, in_fd} = :file.open(in_file, [:read, :raw, :binary, :read_ahead])
    {:ok, out_fd} = :file.open(out_file, [:write, :raw, :binary, :delayed_write])

    copy_loop(in_fd, out_fd, block_size)

    :file.close(in_fd)
    :file.close(out_fd)
  end

  defp copy_loop(in_fd, out_fd, block_size) do
    case :file.read(in_fd, block_size) do
      {:ok, data} ->
        :ok = :file.write(out_fd, data)
        copy_loop(in_fd, out_fd, block_size)

      :eof ->
        :ok
    end
  end
end

# Parse command line args for file size (in MB) and destination
{opts, _} = OptionParser.parse!(System.argv(), strict: [size: :integer, dest: :string])
file_size_mb = Keyword.get(opts, :size, 100)
dest_dir = Keyword.get(opts, :dest)

# Setup: create a test file
tmp_dir = Path.join(System.tmp_dir!(), "second_life_bench")
File.mkdir_p!(tmp_dir)

source_file = Path.join(tmp_dir, "source_#{file_size_mb}mb.bin")

dest_file =
  if dest_dir do
    File.mkdir_p!(dest_dir)
    Path.join(dest_dir, "dest.bin")
  else
    Path.join(tmp_dir, "dest.bin")
  end

IO.puts("Creating #{file_size_mb}MB test file...")

unless File.exists?(source_file) do
  # Create file with random data
  chunk = :crypto.strong_rand_bytes(1024 * 1024)

  File.open!(source_file, [:write, :binary], fn file ->
    for _ <- 1..file_size_mb do
      IO.binwrite(file, chunk)
    end
  end)
end

IO.puts("Test file ready: #{source_file}")
IO.puts("Destination: #{dest_file}")
IO.puts("File size: #{File.stat!(source_file).size |> div(1024 * 1024)}MB")
IO.puts("")

# Cleanup function for after each benchmark run
cleanup = fn ->
  File.rm(dest_file)
end

Benchee.run(
  %{
    "current (1MB stream)" => fn ->
      FileCopyBench.current_stream_copy(source_file, dest_file)
      cleanup.()
    end,
    "File.copy/2" => fn ->
      FileCopyBench.file_copy(source_file, dest_file)
      cleanup.()
    end,
    "raw 1MB blocks" => fn ->
      FileCopyBench.raw_copy(source_file, dest_file, 1 * 1024 * 1024)
      cleanup.()
    end,
    "raw 4MB blocks" => fn ->
      FileCopyBench.raw_copy(source_file, dest_file, 4 * 1024 * 1024)
      cleanup.()
    end,
    "raw 8MB blocks" => fn ->
      FileCopyBench.raw_copy(source_file, dest_file, 8 * 1024 * 1024)
      cleanup.()
    end,
    "raw 16MB blocks" => fn ->
      FileCopyBench.raw_copy(source_file, dest_file, 16 * 1024 * 1024)
      cleanup.()
    end,
    "raw 32MB blocks" => fn ->
      FileCopyBench.raw_copy(source_file, dest_file, 32 * 1024 * 1024)
      cleanup.()
    end
  },
  warmup: 1,
  time: 10,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console
  ]
)

# Cleanup
IO.puts("\nCleaning up test files...")
File.rm_rf!(tmp_dir)

if dest_dir do
  File.rm(dest_file)
end

IO.puts("Done!")
