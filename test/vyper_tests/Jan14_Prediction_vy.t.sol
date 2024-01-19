// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Prediction} from "../../src/Jan14_Prediction.sol";
import "vyper/VyperDeployer.sol";

contract PredictionTest is Test {
    address alice;
    address bob;

    VyperDeployer vyperDeployer = new VyperDeployer();
    
    Prediction private prediction;

    function setUp() public {
        prediction = Prediction(vyperDeployer.deployContract("Jan14_Prediction"));

        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function testPredict() public {
        vm.prank(bob);
        uint256 predId = prediction.createPrediction(keccak256(bytes("hello")));
        bool revealed = prediction.revealPrediction(predId, "hello"); // revealable by anyone, this isnt being called by bob
        assert(revealed);
    }
    function testPredictFail() public {
        vm.prank(bob);
        uint256 predId = prediction.createPrediction(keccak256(bytes("hello")));

        vm.expectRevert("Empty prediction");
        prediction.revealPrediction(predId, "");

        vm.expectRevert("Wrong reveal");
        prediction.revealPrediction(predId, "abcde");

        bool revealed = prediction.revealPrediction(predId, "hello");
        assert(revealed);
        
        vm.expectRevert("Prediction already set");
        prediction.revealPrediction(predId, "hello");
    }
}