// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AggregatorV3Interface} from "@@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title ChainlinkOracleLib
 * @author Shurjeel Khan
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * @dev This library includes sequencer uptime checks for L2 networks and validates price freshness
 */
library ChainlinkOracleLib {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ChainlinkOracleLib__StalePrice();
    error ChainlinkOracleLib__SequencerDown();
    error ChainlinkOracleLib__InvalidPrice();
    error ChainlinkOracleLib__GracePeriodNotOver();
    error ChainlinkOracleLib__InvalidTimestamp();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant GRACE_PERIOD_TIME = 3600; // 1 hour in seconds

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the latest price from Chainlink with full metadata
     * @param _priceFeed The Chainlink price feed aggregator
     * @param _sequencerFeed The Chainlink sequencer uptime feed (address(0) for L1)
     * @param _stalePriceThreshold Maximum age of price data in seconds before considered stale
     * @return roundId The round ID from the price feed
     * @return answer The price answer
     * @return startedAt Timestamp when the round started
     * @return updatedAt Timestamp when the round was updated
     * @return answeredInRound The round ID in which the answer was computed
     */
    function getPriceWithMetadata(address _priceFeed, address _sequencerFeed, uint256 _stalePriceThreshold)
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        AggregatorV3Interface sequencerFeed = AggregatorV3Interface(_sequencerFeed);
        // Check sequencer status if on L2
        _checkSequencerStatus(sequencerFeed);

        // Get latest price data
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();

        // Validate price data
        _validatePriceData(answer, updatedAt, _stalePriceThreshold);

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    /**
     * @notice Gets the latest price from Chainlink (simplified version)
     * @param priceFeed The Chainlink price feed aggregator
     * @param sequencerFeed The Chainlink sequencer uptime feed (address(0) for L1)
     * @param stalePriceThreshold Maximum age of price data in seconds before considered stale
     * @return answer The price answer
     */
    function getPrice(address priceFeed, address sequencerFeed, uint256 stalePriceThreshold)
        public
        view
        returns (int256 answer)
    {
        (, answer,,,) = getPriceWithMetadata(priceFeed, sequencerFeed, stalePriceThreshold);
        return answer;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if the L2 sequencer is up and running
     * @param sequencerFeed The Chainlink sequencer uptime feed
     * @dev Reverts if sequencer is down or grace period after recovery hasn't passed
     */
    function _checkSequencerStatus(AggregatorV3Interface sequencerFeed) private view {
        // Skip check if no sequencer feed provided (L1 networks)
        if (address(sequencerFeed) != address(0)) {
            (
                /*uint80 roundId*/
                ,
                int256 answer,
                uint256 startedAt,
                /*uint256 updatedAt*/
                ,
                /*uint80 answeredInRound*/
            ) = sequencerFeed.latestRoundData();

            // answer == 0: Sequencer is up
            // answer == 1: Sequencer is down
            bool isSequencerUp = answer == 0;
            if (!isSequencerUp) {
                revert ChainlinkOracleLib__SequencerDown();
            }

            // Ensure grace period has passed after sequencer comes back up
            // This prevents accepting stale prices right after sequencer recovery
            uint256 timeSinceUp = block.timestamp - startedAt;
            if (timeSinceUp < GRACE_PERIOD_TIME) {
                revert ChainlinkOracleLib__GracePeriodNotOver();
            }
        }
    }

    /**
     * @notice Validates the price data from the feed
     * @param answer The price answer from the feed
     * @param updatedAt The timestamp when the price was last updated
     * @param stalePriceThreshold Maximum age of price data in seconds
     * @dev Reverts if price is invalid or stale
     */
    function _validatePriceData(int256 answer, uint256 updatedAt, uint256 stalePriceThreshold) private view {
        // Check for invalid price
        if (answer <= 0) {
            revert ChainlinkOracleLib__InvalidPrice();
        }

        if (updatedAt > block.timestamp) {
            revert ChainlinkOracleLib__InvalidTimestamp();
        }

        // Check if price data is stale
        uint256 timeSinceLastUpdate = block.timestamp - updatedAt;
        if (timeSinceLastUpdate > stalePriceThreshold) {
            revert ChainlinkOracleLib__StalePrice();
        }
    }

    /*//////////////////////////////////////////////////////////////
                          GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the grace period time constant
     * @return The grace period in seconds
     */
    function getGracePeriodTime() external pure returns (uint256) {
        return GRACE_PERIOD_TIME;
    }
}
