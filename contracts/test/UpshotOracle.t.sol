// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../lib/forge-std/src/Test.sol";

import { PriceData } from "../IUpshotOracle.sol";
import { UpshotOracle } from "../UpshotOracle.sol";
import { ECDSA } from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract UpshotOracleUnitTests is Test {
    UpshotOracle _upshotOracle;
    address _owner = address(0x100);
    address _imposter = address(0x101);
    uint256 _imposterPrivateKey = 0x0000beeb;
    uint256 _authenticatorPrivateKey = 0xdeadbeef;
    address _authenticator = vm.addr(_authenticatorPrivateKey);
    uint256 private constant TIMESTAMP_NOW = 1682700000;

    PriceData _sample = PriceData({
        signature: "",
        nonce: 1,
        nft: address(0xdead),
        timestamp: uint96(TIMESTAMP_NOW - 1337),
        token: address(0xbeef),
        expiration: type(uint32).max,
        nftId: type(uint256).max,
        price: 1,
        extraData: ""
    });

    function setUp() public {
        vm.prank(_owner);
        _upshotOracle = new UpshotOracle(_authenticator);
        vm.warp(TIMESTAMP_NOW);
    }

    function test_upshotOracleHasCorrectInitialOwner() public {
        assertEq(_upshotOracle.owner(), _owner);
    }

    function test_upshotOracleHasCorrectInitialAuthenticator() public {
        assertEq(_upshotOracle.authenticator(), _authenticator);
    }

    function test_upshotOracleOwnerCanSetAuthenticator() public {
        assertFalse(_upshotOracle.authenticator() == address(0xbeef));
        vm.prank(_owner);
        _upshotOracle.setAuthenticator(address(0xbeef));
        assertEq(_upshotOracle.authenticator(), address(0xbeef));
    }

    function test_imposterCannotSetAuthenticator() public {
        assertFalse(_upshotOracle.authenticator() == _imposter);
        vm.startPrank(_imposter);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", _imposter));
        _upshotOracle.setAuthenticator(_imposter);
        vm.stopPrank();
        assertEq(_upshotOracle.authenticator(), _authenticator);
    }

    function test_getPriceMessageReturnsCorrectHash() public {
        bytes32 correct = 0x32c9508c5e041c56c93a342e1f123f70b7a45d51c19957a62257296a0a429d7c;
        bytes32 actual = _upshotOracle.getPriceMessage(
            1, 
            address(0xbeef), 
            1337, 
            address(0xcafe),
            type(uint256).max,
            1682691526,
            9999999999,
            ""
        );
        assertEq(correct, actual);
    }

    function test_decodeTokenPricesDecodesCorrectData() public {
        PriceData[] memory priceData = new PriceData[](1);
        priceData[0] = _sample;
        uint256[] memory expectedPrices = new uint256[](1);
        expectedPrices[0] = 1.337 ether;
        priceData = _setUpTokenPriceDataFromExpectedPrices(
            priceData,
            expectedPrices,
            _authenticatorPrivateKey
        );
        uint256[] memory actualPrices = _upshotOracle.decodeTokenPrices(priceData);
        for(uint i = 0; i < expectedPrices.length; i++) {
            assertEq(actualPrices[i], expectedPrices[i]);
        }
    }

    function test_decodeTokenPricesDecodesCorrectDataFuzz(
        PriceData[] memory priceData, 
        uint256[] memory expectedPrices
    ) public {
        for(uint256 i = 0; i < priceData.length; i++) {
            priceData[i].nft = address(0x666);
            priceData[i].nonce = i + 1;
        }
        priceData = _setUpTokenPriceDataFromExpectedPrices(
            priceData, 
            expectedPrices, 
            _authenticatorPrivateKey
        );
        uint256[] memory actualPrices = _upshotOracle.decodeTokenPrices(priceData);
        for(uint i = 0; i < expectedPrices.length; i++) {
            assertEq(actualPrices[i], expectedPrices[i]);
        }
    }

    function test_decodeTokenPricesFailsForCorrectSignatureButIncorrectSigner() public {
        PriceData[] memory priceData = new PriceData[](1);
        priceData[0] = _sample;
        uint256[] memory expectedPrices = new uint256[](1);
        expectedPrices[0] = 1.337 ether;
        priceData = _setUpTokenPriceDataFromExpectedPrices(
            priceData,
            expectedPrices,
            _imposterPrivateKey
        );
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleInvalidSigner()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }


    function test_decodeTokenPriceStillFailsForMixedCorrectAndIncorrectSignatures(
    ) public  {
        PriceData[] memory priceData = new PriceData[](3);
        priceData[0] = _sample;
        priceData[1] = _sample;
        priceData[2] = _sample;
        uint256[] memory expectedPrices = new uint256[](3);
        expectedPrices[0] = 1.337 ether;
        expectedPrices[0] = 1.537 ether;
        expectedPrices[0] = 1.637 ether;
        priceData = _setUpTokenPriceDataFromExpectedPrices(
            priceData,
            expectedPrices,
            _authenticatorPrivateKey
        );
        priceData[1].signature = _produceSignature(priceData[1], _imposterPrivateKey);
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleInvalidSigner()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }


    /*
    uint256 private constant SECP256K1_ORDER_SIZE = type(uint16).max;
    // This test passes but is highly computationally expensive
    // and makes the test suite take a long time to run.
    // leave it commented out unless you have changed the Oracle source code 
    // and want to specifically test arbitrary signers.
    // the same test case is manually tested in 
    // test_decodeTokenPricesFailsForCorrectSignatureButIncorrectSigner()
    function test_decodeTokenPricesFailsForCorrectSignatureButIncorrectSignerFuzz(
        PriceData[] memory priceData, 
        uint256[] memory expectedPrices,
        uint256 fuzzPrivateKey
    ) public {
        vm.assume(fuzzPrivateKey != _authenticatorPrivateKey);
        vm.assume(expectedPrices.length > 0);
        _boundUint(fuzzPrivateKey, 1, SECP256K1_ORDER_SIZE - 1);
        priceData = _setUpTokenPriceDataFromExpectedPrices(
            priceData, 
            expectedPrices, 
            fuzzPrivateKey
        );
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleInvalidSigner()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }
    */

    /*
    // This test passes but is highly computationally expensive
    // and makes the test suite take a long time to run.
    // leave it commented out unless you have changed the Oracle source code 
    // and want to specifically test arbitrary signers.
    // the same test case is manually tested in
    // test_decodeTokenPriceStillFailsForMixedCorrectAndIncorrectSignatures()
    function test_decodeTokenPriceStillFailsForMixedCorrectAndIncorrectSignaturesFuzz(
        PriceData[] memory priceData, 
        uint256[] memory expectedPrices,
        uint256 fuzzPrivateKey,
        uint256 indexFuzz
    ) public{
        vm.assume(fuzzPrivateKey != _authenticatorPrivateKey);
        vm.assume(expectedPrices.length > 0);
        _boundUint(fuzzPrivateKey, 1, SECP256K1_ORDER_SIZE - 1);
        priceData = _setUpTokenPriceDataFromExpectedPrices(
            priceData, 
            expectedPrices, 
            _authenticatorPrivateKey
        );
        indexFuzz = indexFuzz % priceData.length;
        priceData[indexFuzz].signature = _produceSignature(priceData[indexFuzz], fuzzPrivateKey);
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleInvalidSigner()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }
    */

    function test_decodeTokenPricesFailsForIncorrectSignature() public {
        PriceData[] memory priceData = new PriceData[](1);
        priceData[0] = _sample;
        priceData[0].signature = bytes("signatures are 65 bytes long but this sig isn't a valid signature");
        vm.expectRevert(abi.encodeWithSignature("ECDSAInvalidSignature()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }

    function test_decodeTokenPricesFailsForIncorrectSignatureFuzz(
        PriceData[] memory priceData, 
        uint256[] memory expectedPrices,
        uint indexFuzz
    ) public {
        vm.assume(expectedPrices.length > 0);
        for(uint256 i = 0; i < priceData.length; i++) {
            priceData[i].nft = address(0x666);
            priceData[i].nonce = i + 1;
        }
        priceData = _setUpTokenPriceDataFromExpectedPrices(
            priceData,
            expectedPrices,
            _authenticatorPrivateKey
        );
        indexFuzz = indexFuzz % priceData.length;
        priceData[indexFuzz].signature = bytes("signatures are 65 bytes long but this sig isn't a valid signature");
        assertEq(priceData[indexFuzz].signature.length, 65);
        vm.expectRevert(abi.encodeWithSignature("ECDSAInvalidSignature()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }

    function test_decodeTokenPricesFailsForIncorrectTimestamp() public {
        PriceData[] memory priceData = new PriceData[](1);
        priceData[0] = _sample;
        priceData[0].timestamp = uint96(TIMESTAMP_NOW + 64);
        priceData[0].signature = _produceSignature(priceData[0], _authenticatorPrivateKey);
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleInvalidPriceTime()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }

    function test_decodeTokenPricesFailsForIncorrectExpiration() public {
        PriceData[] memory priceData = new PriceData[](1);
        priceData[0] = _sample;
        priceData[0].expiration = uint96(TIMESTAMP_NOW - 64);
        priceData[0].signature = _produceSignature(priceData[0], _authenticatorPrivateKey);
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleInvalidPriceTime()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }

    function test_decodeTokenPriceFailsForIncorrectChainId() public {
        PriceData[] memory priceData = new PriceData[](1);
        priceData[0] = _sample;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _authenticatorPrivateKey,
            _toEthSignedMessageHash(priceData[0], block.chainid + 1)
        );
        priceData[0].signature = abi.encodePacked(r, s, v);
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleInvalidSigner()"));
        _upshotOracle.decodeTokenPrices(priceData);
    }

    function test_getSetNonce() public {
        PriceData[] memory priceData = new PriceData[](1);
        priceData[0] = _sample;
        priceData[0].nonce = 13;
        priceData[0].signature = _produceSignature(priceData[0], _authenticatorPrivateKey);

        _upshotOracle.decodeTokenPrices(priceData);
    
        uint256 nonce00 = _upshotOracle.getNonce(_sample.nft);
        assertEq(nonce00, priceData[0].nonce);

        uint nonce01a = 42;

        vm.prank(_owner);
        _upshotOracle.setNonce(_sample.nft, nonce01a);

        uint256 nonce01b = _upshotOracle.getNonce(_sample.nft);
        assertEq(nonce01a, nonce01b);
    }

    function test_decrementNonceFail() public {
        PriceData[] memory priceData00 = new PriceData[](1);
        priceData00[0] = _sample;
        priceData00[0].nonce = 13;
        priceData00[0].signature = _produceSignature(priceData00[0], _authenticatorPrivateKey);

        _upshotOracle.decodeTokenPrices(priceData00);
    
        PriceData[] memory priceData01 = new PriceData[](1);
        priceData01[0] = _sample;
        priceData01[0].nonce = 12;
        priceData01[0].signature = _produceSignature(priceData01[0], _authenticatorPrivateKey);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleInvalidNonce()"));
        _upshotOracle.decodeTokenPrices(priceData01);
    }

    // ***************************************************************
    // * ===================== INTERNAL FUNCTIONS ================== *
    // ***************************************************************

    /**
     * @notice internal function to create a working signed PriceData array
     * @param priceData sample priceData to base a functionally returned one off of (used with fuzzing)
     * @param expectedPrices array of expected prices to be returned by the oracle
     * @param privateKeyForSigning private key to sign the PriceData with
     * @return outData array of PriceData with set up signatures
     */
    function _setUpTokenPriceDataFromExpectedPrices(
        PriceData[] memory priceData, 
        uint256[] memory expectedPrices,
        uint256 privateKeyForSigning
    )  internal view returns(PriceData[] memory outData) {
        outData = new PriceData[](expectedPrices.length);
        PriceData memory data;
        for(uint i = 0; i < expectedPrices.length; i++) {
            // use a sample if the fuzzer doesnt give equally sized arrays
            if(i >= priceData.length){
                data = _sample;
            } else {
                data = priceData[i];
                // force timestamp correctness
                if(data.timestamp >= TIMESTAMP_NOW) {
                    data.timestamp = uint96(data.timestamp % TIMESTAMP_NOW);
                }
                if(data.expiration <= TIMESTAMP_NOW) {
                    data.expiration = uint96(
                        TIMESTAMP_NOW + (data.expiration % type(uint32).max));
                }
            }
            data.price = expectedPrices[i];
            data.signature = _produceSignature(data, privateKeyForSigning);
            outData[i] = data;
        }
    }

    /**
     * @notice internal function to produce a signature for a given PriceData
     * @param data PriceData to sign
     * @param privateKey private key to sign the PriceData with
     * @return signature bytes of the signature
     */
    function _produceSignature(
        PriceData memory data,
        uint256 privateKey
    )  internal view returns(bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            _toEthSignedMessageHash(data, block.chainid)
        );
        signature = abi.encodePacked(r, s, v);
    }

    /**
     * @notice internal stacktoodeep preventing function because of course the stack is too deep
     */
    function _toEthSignedMessageHash(PriceData memory data, uint256 chainId) private pure returns(bytes32) {
        return ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    chainId,
                    data.nonce,
                    data.nft, 
                    data.nftId, 
                    data.token, 
                    data.price, 
                    data.timestamp,
                    data.expiration,
                    data.extraData
                )   
            )
        );
    }

    function _boundUint(uint256 value, uint256 min, uint256 max) private pure returns(uint256) {
        require(min <= max, "impossible bounds");
        if(min == max) {
            return min;
        }
        uint256 width = (max - min);
        return (min + (value % width));
    }

}