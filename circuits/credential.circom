/*
# credential.circom

Circuit to check that the prover have received a claim from an issuer.
The circuit checks:
- idOwnersip: prover is the owner of the identity (knows the private key inside a claim inside the MerkleTree)
- the claim subject == prover identity
- the claim exists in the MerkleTree of the issuer
- the proof is valid (and not revoked) for the given issuer-id-state

*/

pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/smt/smtverifier.circom";
include "./idOwnershipGenesis.circom";

// getClaimSubjectOtherIden checks that a claim Subject is OtherIden and
// outputs the identity within.  Parameter index is bool:  0 if SubjectPos is
// Index, 1 if SubjectPos is Value.
template getClaimSubjectOtherIden(index) {
	signal input claim[8];
	signal input claimFlags[32]; // claimFlags must be parsed from the claim

	signal output id;

	// Assert that claim subject is OtherIden
	// flags[0:2] == [0, 1]: Subject == OtherIden
	claimFlags[0] === 0;
	claimFlags[1] === 1;
	// flags[2] == 0 / 1: SubjectPos == Index / Value
	claimFlags[2] === index;

	if (index == 0) {
		id <== claim[0*4 + 1];
	} else {
		id <== claim[1*4 + 1];
	}
}

// getClaimHeader gets the header of a claim, outputing the claimType as an
// integer and the claimFlags as a bit array.
template getClaimHeader() {
	signal input claim[8];

	signal output claimType;
	signal output claimFlags[32];

 	component i0Bits = Num2Bits(256);
	i0Bits.in <== claim[0*4 + 0];

	component claimTypeNum = Bits2Num(64);

	for (var i=0; i<64; i++) {
		claimTypeNum.in[i] <== i0Bits.out[i];
	}
	claimType <== claimTypeNum.out;

	for (var i=0; i<32; i++) {
		claimFlags[i] <== i0Bits.out[64 + i];
	}
}

// getClaimSchema gets the schema of a claim
template getClaimSchema() {
	signal input claim[8];

	signal output schema;

 	component i0Bits = Num2Bits(256);
	i0Bits.in <== claim[0*4 + 0];

	component schemaNum = Bits2Num(64);

	for (var i=0; i<64; i++) {
		schemaNum.in[i] <== i0Bits.out[i];
	}
	schema <== schemaNum.out;
}

// getClaimRevNonce gets the revocation nonce out of a claim outputing it as an integer.
template getClaimRevNonce() {
	signal input claim[8];

	signal output revNonce;

	component claimRevNonce = Bits2Num(32);

 	component v0Bits = Num2Bits(256);
	v0Bits.in <== claim[1*4 + 0];
	for (var i=0; i<32; i++) {
		claimRevNonce.in[i] <== v0Bits.out[i];
	}
	revNonce <== claimRevNonce.out;
}

//  getClaimHiHv calculates the hashes Hi and Hv of a claim (to be used as
//  key,value in an SMT).
template getClaimHiHv() {
	signal input claim[8];

	signal output hi;
	signal output hv;

	component hashHi = Poseidon(4);
	for (var i=0; i<4; i++) {
		hashHi.inputs[i] <== claim[0*4 + i];
	}
	hi <== hashHi.out;

	component hashHv = Poseidon(4);
	for (var i=0; i<4; i++) {
		hashHv.inputs[i] <== claim[1*4 + i];
	}
	hv <== hashHv.out;
}

//  getClaimHash calculates the hash a claim
template getClaimHash() {
	signal input claim[8];
	signal output hash;

    component hihv = getClaimHiHv();
	for (var i=0; i<8; i++) {
		hihv.claim[i] <== claim[i];
	}

	component hashAll = Poseidon(2);
	hashAll.inputs[0] <== hihv.hi;
	hashAll.inputs[1] <== hihv.hv;
	hash <== hashAll.out;
}

// getIdenState caclulates the Identity state out of the claims tree root,
// revocations tree root and roots tree root.
template getIdenState() {
	signal input claimsTreeRoot;
	signal input revTreeRoot;
	signal input rootsTreeRoot;

	signal output idenState;

	component calcIdState = Poseidon(3);
	calcIdState.inputs[0] <== claimsTreeRoot;
	calcIdState.inputs[1] <== revTreeRoot;
	calcIdState.inputs[2] <== rootsTreeRoot;

	idenState <== calcIdState.out;
}

// getRevNonceNoVerHiHv calculates the hashes Hi and Hv of the leaf used in the
// revocations tree, out of a revocation nonce, to be used as key, value in an
// SMT.
template getRevNonceNoVerHiHv() {
	signal input revNonce;
	// signal input version;

	signal output hi;
	signal output hv;

	component hashHi = Poseidon(6);
	hashHi.inputs[0] <== revNonce;
	for (var i=1; i<6; i++) {
		hashHi.inputs[i] <== 0;
	}
	hi <== hashHi.out;

	component hashHv = Poseidon(6);
	hashHv.inputs[0] <== 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
	for (var i=1; i<6; i++) {
		hashHv.inputs[i] <== 0;
	}
	hv <== hashHv.out;

	// hv = Poseidon([0xffff_ffff, 0, 0, 0, 0)
	//hv <== Poseidon([0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0, 0, 0, 0, 0])
	//hv <== 17142353815121200339963760108352696118925531835836661574604762966243856573359;
	//hv <== 8137207316649344643315856769015464323293372071975540252804619894838929375565; // new from go
}

// getRootHiHv calculates the hashes Hi and Hv of the leaf used in the roots
// tree, out of a root, to be used as a key, value in an SMT.
template getRootHiHv() {
	signal input root;

	signal output hi;
	signal output hv;

	component hashHi = Poseidon(6);
	hashHi.inputs[0] <== root;
	for (var i=1; i<6; i++) {
		hashHi.inputs[i] <== 0;
	}
	hi <== hashHi.out;

	component hashHv = Poseidon(6);
	for (var i=0; i<6; i++) {
		hashHv.inputs[i] <== 0;
	}
	hv <== hashHv.out;

	//hv <== Poseidon([0, 0, 0, 0, 0, 0])
	//hv <== 951383894958571821976060584138905353883650994872035011055912076785884444545;
	//hv <== 14408838593220040598588012778523101864903887657864399481915450526643617223637; // new from go
}


// proveCredentialOwnership proves ownership of an identity (found in `claim[1]`) which
// is contained in a claim (`claim`) issued by an identity that has a recent
// identity state (`isIdenState`), while proving that the claim has not been
// revoked as of the recent identity state.
template proveCredentialOwnership(IdOwnershipLevels, IssuerLevels) {
	// A
	signal input claim[8];

	// B. holder proof of claimKOp in the genesis
	signal input hoKOpSk;
	signal input hoClaimKOpMtp[IdOwnershipLevels];
	signal input hoClaimKOpClaimsTreeRoot;
	// signal input hoClaimKOpRevTreeRoot;
	// signal input hoClaimKOpRootsTreeRoot;

	// C. issuer proof of claim existence
	signal input isProofExistMtp[IssuerLevels];
	signal input isProofExistClaimsTreeRoot;
	// signal input isProofExistRevTreeRoot;
	// signal input isProofExistRootsTreeRoot;

	// D. issuer proof of claim validity
	signal input isProofValidNotRevMtp[IssuerLevels];
	signal input isProofValidNotRevMtpNoAux;
	signal input isProofValidNotRevMtpAuxHi;
	signal input isProofValidNotRevMtpAuxHv;
	signal input isProofValidClaimsTreeRoot;
	signal input isProofValidRevTreeRoot;
	signal input isProofValidRootsTreeRoot;

	// E. issuer proof of Root (ExistClaimsTreeRoot)
	signal input isProofRootMtp[IssuerLevels];

	// F. issuer recent idenState
	signal input isIdenState;

	//
	// A. Prove that the claim has subject OtherIden, and take the subject identity.
	//
	component header = getClaimHeader();
	for (var i=0; i<8; i++) { header.claim[i] <== claim[i]; }
	// out: header.claimType
	// out: header.claimFlags[32]

	component subjectOtherIden = getClaimSubjectOtherIden(0);
	for (var i=0; i<8; i++) { subjectOtherIden.claim[i] <== claim[i]; }
	for (var i=0; i<32; i++) { subjectOtherIden.claimFlags[i] <== header.claimFlags[i]; }
	// out: subjectOtherIden.id

	component claimRevNonce = getClaimRevNonce();
	for (var i=0; i<8; i++) { claimRevNonce.claim[i] <== claim[i]; }
	// out: claimRevNonce.revNonce

	component claimHiHv = getClaimHiHv();
	for (var i=0; i<8; i++) { claimHiHv.claim[i] <== claim[i]; }
	// out: claimHiHv.hi
	// out: claimHiHv.hv

	//
	// B. Prove ownership of the kOpSk associated with the holder identity
	//
	component idOwnership = IdOwnershipGenesis(IdOwnershipLevels);
	idOwnership.id <== subjectOtherIden.id;
	idOwnership.userPrivateKey <== hoKOpSk;
	for (var i=0; i<IdOwnershipLevels; i++) { idOwnership.siblings[i] <== hoClaimKOpMtp[i]; }
	idOwnership.claimsTreeRoot <== hoClaimKOpClaimsTreeRoot;
	// idOwnership.revTreeRoot    <== hoClaimKOpRevTreeRoot;
	// idOwnership.rootsTreeRoot  <== hoClaimKOpRootsTreeRoot;

	//
	// C. Claim proof of existence (isProofExist)
	//
	component smtClaimExists = SMTVerifier(IssuerLevels);
	smtClaimExists.enabled <== 1;
	smtClaimExists.fnc <== 0; // Inclusion
	smtClaimExists.root <== isProofExistClaimsTreeRoot;
	for (var i=0; i<IssuerLevels; i++) { smtClaimExists.siblings[i] <== isProofExistMtp[i]; }
	smtClaimExists.oldKey <== 0;
	smtClaimExists.oldValue <== 0;
	smtClaimExists.isOld0 <== 0;
	smtClaimExists.key <== claimHiHv.hi;
	smtClaimExists.value <== claimHiHv.hv;

	// component isProofExistIdenState = getIdenState();
	// isProofExistIdenState.claimsTreeRoot <== isProofExistClaimsTreeRoot;
	// isProofExistIdenState.revTreeRoot <== isProofExistRevTreeRoot;
	// isProofExistIdenState.rootsTreeRoot <== isProofExistRootsTreeRoot;
	// out: isProofExistIdenState.idenState

	//
	// D. Claim proof of non revocation (validity)
	//
	component revNonceHiHv = getRevNonceNoVerHiHv();
	revNonceHiHv.revNonce <== claimRevNonce.revNonce;

	component smtClaimValid = SMTVerifier(IssuerLevels);
	smtClaimValid.enabled <== 1;
	smtClaimValid.fnc <== 1; // Non-inclusion
	smtClaimValid.root <== isProofValidRevTreeRoot;
	for (var i=0; i<IssuerLevels; i++) { smtClaimValid.siblings[i] <== isProofValidNotRevMtp[i]; }
	smtClaimValid.oldKey <== isProofValidNotRevMtpAuxHi;
	smtClaimValid.oldValue <== isProofValidNotRevMtpAuxHv;
	smtClaimValid.isOld0 <== isProofValidNotRevMtpNoAux;
	smtClaimValid.key <== revNonceHiHv.hi;
	smtClaimValid.value <== 0;


	//
	// E. Claim proof of root
	//
	component rootHiHv = getRootHiHv();
	rootHiHv.root <== isProofExistClaimsTreeRoot;

	component smtRootValid = SMTVerifier(IssuerLevels);
	smtRootValid.enabled <== 1;
	smtRootValid.fnc <== 0; // Inclusion
	smtRootValid.root <== isProofValidRootsTreeRoot;
	for (var i=0; i<IssuerLevels; i++) { smtRootValid.siblings[i] <== isProofRootMtp[i]; }
	smtRootValid.oldKey <== 0;
	smtRootValid.oldValue <== 0;
	smtRootValid.isOld0 <== 0;
	smtRootValid.key <== rootHiHv.hi;
	smtRootValid.value <== rootHiHv.hv;

	//
	// F. Verify ValidIdenState == isIdenState
	//
	component isProofValidIdenState = getIdenState();
	isProofValidIdenState.claimsTreeRoot <== isProofValidClaimsTreeRoot;
	isProofValidIdenState.revTreeRoot <== isProofValidRevTreeRoot;
	isProofValidIdenState.rootsTreeRoot <== isProofValidRootsTreeRoot;
	// out: isProofValidIdenState.idenState

	isProofValidIdenState.idenState === isIdenState;
}






// verifyCredentialSubject verifies that claim is issued to a specified identity
template verifyCredentialSubject() {
	signal input claim[8];
	signal input id;

	//
	// A. Prove that the claim has subject OtherIden, and take the subject identity.
	//
	component header = getClaimHeader();
	for (var i=0; i<8; i++) { header.claim[i] <== claim[i]; }
	// out: header.claimType
	// out: header.claimFlags[32]

    // TODO: add reading SubjectPos from claim (0 = index, 1 = value) and providing it to the following component
	component subjectOtherIden = getClaimSubjectOtherIden(0);
	for (var i=0; i<8; i++) { subjectOtherIden.claim[i] <== claim[i]; }
	for (var i=0; i<32; i++) { subjectOtherIden.claimFlags[i] <== header.claimFlags[i]; }
	// out: subjectOtherIden.id

    subjectOtherIden.id === id;
}

// verifyCredentialSchema verifies that claim matches provided schema
template verifyCredentialSchema() {
	signal input claim[8];
	signal input schema;

	component claimSchema = getClaimSchema();
	for (var i=0; i<8; i++) { claimSchema.claim[i] <== claim[i]; }

	claimSchema.schema === schema;
}

// verifyCredentialNotRevoked verifies that claim is not included into the revocation tree
// TODO: how do we get all of these params and why do we need them at all?
template verifyCredentialNotRevoked(IssuerLevels) {
	signal input claim[8];

	// D. issuer proof of claim validity
	signal input isProofValidNotRevMtp[IssuerLevels];
	signal input isProofValidNotRevMtpNoAux;
	signal input isProofValidNotRevMtpAuxHi;
	signal input isProofValidNotRevMtpAuxHv;
	signal input isProofValidRevTreeRoot;


	component claimRevNonce = getClaimRevNonce();
	for (var i=0; i<8; i++) { claimRevNonce.claim[i] <== claim[i]; }
	// out: claimRevNonce.revNonce

	//
	// D. Claim proof of non revocation (validity)
	//
	component revNonceHiHv = getRevNonceNoVerHiHv();
	revNonceHiHv.revNonce <== claimRevNonce.revNonce;

	component smtClaimValid = SMTVerifier(IssuerLevels);
	smtClaimValid.enabled <== 1;
	smtClaimValid.fnc <== 1; // Non-inclusion
	smtClaimValid.root <== isProofValidRevTreeRoot;
	for (var i=0; i<IssuerLevels; i++) { smtClaimValid.siblings[i] <== isProofValidNotRevMtp[i]; }
	smtClaimValid.oldKey <== isProofValidNotRevMtpAuxHi;
	smtClaimValid.oldValue <== isProofValidNotRevMtpAuxHv;
	smtClaimValid.isOld0 <== isProofValidNotRevMtpNoAux;
	smtClaimValid.key <== revNonceHiHv.hi;
	smtClaimValid.value <== 0;
}

// verifyCredentialMtp verifies that claim is issued by the issuer and included into the claim tree root
template verifyCredentialMtp(IssuerLevels) {
	signal input claim[8];

	// C. issuer proof of claim existence
	// TODO: rename signals
	signal input isProofExistMtp[IssuerLevels]; // issuerClaimMtp
	signal input isProofExistClaimsTreeRoot;    // issuerClaimTreeRoot
	// signal input isProofExistRevTreeRoot;    // issuerRevTreeRoot
	// signal input isProofExistRootsTreeRoot;  // issuerRootsTreeRoot

	component claimHiHv = getClaimHiHv();
	for (var i=0; i<8; i++) { claimHiHv.claim[i] <== claim[i]; }
	// out: claimHiHv.hi
	// out: claimHiHv.hv

	//
	// C. Claim proof of existence (isProofExist)
	//
	component smtClaimExists = SMTVerifier(IssuerLevels);
	smtClaimExists.enabled <== 1;
	smtClaimExists.fnc <== 0; // Inclusion
	smtClaimExists.root <== isProofExistClaimsTreeRoot;
	for (var i=0; i<IssuerLevels; i++) { smtClaimExists.siblings[i] <== isProofExistMtp[i]; }
	smtClaimExists.oldKey <== 0;
	smtClaimExists.oldValue <== 0;
	smtClaimExists.isOld0 <== 0;
	smtClaimExists.key <== claimHiHv.hi;
	smtClaimExists.value <== claimHiHv.hv;
}

// verifyCredentialMtp verifies that claim is issued by the issuer and included into the claim tree root
template verifyCredentialMtpHiHv(IssuerLevels) {
	signal input hi;
	signal input hv;

	signal input isProofExistMtp[IssuerLevels]; // issuerClaimMtp
	signal input isProofExistClaimsTreeRoot;    // issuerClaimTreeRoot
	// signal input isProofExistRevTreeRoot;    // issuerRevTreeRoot
	// signal input isProofExistRootsTreeRoot;  // issuerRootsTreeRoot

	component smtClaimExists = SMTVerifier(IssuerLevels);
	smtClaimExists.enabled <== 1;
	smtClaimExists.fnc <== 0; // Inclusion
	smtClaimExists.root <== isProofExistClaimsTreeRoot;
	for (var i=0; i<IssuerLevels; i++) { smtClaimExists.siblings[i] <== isProofExistMtp[i]; }
	smtClaimExists.oldKey <== 0;
	smtClaimExists.oldValue <== 0;
	smtClaimExists.isOld0 <== 0;
	smtClaimExists.key <== hi;
	smtClaimExists.value <== hv;
}

// verifyClaimsTreeRoot verifies that claim is issued by the issuer and included into the claim tree root
// TODO: what is this check doing? Is it checking inclusion of claim tree root to the roots tree for indirect identities?
// TODO: Or it should be included to the roots tree for direct identities too?
template verifyClaimsTreeRoot(IssuerLevels) {
	signal input isProofExistClaimsTreeRoot;    // issuerClaimTreeRoot
	signal input isProofValidRootsTreeRoot;

	// E. issuer proof of Root (ExistClaimsTreeRoot)
	signal input isProofRootMtp[IssuerLevels];

	//
	// E. Claim proof of root
	//
	component rootHiHv = getRootHiHv();
	rootHiHv.root <== isProofExistClaimsTreeRoot;

	component smtRootValid = SMTVerifier(IssuerLevels);
	smtRootValid.enabled <== 1;
	smtRootValid.fnc <== 0; // Inclusion
	smtRootValid.root <== isProofValidRootsTreeRoot;
	for (var i=0; i<IssuerLevels; i++) { smtRootValid.siblings[i] <== isProofRootMtp[i]; }
	smtRootValid.oldKey <== 0;
	smtRootValid.oldValue <== 0;
	smtRootValid.isOld0 <== 0;
	smtRootValid.key <== rootHiHv.hi;
	smtRootValid.value <== rootHiHv.hv;
}

// verifyCredentialExistence verifies that claim is issued by the issuer
// is contained in a claim (`claim`) issued by an identity that has a recent
// identity state (`isIdenState`), while proving that the claim has not been
// revoked as of the recent identity state.
template verifyIdenStateMatchesRoots() {
	signal input isProofValidClaimsTreeRoot;
	signal input isProofValidRevTreeRoot;
	signal input isProofValidRootsTreeRoot;
	signal input isIdenState;

	//
	// F. Verify ValidIdenState == isIdenState
	//
	component isProofValidIdenState = getIdenState();
	isProofValidIdenState.claimsTreeRoot <== isProofValidClaimsTreeRoot;
	isProofValidIdenState.revTreeRoot <== isProofValidRevTreeRoot;
	isProofValidIdenState.rootsTreeRoot <== isProofValidRootsTreeRoot;
	// out: isProofValidIdenState.idenState

	isProofValidIdenState.idenState === isIdenState;
}

// verifyClaimIssuance verifies that claim is issued by the issuer
template verifyClaimIssuance(IssuerLevels) {
	signal input claim[8];
	signal input claimIssuanceMtp[IssuerLevels];
	signal input claimIssuanceClaimsTreeRoot;
	signal input claimIssuanceRevTreeRoot;
	signal input claimIssuanceRootsTreeRoot;
	signal input claimIssuanceIdenState;

    // verify country claim is included in claims tree root
    component claimIssuanceCheck = verifyCredentialMtp(IssuerLevels);
    for (var i=0; i<8; i++) { claimIssuanceCheck.claim[i] <== claim[i]; }
    for (var i=0; i<IssuerLevels; i++) { claimIssuanceCheck.isProofExistMtp[i] <== claimIssuanceMtp[i]; }
    claimIssuanceCheck.isProofExistClaimsTreeRoot <== claimIssuanceClaimsTreeRoot;

    // verify issuer state includes country claim
    component verifyCountryClaimIssuanceIdenState = verifyIdenStateMatchesRoots();
    verifyCountryClaimIssuanceIdenState.isProofValidClaimsTreeRoot <== claimIssuanceClaimsTreeRoot;
    verifyCountryClaimIssuanceIdenState.isProofValidRevTreeRoot <== claimIssuanceRevTreeRoot;
    verifyCountryClaimIssuanceIdenState.isProofValidRootsTreeRoot <== claimIssuanceRootsTreeRoot;
    verifyCountryClaimIssuanceIdenState.isIdenState <== claimIssuanceIdenState;

}
// verifyClaimSignature verifies that claim is signed with the provided public key
template verifyClaimSignature() {
	signal input claim[8];
	signal input sigR8x;
	signal input sigR8y;
	signal input sigS;
	signal input pubKeyX;
	signal input pubKeyY;

    component hash = getClaimHash();
    for (var i=0; i<8; i++) { hash.claim[i] <== claim[i]; }

    // signature verification
    component sigVerifier = EdDSAPoseidonVerifier();
    sigVerifier.enabled <== 1;

    sigVerifier.Ax <== pubKeyX;
    sigVerifier.Ay <== pubKeyY;

    sigVerifier.S <== sigS;
    sigVerifier.R8x <== sigR8x;
    sigVerifier.R8y <== sigR8y;

    sigVerifier.M <== hash.hash;
}