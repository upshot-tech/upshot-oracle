// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

// ***************************************************************
// * ========================= STRUCTS ========================= *
// ***************************************************************
struct PriceData { 
    bytes signature;
    uint256 nonce;
    address nft; 
    uint96 timestamp;
    address token; 
    uint96 expiration;
    uint256 nftId;
    uint256 price; 
}

/**
 * @title Upshot Oracle Interface
 */
interface IUpshotOracle {
    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************
    event UpshotOracleAdminSetAuthenticator(address authenticator);
    event UpshotOracleAdminSetNonce();

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************
    error UpshotOracleInvalidPriceTime();
    error UpshotOracleInvalidSigner();
    error UpshotOracleInvalidNonce();

    // ***************************************************************
    // * ========================== VIEW =========================== *
    // ***************************************************************

    /**
     * @dev Get current nonce by NFT collection address
     */
    function getNonce(address collection) external view returns (uint256 nonce);

    /**
     * @notice Get the address of the authenticator
     */
    function authenticator() external view returns (address);

    /**
     * @notice Decode the token prices from the encoded upshot price data
     */
    function decodeTokenPrices(
        PriceData[] calldata priceData
    ) external returns (uint256[] memory tokenPrices);
}
