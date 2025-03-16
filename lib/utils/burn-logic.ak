use cardano/assets.{PolicyId}

pub type BurnRedeemer {
  target_policy_id: PolicyId,
  input_index: Int,
}
