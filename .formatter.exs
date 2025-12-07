#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
[
  import_deps: [],
  subdirectories: [],
  plugins: [Styler],
  inputs: [
    "mix.exs",
    ".formatter.exs",
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}"
  ]
]
