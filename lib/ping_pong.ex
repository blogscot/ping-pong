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

  @payload_length 1
  @max_count 10_000

  @doc """
  When a :ping message is received, return a :pong
  """
  def ping do
    receive do
      {from, :ping, payload} ->
        send from, {self(), :pong, payload}
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
  def start_processes(nodes, payload) do

    local  = List.first(nodes)
    remote = Enum.at(nodes, 1)

    pong_pid = Node.spawn_link local,  __MODULE__, :pong, [self()]
    ping_pid = Node.spawn_link remote, __MODULE__, :ping, []
    send pong_pid, {ping_pid, :pong, payload}

    receive do
      {^pong_pid, :done} -> IO.puts "Done!"
    end
  end

  @doc """
  Connects to the remote machine, spawns :ping and :pong process,
  and sends the initial message to start.
  If there is a connection problem, we give up and go home.
  """
  def run do

    # Read remote node info from config
    nodes = Application.get_env(:ping_pong, :nodes)
    IO.puts("Connecting nodes: #{inspect nodes}")

    status = for node <- nodes, do: Node.connect(node)

    # Are all nodes connected?
    case Enum.all?(status, &(&1)) do
      true ->
        payload = 1..@payload_length |> Enum.to_list
        Measure.this(fn -> start_processes(nodes, payload) end)
        |> Kernel./(@max_count)
      _ ->
        IO.puts "Could not connect to remote nodes, status: #{inspect status}"
    end
  end

end
