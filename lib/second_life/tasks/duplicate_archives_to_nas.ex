#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife.Tasks.DuplicateArchivesToNas do
  @moduledoc """
  Task function to duplicate (copy) archives to the NAS.
  """
  require Logger

  @doc """
  Main function to execute the SecondLife duplicating archives to a location on the NAS.
  """
  @spec execute(archive_path :: String.t(), nas_path :: String.t()) :: :ok
  def execute(archive_path, nas_path) when is_binary(archive_path) and is_binary(nas_path) do
    relevant_archives = fn filename ->
      archive_file = Path.join(archive_path, filename)
      nas_file = Path.join(nas_path, filename)

      (Path.extname(archive_file) == ".zip" &&
         File.exists?(nas_file) == false) or
        (Path.extname(archive_file) == ".zip" && File.exists?(nas_file) &&
           File.stat!(archive_file).size != File.stat!(nas_file).size)
    end

    duplicate = fn filename ->
      Logger.info("Copying #{filename} to NAS at #{nas_path}")
      in_file = Path.join(archive_path, filename)
      out_file = Path.join(nas_path, filename)
      File.copy!(in_file, out_file)
    end

    with :ok <- File.mkdir_p(nas_path),
         {:ok, files} <- File.ls(archive_path) do
      archives = Enum.filter(files, relevant_archives)
      Enum.each(archives, duplicate)
    else
      {:error, code} ->
        Logger.warning("Unable to move to NAS path due to #{code} - rolling back")
        # Rollback operations
        rollback_archives(archive_path)
    end
  end

  defp rollback_archives(archive_path) do
    # 1. Move archives back to their source directory - decode path
    # 2. Unzip each moved archive in original source directory
    # 3. Delete archive from source directory
    Logger.info("Rolling back from #{archive_path}")

    with {:ok, archives} <- File.ls(archive_path) do
      results = Enum.map(archives, &rollback(archive_path, &1))

      if Enum.all?(results, &(elem(&1, 0) == :ok)) do
        :ok
      else
        msg = "Unable to rollback"
        Logger.error(msg)
        {:error, msg}
      end
    end
  end

  defp rollback(archive_path, archive_name) do
    archive = Path.join(archive_path, archive_name)
    Logger.info("Rolling back archive #{archive}")
    base_name = Path.basename(archive_name, ".zip")
    origin_dir = Base.decode32!(base_name)
    origin = Path.join([origin_dir, archive_name])

    with {:ok, _bytes_copied} <- File.copy(archive, origin),
         :ok <- SecondLife.recover(origin),
         {:ok, [^archive]} <- File.rm_rf(archive_path) do
      {:ok, origin}
    end
  end
end
