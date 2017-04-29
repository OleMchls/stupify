require Logger

defmodule Stupify do
  @moduledoc """
  Documentation for Stupify.
  """
  @behaviour Plug.Conn.Adapter

  use Application

  alias Stupify.Request

  def start(_type, [plug]) do
    # The options below mean:
    #
    # 1. `:binary` - receives data as binaries (instead of lists)
    # 2. `packet: :line` - receives data line by line
    # 3. `active: false` - blocks on `:gen_tcp.recv/2` until data is available
    # 4. `reuseaddr: true` - allows us to reuse the address if the listener crashes
    #
    port = 4400
    {:ok, socket} = :gen_tcp.listen(port,
                      [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    opts = plug.init(%{})
    Task.start_link(fn -> loop_acceptor(socket, {plug, opts}) end)
    {:ok, self()}
  end

  defp loop_acceptor(socket, plug) do
    {:ok, client} = :gen_tcp.accept(socket)
    serve(client, %Request{})
    |> respond(plug, client)
    :gen_tcp.close(client)
    loop_acceptor(socket, plug)
  end

  defp respond(req, {plug, opts}, socket) do
    plug.call(Request.build_conn(req, socket), opts)
  end

  defp serve(socket, %Request{awaiting: :response} = req), do: req
  defp serve(socket, req) do
    req = socket
    |> read_line()
    |> parse(req)

    serve(socket, req)
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    String.strip data
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, String.to_charlist(line <> "\r\n"))
  end

  defp parse(data, %Request{awaiting: :statusline} = req) do
    %{req | statusline: data, awaiting: :headers}
  end

  defp parse("", %Request{awaiting: :headers} = req) do
    %{req | awaiting: :response}
  end

  defp parse(data, %Request{awaiting: :headers} = req) do
    %{req | headers: [parse_header(data) | req.headers] , awaiting: :headers}
  end

  defp parse_header(header) do
    [_, key, value] = Regex.run(~r/(.+)\:\s(.+)/, header)
    {String.downcase(key), value}
  end

  # Catch all
  defp parse(data, %Request{} = req) do
    Logger.info {data, req}
  end

  ## Conn

  def send_resp(socket, status, headers, body) do
    IO.inspect {socket, status, headers, body}
    write_line("HTTP/1.1 #{status} #{Plug.Conn.Status.reason_phrase(status)}", socket)
    send_headers headers, socket
    write_line("", socket)
    write_line(body, socket)
    {:ok, nil, socket}
  end

  defp send_headers([], socket), do: nil
  defp send_headers([{k, v} | rest], socket) do
    write_line("#{k}: #{v}", socket)
    send_headers(rest, socket)
  end
end
