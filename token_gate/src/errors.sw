library errors;

pub enum TokenGatewayError {
    CannotReinitialize: (),
    ContractNotInitialized: (),
    IncorrectAssetAmount: (),
    IncorrectAssetDeposited: (),
    UnauthorizedUser: (),
    NoCoinsForwarded: (),
    IncorrectMessageOwner: (),
}
