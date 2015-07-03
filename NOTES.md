>> crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
>> encrypted_data = crypt.encrypt_and_sign('my confidental data')
>> decrypted_back = crypt.decrypt_and_verify(encrypted_data)
