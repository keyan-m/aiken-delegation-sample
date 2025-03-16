use aiken/builtin
use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken_design_patterns/merkelized_validator
use cardano/address.{Credential}
use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}

pub type MintRedeemer {
  Mint
  Burn { owner: VerificationKeyHash }
}

pub type SpendRedeemer {
  index: Int,
}

validator main(
  mint_logic_script_hash: ScriptHash,
  burn_logic_script_hash: ScriptHash,
) {
  mint(redeemer: MintRedeemer, own_policy_id: PolicyId, tx: Transaction) {
    when redeemer is {
      Mint ->
        merkelized_validator.generic_delegated_validation(
          staking_validator: mint_logic_script_hash,
          withdraw_redeemer_validator: fn(withdraw_redeemer: Data) -> Bool {
            let stakings_policy_id = builtin.un_b_data(withdraw_redeemer)
            stakings_policy_id == own_policy_id
          },
          redeemers: tx.redeemers,
        )
      Burn { owner } -> todo
    }
  }

  spend(
    m_datum: Option<VerificationKeyHash>,
    redeemer: SpendRedeemer,
    own_out_ref: OutputReference,
    tx: Transaction,
  ) {
    todo
  }

  else(_) {
    fail
  }
}
