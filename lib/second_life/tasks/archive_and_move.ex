#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife.Tasks.ArchiveAndMove do
  @moduledoc """
  Task function to archive a source directory, move the archive to
  a target directory, then clean the source directory.
  """
  require Logger

  @doc """
  Main function to execute the SecondLife archiving and subsequent moving of that archive
  to a terget location.
  """
  @spec execute(source_dir :: String.t(), target_dir :: String.t(), keep_files? :: boolean()) ::
          :ok | {:error, :archive_exists}
  def execute(source_dir, target_dir, keep_files? \\ false)
      when is_boolean(keep_files?) and is_binary(source_dir) and is_binary(target_dir) do
    source_path = Path.expand(source_dir)
    target_path = Path.expand(target_dir)

    with :ok <- File.mkdir_p!(target_path),
         {:ok, [_ | _] = filenames} <- SecondLife.fetch_source_filenames(source_dir),
         {:ok, archive} <- SecondLife.archive(filenames, source_path),
         :ok <- Logger.info("Archive is #{archive}"),
         target_archive = Path.join(target_path, Path.basename(archive)),
         :ok <- Logger.info("Target Archive is #{target_archive}"),
         false <- File.exists?(target_archive),
         :ok <- File.cp(archive, target_archive),
         :ok <- File.rm(archive) do
      wait_for_target(target_path, File.ls!(target_path))
      Logger.info("Moved archive file to #{target_archive}")

      if keep_files? == false do
        {dirs, files} =
          filenames |> Enum.map(&Path.join(source_path, &1)) |> Enum.split_with(&File.dir?(&1))

        for dir <- dirs do
          :ok = File.touch!(dir)
          File.rm_rf!(dir)
        end

        for file <- files do
          :ok = File.touch!(file)
          File.rm!(file)
        end

        Logger.info("Deleted source files from #{source_path}")
      end

      :ok
    else
      {:ok, []} ->
        Logger.info("The source directory is empty - skipping workflow")
        :ok

      true ->
        {:error, :archive_exists}
    end
  end

  defp wait_for_target(target, []) do
    :timer.sleep(100)
    wait_for_target(target, File.ls!(target))
  end

  defp wait_for_target(_target, _files), do: :done
end
