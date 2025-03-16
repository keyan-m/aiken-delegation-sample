use cardano/assets.{PolicyId}

pub type MintRedeemer {
  target_policy_id: PolicyId,
  spent_utxo_input_index: Int,
  output_index: Int,
}
