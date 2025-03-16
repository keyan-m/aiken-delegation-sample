use cardano/certificate.{Certificate, RegisterCredential, UnregisterCredential}

// This is mostly boilerplate. Since we are delegating parts of the contract to
// staking scripts, we also need to allow their registrations in order to be
// able to use them. We're also freely allowing them to be unregistered here for
// simplicity.
//
// With observer scripts (CIP-112) we won't need this.
pub fn handle_publish(certificate: Certificate) -> Bool {
  when certificate is {
    RegisterCredential { .. } | UnregisterCredential { .. } -> True
    _ -> False
  }
}
