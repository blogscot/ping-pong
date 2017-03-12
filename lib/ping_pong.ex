defmodule PingPong do

  @moduledoc """
  Plays Ping Pong between a local and remote machine.
  Start both machines using short names:

    iex --sname node1 --cookie fudge
    iex --sname node2 --cookie fudge

    or if using IP addresses use:

    iex --name node1@127.0.0.1 --cookie fudge -S mix
    iex --name node2@127.0.0.1 --cookie fudge -S mix
  """

  @max_count 10_000        # number of PingPong messages
  @compression_level 1

  @doc """
  When a :ping message is received return a :pong
  """
  def ping do
    receive do
      {from, :ping, payload} ->
        send from, {self(), :pong, payload}
      {from, :pingc, compressed_payload} ->
        # unpack the compressed payload
        payload = compressed_payload |> :erlang.binary_to_term([:safe])
        # processing complete, so re-compress
        new_payload = payload |> :erlang.term_to_binary([{:compressed, @compression_level}])
        send from, {self(), :pongc, new_payload}
    end
    ping()
  end

  @doc """
  When a :pong message is received return a :ping
  This repeats @max_count times.
  """
  def pong(sender, count \\ 1) do
    receive do
      {from, :pong, payload} ->
        send from, {self(), :ping, payload}
      {from, :pongc, compressed_payload} ->
        # unpack the compressed payload
        uncompressed_payload = compressed_payload |> :erlang.binary_to_term([:safe])
        # processing complete, so re-compress
        new_payload = uncompressed_payload |> :erlang.term_to_binary([{:compressed, @compression_level}])
        send from, {self(), :pingc, new_payload}
    end

    if (count < @max_count) do
      pong(sender, count + 1)
    else
      # let the sender know we're done.
      send sender, {self(), :done}
    end
  end

  @doc """
  Spawn local and remote ping pong processes.
  """
  def start_processes(nodes, payload, compress? \\ false) do

    local  = List.first(nodes)
    remote = Enum.at(nodes, 1)

    pong_pid = Node.spawn_link local,  __MODULE__, :pong, [self()]
    ping_pid = Node.spawn_link remote, __MODULE__, :ping, []

    case compress? do
      true ->
        new_payload = payload |> :erlang.term_to_binary([{:compressed, @compression_level}])
        send pong_pid, {ping_pid, :pongc, new_payload}
      _ ->
        send pong_pid, {ping_pid, :pong, payload}
    end

    receive do
      {^pong_pid, :done} -> IO.puts "Done!"
    end
  end

  @doc """
  Connects to the remote machine, spawns :ping and :pong process,
  and sends the initial message to start.
  If there is a connection problem, we give up and go home.
  """
  def run(payload_length \\ 1, compress? \\ false) do

    # Read remote node info from config
    nodes = Application.get_env(:ping_pong, :nodes)
    IO.puts("Connecting nodes: #{inspect nodes}")

    status = for node <- nodes, do: Node.connect(node)

    # Are all nodes connected?
    case Enum.all?(status, &(&1)) do
      true ->
        payload = 1..payload_length |> Enum.to_list
        Measure.this(fn -> start_processes(nodes, payload, compress?) end)
        |> Kernel./(@max_count)
      _ ->
        IO.puts "Could not connect to remote nodes, status: #{inspect status}"
    end
  end

end
