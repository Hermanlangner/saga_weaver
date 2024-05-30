defmodule SagaWeaver.MixProject do
  use Mix.Project

  @version "0.1.3"
  @source_url "https://github.com/Hermanlangner/saga_weaver"

  def project do
    [
      app: :saga_weaver,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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

  defp package do
    [
      name: "saga_weaver",
      description: """
      Ex Saga is an NServiceBus Saga implementation in Elixir, while being abstracted away from storage and transport.
      """,
      maintainers: ["Herman Langner"],
      links: %{"GitHub" => @source_url},
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs LICENSE README*)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:sobelow, "~> 0.8", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: :test},
      {:elixir_uuid, "~>1.2", only: [:dev, :test]},
      {:jason, "~> 1.2"},
      {:redix, "~> 1.5"},
      {:gen_stage, "~> 1.2.1"}
    ]
  end
end
