// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

contract OmniRideShareHub {
    struct RideOffer {
        address payable driver;
        uint256 seatPriceWei;
        uint256 availableSeats;
        bool isActive;
        bytes32 routeHash;
    }

    address payable public immutable hubAdmin;
    string public hubDescriptor;
    uint256 public platformFeeBps; // 250 = 2.5%
    uint256 public rideCounter;
    uint256 public accumulatedFees;
    bool public isHubPaused;

    mapping(address => bool) public verifiedDrivers;
    mapping(uint256 => RideOffer) public rides;
    mapping(uint256 => mapping(address => bool)) public hasBooked;

    event DriverVerified(address indexed driver);
    event SeatBooked(uint256 indexed rideId, address indexed passenger, uint256 price);
    event RideCanceled(uint256 indexed rideId);
    event TreasuryDeposited(address indexed funder, uint256 amount);
    event ReservesDrained(address indexed admin, uint256 amount);
    event FeesHarvested(address indexed admin, uint256 amount);
    event RideListed(uint256 indexed rideId, address indexed driver, uint256 price, uint256 seats);
    event HubPauseToggled(bool isPaused);
    event DescriptorUpdated(string newDescriptor);

    modifier onlyAdmin() {
        require(msg.sender == hubAdmin, "OmniRide: Access denied");
        _;
    }

    modifier whenNotPaused() {
        require(!isHubPaused, "OmniRide: Hub is paused");
        _;
    }

    constructor() {
        hubAdmin = payable(msg.sender);
        hubDescriptor = "Omni Base Ride-Share Hub v1";
        platformFeeBps = 250; // 2.5%
        isHubPaused = false;
        verifiedDrivers[msg.sender] = true;
    }

    // 1. addVerifiedDriver
    function addVerifiedDriver(address driver) external onlyAdmin {
        require(!verifiedDrivers[driver], "OmniRide: Already verified");
        verifiedDrivers[driver] = true;
        emit DriverVerified(driver);
    }

    // 2. bookRideSeat
    function bookRideSeat(uint256 rideId) external payable whenNotPaused {
        RideOffer storage r = rides[rideId];
        require(rideId > 0 && rideId <= rideCounter, "OmniRide: Invalid ID");
        require(r.isActive, "OmniRide: Ride inactive");
        require(r.availableSeats > 0, "OmniRide: No seats left");
        require(!hasBooked[rideId][msg.sender], "OmniRide: Already booked");
        require(msg.value >= r.seatPriceWei, "OmniRide: Insufficient payment");

        uint256 fee = (msg.value * platformFeeBps) / 10000;
        uint256 driverShare = msg.value - fee;

        accumulatedFees += fee;
        r.availableSeats--;
        hasBooked[rideId][msg.sender] = true;

        if (driverShare > 0) {
            (bool sent, ) = r.driver.call{value: driverShare}("");
            require(sent, "OmniRide: Payout failed");
        }

        emit SeatBooked(rideId, msg.sender, msg.value);
    }

    // 3. cancelRideOffer
    function cancelRideOffer(uint256 rideId) external {
        RideOffer storage r = rides[rideId];
        require(rideId > 0 && rideId <= rideCounter, "OmniRide: Invalid ID");
        require(msg.sender == r.driver || msg.sender == hubAdmin, "OmniRide: Unauthorized");
        require(r.isActive, "OmniRide: Already inactive");

        r.isActive = false;
        emit RideCanceled(rideId);
    }

    // 4. depositPlatformTreasury
    function depositPlatformTreasury() external payable whenNotPaused {
        require(msg.value > 0, "OmniRide: Zero deposit");
        accumulatedFees += msg.value;
        emit TreasuryDeposited(msg.sender, msg.value);
    }

    // 5. drainHubReserves
    function drainHubReserves() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "OmniRide: Zero balance");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: balance}("");
        require(sent, "OmniRide: Sweep failed");

        emit ReservesDrained(hubAdmin, balance);
    }

    // 6. harvestPlatformFees
    function harvestPlatformFees() external onlyAdmin {
        uint256 amount = accumulatedFees;
        require(amount > 0, "OmniRide: Zero fees");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: amount}("");
        require(sent, "OmniRide: Harvest failed");

        emit FeesHarvested(hubAdmin, amount);
    }

    // 7. listNewRide
    function listNewRide(uint256 seatPriceWei, uint256 seats, bytes32 routeHash) external whenNotPaused returns (uint256) {
        require(verifiedDrivers[msg.sender], "OmniRide: Not a verified driver");
        require(seats > 0, "OmniRide: Zero seats");

        rideCounter++;
        rides[rideCounter] = RideOffer({
            driver: payable(msg.sender),
            seatPriceWei: seatPriceWei,
            availableSeats: seats,
            isActive: true,
            routeHash: routeHash
        });

        emit RideListed(rideCounter, msg.sender, seatPriceWei, seats);
        return rideCounter;
    }

    // 8. pauseRideHub
    function pauseRideHub(bool isPaused) external onlyAdmin {
        isHubPaused = isPaused;
        emit HubPauseToggled(isPaused);
    }

    // 9. updateHubDescriptor
    function updateHubDescriptor(string calldata newDescriptor) external onlyAdmin {
        require(bytes(newDescriptor).length > 0, "OmniRide: Empty string");
        hubDescriptor = newDescriptor;
        emit DescriptorUpdated(newDescriptor);
    }

    // Read-метод
    function getRideInfo(uint256 rideId) external view returns (
        address driver, uint256 price, uint256 seats, bool isActive
    ) {
        RideOffer memory r = rides[rideId];
        return (r.driver, r.seatPriceWei, r.availableSeats, r.isActive);
    }
}