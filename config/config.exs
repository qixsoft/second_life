#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id
  ]

if Mix.env() in [:dev, :test] do
  pre_commit_task_list = [
    {:cmd, "mix format --check-formatted"},
    {:cmd, "mix sobelow -d --config -v"},
    {:cmd, "mix deps.audit --format human"},
    {:cmd, "mix hex.audit"},
    {:cmd, "mix credo --strict"}
  ]

  pre_push_task_list = [
    {:cmd, "mix dialyzer --format github"},
    {:cmd, "mix test --max-failures=1"}
  ]

  config :git_hooks,
    auto_install: true,
    verbose: true,
    branches: [
      whitelist: ["^\d{1,4}-[\w-]*"],
      blacklist: ["main"]
    ],
    hooks: [
      pre_commit: [
        tasks: pre_commit_task_list
      ],
      pre_push: [
        verbose: true,
        tasks: pre_push_task_list
      ]
    ]
end

import_config "#{config_env()}.exs"
