use aiken/builtin
use aiken/cbor
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash, blake2b_256}
use cardano/address.{Address, Credential, Script}
use cardano/assets.{PolicyId}
use cardano/certificate.{Certificate, RegisterCredential, UnregisterCredential}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

pub type MintRedeemer {
  target_policy_id: PolicyId,
  spent_utxo_input_index: Int,
  output_index: Int,
}

pub type BurnRedeemer {
  target_policy_id: PolicyId,
  spent_utxo_input_index: Int,
  output_index: Int,
}

validator mint_logic {
  withdraw(redeemer: MintRedeemer, _account: Credential, tx: Transaction) {
    let Transaction { inputs, outputs, mint, extra_signatories, .. } = tx
    let MintRedeemer { target_policy_id, spent_utxo_input_index, output_index } =
      redeemer
    expect Some(Input { output_reference: nonce, .. }) =
      inputs |> list.at(spent_utxo_input_index)
    expect Some(Output {
      address: Address { payment_credential: Script(output_script_hash), .. },
      value: output_value,
      datum: InlineDatum(output_datum_data),
      reference_script: None,
    }) = outputs |> list.at(output_index)
    let owner: PolicyId = builtin.un_b_data(output_datum_data)
    expect extra_signatories |> list.any(fn(vkey) -> Bool { owner == vkey })
    let asset_name = nonce |> cbor.serialise |> blake2b_256
    let mint_quantity = mint |> assets.quantity_of(target_policy_id, asset_name)
    mint_quantity == 1
  }

  // This is boilerplate for the most part. Since we are defining this part of
  // the logic in a staking script, we also need to allow its registration in
  // order to be able to use it. We're also freely allowing its unregistration
  // here for simplicity.
  //
  // With observer scripts (CIP-112) we won't need this.
  publish(_redeemer: Data, certificate: Certificate, _self: Transaction) {
    when certificate is {
      RegisterCredential { .. } | UnregisterCredential { .. } -> True
      _ -> False
    }
  }

  else(_) {
    fail
  }
}

validator burn_logic {
  withdraw(redeemer: BurnRedeemer, _account: Credential, tx: Transaction) {
    todo
  }

  publish(_redeemer: Data, certificate: Certificate, _self: Transaction) {
    when certificate is {
      RegisterCredential { .. } | UnregisterCredential { .. } -> True
      _ -> False
    }
  }

  else(_) {
    fail
  }
}
