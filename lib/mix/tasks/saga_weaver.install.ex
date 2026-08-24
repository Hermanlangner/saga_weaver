defmodule Mix.Tasks.SagaWeaver.Install do
  use Mix.Task

  @shortdoc "Generates SagaWeaver storage setup"

  @moduledoc """
  Generates setup instructions and, for PostgreSQL, a compatible migration.

      mix saga_weaver.install --storage postgres
      mix saga_weaver.install --storage redis

  The application module names are inferred from the current Mix project and
  may be overridden with `--facade`, `--repo`, or `--connection`.
  """

  @switches [
    storage: :string,
    facade: :string,
    repo: :string,
    connection: :string,
    namespace: :string,
    migrations_path: :string,
    dry_run: :boolean
  ]

  @module_name ~r/\A[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*\z/
  @control_characters ~r/[\x00-\x1F\x7F]/

  @impl Mix.Task
  def run(argv) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @switches)

    if args != [] or invalid != [] do
      Mix.raise("invalid arguments: #{inspect(args ++ invalid)}")
    end

    app_module = Mix.Project.config()[:app] |> Atom.to_string() |> Macro.camelize()
    facade = opts |> Keyword.get(:facade, "#{app_module}.Sagas") |> module_name!("--facade")

    case Keyword.fetch(opts, :storage) do
      {:ok, "postgres"} ->
        install_postgres(opts, app_module, facade)

      {:ok, "redis"} ->
        install_redis(opts, app_module, facade)

      {:ok, storage} ->
        Mix.raise("unsupported storage #{inspect(storage)}; expected postgres or redis")

      :error ->
        Mix.raise("--storage is required; expected postgres or redis")
    end
  end

  defp install_postgres(opts, app_module, facade) do
    repo = opts |> Keyword.get(:repo, "#{app_module}.Repo") |> module_name!("--repo")

    migrations_path =
      opts
      |> Keyword.get(:migrations_path, "priv/repo/migrations")
      |> migrations_path!()

    filename = "#{timestamp()}_create_sagaweaver_sagas.exs"
    path = Path.join(migrations_path, filename)
    content = migration("#{repo}.Migrations.CreateSagaWeaverSagas")

    if Keyword.get(opts, :dry_run, false) do
      Mix.shell().info("Would create #{path}")
    else
      Mix.Generator.create_directory(migrations_path)
      Mix.Generator.create_file(path, content)
    end

    Mix.shell().info("""

    Add this facade:

        defmodule #{facade} do
          use SagaWeaver, otp_app: :#{Mix.Project.config()[:app]}
        end

    Add this configuration:

        config :#{Mix.Project.config()[:app]}, #{facade},
          storage: {SagaWeaver.Storage.Postgres, repo: #{repo}}
    """)
  end

  defp install_redis(opts, app_module, facade) do
    connection =
      opts
      |> Keyword.get(:connection, "#{app_module}.SagaRedis")
      |> module_name!("--connection")

    namespace = Keyword.get(opts, :namespace, Mix.Project.config()[:app] |> Atom.to_string())

    Mix.shell().info("""
    Add the Redix connection to your application supervision tree:

        {Redix, name: #{connection}, host: "localhost", port: 6379}

    Add this facade:

        defmodule #{facade} do
          use SagaWeaver, otp_app: :#{Mix.Project.config()[:app]}
        end

    Add this configuration:

        config :#{Mix.Project.config()[:app]}, #{facade},
          storage: {
            SagaWeaver.Storage.Redis,
            connection: #{connection},
            namespace: #{inspect(namespace)}
          }
    """)
  end

  @doc false
  def migration(module_name) do
    """
    defmodule #{module_name} do
      use Ecto.Migration

      def change do
        create table(:sagaweaver_sagas) do
          add :uuid, :string, null: false
          add :saga_name, :string, null: false
          add :states, :map, default: %{}, null: false
          add :context, :map, default: %{}, null: false
          add :marked_as_completed, :boolean, default: false, null: false
          add :lock_version, :integer, default: 1, null: false

          timestamps()
        end

        create unique_index(:sagaweaver_sagas, [:uuid])
      end
    end
    """
  end

  defp timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d%H%M%S")
  end

  defp module_name!(name, switch) do
    if Regex.match?(@module_name, name) do
      name
    else
      Mix.raise("#{switch} must be an Elixir alias such as MyApp.Sagas")
    end
  end

  defp migrations_path!(path) do
    root = File.cwd!() |> Path.expand()
    expanded = Path.expand(path, root)

    if String.starts_with?(expanded, root <> "/") and
         not Regex.match?(@control_characters, path) do
      path
    else
      Mix.raise("--migrations-path must stay within the current project")
    end
  end
end
