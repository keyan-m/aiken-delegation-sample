use aiken/collection/dict.{Dict}
use aiken/collection/list
use aiken_design_patterns/tx_level_minter
use cardano/address.{Address, Credential, Script}
use cardano/assets.{AssetName}
use cardano/certificate.{Certificate, RegisterCredential, UnregisterCredential}
use cardano/transaction.{Input, Output, Transaction}
use utils/main
use utils/spend_logic.{SpendRedeemer}

validator mint_logic {
  withdraw(redeemer: SpendRedeemer, _account: Credential, tx: Transaction) {
    let SpendRedeemer { target_out_ref, input_index } = redeemer

    // Fetch own input and get access to its values.
    expect Some(Input {
      output_reference,
      output: Output {
        address: Address {
          payment_credential: Script(spending_script_hash),
          ..
        },
        ..
      },
    }) = tx.inputs |> list.at(input_index)

    // Validate correctness of the specified input index.
    expect output_reference == target_out_ref

    // Using the `tx-level-minter` design pattern to ensure the burning endpoint
    // of `spending_script_hash` is invoked. We're allowing multiple burns, but
    // no mints can occur simultaneously.
    tx_level_minter.spend(
      mint_script_hash: spending_script_hash,
      mint_redeemer_validator: fn(r: Data) -> Bool {
        expect coerced: main.MintRedeemer = r
        coerced == main.Burn
      },
      mint_tokens_validator: fn(name_quantity_pairs: Dict<AssetName, Int>) -> Bool {
        name_quantity_pairs
          |> dict.foldr(
              True,
              fn(_key: AssetName, quantity: Int, acc: Bool) {
                acc && quantity == -1
              },
            )
      },
      tx: tx,
    )
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
