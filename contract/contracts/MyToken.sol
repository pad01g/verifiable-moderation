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
        mapping(address => string) tmpTarget;
    }

    Vote private vote;
    string private currentQuestion;
    address[] private voters;

    function startVote(string memory question) public {
        require(!vote.isOpen, "Vote already in progress.");
        vote.isOpen = true;
        vote.yesCount = 0;
        vote.noCount = 0;
        currentQuestion = question;
        delete voters;
    }

    function endVote() public returns (bool) {
        require(vote.isOpen, "No vote in progress.");
        bool result = vote.yesCount > vote.noCount;
        vote.isOpen = false;
        if (result) {
            for (uint i = 0; i < voters.length; i++) {
                vote.target[voters[i]] = vote.tmpTarget[voters[i]];
            }
        }
        for (uint i = 0; i < voters.length; i++) {
            delete vote.tmpTarget[voters[i]];
        }
        delete voters;
        return result;
    }

    function castVote(bool _voteYes) public {
        require(vote.isOpen, "No vote in progress.");
        require(stringsEquals(vote.tmpTarget[msg.sender], ""), "Already voted.");
        require(balanceOf(msg.sender) > 0, "No tokens to vote.");

        voters.push(msg.sender);

        if (_voteYes) {
            vote.yesCount += balanceOf(msg.sender);
            vote.tmpTarget[msg.sender] = "YES";
        } else {
            vote.noCount += balanceOf(msg.sender);
            vote.tmpTarget[msg.sender] = "NO";
        }
    }

    function getCurrentQuestion() public view returns (string memory) {
        require(vote.isOpen, "No vote in progress.");
        return currentQuestion;
    }
}
