#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
import Config

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "$time - [$level] - $message $metadata \n"
