// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {AggregatorV3Interface, AggregatorInterface} from '../dependencies/chainlink/AggregatorInterface.sol';
import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';
import {SafeCast} from '../dependencies/openzeppelin/contracts/SafeCast.sol';
import {ISupraSValueFeed} from '../dependencies/supra/ISupraSValueFeed.sol';

contract SupraAggregator is Ownable, AggregatorInterface {
  /// @notice decimals of the data from the aggregator
  uint8 decimals;
  /// @notice address of the asset the aggregator is suppporting
  address public asset;
  /// @notice address of the Supra Push Oracle contract
  ISupraSValueFeed public supraOracle;
  /// @notice price index id used by Supra for the identification of the token pair
  uint256 assetPriceIndex;
  /// @notice price index id used by Supra for the identification of the USDT/USD pair
  /// @dev this price index is required for return price data in USD and not USDT
  uint256 public usdtUsdPriceIndex;
  /// @notice name of the token pair the aggregator is supporting
  string public tokenPair;

  constructor(
    address _asset,
    address _supraOracle,
    uint256 _assetPriceIndex,
    uint256 _usdtUsdPriceIndex,
    uint8 _decimals,
    string memory _tokenPair
  ) Ownable() {
    asset = _asset;
    supraOracle = ISupraSValueFeed(_supraOracle);
    assetPriceIndex = _assetPriceIndex;
    usdtUsdPriceIndex = _usdtUsdPriceIndex;
    uint8 decimals = _decimals;
    tokenPair = _tokenPair;
  }

  /// @notice Get latest answer for the asset returned in market BASE CURRENCY
  function latestAnswer() external view returns (int256) {
    ISupraSValueFeed.priceFeed memory priceFeed = supraOracle.getSvalue(assetPriceIndex);
    return SafeCast.toInt256(convertToUsd(priceFeed.price, decimals));
  }

  /// @notice Get latest timestamp for the asset
  function latestTimestamp() external view returns (uint256) {
    return supraOracle.getTimestamp(assetPriceIndex);
  }

  /// @notice Get latest round in which the asset has been updated
  function latestRound() external view returns (uint256) {
    return supraOracle.getRound(assetPriceIndex);
  }

  /// @notice Not supported by Supra Oracle
  function getAnswer(uint256 roundId) external view returns (int256) {
    revert('Not supported by Supra');
  }

  /// @notice Not supported by Supra Oracle
  function getTimestamp(uint256 roundId) external view returns (uint256) {
    revert('Not supported by Supra');
  }

  /// @notice Convert the price of the asset to USD as
  function convertToUsd(uint256 price, uint256 _decimals) internal view returns (uint256) {
    // get usd price of the usdt
    ISupraSValueFeed.priceFeed memory priceFeed = supraOracle.getSvalue(usdtUsdPriceIndex);

    // use the higher decimals of the two received
    uint256 maxDecimals = _decimals > priceFeed.decimals ? _decimals : priceFeed.decimals;
    uint256 usdtPrice = normalizeDecimals(priceFeed.price, priceFeed.decimals, maxDecimals);

    // convert the asset_usdt pair to asset_usd pair
    uint256 usdPrice = price * usdtPrice;

    // normalize the return to the contract defined decimals
    return normalizeDecimals(usdPrice, maxDecimals, SafeCast.toUint8(decimals));
  }

  /// @notice Shifts the pricing according to the difference in decimals
  function normalizeDecimals(
    uint256 price,
    uint256 currentDecimals,
    uint256 expectedDecimals
  ) internal pure returns (uint256) {
    if (currentDecimals > expectedDecimals) {
      return price / (10 ** (currentDecimals - expectedDecimals));
    } else if (currentDecimals < expectedDecimals) {
      return price * (10 ** (expectedDecimals - currentDecimals));
    }

    return price;
  }
}
