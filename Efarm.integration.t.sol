// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/token/EFarm.sol";

import "forge-std/console.sol";

contract EfarmIntegrationTest is Test {
    bytes32 public constant PHASE_ADMIN_ROLE = keccak256("PHASE_ADMIN_ROLE");

    EFarm public efarm;
    address internal admin;
    address internal phaseAdmin;

    uint256[8] public weeklyDrops = [
        10_000 * (10 ** 18),
        100_000 * (10 ** 18),
        1_000_000 * (10 ** 18),
        10_000_000 * (10 ** 18),
        100_000_000 * (10 ** 18),
        1_000_000_000 * (10 ** 18),
        10_000_000_000 * (10 ** 18),
        100_000_000_000 * (10 ** 18)
    ];

    uint256 totalTokensDistributed;
    uint256 numberOfUsers = 10;
    address[] users;

    function setUp() public {
        admin = vm.addr(0xdeadbeef);
        phaseAdmin = vm.addr(0xdeefbeef);
        efarm = new EFarm(admin);

        vm.startPrank(admin);
        bool[] memory roles = new bool[](4);
        roles[0] = true; // PHASE_ADMIN_ROLE
        efarm.assignRoles(phaseAdmin, roles);
        vm.stopPrank();

        // Set phase limits for all 8 weeks
        uint8[] memory phases = new uint8[](8);
        uint256[] memory limits = new uint256[](8);

        for (uint8 week = 0; week < 8; week++) {
            phases[week] = week;
            limits[week] = weeklyDrops[week];
        }

        vm.startPrank(phaseAdmin);
        efarm.setPhaseLimits(phases, limits);
        vm.stopPrank();

        // Initialize user addresses
        users = new address[](numberOfUsers);
        for (uint256 i = 0; i < numberOfUsers; i++) {
            users[i] = vm.addr(uint256(keccak256(abi.encodePacked(i))));
        }

        (, uint256[] memory fetchedLimits) = efarm.getPhaseLimits();

        for (uint8 i = 0; i < fetchedLimits.length; i++) {
            console.log("Phase", i, "Limit:", fetchedLimits[i]);
        }
        totalTokensDistributed = 0;
    }

    function simulateWeek(uint8 week) internal {
        console.log("Current Phase:", efarm.getCurrentPhase());

        uint256 phaseDrop = weeklyDrops[week];

        uint256[] memory tokenAmounts = new uint256[](numberOfUsers);
        for (uint256 i = 0; i < numberOfUsers; i++) {
            tokenAmounts[i] = phaseDrop / numberOfUsers;
        }

        // Log token amounts
        for (uint256 i = 0; i < numberOfUsers; i++) {
            console.log("Token Amounts for user", i, ":", tokenAmounts[i]);
        }

        // Distribute tokens in multiple batches within the same phase
        vm.startPrank(phaseAdmin);
        efarm.updateTokenAmounts(users, tokenAmounts);
        vm.stopPrank();

        for (uint256 i = 0; i < numberOfUsers; i++) {
            console.log("user ", i, ":", users[i]);
        }
        totalTokensDistributed += phaseDrop;

        vm.startPrank(phaseAdmin);
        efarm.closeCurrentPhase();
        vm.stopPrank();

        for (uint256 i = 0; i < numberOfUsers; i++) {
            vm.startPrank(users[i]);
            efarm.claimRewards(week);
            vm.stopPrank();

            uint256 cumulativeDrop = 0;
            for (uint8 w = 0; w <= week; w++) {
                cumulativeDrop += weeklyDrops[w];
            }
            uint256 expectedBalance = cumulativeDrop / numberOfUsers;
            assertEq(efarm.balanceOf(users[i]), expectedBalance, "User balance mismatch");
        }
        console.log("Total Tokens Distributed:", totalTokensDistributed);
        console.log("New Phase:", efarm.getCurrentPhase());
    }

    function testSimulateWeeks() public {
        for (uint8 week = 0; week < 8; week++) {
            simulateWeek(week);
        }

        assertEq(totalTokensDistributed, efarm.INITIAL_SUPPLY(), "Total supply mismatch");
    }
}
