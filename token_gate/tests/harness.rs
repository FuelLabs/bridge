use fuels::{prelude::*, tx::ContractId};

abigen!(TokenGate, "out/debug/token_gate-abi.json");

pub async fn setup() -> (TokenGate, ContractId) {
    // Launch a local network and deploy the contract
    let wallet = launch_provider_and_get_single_wallet().await;
    let id = Contract::deploy(
        "./out/debug/token_gate.bin",
        &wallet,
        TxParameters::default(),
    )
    .await
    .unwrap();
    let instance = TokenGate::new(id.to_string(), wallet);

    (instance, id)
}

mod token {
    use super::*;

    mod successes {
        use super::*;

        #[tokio::test]
        async fn can_get_token_name() {
            let (instance, _id) = setup().await;
            let call_response = instance.name().call().await.unwrap();

            assert_eq!(call_response.value, "PLACEHOLDER");
        }

        #[tokio::test]
        async fn can_get_token_symbol() {
            let (instance, _id) = setup().await;
            let call_response = instance.symbol().call().await.unwrap();

            assert_eq!(call_response.value, "PLACEHOLDER");
        }

        #[tokio::test]
        async fn can_get_token_decimals() {
            let (instance, _id) = setup().await;
            let call_response = instance.decimals().call().await.unwrap();

            assert_eq!(call_response.value, 18);
        }
    }

    mod failures {
        #[tokio::test]
        #[ignore]
        async fn fails_to_reinitialize() {}
    }
}

mod gateway {
    use super::*;

    mod successes {
        use super::*;

        #[tokio::test]
        async fn can_get_layer_1_token() {
            let (instance, _id) = setup().await;
            let call_response = instance.layer1_token().call().await.unwrap();
            let dummy_layer_1_token = Address::from([0u8; 32]);
            assert_eq!(call_response.value, dummy_layer_1_token);
        }

        #[tokio::test]
        async fn can_get_layer_1_decimals() {
            let (instance, _id) = setup().await;
            let call_response = instance.layer1_decimals().call().await.unwrap();

            assert_eq!(call_response.value, 18u8);
        }
    }
}
