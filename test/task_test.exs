defmodule ElixirEither.Test.TaskExTest do
  alias ElixirEither.TaskEx
  alias ElixirEither.Either

  use ExUnit.Case

  describe "TaskEx" do

    test "#async_all: will merge non-either results" do
      func1 = fn-> 1 end
      func2 = fn-> 2 end
      func3 = fn-> 3 end

      result = TaskEx.async_all([func1, func2, func3], merge_strategy: :only_successes)
      assert result == Either.success([1, 2, 3])
    end

    test "#async_all: will merge either results according to merge strategy" do
      func1 = fn-> Either.success(1) end
      func2 = fn-> Either.success(2) end
      func3 = fn-> Either.failure(3) end

      result = TaskEx.async_all([func1, func2, func3], merge_strategy: :only_successes)
      assert result == Either.success([1, 2])
    end

    test "#map_async: can run parallel task and apply merge strategy on resulting eithers" do
      nums = [1, 2, 3, 4]
      result = TaskEx.map_async(nums, fn x -> x + 1  end, merge_strategy: :only_successes)
      assert result == Either.success([2, 3, 4, 5])
    end

    test "#map_async: will extract either results and wrap in task result" do
      nums = [1, 2, 3, 4]
      result = TaskEx.map_async(nums, fn x -> Either.success(x + 1) end, merge_strategy: :only_successes)
      assert result == Either.success([2, 3, 4, 5])

      result = TaskEx.map_async(nums, fn _ -> Either.failure("SomeErr") end, merge_strategy: :only_successes)
      assert result == Either.success([])
    end
  end
end