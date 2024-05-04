defmodule ExSaga.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Hermanlangner/ex_saga"

  def project do
    [
      app: :ex_saga,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      name: "ex_saga",
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
      {:jason, "~> 1.2"},
      {:sobelow, "~> 0.8", only: [:dev, :test]}
    ]
  end
end
