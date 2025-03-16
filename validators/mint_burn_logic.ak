use aiken/builtin
use aiken/cbor
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash, blake2b_256}
use cardano/address.{Address, Credential, Script}
use cardano/assets.{PolicyId}
use cardano/certificate.{Certificate, RegisterCredential, UnregisterCredential}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction,
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

    // Find the output reference of the spent UTxO specified via the redeemer.
    expect Some(Input { output_reference: nonce, .. }) =
      inputs |> list.at(spent_utxo_input_index)

    // Find the produce output at `target_policy_id` script.
    expect Some(Output {
      address: Address { payment_credential: Script(output_script_hash), .. },
      value: output_value,
      datum: InlineDatum(output_datum_data),
      reference_script: None,
    }) = outputs |> list.at(output_index)

    // The specified output must go to the `target_policy_id` script address.
    // We're allowing the staking part of the address to be up to the `owner`.
    expect output_script_hash == target_policy_id

    // The output must only contain the minted NFT (apart from ADA).
    expect [Pair(output_nft_symbol, output_nft_tn_qty_pair)] =
      output_value |> assets.without_lovelace |> assets.to_dict |> dict.to_pairs
    expect [Pair(output_nft_name, _output_nft_quantity)] =
      output_nft_tn_qty_pair |> dict.to_pairs

    // To ensure uniqueness of the asset name, it has to be the hash of the
    // nonce.
    let asset_name = nonce |> cbor.serialise |> blake2b_256

    // Now that we have the name of this new NFT, we can validate that the
    // produced output contains it.
    expect and {
      output_nft_symbol == target_policy_id,
      output_nft_name == asset_name,
    }

    // There has to be a mint of this NFT with a quantity of 1. Note that with
    // this check, we won't need to check the quantity of the NFT in the output,
    // as anything other than 1 is impossible.
    expect 1 = mint |> assets.quantity_of(target_policy_id, asset_name)

    // Find the `owner` attached to the output UTxO.
    let owner: VerificationKeyHash = builtin.un_b_data(output_datum_data)

    // This specified `owner` must have signed this minting transaction.
    extra_signatories |> list.any(fn(vkey) -> Bool { owner == vkey })
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
