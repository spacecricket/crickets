defmodule Crickets.ChatMessage do
  @derive Jason.Encoder
  defstruct [from: String, message: String, at: DateTime]
end
