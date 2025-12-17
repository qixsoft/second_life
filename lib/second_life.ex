#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife do
  @moduledoc """
  Main API module for `SecondLife`.
  """
  require Logger

  @doc """
  Fetch the contents file names of the source directory.
  """
  @spec fetch_source_filenames!(String.t()) :: [String.t()]
  def fetch_source_filenames!(source_dir) when is_binary(source_dir) do
    source_dir |> Path.expand() |> File.ls!()
  end

  @doc """
  Fetch the contents file names of the source directory.
  """
  @spec fetch_source_filenames(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def fetch_source_filenames(source_dir) when is_binary(source_dir) do
    case File.ls(Path.expand(source_dir)) do
      {:ok, contents} -> {:ok, contents}
      {:error, :enoent} -> {:error, "Failed to fetch source contents: directory does not exist"}
      {:error, reason} -> {:error, "Failed to fetch source contents: #{reason}"}
    end
  end

  @doc """
  Fetch the contents paths of the source directory.
  """
  @spec fetch_source_paths(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def fetch_source_paths(source_dir) when is_binary(source_dir) do
    expanded = Path.expand(source_dir)

    case File.ls(expanded) do
      {:ok, contents} -> {:ok, Enum.map(contents, &Path.join(expanded, &1))}
      {:error, :enoent} -> {:error, "Failed to fetch source contents: directory does not exist"}
      {:error, reason} -> {:error, "Failed to fetch source contents: #{reason}"}
    end
  end

  @doc """
  Archive the list of files supplied with the working directory.
  """
  @spec archive([String.t()], String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def archive(filenames, source_dir) when is_list(filenames) and is_binary(source_dir) do
    source_path = Path.expand(source_dir)
    archive_name = ~c"#{Base.encode32(source_path)}.zip"

    opts = [
      {:comment, ~c"Archive of #{source_path} created at #{DateTime.utc_now()}"},
      {:cwd, String.to_charlist(source_path)}
    ]

    files = Enum.map(filenames, &String.to_charlist/1)

    Logger.info("Archiving #{Enum.count(files)} files in #{source_path}")

    with {:ok, _archive} <- :zip.zip(archive_name, files, opts),
         target_path = Path.join(source_path, archive_name),
         {:ok, working_path} <- File.cwd(),
         zip_path = Path.join(working_path, archive_name),
         :ok <- File.cp(zip_path, target_path),
         :ok <- File.rm(zip_path) do
      Logger.info("Archived and moved to #{target_path}")
      {:ok, target_path}
    else
      {:error, reason} ->
        {:error, "Failed to create archive: #{inspect(reason)}"}
    end
  end

  @spec archive!([String.t()], String.t()) :: String.t()
  def archive!(filenames, working_dir) when is_list(filenames) and is_binary(working_dir) do
    case archive(filenames, working_dir) do
      {:ok, archive} -> archive
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Recover the files from an archive then delete the archive.
  """
  def recover(origin_path) do
    cwd = String.to_charlist(Path.dirname(origin_path))

    with {:ok, _file_list} <- :zip.unzip(String.to_charlist(origin_path), [{:cwd, cwd}]),
         :ok <- File.rm!(origin_path) do
      :ok
    else
      {:error, reason} = err ->
        Logger.error("Unable to recover archive #{origin_path} due to #{inspect(reason)}")
        err
    end
  end
end
