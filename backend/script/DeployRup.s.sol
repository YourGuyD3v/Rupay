// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {Rupay} from "../src/Rupay.sol";
import {RupIssuer} from "../src/RupIssuer.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRup is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    address[] public sequencerFeedAddresses;
    uint256[] public stalePriceThresholds;

    function run() external returns (Rupay, RupIssuer, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wethUsdSequencerFeed,
            address wbtcUsdSequencerFeed,
            uint256 wethStalePriceThreshold,
            uint256 wbtcStalePriceThreshold,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        sequencerFeedAddresses = [wethUsdSequencerFeed, wbtcUsdSequencerFeed];
        stalePriceThresholds = [wethStalePriceThreshold, wbtcStalePriceThreshold];

        vm.startBroadcast(deployerKey);
        Rupay rup = new Rupay();
        RupIssuer rupIssuer = new RupIssuer(
            tokenAddresses, priceFeedAddresses, sequencerFeedAddresses, stalePriceThresholds, address(rup)
        );
        rup.transferOwnership(address(rupIssuer));
        vm.stopBroadcast();
        return (rup, rupIssuer, helperConfig);
    }
}
