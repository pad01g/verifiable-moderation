// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
    {
        _mint(msg.sender, 100 * 10**uint(decimals()));
    }

    struct Vote {
        bool isOpen;
        uint256 yesCount;
        uint256 noCount;
        mapping(address => string) target;
    }

    Vote private vote;

    function startVote() public {
        require(!vote.isOpen, "Vote already in progress.");
        vote.isOpen = true;
        vote.yesCount = 0;
        vote.noCount = 0;
    }

    function endVote() public returns (bool) {
        require(vote.isOpen, "No vote in progress.");
        vote.isOpen = false;

        return vote.yesCount > vote.noCount;
    }

    function castVote(bool _voteYes) public {
        require(vote.isOpen, "No vote in progress.");
        require(vote.target[msg.sender]=="NO", "Already YES.");
        require(balanceOf(msg.sender) > 0, "No tokens to vote.");

        if (_voteYes) {
            vote.yesCount += balanceOf(msg.sender);
        } else {
            vote.noCount += balanceOf(msg.sender);
        }

        vote.target[msg.sender] = "YES";
    }
}
