defmodule Processes do
  use Koans

  @intro "Processes"

  koan "You are a process" do
    assert Process.alive?(self()) == true
  end

  koan "You can ask a process to introduce itself" do
    information = Process.info(self())

    assert information[:status] == :running
  end

  koan "Processes are referenced by their process ID (pid)" do
    assert is_pid(self()) == true
  end

  koan "New processes are spawned functions" do
    pid = spawn(fn -> nil end)

    assert Process.alive?(pid) == true
  end

  koan "Processes can send and receive messages" do
    send self(), "hola!"

    receive do
      msg -> assert msg == "hola!"
    end
  end

  koan "Received messages are queued, first in first out" do
    send self(), "hola!"
    send self(), "como se llama?"

    assert_receive "hola!"
    assert_receive "como se llama?"
  end

  koan "A common pattern is to include the sender in the message, so that it can reply" do
    greeter = fn ->
      receive do
        {:hello, sender} -> send sender, :how_are_you?
      end
    end

    pid = spawn(greeter)

    send pid, {:hello, self()}
    assert_receive :how_are_you?
  end

  def yelling_echo_loop do
    receive do
      {caller, value} ->
        send caller, String.upcase(value)
        yelling_echo_loop()
    end
  end

  koan "Use tail recursion to receive multiple messages" do
    pid = spawn_link(&yelling_echo_loop/0)

    send pid, {self(), "o"}
    assert_receive "O"

    send pid, {self(), "hai"}
    assert_receive "HAI"
  end

  def state(value) do
    receive do
      {caller, :get} ->
        send caller, value
        state(value)
      {caller, :set, new_value} ->
        state(new_value)
    end
  end

  koan "Processes can be used to hold state" do
    initial_state = "foo"
    pid = spawn(fn ->
      state(initial_state)
    end)

    send pid, {self(), :get}
    assert_receive "foo"

    send pid, {self(), :set, "bar"}
    send pid, {self(), :get}
    assert_receive "bar"
  end

  koan "Waiting for a message can get boring" do
    parent = self()
    spawn(fn -> receive do
                after
                  5 -> send parent, {:waited_too_long, "I am impatient"}
                end
           end)

    assert_receive {:waited_too_long, "I am impatient"}
  end

  koan "Trapping will allow you to react to someone terminating the process" do
    parent = self()
    pid = spawn(fn ->
                      Process.flag(:trap_exit, true)
                      send parent, :ready
                      receive do
                        {:EXIT, _pid, reason} -> send parent, {:exited, reason}
                      end
              end)

    receive do
      :ready -> true
    end

    Process.exit(pid, :random_reason)

    assert_receive {:exited, :random_reason}
  end

  koan "Parent processes can trap exits for children they are linked to" do
    Process.flag(:trap_exit, true)
    spawn_link(fn -> Process.exit(self(), :normal) end)

    assert_receive {:EXIT, _pid, :normal}
  end

  koan "If you monitor your children, you'll be automatically informed for their depature" do
    spawn_monitor(fn -> Process.exit(self(), :normal) end)

    assert_receive {:DOWN, _ref, :process, _pid, :normal}
  end
end
