defmodule ElixirEither.Test.EitherTest do
  import Mock
  alias ElixirEither.Either
  use ExUnit.Case

  describe "Either" do
    test "can ignore map func if failure" do
      value = Either.failure("SomeError")
      assert Either.map(value, fn x -> x + 1 end) == Either.failure("SomeError")
    end

    test "Can transform success" do
      value = Either.success(2)
      assert Either.map(value, fn x -> x + 1 end) == Either.success(3)
    end

    test "Can transform failure" do
      value = Either.failure("error1")
      assert Either.map_error(value, fn x -> "#{x}-is-bad" end) == Either.failure("error1-is-bad")
    end

    test "Can chain on failure" do
      value = Either.failure("SomeError")
      result = value
               |> Either.then(fn x -> Either.success(x + 1) end)
               |> Either.then(fn x -> Either.success(x + 2) end)
      assert result == Either.failure("SomeError")
    end

    test "Can chain on success" do
      value = Either.success(2)
      result = value
               |> Either.then(fn x -> Either.success(x + 1) end)
               |> Either.then(fn x -> Either.success(x + 2) end)
      assert result  ==  Either.success(5)
    end

    test "catch_error: Should throw error if not a valid either" do
      value = "not_an_either"
      catch_throw(value |> Either.catch_error(fn _ -> {} end))
    rescue
      e -> assert e.message =~ ~r/Invalid Either/
    end

    test "map_error: Should throw error if not a valid either" do
      value = "not_an_either"
      catch_throw(value |> Either.map_error(fn _ -> {} end))
    rescue
      e -> assert e.message =~ ~r/Invalid Either/
    end

    test "map: Should throw error if not a valid either" do
      value = "not_an_either"
      catch_throw(value |> Either.map(fn x -> x + 1 end))
    rescue
      e -> assert e.message =~ ~r/Invalid Either/
    end

    test "on: Should throw error if not a valid either" do
      value = "not_an_either"
      catch_throw(value |> Either.on(success: fn _ -> {} end))
    rescue
      e -> assert e.message =~ ~r/Invalid Either/
    end

    test "then: Should throw error if not a valid either" do
      value = "not_an_either"
      catch_throw(value |> Either.then(fn x -> Either.success(x + 1) end))
    rescue
      e -> assert e.message =~ ~r/Invalid Either/
    end

    test "Can terminate Either chain with failure" do
      value = Either.success(1)
      result = value
               |> Either.then(fn x -> Either.success(x + 1) end)
               |> Either.then(fn _ -> Either.failure("SomeError") end)
               |> Either.from_either(
                    success: fn _ -> "Something" end,
                    failure: fn _ -> "Nothing" end
                  )
      assert result  == "Nothing"
    end

    test "Can transform error in failure chain" do
      value = Either.success(1)
      result = value
               |> Either.then(fn x -> Either.success(x + 1) end)
               |> Either.then(fn _ -> Either.failure("SomeError") end)
               |> Either.catch_error(fn _ -> Either.failure("SomeOtherError") end)
               |> Either.from_either(
                    success: fn _ -> "Something" end,
                    failure: fn x -> x end
                  )
      assert result  == "SomeOtherError"
    end

    test "Returning plain value from catch_error resumes processing" do
      value = Either.success(1)
      result = value
               |> Either.then(fn x -> Either.success(x + 1) end)
               |> Either.then(fn _ -> Either.failure("SomeError") end)
               |> Either.catch_error(fn _ -> 5 end)
               |> Either.from_either(
                    success: fn x -> x end,
                    failure: fn x -> x end
                  )
      assert result  == 5
    end

    test "Returning plan success from catch_error resumes processing" do
      value = Either.success(1)
      result = value
               |> Either.then(fn x -> Either.success(x + 1) end)
               |> Either.then(fn _ -> Either.failure("SomeError") end)
               |> Either.catch_error(fn _ -> Either.success(5) end)
               |> Either.from_either(
                    success: fn x -> x end,
                    failure: fn x -> x end
                  )
      assert result  == 5
    end

    test "Can terminate Either chain with success" do
      value = Either.success(2)
      result = value
               |> Either.then(fn x -> Either.success(x + 1) end)
               |> Either.then(fn x -> Either.success(x + 2) end)
               |> Either.from_either(
                    success: fn x -> x end,
                    failure: fn x -> x end
                  )
      assert result  == 5
    end

    test "If any succeed strategy, will merge results from mulitple eithers into a single either if any successful" do
      value1 = Either.success(1)
      value2 = Either.success(2)
      value3 = Either.failure(3)

      result = [value1, value2, value3] |> Either.merge_eithers(strategy: :any_succeed_else_fail)

      assert result == Either.success([1, 2])
    end

    test "If any succeed strategy, will fail if no eithers successful" do
      value1 = Either.failure("Some Error1")
      value2 = Either.failure("Some Error2")
      value3 = Either.failure("Some Error3")

      result = [value1, value2, value3] |> Either.merge_eithers(strategy: :any_succeed_else_fail)

      assert result == Either.failure(["Some Error1", "Some Error2", "Some Error3"])
    end

    test "If all succeed strategy, will merge results from mulitple eithers into a single either if all successful" do
      value1 = Either.success(1)
      value2 = Either.success(2)
      value3 = Either.success(3)

      result = [value1, value2, value3] |> Either.merge_eithers(strategy: :all_succeed_else_fail)

      assert result == Either.success([1, 2, 3])
    end

    test "If all succeed strategy, will fail if any eithers fail" do
      value1 = Either.success(1)
      value2 = Either.failure("Some Error2")
      value3 = Either.failure("Some Error3")

      result = [value1, value2, value3] |> Either.merge_eithers(strategy: :all_succeed_else_fail)

      assert result == Either.failure(["Some Error2", "Some Error3"])
    end

    test "If success or default strategy, will merge results from mulitple eithers into a single either and turn failures into success with default" do
      value1 = Either.success(1)
      value2 = Either.success(2)
      value3 = Either.failure("Some Error")
      value4 = Either.failure("Some Error")

      result = [value1, value2, value3, value4] |> Either.merge_eithers(strategy: :success_or, default: 10)

      assert result == Either.success([1, 2, 10, 10])
    end

    test "If only successes strategy, will merge results from mulitple eithers into a single either ignoring all failures" do
      value1 = Either.success(1)
      value2 = Either.success(2)
      value3 = Either.failure("Some Error")
      value4 = Either.failure("Some Error")

      result = [value1, value2, value3, value4] |> Either.merge_eithers(strategy: :only_successes)
      assert result == Either.success([1, 2])

      result = [value3, value4] |> Either.merge_eithers(strategy: :only_successes)
      assert result == Either.success([])
    end

    test "Can return success or default" do
      either = Either.success(2)
      assert Either.success_or_default(either, 1) == 2

      either = Either.failure("SomeError")
      assert Either.success_or_default(either, 1) == 1
    end

    test "let `then` be turned into `map` if `then` function doesn't return Either" do
      value = Either.success(1)
      result = value
               |> Either.then(fn x -> Either.success(x + 1) end)
               |> Either.then(fn x -> x + 5 end)
               |> Either.success_or_default(0)

      assert result  == 7
    end

    test "on: should execute success if either is successful" do
      defmodule TestModule do
        def success_method(_) do end
        def failure_method(_) do end
      end

      with_mock TestModule, [
        success_method: fn(v) -> v end,
        failure_method: fn(v) -> v end
      ] do

        Either.success(1)
        |> Either.on(
             success: &TestModule.success_method/1,
             failure: &TestModule.failure_method/1)

        assert (called TestModule.success_method(1))
        assert (called TestModule.failure_method(1)) == false
      end
    end

    test "on: should execute failure if either is failed" do
      defmodule TestModule do
        def success_method(_) do end
        def failure_method(_) do end
      end

      with_mock TestModule, [
        success_method: fn(v) -> v end,
        failure_method: fn(v) -> v end
      ] do

        Either.failure("SomeError")
        |> Either.on(
             success: &TestModule.success_method/1,
             failure: &TestModule.failure_method/1)

        assert (called TestModule.failure_method("SomeError"))
        assert (called TestModule.success_method(1)) == false
      end
    end

    test "try: can return func result if no exception raised" do
      value  = "SomeValue"
      action = fn-> value end
      result = Either.try_catch(action)
      assert result == Either.success(value)
    end

    test "try_catch: can return error if exception raised" do
      error  = "SomeError"
      action = fn-> raise error end
      result = Either.try_catch(action)
      assert result == Either.failure(%RuntimeError{message: "SomeError"})
    end

    test "to_elixir_result: will convert either to elixir system result format" do
      assert Either.success(3) |> Either.to_elixir_result == {:ok, 3}
      assert Either.success() |> Either.to_elixir_result == :ok
      assert Either.failure("SomeError") |> Either.to_elixir_result == {:error, "SomeError"}
    end

    test "from_elixir_result: will convert elixir system result format to either" do
      assert Either.from_elixir_result({:ok, 3}) == Either.success(3)
      assert Either.from_elixir_result(:ok) == Either.success()
      assert Either.from_elixir_result({:error, "SomeError"}) == Either.failure("SomeError")
    end
  end
end
