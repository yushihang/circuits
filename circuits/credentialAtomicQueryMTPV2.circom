pragma circom 2.0.0;

include "offchain/credentialAtomicQueryMTPOffChain.circom";

/*
 public signals:
 userID - user profile id
 merklized - `1` if claim is merklized
*/
component main{public [requestID,
                       issuerID,
                       issuerClaimIdenState,
                       issuerClaimNonRevState,
                       claimSchema,
                       slotIndex,
                       claimPathKey,
                       claimPathNotExists,
                       operator,
                       value,
                       timestamp, isRevocationChecked]} = CredentialAtomicQueryMTPOffChain(6, 4, 8);
