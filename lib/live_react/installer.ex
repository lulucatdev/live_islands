defmodule LiveReact.Installer do
  @moduledoc false

  defdelegate dependency_path(), to: LiveIslands.Installer

  defdelegate install(
                project_root \\ File.cwd!(),
                dependency_root \\ LiveIslands.Installer.dependency_path()
              ),
              to: LiveIslands.Installer

  defdelegate copy_templates(project_root, dependency_root), to: LiveIslands.Installer
  defdelegate patch_project(project_root), to: LiveIslands.Installer
  defdelegate patch_app_js(content), to: LiveIslands.Installer
  defdelegate patch_base_config(content), to: LiveIslands.Installer
  defdelegate patch_dev_config(content), to: LiveIslands.Installer
  defdelegate patch_prod_config(content), to: LiveIslands.Installer
end
