class Cookiemonster
  class Cryptor
    def initialize(datadb, keypair)
      @datadb = datadb
      @keypair = keypair
      unless keypair[:primitive] == Crypto::Box::PRIMITIVE
        raise ArgumentError, "keypair can only be a Crypto::Box.keypair"
      end
    end

    def []=(key, value)
      msgpack_value = value.to_msgpack
      nonce = Crypto::Box.nonce
      @keypair[:secret_key].readonly
      ciphertext = Crypto.box(msgpack_value, nonce, @keypair[:public_key], @keypair[:secret_key])
      hash = Crypto.generichash(key, Crypto::GenericHash::BYTES, @keypair[:secret_key])
      @datadb[hash] = {nonce: nonce, ciphertext: ciphertext}.to_msgpack
      self
    ensure
      Sodium.memzero(key, key.bytesize) if key
      Sodium.memzero(value, value.bytesize) if value.respond_to?(:bytesize)
      Sodium.memzero(msgpack_value, msgpack_value.bytesize) if msgpack_value
      @keypair[:secret_key].noaccess
    end

    def [](key)
      @keypair[:secret_key].readonly
      hash = Crypto.generichash(key, Crypto::GenericHash::BYTES, @keypair[:secret_key])
      unless ciphertext = @datadb[hash]
        return nil
      end
      ciphertext = MessagePack.unpack(ciphertext)
      value = Crypto::Box.open(ciphertext[:ciphertext], ciphertext[:nonce], @keypair[:public_key], @keypair[:secret_key])
      MessagePack.unpack(value, true)
    ensure
      Sodium.memzero(key, key.bytesize) if key
      @keypair[:secret_key].noaccess
      Sodium.memzero(value, value.bytesize) if value
    end
  end
end
