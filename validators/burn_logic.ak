use cardano/address.{Credential}
use cardano/assets.{PolicyId}
use cardano/certificate.{Certificate}
use cardano/transaction.{OutputReference, Transaction}

validator burn_logic {
  withdraw(target_policy_id: PolicyId, _account: Credential, _self: Transaction) {
    todo @"withdraw logic goes here"
  }

  publish(_redeemer: Data, _certificate: Certificate, _self: Transaction) {
    todo @"publish logic goes here"
  }
}
