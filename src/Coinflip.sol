// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DirectFundingConsumer} from "./DirectFundingConsumer.sol";

interface LinkTokenInterface {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

/**
 * Coinflip contract that integrates with the Chainlink VRF system using DirectFundingConsumer
 */
contract Coinflip is Ownable {
    // A map of the player and their corresponding requestId
    mapping(address => uint256) public playerRequestID;
    // A map that stores the player's 3 Coinflip guesses
    mapping(address => uint8[3]) public bets;
    // A map that tracks the randomness fulfillment status for each request
    mapping(uint256 => bool) public requestFulfilled;
    // A map that stores the random numbers generated for each request
    mapping(uint256 => uint8[3]) public randomNumbers;
    // An instance of the random number requestor (VRF)
    DirectFundingConsumer private vrfRequestor;

    /// @dev Constructor to initialize the Coinflip contract and set the owner
    constructor() Ownable(msg.sender) {
        vrfRequestor = new DirectFundingConsumer(); // Deploys a new VRF requestor automatically
    }

    /// @notice Fund the VRF instance with 5 LINK tokens.
    /// @return boolean indicating whether the funding was successful
    function fundOracle() external returns (bool) {
        address LINK_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Sepolia LINK Address
        uint256 amount = 5 * 10**18; // 5 LINK tokens
        LinkTokenInterface link = LinkTokenInterface(LINK_ADDRESS);
        require(link.transfer(address(vrfRequestor), amount), "LINK transfer failed");
        return true;
    }

    /// @notice User guesses THREE flips, either a 1 or a 0.
    /// @param guess 3 guesses - each must be either 1 or 0
    function userInput(uint8[3] calldata guess) external {
        for (uint8 i = 0; i < 3; i++) {
            require(guess[i] == 0 || guess[i] == 1, "Each guess must be 0 or 1");
        }

        bets[msg.sender] = guess;
        uint256 requestId = vrfRequestor.requestRandomWords(false);
        playerRequestID[msg.sender] = requestId;
    }

    /// @notice Check if the randomness has been fulfilled for the current request
    function checkStatus() external view returns (bool) {
        uint256 requestId = playerRequestID[msg.sender];
        require(requestId != 0, "No request found");
        
        // Ensure the VRF request has been fulfilled
        (, bool fulfilled, ) = vrfRequestor.getRequestStatus(requestId);
        require(fulfilled, "Randomness not fulfilled yet");

        return fulfilled;
    }

    /// @notice Determine if the user's guess matches the random flip outcome
    function determineFlip() external view returns (bool) {
        uint256 requestId = playerRequestID[msg.sender];
        (, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(requestId);
        require(requestFulfilled[requestId], "Random number not fulfilled yet");

        uint8[3] memory userGuess = bets[msg.sender];
        uint8[3] memory flips = randomNumbers[requestId];

        return (userGuess[0] == flips[0] && userGuess[1] == flips[1] && userGuess[2] == flips[2]);
    }



    
}




