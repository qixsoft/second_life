#
# Copyright © QixSoft Limited 2002-2025
# Copyright © octowombat 2021-2025
#
defmodule SecondLife.MixProject do
  @moduledoc false
  use Mix.Project

  def application do
    [
      extra_applications: [:logger, :observer, :runtime_tools, :wx],
      mod: {SecondLife.Application, []}
    ]
  end

  def project do
    [
      app: :second_life,
      deps: deps(),
      description: description(),
      dialyzer: dialyzer_opts(),
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      releases: releases(),
      start_permanent: Mix.env() == :prod,
      version: "0.3.2"
    ]
  end

  defp dialyzer_opts do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [
        :ex_unit,
        :mix
      ],
      plt_file: {:no_warn, "priv/plts/second_life.plt"},
      plt_local_path: "priv/plts/second_life.plt",
      plt_core_path: "priv/plts/core",
      plt_core: :second_life
    ]
  end

  defp deps do
    [
      # Development and testing tools, libraries and apps
      {:credo, "== 1.7.14", only: [:dev, :test], runtime: false},
      {:dialyxir, "1.4.7", only: [:dev, :test], runtime: false},
      {:git_hooks, "0.8.1", only: [:dev, :test], runtime: false},
      {:mix_audit, "2.1.5", only: [:dev, :test], runtime: false},
      {:sobelow, "== 0.14.1", only: [:dev, :test], runtime: false},
      {:styler, "== 1.10.0", only: [:dev, :test], runtime: false},
      {:benchee, "== 1.5.0", only: :dev, runtime: false}

      # Runtime libraries
    ]
  end

  defp description, do: "Giving files a second life after downloads."

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp releases do
    [
      second_life: [validate_compile_env: false]
    ]
  end
end
