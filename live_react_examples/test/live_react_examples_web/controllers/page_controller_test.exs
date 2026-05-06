defmodule LiveReactExamplesWeb.PageControllerTest do
  use LiveReactExamplesWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) == ~p"/simple"
  end
end
