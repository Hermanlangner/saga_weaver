defmodule ExSaga.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_saga,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
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
