use aiken/builtin
use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken_design_patterns/merkelized_validator
use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Redeemer, Transaction}
use utils/main.{Burn, Mint, MintRedeemer}

validator main_contract(
  mint_logic_script_hash: ScriptHash,
  burn_logic_script_hash: ScriptHash,
  spend_logic_script_hash: ScriptHash,
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
    _redeemer: Redeemer,
    own_out_ref: OutputReference,
    tx: Transaction,
  ) {
    merkelized_validator.generic_delegated_validation(
      staking_validator: spend_logic_script_hash,
      withdraw_redeemer_validator: fn(withdraw_redeemer: Data) -> Bool {
        expect [stakings_out_ref, ..] =
          builtin.unconstr_fields(withdraw_redeemer)
        let own_out_ref_data: Data = own_out_ref
        stakings_out_ref == own_out_ref_data
      },
      redeemers: tx.redeemers,
    )
  }

  else(_) {
    fail
  }
}
