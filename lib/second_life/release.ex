#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife.Release do
  @moduledoc """
  Release functions that can be called by eval after mix release has
  been used to generate the application.
  """
  alias SecondLife.Tasks.ArchiveAndMove
  alias SecondLife.Tasks.DuplicateArchivesToNas

  require Logger

  @doc """
  Run the main workflow for SecondLife.
  """
  @spec run :: :ok | {:error, :archive_exists}
  def run do
    args = System.argv()
    Application.ensure_all_started(:second_life)
    today = Date.utc_today()
    machine_name = :inet.gethostname() |> elem(1) |> to_string()

    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [keep_files: :boolean, source_dir: :string, target_dir: :string, timeout: :integer]
      )

    keep_files? = parsed[:keep_files] || false
    nas_path = parsed[:nas_path] || "/Volumes/The Crag/Second Life/#{machine_name}/#{today}"
    source_dir = parsed[:source_dir] || "~/Downloads"
    target_dir = parsed[:target_dir] || "/Volumes/Second Life/#{today}"
    timeout = parsed[:timeout] || 600_000
    Logger.info("Performing Tasks to archive #{source_dir} to #{target_dir}")

    archive_task =
      Task.Supervisor.async(SecondLife.TaskSupervisor, ArchiveAndMove, :execute, [
        source_dir,
        target_dir,
        keep_files?
      ])

    case Task.await(archive_task, timeout) do
      :ok ->
        archive_path = Path.expand(target_dir)

        duplicate_task =
          Task.Supervisor.async(SecondLife.TaskSupervisor, DuplicateArchivesToNas, :execute, [
            archive_path,
            nas_path
          ])

        :ok = Task.await(duplicate_task, timeout)

      {:error, :archive_exists} ->
        Logger.warning("Stopping due to the archive being already present in #{target_dir}")
    end
  end
end
