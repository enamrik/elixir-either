defmodule ElixirEither.Either do
  defstruct [:result]

  @type e :: any
  @type v :: any
  @type e1 :: any
  @type v1 :: any
  @type u :: any
  @type t(value, error) :: %__MODULE__{result: {:ok, value}} | %__MODULE__{result: {:error, error}}

  @spec success() :: __MODULE__.t(:no_value, e)
  def success() do
    %__MODULE__{result: {:ok, :no_value}}
  end

  @spec success(v) :: __MODULE__.t(v, e)
  def success(value) do
    %__MODULE__{result: {:ok, value}}
  end

  @spec from_elixir_result(:ok | {:ok, v} | {:error, e}) :: __MODULE__.t(v, e)
  def from_elixir_result(value) do
    case value do
      :ok             -> success()
      {:ok,    value} -> success(value)
      {:error, error} -> failure(error)
    end
  end

  @spec to_elixir_result(__MODULE__.t(v, e)) :: :ok | {:ok, v} | {:error, e}
  def to_elixir_result(either) do
    either
    |> from_either(
      success: fn
        :no_value -> :ok
        value     -> {:ok, value}
      end,
      failure: fn error -> {:error, error} end)
  end

  @spec failure(e) :: __MODULE__.t(v, e)
  def failure(error) do
    %__MODULE__{result: {:error, error}}
  end

  @spec map(__MODULE__.t(v, e), (v -> v1)) :: __MODULE__.t(v1, e)
  def map(either, f) do
    case either do
      %__MODULE__{result: {:ok,    value}} -> success(f.(value))
      %__MODULE__{result: {:error, error}} -> failure(error)
      _                                    -> raise_either_error("map", either)
    end
  end

  @spec map_error(__MODULE__.t(v, e), (e -> e1)) :: __MODULE__.t(v, e1)
  def map_error(either, f) do
    case either do
      %__MODULE__{result: {:error, error}} -> failure(f.(error))
      %__MODULE__{result: {:ok,    value}} -> success(value)
      _                                    -> raise_either_error("map_error", either)
    end
  end

  @spec on(__MODULE__.t(v, e), nonempty_list({:success, (v -> none())} | {:failure, (e -> none())})) :: __MODULE__.t(v, e)
  def on(either, options) do
    success_f = options[:success] || fn x -> x end
    failure_f = options[:failure] || fn x -> x end

    case either do
      %__MODULE__{result: {:error, error}} -> failure_f.(error)
      %__MODULE__{result: {:ok,    value}} -> success_f.(value)
      _                                    -> raise_either_error("on", either)
    end
    either
  end

  @spec then(__MODULE__.t(v, e), (v -> __MODULE__.t(v1, e1))) :: __MODULE__.t(v1, e1)
  def then(either, f) do
    case either do
      %__MODULE__{result: {:ok,    value}} ->
        case f.(value) do
          %__MODULE__{result: {:ok,    next_value}} -> success(next_value)
          %__MODULE__{result: {:error, error}}      -> failure(error)
          value                                     -> success(value)
        end
      %__MODULE__{result: {:error, error}} -> failure(error)
      _                                    -> raise_either_error("then", either)
    end
  end

  @spec catch_error(__MODULE__.t(v, e), (e -> __MODULE__.t(v1, e1))) :: __MODULE__.t(v1, e1)
  def catch_error(either, f) do
    case either do
      %__MODULE__{result: {:error, error}} ->
        case f.(error) do
          %__MODULE__{result: {:error, next_error}} -> failure(next_error)
          %__MODULE__{result: {:ok,    value}}      -> success(value)
          value                                     -> success(value)
        end
      %__MODULE__{result: {:ok,    value}} -> {:ok, value}
      _                                    -> raise_either_error("catch_error", either)
    end
  end

  @spec success_or_default(__MODULE__.t(v, e), v) :: v
  def success_or_default(either, default) do
    either |> from_either( [{:success, fn value -> value end}, {:failure, fn _     -> default end}] )
  end

  @spec merge_eithers([__MODULE__.t(v, e)],
          [{:strategy, :any_succeed_else_fail}]
          | [{:strategy, :success_or, default: v}]
          | [{:strategy, :all_succeed_else_fail}]
            | [{:strategy, :only_successes}]
        ) :: __MODULE__.t(v, e)
  def merge_eithers(eithers, options) do
    case options do
      [strategy: :any_succeed_else_fail]              -> eithers |> any_succeed_else_fail
      [strategy: :success_or, default: default_value] -> eithers |> all_succeed_using_default(default_value)
      [strategy: :all_succeed_else_fail]              -> eithers |> all_succeed_else_fail
      [strategy: :only_successes]                     -> eithers |> only_successes
    end
  end

  @spec from_either(__MODULE__.t(v, e), nonempty_list({:success, (v -> u)} | {:failure, (e -> u)})) :: u
  def from_either(either, options) do
    [success: get_f, failure: return_f] = options
    case either do
      %__MODULE__{result: {:ok,    value}} -> get_f.(value)
      %__MODULE__{result: {:error, error}} -> return_f.(error)
      _                                    -> raise_either_error("from_either", either)
    end
  end

  @spec try_catch((() -> v)) :: __MODULE__.t(v, e)
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
