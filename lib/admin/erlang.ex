defmodule Admin.Erlang do
  def monitors_for_room(room \\ "garden.main") do
    monitors_for_registry(Mud.RoomRegistry, room)
  end

  def monitors(pid) do
    Process.info(pid, :monitors)
  end

  def pid_for_registry(registry \\ Mud.RoomRegistry, name) do
    case Registry.lookup(registry, name) do
      [{pid, _}] -> pid
      [] -> {:error, :not_found}
    end
  end

  def monitors_for_registry(registry, name) do
    with pid when is_pid(pid) <- pid_for_registry(registry, name) do
       monitors(pid)
    end

  end

  def alive?(pid), do: Process.alive?(pid)

  def state(pid), do: :sys.get_state(pid)
end
