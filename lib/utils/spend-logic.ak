use cardano/transaction.{OutputReference}

pub type SpendRedeemer {
  target_out_ref: OutputReference,
  input_index: Int,
}
