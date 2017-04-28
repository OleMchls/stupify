defmodule Stupify.Request do
  defstruct awaiting: :statusline, headers: [], statusline: ''

  def build_conn(%Stupify.Request{} = req, socket) do
    { verb, path, version } = parse_statusline(req.statusline)
    headers = Enum.into(req.headers, %{})
    IO.inspect %Plug.Conn{
      host: headers["host"],
      method: verb,
      request_path: path,
      req_headers: headers,
      scheme: :http,
      adapter: {Stupify, socket},
      owner: self()
    }
  end

  defp parse_statusline(status) do
    [_, verb, path, version] = Regex.run(~r/(.+)\s(.+)\s(.+)/, status)
    {verb, path, version}
  end
end
