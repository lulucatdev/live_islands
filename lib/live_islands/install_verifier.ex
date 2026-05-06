defmodule LiveIslands.InstallVerifier do
  @moduledoc false

  @type check :: %{
          required(:name) => String.t(),
          required(:ok?) => boolean(),
          required(:detail) => String.t()
        }

  @doc false
  def verify(project_root \\ File.cwd!()) do
    checks = [
      mix_dependency(project_root),
      package_dependencies(project_root),
      vite_config(project_root),
      app_js_hooks(project_root),
      component_roots(project_root),
      server_entrypoint(project_root),
      web_helpers(project_root),
      root_layout(project_root),
      live_islands_config(project_root)
    ]

    if Enum.all?(checks, & &1.ok?) do
      {:ok, checks}
    else
      {:error, checks}
    end
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

      required = ~w(live_islands vite @vitejs/plugin-react @vitejs/plugin-vue react react-dom vue)
      missing = Enum.reject(required, &Map.has_key?(dependencies, &1))

      check(
        "package dependencies",
        missing == [],
        if(missing == [],
          do: "assets/package.json has LiveIslands, Vite, React, and Vue dependencies",
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
      ["live_islands/vite-plugin", "@vitejs/plugin-react", "@vitejs/plugin-vue"],
      "Vite config includes LiveIslands, React, and Vue plugins"
    )
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

  defp server_entrypoint(project_root) do
    file_contains_check(
      "SSR entrypoint",
      Path.join([project_root, "assets", "js", "server.js"]),
      ["getRender", "react", "vue"],
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

  defp check(name, ok?, detail), do: %{name: name, ok?: ok?, detail: detail}
end
