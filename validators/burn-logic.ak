use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address, Credential, Script}
use cardano/assets
use cardano/certificate.{Certificate}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use utils/burn_logic.{BurnRedeemer}
use utils/common

validator main {
  withdraw(redeemer: BurnRedeemer, _account: Credential, tx: Transaction) {
    let Transaction { inputs, mint, extra_signatories, .. } = tx

    let BurnRedeemer { target_policy_id, input_index } = redeemer

    // Find the input UTxO specified via the redeemer.
    expect Some(Input {
      output: Output {
        address: Address { payment_credential: Script(input_script_hash), .. },
        value: input_value,
        datum: InlineDatum(input_datum_data),
        ..
      },
      ..
    }) = inputs |> list.at(input_index)

    // This input must be coming from the `target_policy_id` script address.
    expect input_script_hash == target_policy_id

    // Apart from ADA, it is expected the UTxO contains only the NFT being
    // burnt.
    expect [Pair(input_nft_symbol, input_nft_tn_qty_pair)] =
      input_value |> assets.without_lovelace |> assets.to_dict |> dict.to_pairs
    expect [Pair(input_nft_name, _input_nft_quantity)] =
      input_nft_tn_qty_pair |> dict.to_pairs

    // Again, no need to validate the quantity of the NFT in input UTxO, as any
    // value other than 1 is not possible.
    expect and {
        input_nft_symbol == target_policy_id,
        -1 == ( mint |> assets.quantity_of(target_policy_id, input_nft_name) ),
      }

    // Extract the owner public key hash from the input datum.
    let owner: VerificationKeyHash = builtin.un_b_data(input_datum_data)

    // This `owner` must have signed the transaction.
    extra_signatories |> list.any(fn(vkey) -> Bool { owner == vkey })
  }

  publish(_redeemer: Data, certificate: Certificate, _self: Transaction) {
    common.handle_publish(certificate)
  }

  else(_) {
    fail
  }
}
