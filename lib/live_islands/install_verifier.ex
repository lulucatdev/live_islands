defmodule LiveIslands.InstallVerifier do
  @moduledoc false

  @type check :: %{
          required(:name) => String.t(),
          required(:ok?) => boolean(),
          required(:detail) => String.t()
        }

  @doc false
  def verify(project_root \\ File.cwd!(), opts \\ []) do
    checks =
      static_checks(project_root) ++
        if Keyword.get(opts, :artifacts, false) do
          artifact_checks(project_root, opts)
        else
          []
        end

    result(checks)
  end

  def verify_full(project_root \\ File.cwd!(), opts \\ []) do
    static_checks = static_checks(project_root)

    if Enum.all?(static_checks, & &1.ok?) do
      skip_ssr? = boolean_opt(opts, :skip_ssr?, ssr_disabled?(project_root))
      install? = boolean_opt(opts, :install?, false)
      command_checks = run_build_commands(project_root, install?, skip_ssr?, opts)

      artifact_checks =
        if Enum.all?(command_checks, & &1.ok?) do
          artifact_checks(project_root, skip_ssr?: skip_ssr?)
        else
          []
        end

      result(static_checks ++ command_checks ++ artifact_checks)
    else
      result(static_checks)
    end
  end

  def static_checks(project_root) do
    [
      mix_dependency(project_root),
      package_dependencies(project_root),
      vite_config(project_root),
      tailwind_css(project_root),
      app_js_hooks(project_root),
      component_roots(project_root),
      lazy_component_registries(project_root),
      server_entrypoint(project_root),
      web_helpers(project_root),
      root_layout(project_root),
      live_islands_config(project_root)
    ]
  end

  defp mix_dependency(project_root) do
    file_contains_check(
      "mix dependency",
      Path.join(project_root, "mix.exs"),
      [":live_islands"],
      "mix.exs includes the :live_islands dependency"
    )
  end

  defp package_dependencies(project_root) do
    path = Path.join([project_root, "assets", "package.json"])

    with {:ok, content} <- read_file(path),
         {:ok, package} <- Jason.decode(content) do
      dependencies =
        package
        |> Map.get("dependencies", %{})
        |> Map.merge(Map.get(package, "devDependencies", %{}))

      required =
        ~w(live_islands vite @vitejs/plugin-react @vitejs/plugin-vue @tailwindcss/vite tailwindcss react react-dom vue)

      missing = Enum.reject(required, &Map.has_key?(dependencies, &1))

      check(
        "package dependencies",
        missing == [],
        if(missing == [],
          do: "assets/package.json has LiveIslands, Vite, Tailwind, React, and Vue dependencies",
          else: "assets/package.json is missing #{Enum.join(missing, ", ")}"
        )
      )
    else
      {:error, %Jason.DecodeError{} = error} ->
        check("package dependencies", false, "assets/package.json is invalid JSON: #{error.data}")

      {:error, reason} ->
        check("package dependencies", false, "cannot read assets/package.json: #{reason}")
    end
  end

  defp vite_config(project_root) do
    path =
      find_first(project_root, [
        "assets/vite.config.js",
        "assets/vite.config.mjs",
        "assets/vite.config.ts"
      ])

    file_contains_check(
      "vite config",
      path,
      ["live_islands/vite-plugin", "@vitejs/plugin-react", "@vitejs/plugin-vue", "tailwindcss"],
      "Vite config includes LiveIslands, Tailwind, React, and Vue plugins"
    )
  end

  defp tailwind_css(project_root) do
    path = Path.join([project_root, "assets", "css", "app.css"])

    case read_file(path) do
      {:ok, content} ->
        missing =
          [
            {"Tailwind import", Regex.match?(~r/@import\s+["']tailwindcss["']/, content)},
            {"React component source",
             Regex.match?(~r/@source\s+["'][^"']*react-components/, content)},
            {"Vue component source",
             Regex.match?(~r/@source\s+["'][^"']*vue-components/, content)}
          ]
          |> Enum.reject(fn {_name, ok?} -> ok? end)
          |> Enum.map(fn {name, _ok?} -> name end)

        check(
          "Tailwind CSS",
          missing == [],
          if(missing == [],
            do: "assets/css/app.css imports Tailwind and scans React/Vue component roots",
            else: "assets/css/app.css is missing #{Enum.join(missing, ", ")}"
          )
        )

      {:error, reason} ->
        check("Tailwind CSS", false, "cannot read assets/css/app.css: #{reason}")
    end
  end

  defp app_js_hooks(project_root) do
    file_contains_check(
      "LiveSocket hooks",
      Path.join([project_root, "assets", "js", "app.js"]),
      ["getIslandHooks", "reactComponents", "vueComponents"],
      "assets/js/app.js combines React and Vue island hooks"
    )
  end

  defp component_roots(project_root) do
    required = [
      {"React", "assets/react-components/index.{js,jsx,ts,tsx}"},
      {"Vue", "assets/vue-components/index.{js,ts}"}
    ]

    missing =
      required
      |> Enum.reject(fn {_name, pattern} ->
        project_root
        |> Path.join(pattern)
        |> Path.wildcard()
        |> Enum.any?()
      end)
      |> Enum.map(fn {name, pattern} -> "#{name} root matching #{pattern}" end)

    check(
      "component roots",
      missing == [],
      if(missing == [],
        do: "React and Vue component roots exist",
        else: "missing #{Enum.join(missing, ", ")}"
      )
    )
  end

  defp lazy_component_registries(project_root) do
    checks = [
      lazy_registry(project_root, "React", "assets/react-components/index.{js,jsx,ts,tsx}"),
      lazy_registry(project_root, "Vue", "assets/vue-components/index.{js,ts}")
    ]

    missing =
      checks
      |> Enum.reject(fn {_framework, ok?} -> ok? end)
      |> Enum.map(fn {framework, _ok?} -> framework end)

    check(
      "lazy component registries",
      missing == [],
      if(missing == [],
        do: "React and Vue registries use async imports so Vite can split island chunks",
        else: "#{Enum.join(missing, " and ")} registry should use import() or import.meta.glob"
      )
    )
  end

  defp lazy_registry(project_root, framework, pattern) do
    path =
      project_root
      |> Path.join(pattern)
      |> Path.wildcard()
      |> List.first()

    lazy? =
      case path && read_file(path) do
        {:ok, content} ->
          String.contains?(content, "import(") or String.contains?(content, "import.meta.glob")

        _other ->
          false
      end

    {framework, lazy?}
  end

  defp server_entrypoint(project_root) do
    file_contains_check(
      "SSR entrypoint",
      Path.join([project_root, "assets", "js", "server.js"]),
      ["live_islands/react/server", "live_islands/vue/server", "render("],
      "assets/js/server.js can dispatch SSR for React and Vue"
    )
  end

  defp web_helpers(project_root) do
    project_root
    |> Path.join("lib/*_web.ex")
    |> Path.wildcard()
    |> Enum.find(fn path ->
      path
      |> File.read!()
      |> String.contains?("import LiveIslands")
    end)
    |> case do
      nil -> check("web helpers", false, "lib/*_web.ex does not import LiveIslands")
      _path -> check("web helpers", true, "web helpers import LiveIslands")
    end
  end

  defp root_layout(project_root) do
    project_root
    |> Path.join("lib/*_web/components/layouts/root.html.heex")
    |> Path.wildcard()
    |> Enum.find(fn path ->
      content = File.read!(path)

      String.contains?(content, "LiveIslands.Reload.vite_assets") and
        String.contains?(content, ~s(type="module"))
    end)
    |> case do
      nil -> check("root layout", false, "root layout is not wired to Vite module assets")
      _path -> check("root layout", true, "root layout uses the Vite asset helper")
    end
  end

  defp live_islands_config(project_root) do
    config_files =
      project_root
      |> Path.join("config/*.exs")
      |> Path.wildcard()

    found? =
      Enum.any?(config_files, fn path ->
        path
        |> File.read!()
        |> String.contains?("config :live_islands")
      end)

    check(
      "LiveIslands config",
      found?,
      if(found?,
        do: "config files include config :live_islands",
        else: "config/*.exs does not configure :live_islands"
      )
    )
  end

  defp artifact_checks(project_root, opts) do
    skip_ssr? = boolean_opt(opts, :skip_ssr?, false)

    [
      vite_build_artifacts(project_root),
      lazy_chunk_artifacts(project_root),
      ssr_build_artifacts(project_root, skip_ssr?)
    ]
  end

  defp vite_build_artifacts(project_root) do
    asset_dir = Path.join([project_root, "priv", "static", "assets"])
    js_files = Path.wildcard(Path.join(asset_dir, "*.js"))
    css_files = Path.wildcard(Path.join(asset_dir, "*.css"))

    check(
      "Vite build artifacts",
      js_files != [] and css_files != [],
      if(js_files != [] and css_files != [],
        do: "priv/static/assets contains built JavaScript and CSS assets",
        else: "run npm run build --prefix assets and confirm JavaScript and CSS are emitted"
      )
    )
  end

  defp lazy_chunk_artifacts(project_root) do
    asset_dir = Path.join([project_root, "priv", "static", "assets"])

    chunks =
      asset_dir
      |> Path.join("*.js")
      |> Path.wildcard()
      |> Enum.reject(&(Path.basename(&1) == "app.js"))

    check(
      "lazy chunk artifacts",
      chunks != [],
      if(chunks != [],
        do: "Vite emitted #{length(chunks)} lazy JavaScript chunk(s) for islands",
        else: "Vite did not emit lazy JavaScript chunks; check async component registries"
      )
    )
  end

  defp ssr_build_artifacts(_project_root, true) do
    check("SSR build artifacts", true, "SSR build was skipped because SSR is disabled")
  end

  defp ssr_build_artifacts(project_root, false) do
    server_path = Path.join([project_root, "priv", "island-components", "server.js"])
    package_path = Path.join([project_root, "priv", "island-components", "package.json"])

    ok? =
      File.exists?(server_path) and
        match?({:ok, content} when is_binary(content), read_file(package_path))

    check(
      "SSR build artifacts",
      ok?,
      if(ok?,
        do: "priv/island-components contains the Node SSR bundle",
        else:
          "run npm run build-server --prefix assets and confirm priv/island-components/server.js exists"
      )
    )
  end

  defp run_build_commands(project_root, install?, skip_ssr?, opts) do
    runner = Keyword.get(opts, :runner, &System.cmd/3)

    [
      if(install?, do: {"npm install", "npm", ["install", "--prefix", "assets"]}),
      {"Vite client build", "npm", ["run", "build", "--prefix", "assets"]},
      unless(skip_ssr?,
        do: {"SSR bundle build", "npm", ["run", "build-server", "--prefix", "assets"]}
      )
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce_while([], fn {name, command, args}, acc ->
      detail = Enum.join([command | args], " ")

      case runner.(command, args, cd: project_root, stderr_to_stdout: true) do
        {_output, 0} ->
          {:cont, [check(name, true, "#{detail} completed") | acc]}

        {output, status} ->
          {:halt,
           [
             check(
               name,
               false,
               "#{detail} failed with exit status #{status}\n#{compact_output(output)}"
             )
             | acc
           ]}
      end
    end)
    |> Enum.reverse()
  end

  defp file_contains_check(name, nil, _markers, _ok_detail) do
    check(name, false, "file is missing")
  end

  defp file_contains_check(name, path, markers, ok_detail) do
    case read_file(path) do
      {:ok, content} ->
        missing = Enum.reject(markers, &String.contains?(content, &1))

        check(
          name,
          missing == [],
          if(missing == [],
            do: ok_detail,
            else: "#{Path.relative_to_cwd(path)} is missing #{Enum.join(missing, ", ")}"
          )
        )

      {:error, reason} ->
        check(name, false, "#{Path.relative_to_cwd(path)} cannot be read: #{reason}")
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, :file.format_error(reason)}
    end
  end

  defp find_first(project_root, paths) do
    paths
    |> Enum.map(&Path.join(project_root, &1))
    |> Enum.find(&File.exists?/1)
  end

  defp ssr_disabled?(project_root) do
    project_root
    |> Path.join("config/*.exs")
    |> Path.wildcard()
    |> Enum.any?(fn path ->
      path
      |> File.read!()
      |> String.contains?("ssr: false")
    end)
  end

  defp boolean_opt(opts, key, default) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_boolean(value) -> value
      _other -> default
    end
  end

  defp compact_output(output) when is_binary(output) do
    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.take(-20)
    |> Enum.join("\n")
  end

  defp result(checks) do
    if Enum.all?(checks, & &1.ok?) do
      {:ok, checks}
    else
      {:error, checks}
    end
  end

  defp check(name, ok?, detail), do: %{name: name, ok?: ok?, detail: detail}
end
