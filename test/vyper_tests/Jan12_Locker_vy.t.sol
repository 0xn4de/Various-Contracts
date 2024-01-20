// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Locker} from "../../src/Jan12_Locker.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "vyper/VyperDeployer.sol";

contract LockerTest is Test {
    address alice;
    address bob;
    address charlie;
    IERC20 usdc;
    
    VyperDeployer vyperDeployer = new VyperDeployer();
    Locker private locker;

    function setUp() public {
        // Vyper contract wont be deployed in a fork
        // TODO(figure out why, fix)
        //vm.createSelectFork(vm.rpcUrl('mainnet'), 18800000);
        locker = Locker(vyperDeployer.deployContract("Jan12_Locker"));
        
        usdc = IERC20(address(new MockERC20("testUSDC", "USDC", 6)));

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        deal(address(usdc), bob, 10000*1e6);
        vm.prank(bob);
        usdc.approve(address(locker), type(uint256).max);
        vm.makePersistent(address(usdc));

    }
    function testDeposit() public {
        vm.startPrank(bob);
        locker.deposit(address(usdc), 1000*1e6, 365 days, address(alice));
        locker.deposit{value: 1 ether}(address(0), 1 ether, 365 days, address(alice));
        vm.stopPrank();
    }
    function testDepositAndWithdraw() public {
        vm.startPrank(bob);
        uint256 vestingId = locker.deposit(address(usdc), 1000*1e6, 365 days, address(alice));
        uint256 vestingId2 = locker.deposit{value: 1 ether}(address(0), 1 ether, 365 days, address(alice));
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days);
        uint256 aliceEthBefore = alice.balance;
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        vm.startPrank(alice);
        locker.withdraw(vestingId);
        locker.withdraw(vestingId2);
        vm.stopPrank();
        assertEq(alice.balance-aliceEthBefore, 1 ether);
        assertEq(usdc.balanceOf(alice)-aliceUsdcBefore, 1000*1e6);
    }
    function testDepositReverts() public {
        vm.startPrank(bob);
        vm.expectRevert("Invalid deposit"); // amount set to 0 
        locker.deposit(address(usdc), 0, 365 days, address(alice));
        vm.expectRevert("Invalid deposit"); // vesting duration set to 0
        locker.deposit(address(usdc), 1, 0, address(alice));
        vm.expectRevert("Wrong value sent"); // vesting duration set to 0
        locker.deposit(address(0), 1 ether, 365 days, address(alice));

        usdc.approve(address(locker), 0);
        vm.expectRevert(); // no token approval
        locker.deposit(address(usdc), 1, 365 days, address(alice));
        vm.stopPrank();
    }
    function testWithdrawReverts() public {
        vm.startPrank(bob);
        uint256 vestingId = locker.deposit(address(usdc), 1000*1e6, 365 days, address(alice));
        uint256 vestingId2 = locker.deposit{value: 1 ether}(address(0), 1 ether, 365 days, address(alice));
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert("Vesting period not over");
        locker.withdraw(vestingId);

        vm.warp(block.timestamp + 365 days);

        vm.prank(charlie);
        vm.expectRevert("Not the beneficiary");
        locker.withdraw(vestingId);

        vm.startPrank(alice);
        locker.withdraw(vestingId2);
        vm.expectRevert("Already withdrawn");
        locker.withdraw(vestingId2);
    }
    function testBeneficiaryChange() public {
        vm.startPrank(bob);
        uint256 vestingId = locker.deposit(address(usdc), 1000*1e6, 365 days, address(alice));
        vm.stopPrank();

        vm.startPrank(alice);
        locker.changeBeneficiary(vestingId, charlie);
        vm.expectRevert("Not the beneficiary");
        locker.withdraw(vestingId); // no need to warp since it'll check beneficiary first
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        vm.prank(charlie);
        locker.withdraw(vestingId);
        assertEq(usdc.balanceOf(charlie), 1000*1e6);
    }
}