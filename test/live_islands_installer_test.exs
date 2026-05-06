defmodule LiveIslandsInstallerTest do
  use ExUnit.Case, async: true

  alias LiveIslands.Installer

  test "copy_templates creates missing files and preserves existing project files" do
    project_root = tmp_dir!("live_islands_project")
    dependency_root = tmp_dir!("live_islands_dep")
    copy_root = Path.join([dependency_root, "assets", "copy"])

    File.mkdir_p!(Path.join([copy_root, "js"]))
    File.mkdir_p!(Path.join([project_root, "assets", "js"]))
    File.write!(Path.join([copy_root, "js", "server.js"]), "generated")
    File.write!(Path.join([copy_root, "package.json"]), ~s({"private":true}))
    File.write!(Path.join([project_root, "assets", "package.json"]), "existing")

    Installer.copy_templates(project_root, dependency_root)

    assert File.read!(Path.join([project_root, "assets", "js", "server.js"])) == "generated"
    assert File.read!(Path.join([project_root, "assets", "package.json"])) == "existing"
  end

  defp tmp_dir!(name) do
    path = Path.join(System.tmp_dir!(), "#{name}_#{System.unique_integer([:positive])}")
    File.rm_rf!(path)
    File.mkdir_p!(path)
    path
  end
end
