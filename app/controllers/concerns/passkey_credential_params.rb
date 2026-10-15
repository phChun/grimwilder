# The JSON a browser sends back from navigator.credentials.create/get, as
# serialized by passkey_controller.js (binary fields base64url-encoded).
module PasskeyCredentialParams
  extend ActiveSupport::Concern

  private
    def passkey_credential_params
      params.expect(credential: [
        :id, :rawId, :type, :authenticatorAttachment,
        response: [ :clientDataJSON, :attestationObject, :authenticatorData, :signature, :userHandle, transports: [] ],
        clientExtensionResults: {}
      ]).to_h
    end
end
