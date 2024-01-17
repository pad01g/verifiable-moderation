// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    function stringsEquals(string memory s1, string memory s2) private pure returns (bool) {
    bytes memory b1 = bytes(s1);
    bytes memory b2 = bytes(s2);
    uint256 l1 = b1.length;
    if (l1 != b2.length) return false;
    for (uint256 i=0; i<l1; i++) {
        if (b1[i] != b2[i]) return false;
    }
    return true;
}
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
    require(stringsEquals(vote.target[msg.sender], "") || !stringsEquals(vote.target[msg.sender], "YES"), "Already voted.");
    require(balanceOf(msg.sender) > 0, "No tokens to vote.");

    if (_voteYes) {
        vote.yesCount += balanceOf(msg.sender);
        vote.target[msg.sender] = "YES";
    } else {
        vote.noCount += balanceOf(msg.sender);
        vote.target[msg.sender] = "NO";
    }
    }
}
