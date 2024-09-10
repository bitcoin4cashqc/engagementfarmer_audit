// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/token/EFarm.sol";

contract EfarmTokenTest is Test {
    bytes32 public constant PHASE_ADMIN_ROLE = keccak256("PHASE_ADMIN_ROLE");

    EFarm public efarm;
    address internal admin;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    function setUp() public {
        admin = vm.addr(0xdeadbeef);
        efarm = new EFarm(admin);
    }

    function testNameAndSymbol() public {
        string memory name = "EFarm";
        string memory symbol = "FARM";
        assertEq(efarm.name(), name);
        assertEq(efarm.symbol(), symbol);
    }

    function testSupply() public {
        assertEq(efarm.totalSupply(), efarm.INITIAL_SUPPLY());
    }

    function testInitialOwner() public {
        assertEq(efarm.owner(), admin, "Initial owner is not correctly set to admin");
    }

    function testFailNonAdminsCantClosePhase() public {
        vm.prank(admin);
        uint8[] memory phases = new uint8[](4);
        uint256[] memory limits = new uint256[](4);

        phases[0] = uint8(1);
        phases[1] = uint8(2);
        phases[2] = uint8(3);
        phases[3] = uint8(4);

        limits[0] = uint256(10);
        limits[1] = uint256(100);
        limits[2] = uint256(1000);
        limits[3] = uint256(10000);

        efarm.setPhaseLimits(phases, limits);
        vm.stopPrank();

        address nonAdmin = vm.addr(0xabcdef);

        vm.prank(nonAdmin);
        vm.expectRevert(
            "AccessControl: account 0xabcdef lacks role 0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1"
        );
        efarm.closeCurrentPhase();
    }

    function testChangePhaseAdminRole() public {
        address phaseAdmin = vm.addr(0xdeefbeef);

        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit RoleGranted(PHASE_ADMIN_ROLE, phaseAdmin, admin);

        bool[] memory roles = new bool[](4);
        roles[0] = true; // PHASE_ADMIN_ROLE
        efarm.assignRoles(phaseAdmin, roles);

        vm.stopPrank();
    }

    function testSetPhaseLimits() public {
        uint8[] memory phases = new uint8[](4);
        uint256[] memory limits = new uint256[](4);

        phases[0] = uint8(1);
        phases[1] = uint8(2);
        phases[2] = uint8(3);
        phases[3] = uint8(4);

        limits[0] = uint256(10);
        limits[1] = uint256(100);
        limits[2] = uint256(1000);
        limits[3] = uint256(10000);

        vm.prank(admin);
        efarm.setPhaseLimits(phases, limits);

        for (uint256 i = 0; i < phases.length; i++) {
            assertEq(efarm.phaseLimit(phases[i]), limits[i]);
        }
    }

    function testSetPhaseLimitsRevert() public {
        uint8[] memory phases = new uint8[](4);
        uint256[] memory limits = new uint256[](4);

        phases[0] = uint8(1);
        phases[1] = uint8(2);
        phases[2] = uint8(3);
        phases[3] = uint8(4);

        limits[0] = uint256(10);
        limits[1] = uint256(100);
        limits[2] = uint256(1000);
        limits[3] = uint256(1_000_000_000_000 * (10 ** 18));

        uint8[] memory invalidPhases = new uint8[](8);
        uint8[] memory invalidLength = new uint8[](5);

        vm.startPrank(admin);
        //too many phases
        vm.expectRevert(bytes("Mismatched array lengths"));
        efarm.setPhaseLimits(invalidPhases, limits);
        //not all phases have a corresponding limit value
        vm.expectRevert(bytes("Mismatched array lengths"));
        efarm.setPhaseLimits(invalidLength, limits);
        //exceeds supply
        vm.expectRevert();
        efarm.setPhaseLimits(phases, limits);

        vm.stopPrank();
    }

    function testSetTokenAmounts() public {
        uint8[] memory phases = new uint8[](4);
        uint256[] memory limits = new uint256[](4);

        phases[0] = uint8(0);
        phases[1] = uint8(1);
        phases[2] = uint8(2);
        phases[3] = uint8(3);

        limits[0] = uint256(100);
        limits[1] = uint256(1000);
        limits[2] = uint256(10000);
        limits[3] = uint256(100000);

        address[] memory users = new address[](4);
        uint256[] memory amts = new uint256[](4);

        users[0] = vm.addr(0xdeddbeef);
        users[1] = vm.addr(0xdecdbeef);
        users[2] = vm.addr(0xdefdbeef);
        users[3] = vm.addr(0xdebdbeef);

        amts[0] = uint256(1);
        amts[1] = uint256(2);
        amts[2] = uint256(3);
        amts[3] = uint256(4);

        vm.startPrank(admin);
        efarm.setPhaseLimits(phases, limits);
        efarm.updateTokenAmounts(users, amts);
        vm.stopPrank();

        for (uint256 i = 0; i < users.length; i++) {
            (uint256 tokenAmount,) = efarm.userPhases(users[i], 0);
            assertEq(tokenAmount, amts[i]);
        }
    }

    function testMintBurnFunctions() public {
        vm.startPrank(admin);

        uint256 initialSupply = efarm.INITIAL_SUPPLY();
        assertEq(efarm.totalSupply(), initialSupply);

        uint256 remainingSupply = efarm.MAX_SUPPLY() - initialSupply;

        uint256 mintAmount = 1000 * (10 ** 18);
        if (remainingSupply >= mintAmount) {
            efarm.mint(admin, mintAmount);
            assertEq(efarm.balanceOf(admin), initialSupply + mintAmount);
        } else {
            vm.expectRevert("EFarm: cap exceeded");
            efarm.mint(admin, mintAmount);
        }

        vm.expectRevert("EFarm: cap exceeded");
        efarm.mint(admin, remainingSupply + 1);

        if (remainingSupply >= mintAmount) {
            efarm.burn(mintAmount);
            assertEq(efarm.balanceOf(admin), initialSupply);
        }

        vm.stopPrank();
    }

    function testMultiplePhaseUpdates() public {
        uint8[] memory phases = new uint8[](2);
        uint256[] memory limits = new uint256[](2);
        phases[0] = uint8(0);
        phases[1] = uint8(1);

        limits[0] = uint256(100);
        limits[1] = uint256(1000);

        address[] memory users = new address[](2);
        uint256[] memory amts = new uint256[](2);

        users[0] = vm.addr(0xdeddbeef);
        users[1] = vm.addr(0xdecdbeef);

        amts[0] = uint256(50);
        amts[1] = uint256(50);

        vm.startPrank(admin);
        efarm.setPhaseLimits(phases, limits);
        efarm.updateTokenAmounts(users, amts);
        efarm.closeCurrentPhase();

        amts[0] = uint256(500);
        amts[1] = uint256(500);
        efarm.updateTokenAmounts(users, amts);
        efarm.closeCurrentPhase();
        vm.stopPrank();

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            efarm.claimRewards(0);
            efarm.claimRewards(1);
            assertEq(efarm.balanceOf(users[i]), 550);
            vm.stopPrank();
        }
    }

    function testClaims() public {
        uint8[] memory phases = new uint8[](4);
        uint256[] memory limits = new uint256[](4);

        phases[0] = uint8(0);
        phases[1] = uint8(1);
        phases[2] = uint8(2);
        phases[3] = uint8(3);

        limits[0] = uint256(100);
        limits[1] = uint256(1000);
        limits[2] = uint256(10000);
        limits[3] = uint256(100000);

        address[] memory users = new address[](4);
        uint256[] memory amts = new uint256[](4);

        users[0] = vm.addr(0xdeddbeef);
        users[1] = vm.addr(0xdecdbeef);
        users[2] = vm.addr(0xdefdbeef);
        users[3] = vm.addr(0xdebdbeef);

        amts[0] = uint256(1);
        amts[1] = uint256(2);
        amts[2] = uint256(3);
        amts[3] = uint256(4);

        // TODO Do this prank with another account that is not admin
        vm.startPrank(admin);
        efarm.setPhaseLimits(phases, limits);
        efarm.updateTokenAmounts(users, amts);
        efarm.closeCurrentPhase();
        vm.stopPrank();

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            efarm.claimRewards(0);
            assertEq(efarm.balanceOf(users[i]), amts[i]);
            vm.stopPrank();
        }
    }

    function testClosePhase() public {
        uint8[] memory phases = new uint8[](4);
        uint256[] memory limits = new uint256[](4);
        phases[0] = uint8(1);
        phases[1] = uint8(2);
        phases[2] = uint8(3);
        phases[3] = uint8(4);
        limits[0] = uint256(100);
        limits[1] = uint256(1000);
        limits[2] = uint256(10000);
        limits[3] = uint256(100000);
        vm.startPrank(admin);
        efarm.setPhaseLimits(phases, limits);
        efarm.closeCurrentPhase();
        vm.stopPrank();
        assertEq(efarm.phaseClosed(0), true);
    }

    function testFailExceedingMaxSupply() public {
        vm.startPrank(admin);
        efarm.mint(admin, efarm.MAX_SUPPLY());
        vm.expectRevert("EFarm: cap exceeded");
        efarm.mint(admin, 1);
        vm.stopPrank();
    }

    function testInvalidPhase() public {
        address user = vm.addr(0xdeddbeef);
        vm.startPrank(admin);
        efarm.closeCurrentPhase();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert("invalid phase");
        efarm.claimRewards(8);
        vm.stopPrank();
    }

    function testAssignRoles() public {
        address phaseAdmin = vm.addr(0x1);

        vm.startPrank(admin);

        // Assign all roles to phaseAdmin
        bool[] memory roles = new bool[](4);
        roles[0] = true; // PHASE_ADMIN_ROLE
        roles[1] = true; // TOKEN_MINTER_ROLE
        roles[2] = true; // TOKEN_BURNER_ROLE
        roles[3] = true; // FREEZER_ROLE

        efarm.assignRoles(phaseAdmin, roles);

        // Check if the roles were assigned correctly
        assertTrue(efarm.hasRole(PHASE_ADMIN_ROLE, phaseAdmin));
        assertTrue(efarm.hasRole(efarm.TOKEN_MINTER_ROLE(), phaseAdmin));
        assertTrue(efarm.hasRole(efarm.TOKEN_BURNER_ROLE(), phaseAdmin));
        assertTrue(efarm.hasRole(keccak256("FREEZER_ROLE"), phaseAdmin));

        vm.stopPrank();
    }

    function testFreezingAndUnfreezingContract() public {
        vm.startPrank(admin);
        bool[] memory roles = new bool[](4);
        roles[3] = true; // FREEZER_ROLE
        efarm.assignRoles(admin, roles);
        vm.stopPrank();

        vm.startPrank(admin);
        efarm.freezeContract();
        vm.expectRevert("Contract is frozen");
        efarm.mint(admin, 1000 * (10 ** 18));
        vm.stopPrank();

        // Unfreeze the contract and try the action again
        vm.startPrank(admin);
        efarm.unfreezeContract();
        efarm.mint(admin, 1000 * (10 ** 18));
        assertEq(efarm.balanceOf(admin), efarm.INITIAL_SUPPLY() + 1000 * (10 ** 18));
        vm.stopPrank();
    }

    function testOnlyFreezerRoleCanFreeze() public {
        vm.startPrank(admin);
        bool[] memory roles = new bool[](4);
        roles[3] = true; // FREEZER_ROLE
        efarm.assignRoles(admin, roles);
        vm.stopPrank();

        // Try to freeze the contract with a non-freezer role
        address nonFreezer = vm.addr(0xabcdef);
        vm.startPrank(nonFreezer);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", nonFreezer, keccak256("FREEZER_ROLE")
            )
        );
        efarm.freezeContract();
        vm.stopPrank();
    }

    function testOnlyPhaseAdminCanSetPhaseLimits() public {
        address phaseAdmin = vm.addr(0x1);

        // Assign PHASE_ADMIN_ROLE to phaseAdmin using the new function
        vm.startPrank(admin);
        bool[] memory roles = new bool[](4);
        roles[0] = true; // PHASE_ADMIN_ROLE
        efarm.assignRoles(phaseAdmin, roles);
        vm.stopPrank();

        uint8[] memory phases = new uint8[](2);
        uint256[] memory limits = new uint256[](2);
        phases[0] = uint8(0);
        phases[1] = uint8(1);
        limits[0] = uint256(100);
        limits[1] = uint256(1000);

        // Non-phase admin should fail
        address nonPhaseAdmin = vm.addr(0x2);
        vm.startPrank(nonPhaseAdmin);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", nonPhaseAdmin, efarm.PHASE_ADMIN_ROLE()
            )
        );
        efarm.setPhaseLimits(phases, limits);
        vm.stopPrank();

        // Phase admin should succeed
        vm.startPrank(phaseAdmin);
        efarm.setPhaseLimits(phases, limits);
        vm.stopPrank();

        assertEq(efarm.phaseLimit(0), 100);
        assertEq(efarm.phaseLimit(1), 1000);
    }

    function testOnlyMinterCanMint() public {
        address minter = vm.addr(0x2);

        // Assign TOKEN_MINTER_ROLE to minter using the new function
        vm.startPrank(admin);
        bool[] memory roles = new bool[](4);
        roles[1] = true; // TOKEN_MINTER_ROLE
        efarm.assignRoles(minter, roles);
        vm.stopPrank();

        uint256 mintAmount = 1000 * (10 ** 18);

        // Non-minter should fail
        address nonMinter = vm.addr(0x4);
        vm.startPrank(nonMinter);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", nonMinter, efarm.TOKEN_MINTER_ROLE()
            )
        );
        efarm.mint(nonMinter, mintAmount);
        vm.stopPrank();

        // Minter should succeed
        vm.startPrank(minter);
        efarm.mint(minter, mintAmount);
        vm.stopPrank();

        assertEq(efarm.balanceOf(minter), mintAmount);
    }

    function testOnlyBurnerCanBurn() public {
        address burner = vm.addr(0x3);

        // Assign TOKEN_BURNER_ROLE to burner using the new function
        vm.startPrank(admin);
        bool[] memory roles = new bool[](4);
        roles[2] = true; // TOKEN_BURNER_ROLE
        efarm.assignRoles(burner, roles);
        efarm.mint(burner, 1000 * (10 ** 18)); // Mint tokens to burner for burning
        vm.stopPrank();

        uint256 burnAmount = 500 * (10 ** 18);

        // Non-burner should fail
        address nonBurner = vm.addr(0x4);
        vm.startPrank(nonBurner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", nonBurner, efarm.TOKEN_BURNER_ROLE()
            )
        );
        efarm.burn(burnAmount);
        vm.stopPrank();

        // Burner should succeed
        vm.startPrank(burner);
        efarm.burn(burnAmount);
        vm.stopPrank();

        assertEq(efarm.balanceOf(burner), 500 * (10 ** 18)); // 1000 - 500
    }
}
