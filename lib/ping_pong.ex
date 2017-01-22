defmodule PingPong do

  @moduledoc """
  Plays Ping Pong between a local and remote machine.
  Start both machines using short names:

    iex --sname node1 --cookie fudge
    iex --sname node2 --cookie fudge
  """

  @remote :node2@Baggins

  @doc """
  When a :ping message is received, return a :pong
  """
  def ping do
    receive do
      {from, :ping} ->
        :timer.sleep 1000
        IO.puts "ping"
        send from, {self(), :pong}
    end
    ping
  end

  @doc """
  When a :pong message is recieved return a :ping
  This repeats up to 10 times by default.
  """
  def pong(count \\ 0) do
    receive do
      {from, :pong} ->
        :timer.sleep 1000
        IO.puts "pong"
        send from, {self(), :ping}
    end
    if (count < 9) do
      pong(count + 1)
    end
  end

  @doc """
  Connects to the remote machine, spawns :ping and :pong process,
  and sends the initial message to start.
  If there is a connection problem, we give up and go home.
  """
  def start do
    case Node.connect(@remote) do
      true -> (fn ->
        ping_pid = Node.spawn @remote, __MODULE__, :ping, []
        pong_pid = spawn __MODULE__, :pong, []
        send ping_pid, {pong_pid, :ping}
      end).()
      reason ->
        IO.puts "Could not connect to remote machine, reason: #{reason}"
        System.halt(0)
    end
  end
end

