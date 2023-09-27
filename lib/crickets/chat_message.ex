defmodule Crickets.ChatMessage do

  @derive Jason.Encoder
  defstruct [
    from: String,
    to: String,
    message: String,
    at: DateTime
  ]
end
