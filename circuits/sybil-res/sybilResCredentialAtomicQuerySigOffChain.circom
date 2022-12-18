pragma circom 2.0.0;

include "sybilUtils.circom";

template SybilResCredentialAtomicQuerySigOffChain(IssuerLevels, ClaimLevels, gistLevels) {
    
    /* userID ownership signals */
    signal input userGenesisID;
    signal input profileNonce; /* random number */
    signal input claimSubjectProfileNonce; // nonce of the profile that claim is issued to, 0 if claim is issued to genesisID

    signal input issuerID;

    // issuer auth proof of existence
    signal input issuerAuthClaim[8];
    signal input issuerAuthClaimMtp[IssuerLevels];
    signal input issuerAuthClaimsRoot;
    signal input issuerAuthRevRoot;
    signal input issuerAuthRootsRoot;
    signal output issuerAuthState;

    // issuer auth claim non rev proof
    signal input issuerAuthClaimNonRevMtp[IssuerLevels];
    signal input issuerAuthClaimNonRevMtpNoAux;
    signal input issuerAuthClaimNonRevMtpAuxHi;
    signal input issuerAuthClaimNonRevMtpAuxHv;

    // claim issued by issuer to the user
    signal input issuerClaim[8];
    // issuerClaim non rev inputs
    signal input issuerClaimNonRevMtp[IssuerLevels];
    signal input issuerClaimNonRevMtpNoAux;
    signal input issuerClaimNonRevMtpAuxHi;
    signal input issuerClaimNonRevMtpAuxHv;
    signal input issuerClaimNonRevClaimsRoot;
    signal input issuerClaimNonRevRevRoot;
    signal input issuerClaimNonRevRootsRoot;
    signal input issuerClaimNonRevState;

    // issuerClaim signature
    signal input issuerClaimSignatureR8x;
    signal input issuerClaimSignatureR8y;
    signal input issuerClaimSignatureS;

    /** Query */
    signal input claimSchema;

    signal input claimPathNotExists; // 0 for inclusion, 1 for non-inclusion
    signal input claimPathMtp[ClaimLevels];
    signal input claimPathMtpNoAux; // 1 if aux node is empty, 0 if non-empty or for inclusion proofs
    signal input claimPathMtpAuxHi; // 0 for inclusion proof
    signal input claimPathMtpAuxHv; // 0 for inclusion proof
    signal input claimPathKey; // hash of path in merklized json-ld document
    signal input claimPathValue; // value in this path in merklized json-ld document

  // claim of state secret stateSecret
    signal input holderClaim[8];
    signal input holderClaimMtp[holderLevels];
    signal input holderClaimClaimsRoot;
    signal input holderClaimRevRoot;
    signal input holderClaimRootsRoot;
    signal input holderClaimIdenState;
    
    signal input holderClaimSchema;

    // GIST and path to holderState
    signal input gist;
    signal input gistMtp[GistLevels];
    signal input idenGistState;

    signal input crs;

    signal input userGenesisID;
    signal input profileNonce;

    signal output sybilID;
    signal output userID;


    component verifyUniClaim = VerifyAndHashUniClaim(IssuerLevels);
    for (var i=0; i<8; i++) { verifyUniClaim.issuerAuthClaim[i] <== issuerClaim[i]; }
    for (var i=0; i<IssuerLevels; i++) { verifyUniClaim.issuerAuthClaimMtp[i] <== issuerAuthClaimMtp[i]; }
    verifyUniClaim.issuerAuthClaimsRoot <== issuerAuthClaimsRoot;
    verifyUniClaim.issuerAuthRevRoot <== issuerAuthRevRoot;
    verifyUniClaim.issuerAuthRootsRoot <== issuerAuthRootsRoot;
    verifyUniClaim.issuerAuthState <== issuerAuthState;

    for (var i=0; i<IssuerLevels; i++) { verifyUniClaim.issuerAuthClaimNonRevMtp[i] <== issuerAuthClaimNonRevMtp[i]; }
    verifyUniClaim.issuerAuthClaimNonRevMtpNoAux <== issuerAuthClaimNonRevMtpNoAux;
    verifyUniClaim.issuerAuthClaimNonRevMtpAuxHi <== issuerAuthClaimNonRevMtpAuxHi;
    verifyUniClaim.issuerAuthClaimNonRevMtpAuxHv <== issuerAuthClaimNonRevMtpAuxHv;

    for (var i=0; i<8; i++) { verifyUniClaim.issuerClaim[i] <== issuerClaim[i]; }

    for (var i=0; i<IssuerLevels; i++) { verifyUniClaim.issuerClaimNonRevMtp[i] <== issuerClaimNonRevMtp[i]; }
    verifyUniClaim.issuerClaimNonRevMtpNoAux <== issuerClaimNonRevMtpNoAux;
    verifyUniClaim.issuerClaimNonRevMtpAuxHi <== issuerClaimNonRevMtpAuxHi;
    verifyUniClaim.issuerClaimNonRevMtpAuxHv <== issuerClaimNonRevMtpAuxHv;
    verifyUniClaim.issuerClaimNonRevClaimsRoot <== issuerClaimNonRevClaimsRoot;
    verifyUniClaim.issuerClaimNonRevRevRoot <== issuerClaimNonRevRevRoot;
    verifyUniClaim.issuerClaimNonRevRootsRoot <== issuerClaimNonRevRootsRoot;
    verifyUniClaim.issuerClaimNonRevState <== issuerClaimNonRevState;

    verifyUniClaim.issuerClaimSignatureR8x <== issuerClaimSignatureR8x;
    verifyUniClaim.issuerClaimSignatureR8y <== issuerClaimSignatureR8y;
    verifyUniClaim.issuerClaimSignatureS <== issuerClaimSignatureS;

    verifyUniClaim.hash ==> uniClaimHash;


    component verifyStateSecret = VerifyAndExtractValStateSecret()
    for (var i=0; i<8; i++) { verifyStateSecret.claim[i] <== holderClaim[i]; }
    for (var i=0; i<holderLevels; i++) { verifyStateSecret.claimMtp[i] <== holderClaimMtp[i]; }
    verifyStateSecret.claimIssuanceClaimsRoot <== holderClaimClaimsRoot;
    verifyStateSecret.claimIssuanceRevRoot <== holderClaimRevRoot;
    verifyStateSecret.claimIssuanceRootsRoot <== holderClaimRootsRoot;
    verifyStateSecret.claimIssuanceIdenState <== holderClaimIdenState;

    verifyStateSecret.claimSchema <== holderClaimSchema;

    for (var i=0; i<gistLevels; i++) { verifyStateSecret.idenGistMtp[i] <== idenGistMtp[i]; }
    for (var i=0; i<8; i++) { verifyStateSecret.idenGistState[i] <== idenGistState[i]; }                // double check this declration 
    verifyStateSecret.gist <== gist;

    verifyStateSecret.secret ==> secret;
    // 3. Compute profile.
    component selectProfile = SelectProfile();
    selectProfile.in <== userGenesisID;
    selectProfile.nonce <== profileNonce;
    userId <== selectProfile.out;

    // 4. Compute sybil
    component computeSybilID = ComputeSybilID();
    computeSybilID.crs <== crs;
    computeSybilID.stateSecret <== secret;
    computeSybilID.claimHash <== uniClaimHash;
    sybilId <== computeSybilID,out;
}







    // 1. Verify uniClaim - 
    //      A. Verify issued and not revoked
    //      B. Verify claim schema
    //      C. Verify claim index check
    //      D. Verify Issued to provided identity
    //      E. Return hash of claim
template VerifyAndHashUniClaim(IssuerLevels){
    signal input issuerAuthClaim[8];
    signal input issuerAuthClaimMtp[IssuerLevels];
    signal input issuerAuthClaimsRoot;
    signal input issuerAuthRevRoot;
    signal input issuerAuthRootsRoot;
    signal output issuerAuthState;

    // issuer auth claim non rev proof
    signal input issuerAuthClaimNonRevMtp[IssuerLevels];
    signal input issuerAuthClaimNonRevMtpNoAux;
    signal input issuerAuthClaimNonRevMtpAuxHi;
    signal input issuerAuthClaimNonRevMtpAuxHv;

    // claim issued by issuer to the user
    signal input issuerClaim[8];
    // issuerClaim non rev inputs
    signal input issuerClaimNonRevMtp[IssuerLevels];
    signal input issuerClaimNonRevMtpNoAux;
    signal input issuerClaimNonRevMtpAuxHi;
    signal input issuerClaimNonRevMtpAuxHv;
    signal input issuerClaimNonRevClaimsRoot;
    signal input issuerClaimNonRevRevRoot;
    signal input issuerClaimNonRevRootsRoot;
    signal input issuerClaimNonRevState;

    // issuerClaim signature
    signal input issuerClaimSignatureR8x;
    signal input issuerClaimSignatureR8y;
    signal input issuerClaimSignatureS;

    signal output claimHash;

    //  A. Verify issued and not revoked
    var AUTH_SCHEMA_HASH  = 301485908906857522017021291028488077057;
    component issuerSchemaCheck = verifyCredentialSchema();
    for (var i=0; i<8; i++) { issuerSchemaCheck.claim[i] <== issuerAuthClaim[i]; }
    issuerSchemaCheck.schema <== AUTH_SCHEMA_HASH;
    // verify authClaim issued and not revoked
    // calculate issuerAuthState
    component issuerAuthStateComponent = getIdenState();
    issuerAuthStateComponent.claimsTreeRoot <== issuerAuthClaimsRoot;
    issuerAuthStateComponent.revTreeRoot <== issuerAuthRevRoot;
    issuerAuthStateComponent.rootsTreeRoot <== issuerAuthRootsRoot;

    issuerAuthState <== issuerAuthStateComponent.idenState;

    // issuerAuthClaim proof of existence (isProofExist)
    component smtIssuerAuthClaimExists = checkClaimExists(IssuerLevels);
    for (var i=0; i<8; i++) { smtIssuerAuthClaimExists.claim[i] <== issuerAuthClaim[i]; }
    for (var i=0; i<IssuerLevels; i++) { smtIssuerAuthClaimExists.claimMTP[i] <== issuerAuthClaimMtp[i]; }
    smtIssuerAuthClaimExists.treeRoot <== issuerAuthClaimsRoot;

    component verifyIssuerAuthClaimNotRevoked = checkClaimNotRevoked(IssuerLevels);
    for (var i=0; i<8; i++) { verifyIssuerAuthClaimNotRevoked.claim[i] <== issuerAuthClaim[i]; }
    for (var i=0; i<IssuerLevels; i++) {
        verifyIssuerAuthClaimNotRevoked.claimNonRevMTP[i] <== issuerAuthClaimNonRevMtp[i];
    }
    verifyIssuerAuthClaimNotRevoked.noAux <== issuerAuthClaimNonRevMtpNoAux;
    verifyIssuerAuthClaimNotRevoked.auxHi <== issuerAuthClaimNonRevMtpAuxHi;
    verifyIssuerAuthClaimNotRevoked.auxHv <== issuerAuthClaimNonRevMtpAuxHv;
    verifyIssuerAuthClaimNotRevoked.treeRoot <== issuerClaimNonRevRevTreeRoot;

    component issuerAuthPubKey = getPubKeyFromClaim();
    for (var i=0; i<8; i++){ issuerAuthPubKey.claim[i] <== issuerAuthClaim[i]; }

    // issuerClaim  check signature
    component verifyClaimSig = verifyClaimSignature();
    for (var i=0; i<8; i++) { verifyClaimSig.claim[i] <== issuerClaim[i]; }
    verifyClaimSig.sigR8x <== issuerClaimSignatureR8x;
    verifyClaimSig.sigR8y <== issuerClaimSignatureR8y;
    verifyClaimSig.sigS <== issuerClaimSignatureS;
    verifyClaimSig.pubKeyX <== issuerAuthPubKey.Ax;
    verifyClaimSig.pubKeyY <== issuerAuthPubKey.Ay;

    // verify issuer state includes issuerClaim
    component verifyClaimIssuanceIdenState = checkIdenStateMatchesRoots();
    verifyClaimIssuanceIdenState.claimsTreeRoot <== issuerClaimNonRevClaimsRoot;
    verifyClaimIssuanceIdenState.revTreeRoot <== issuerClaimNonRevRevRoot;
    verifyClaimIssuanceIdenState.rootsTreeRoot <== issuerClaimNonRevRootsRoot;
    verifyClaimIssuanceIdenState.expectedState <== issuerClaimNonRevState;

    // non revocation status
    component verifyClaimNotRevoked = checkClaimNotRevoked(IssuerLevels);
    for (var i=0; i<8; i++) { verifyClaimNotRevoked.claim[i] <== issuerClaim[i]; }
    for (var i=0; i<IssuerLevels; i++) {
        verifyClaimNotRevoked.claimNonRevMTP[i] <== issuerClaimNonRevMtp[i];
    }
    verifyClaimNotRevoked.noAux <== issuerClaimNonRevMtpNoAux;
    verifyClaimNotRevoked.auxHi <== issuerClaimNonRevMtpAuxHi;
    verifyClaimNotRevoked.auxHv <== issuerClaimNonRevMtpAuxHv;
    verifyClaimNotRevoked.treeRoot <== issuerClaimNonRevRevTreeRoot;


    component smtIssuerAuthClaimExists = checkClaimExists(IssuerLevels);   
    for (var i=0; i<8; i++) { smtIssuerAuthClaimExists.claim[i] <== issuerAuthClaim[i]; }
    for (var i=0; i<IssuerLevels; i++) { smtIssuerAuthClaimExists.claimMTP[i] <== issuerAuthClaimMtp[i]; }
    smtIssuerAuthClaimExists.treeRoot <== issuerAuthClaimsRoot;

    component verifyIssuerAuthClaimNotRevoked = checkClaimNotRevoked(IssuerLevels);
    for (var i=0; i<8; i++) { verifyIssuerAuthClaimNotRevoked.claim[i] <== issuerAuthClaim[i]; }
    for (var i=0; i<IssuerLevels; i++) {
        verifyIssuerAuthClaimNotRevoked.claimNonRevMTP[i] <== issuerAuthClaimNonRevMtp[i];
    }
    verifyIssuerAuthClaimNotRevoked.noAux <== issuerAuthClaimNonRevMtpNoAux;
    verifyIssuerAuthClaimNotRevoked.auxHi <== issuerAuthClaimNonRevMtpAuxHi;
    verifyIssuerAuthClaimNotRevoked.auxHv <== issuerAuthClaimNonRevMtpAuxHv;
    verifyIssuerAuthClaimNotRevoked.treeRoot <== issuerClaimNonRevRevTreeRoot;

    //      B. Verify claim schema
    component claimSchemaCheck = verifyCredentialSchema();
    for (var i=0; i<8; i++) { claimSchemaCheck.claim[i] <== issuerClaim[i]; }
    claimSchemaCheck.schema <== claimSchema;

    //      C. Verify Issued to provided identity
    component claimIdCheck = verifyCredentialSubjectProfile();
    for (var i=0; i<8; i++) { claimIdCheck.claim[i] <== issuerClaim[i]; }
    claimIdCheck.id <== userGenesisID;
    claimIdCheck.nonce <== claimSubjectProfileNonce;

    //      D. Return hash of claim
    component hasher = getClaimHash()
    hasher.claim <== issuerClaim;
    claimHash <== hasher.hash;
}