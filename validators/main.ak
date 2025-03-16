use aiken/builtin
use aiken/collection/dict.{Dict}
use aiken/collection/list
use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken_design_patterns/merkelized_validator
use aiken_design_patterns/tx_level_minter
use cardano/address.{Address, Script}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{Input, Output, OutputReference, Transaction}

pub type MintRedeemer {
  Mint
  Burn
}

pub type SpendRedeemer {
  own_index: Int,
}

validator main(
  mint_logic_script_hash: ScriptHash,
  burn_logic_script_hash: ScriptHash,
) {
  mint(redeemer: MintRedeemer, own_policy_id: PolicyId, tx: Transaction) {
    when redeemer is {
      Mint ->
        // Since the structure of the staking script's redeemer is of no
        // importance, we can use the generic variant of the Merkelized
        // validator to "unsafely" extract the first value of its redeemer.
        // We know this value is supposed to be a policy ID, and that it must be
        // equal to this script's hash, which gives the staking script access to
        // the policy ID (i.e. scrip hash) of this validator.
        merkelized_validator.generic_delegated_validation(
          staking_validator: mint_logic_script_hash,
          withdraw_redeemer_validator: fn(withdraw_redeemer: Data) -> Bool {
            expect [stakings_policy_id, ..] =
              builtin.unconstr_fields(withdraw_redeemer)
            builtin.un_b_data(stakings_policy_id) == own_policy_id
          },
          redeemers: tx.redeemers,
        )
      Burn ->
        // This is identical to the minting endpoint, only the target script
        // hash is different.
        merkelized_validator.generic_delegated_validation(
          staking_validator: burn_logic_script_hash,
          withdraw_redeemer_validator: fn(withdraw_redeemer: Data) -> Bool {
            expect [stakings_policy_id, ..] =
              builtin.unconstr_fields(withdraw_redeemer)
            builtin.un_b_data(stakings_policy_id) == own_policy_id
          },
          redeemers: tx.redeemers,
        )
    }
  }

  spend(
    _m_datum: Option<VerificationKeyHash>,
    redeemer: SpendRedeemer,
    own_out_ref: OutputReference,
    tx: Transaction,
  ) {
    let SpendRedeemer { own_index } = redeemer

    // Fetch own input and get access to its values.
    expect Some(Input {
      output_reference,
      output: Output {
        address: Address { payment_credential: Script(own_script_hash), .. },
        ..
      },
    }) = tx.inputs |> list.at(own_index)

    // Validate correctness of the specified input index.
    expect output_reference == own_out_ref

    // Using the `tx-level-minter` design pattern to ensure the burning endpoint
    // of this script is invoked. We're allowing multiple burns, but no mints
    // can occur simultaneously.
    tx_level_minter.spend(
      mint_script_hash: own_script_hash,
      mint_redeemer_validator: fn(r: Data) -> Bool {
        expect coerced: MintRedeemer = r
        coerced == Burn
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

  else(_) {
    fail
  }
}
