defmodule ElixirEither.Either do
  @type e :: any
  @type v :: any
  @type e1 :: any
  @type v1 :: any
  @type u :: any
  @type either(value, error) :: {:ok, value} | {:error, error}

  @spec success() :: either(:no_value, v)
  def success() do
    :ok
  end

  @spec success(v) :: either(v, e)
  def success(value) do
    {:ok, value}
  end

  @spec failure(e) :: either(:error, e)
  def failure(error) do
    {:error, error}
  end

  @spec map(either(v, e), (v -> v1)) :: either(v1, e)
  def map(either, f) do
    case either do
      {:ok, value}    -> {:ok, f.(value)}
      {:error, error} -> {:error, error}
      _               -> raise_either_error("map", either)
    end
  end

  @spec map_error(either(v, e), (e -> e1)) :: either(v, e1)
  def map_error(either, f) do
    case either do
      {:error, error} -> {:error, f.(error)}
      {:ok, value}    -> {:ok, value}
      _               -> raise_either_error("map_error", either)
    end
  end

  @doc """
  ## Examples
      either = Either.success(1)
      Either.on(either, success: fn v -> _ end, failure: fn e -> _ end)
  """
  @spec on(either(v, e), nonempty_list({:ok, (v -> none())} | {:error, (e -> none())})) :: either(v, e)
  def on(either, options) do
    success_f = options[:success] || fn x -> x end
    failure_f = options[:failure] || fn x -> x end

    case either do
      {:error, error} -> failure_f.(error)
      {:ok, value}    -> success_f.(value)
      _               -> raise_either_error("on", either)
    end
    either
  end

  @spec then(either(v, e), (v -> either(v1, e1))) :: either(v1, e1)
  def then(either, f) do
    case either do
      {:ok, value}    ->
        case f.(value) do
          {:ok, next_value} -> {:ok, next_value}
          {:error, e}       -> {:error, e}
          value             -> {:ok, value}
        end
      {:error, error} -> {:error, error}
      _               -> raise_either_error("then", either)
    end
  end

  @spec catch_error(either(v, e), (e -> either(v1, e1))) :: either(v1, e1)
  def catch_error(either, f) do
    case either do
      {:error, value} ->
        case f.(value) do
          {:error, next_value} -> {:error, next_value}
          {:ok, next_value}    -> {:ok, next_value}
          value                -> {:ok,      value}
        end
      {:ok, value}    -> {:ok, value}
      _               -> raise_either_error("catch_error", either)
    end
  end

  @spec success_or_default(either(v, e), v) :: v
  def success_or_default(either, default) do
    either |> from_either( [{:success, fn value -> value end}, {:failure, fn _     -> default end}] )
  end

  @spec merge_eithers([either(v, e)],
          [{:strategy, :any_succeed_else_fail}]
          | [{:strategy, :success_or, default: v}]
          | [{:strategy, :all_succeed_else_fail}]
            | [{:strategy, :only_successes}]
        ) :: either(v, e)
  def merge_eithers(eithers, options) do
    case options do
      [strategy: :any_succeed_else_fail]              -> eithers |> any_succeed_else_fail
      [strategy: :success_or, default: default_value] -> eithers |> all_succeed_using_default(default_value)
      [strategy: :all_succeed_else_fail]              -> eithers |> all_succeed_else_fail
      [strategy: :only_successes]                     -> eithers |> only_successes
    end
  end

  @spec from_either(either(v, e), nonempty_list({:ok, (v -> u)} | {:error, (e -> u)})) :: u
  def from_either(either, options) do
    [success: get_f, failure: return_f] = options
    case either do
      {:ok, value} -> get_f.(value)
      {:error, error} -> return_f.(error)
      _                 -> raise_either_error("from_either", either)
    end
  end

  @spec try_catch((() -> v)) :: either(v, e)
  def try_catch(func) do
    try do
      func.() |> success()
    rescue
      error -> failure(error)
    end
  end

  defp only_successes(eithers) do
    {success_results, _} = eithers |> eval_either_list
    success(success_results)
  end

  defp all_succeed_using_default(eithers, default) do
    eithers |> Enum.map(&success_or_default(&1, default))
    |> success
  end

  defp all_succeed_else_fail(eithers) do
    {success_results, failed_results} = eithers |> eval_either_list

    if length(failed_results) == 0,
       do:   success(success_results),
       else: failure(failed_results)
  end

  defp any_succeed_else_fail(eithers) do
    {success_results, failed_results} = eithers |> eval_either_list

    if length(success_results) > 0,
       do:   success(success_results),
       else: failure(failed_results)
  end

  defp eval_either_list(eithers) do
    success_results = eithers
                      |> Enum.map(&success_or_nil(&1))
                      |> Enum.filter(&(&1 != nil))

    failed_results  = eithers
                      |> Enum.map(&failure_or_nil(&1))
                      |> Enum.filter(&(&1 != nil))

    {success_results, failed_results}
  end

  defp failure_or_nil(either) do
    either |>
      from_either(
        success: fn _ -> nil end,
        failure: fn x -> x end
      )
  end

  defp success_or_nil(either) do
    either |>
      from_either(
        success: fn x -> x end,
        failure: fn _ -> nil end
      )
  end

  defp raise_either_error(method, value) do
    raise("Either.#{method}: Invalid Either: #{inspect(value)}. " <>
          "Supported formats: {:ok, value}, {:error, error}. " <>
          "Use Either.success(value) or Either.failure(error) to create an Either.")
  end
end