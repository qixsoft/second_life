#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife.Release do
  @moduledoc """
  Release functions that can be called by eval after mix release has
  been used to generate the application.
  """
  alias SecondLife.Release
  alias SecondLife.Tasks.ArchiveAndMove
  alias SecondLife.Tasks.DuplicateArchivesToNas

  require Logger

  @default_timeout 600_000

  defstruct [
    :nas_path,
    :source_dir,
    :target_dir,
    keep_files?: false,
    timeout: @default_timeout
  ]

  @type t :: %Release{
          nas_path: String.t(),
          source_dir: String.t(),
          target_dir: String.t(),
          keep_files?: boolean(),
          timeout: pos_integer()
        }

  @doc """
  Parses command line arguments into a Release config struct.

  ## Options

    * `:nas_path` - Path to NAS storage (default: "/Volumes/The Crag/Second Life/{machine}/{date}")
    * `:source_dir` - Source directory to archive (default: "~/Downloads")
    * `:target_dir` - Target directory for archives (default: "/Volumes/Second Life/{date}")
    * `:keep_files` - Whether to keep source files after archiving (default: false)
    * `:timeout` - Task timeout in milliseconds (default: 600_000)

  """
  @spec parse_args(list(String.t())) :: t()
  def parse_args(args) do
    today = Date.utc_today()
    machine_name = :inet.gethostname() |> elem(1) |> to_string()

    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [
          nas_path: :string,
          keep_files: :boolean,
          source_dir: :string,
          target_dir: :string,
          timeout: :integer
        ]
      )

    %Release{
      keep_files?: parsed[:keep_files] || false,
      nas_path: parsed[:nas_path] || "/Volumes/The Crag/Second Life/#{machine_name}/#{today}",
      source_dir: parsed[:source_dir] || "~/Downloads",
      target_dir: parsed[:target_dir] || "/Volumes/Second Life/#{today}",
      timeout: parsed[:timeout] || @default_timeout
    }
  end

  @doc """
  Run the main workflow for SecondLife.
  """
  @spec run :: :ok | {:error, :archive_exists}
  def run do
    args = System.argv()
    Application.ensure_all_started(:second_life)
    config = parse_args(args)
    run_workflow(config)
  end

  @doc """
  Executes the archive and duplicate workflow with the given configuration.
  """
  @spec run_workflow(t()) :: :ok | {:error, :archive_exists}
  def run_workflow(%Release{} = config) do
    %Release{
      source_dir: source_dir,
      target_dir: target_dir,
      nas_path: nas_path,
      keep_files?: keep_files?,
      timeout: timeout
    } = config

    Logger.info("Performing Tasks to archive #{source_dir} to #{target_dir}")

    archive_task =
      Task.Supervisor.async(SecondLife.TaskSupervisor, ArchiveAndMove, :execute, [
        source_dir,
        target_dir,
        keep_files?
      ])

    archive_path = Path.expand(target_dir)

    with :ok <- Task.await(archive_task, timeout),
         duplicate_task =
           Task.Supervisor.async(SecondLife.TaskSupervisor, DuplicateArchivesToNas, :execute, [
             archive_path,
             nas_path
           ]),
         :ok <- Task.await(duplicate_task, timeout) do
      :ok
    else
      {:error, :archive_exists} ->
        Logger.warning("Stopping due to the archive being already present in #{target_dir}")
        {:error, :archive_exists}
    end
  end
end
