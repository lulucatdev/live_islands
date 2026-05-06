defmodule LiveIslandsExamplesWeb.PageControllerTest do
  use LiveIslandsExamplesWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) == ~p"/simple"
  end
end
