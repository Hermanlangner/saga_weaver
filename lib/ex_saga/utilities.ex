## I hate utils modules, I will move this out asap
defmodule ExSaga.Utilities do
  def md5_hash(input_string) do
    :crypto.hash(:sha256, input_string)
    |> Base.encode16(case: :lower)
  end
end
