// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IOmniRideShareHub {
    function bookRideSeat(uint256 rideId) external payable;
    function listNewRide(uint256 seatPriceWei, uint256 seats, bytes32 routeHash) external returns (uint256);
}
