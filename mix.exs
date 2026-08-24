defmodule SagaWeaver.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/Hermanlangner/saga_weaver"

  def project do
    [
      app: :saga_weaver,
      version: @version,
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      test_coverage: [tool: ExCoveralls],
      package: package(),
      docs: docs()
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.github": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
      # mod: {SagaWeaver, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp aliases do
    [
      test: ["test.setup", "test"],
      "test.reset": ["ecto.drop", "test.setup"],
      "test.setup": ["ecto.create", "ecto.migrate"]
    ]
  end

  defp package do
    [
      name: "saga_weaver",
      description: """
      Transport-agnostic saga coordination for Elixir with concurrency-safe PostgreSQL and Redis storage.
      """,
      maintainers: ["Herman Langner"],
      links: %{"GitHub" => @source_url},
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs LICENSE README.md CHANGELOG.md ARCHITECTURE.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "ARCHITECTURE.md", "CHANGELOG.md"],
      groups_for_modules: [
        Core: [
          SagaWeaver,
          SagaWeaver.Config,
          SagaWeaver.Error,
          SagaWeaver.Instance,
          SagaWeaver.Saga
        ],
        Storage: ~r/^SagaWeaver\.Storage/,
        Testing: [SagaWeaver.Testing],
        Compatibility: [
          SagaWeaver.Orchestrator,
          SagaWeaver.SagaSchema,
          SagaWeaver.Adapters.PostgresAdapter,
          SagaWeaver.Adapters.RedisAdapter,
          SagaWeaver.Adapters.StorageAdapter
        ]
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:sobelow, "~> 0.8", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: :test},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.3"},
      {:redix, "~> 1.5"},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.16", optional: true}
    ]
  end
end
