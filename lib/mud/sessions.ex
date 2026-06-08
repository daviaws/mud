defmodule Mud.Sessions do
  @registry Mud.SessionRegistry

  def register(name), do: Registry.register(@registry, name, nil)
  def unregister(name), do: Registry.unregister(@registry, name)

  def get(name) do
    case Registry.lookup(@registry, name) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
end
