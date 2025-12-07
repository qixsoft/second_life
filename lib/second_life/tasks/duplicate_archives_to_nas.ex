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

    # Create NAS dir if not present
    :ok = File.mkdir_p!(nas_path)

    with {:ok, files} <- File.ls(archive_path) do
      archives = Enum.filter(files, relevant_archives)
      Enum.each(archives, duplicate)
    end
  end
end
