defmodule Pgvector.Extensions.Vector do
  import Postgrex.BinaryUtils, warn: false

  def init(opts), do: Keyword.get(opts, :decode_binary, :copy)

  def matching(_), do: [type: "vector"]

  def format(_), do: :binary

  def encode(_) do
    quote do
      vec ->
        data = unquote(__MODULE__).encode_vector(vec)
        [<<IO.iodata_length(data)::int32()>> | data]
    end
  end

  def decode(_) do
    quote do
      <<len::int32(), data::binary-size(len)>> ->
        unquote(__MODULE__).decode_vector(data)
    end
  end

  def encode_vector(vec) when is_list(vec) do
    dim = length(vec)
    bin = Enum.map(vec, fn v -> <<v::float32>> end)
    [<<dim::uint16>>, <<0::uint16>> | bin]
  end

  if Code.ensure_loaded?(Nx) do
    # TODO encode directly
    def encode_vector(t) when is_struct(t, Nx.Tensor) do
      if Nx.rank(t) != 1 do
        raise ArgumentError, "expected rank to be 1"
      end
      encode_vector(t |> Nx.to_list())
    end
  end

  def decode_vector(<<dim::uint16, 0::uint16, bin::binary-size(dim)-unit(32)>>) do
    for <<v::float32 <- bin>>, do: v
  end
end
