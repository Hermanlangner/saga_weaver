defmodule Sample.Sagas do
  @moduledoc """
  Application-owned SagaWeaver facade for the sample application.
  """

  use SagaWeaver, otp_app: :sample
end
