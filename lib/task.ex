
defmodule ElixirEither.TaskEx do
  alias ElixirEither.Either

  def async_all(funcs, merge_strategy) do
    pids = Enum.map(funcs, fn func -> Task.async(func) end)
    await_multiple(pids, merge_strategy)
  end

  def map_async(list, func, merge_strategy) do
    pids = Enum.map(list,
      fn item ->
        Task.async(fn-> func.(item) end)
      end)

    await_multiple(pids, merge_strategy)
  end

  def wait_for_eithers(tasks) do
    Task.yield_many(tasks, 20000)
    |> Enum.map(fn {_, result} -> result_to_either(result) end)
  end

  def yield_either(task) do
    Task.yield(task, 20000) |> result_to_either
  end

  defp result_to_either(result) do
    case result do
      {:ok, nested_result} -> case nested_result do
                                :ok             -> Either.success()
                                {:ok, value}    -> Either.success(value)
                                {:error, error} -> Either.failure(error)
                                _               -> Either.success(nested_result)
                              end
      {:exit,      reason} -> Either.failure(reason)
      nil                  -> Either.failure("Task timeout reach but task still going")
    end
  end

  defp await_multiple(pids, merge_strategy) do
    pids |> wait_for_eithers |> Either.merge_eithers(strategy: merge_strategy[:merge_strategy])
  end
end
