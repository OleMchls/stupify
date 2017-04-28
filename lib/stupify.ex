require Logger

defmodule Stupify do
  @moduledoc """
  Documentation for Stupify.
  """

  use Application

  alias Stupify.Request

  def start(_type, _args) do
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
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    serve(client, %Request{})
    loop_acceptor(socket)
  end

  defp serve(socket, %Request{awaiting: :response} = req) do
    Logger.info "sending response now"
    IO.inspect req
  end

  defp serve(socket, req) do
    req = socket
    |> read_line()
    |> String.strip
    |> parse(req)

    serve(socket, req)
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line)
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
    {key, value}
  end

  # Catch all
  defp parse(data, %Request{} = req) do
    Logger.info {data, req}
  end
end
