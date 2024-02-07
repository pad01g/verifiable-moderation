// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
    {
        _mint(msg.sender, 100 * 10**uint(decimals()));
    }

    enum VoteOption { NotVoted, Yes, No }

    struct Vote {
        bool isOpen;
        uint256 yesCount;
        uint256 noCount;
        mapping(address => VoteOption) votes;
    }

    Vote private vote;
    string private potentialQuestion;
    string private currentQuestion;
    address[] private voters;

    event VoteStarted(string question);
    event VoteEnded(bool result);
    event VoteCast(address voter, bool voteYes);

    function startVote(string memory question) public  {
        require(!vote.isOpen, "Vote already in progress.");
        vote.isOpen = true;
        vote.yesCount = 0;
        vote.noCount = 0;
        potentialQuestion = question;
        delete voters;
        emit VoteStarted(question);
    }

    function endVote() public  returns (bool) {
        require(vote.isOpen, "No vote in progress.");
        bool result = vote.yesCount > vote.noCount;
        vote.isOpen = false;
        if (result) {
            currentQuestion = potentialQuestion;
        }
        for (uint i = 0; i < voters.length; i++) {
            delete vote.votes[voters[i]];
        }
        delete voters;
        emit VoteEnded(result);
        return result;
    }

    function castVote(bool _voteYes) public {
        require(vote.isOpen, "No vote in progress.");
        require(vote.votes[msg.sender] == VoteOption.NotVoted, "Already voted.");
        require(balanceOf(msg.sender) > 0, "No tokens to vote.");

        voters.push(msg.sender);

        if (_voteYes) {
            vote.yesCount += balanceOf(msg.sender);
            vote.votes[msg.sender] = VoteOption.Yes;
        } else {
            vote.noCount += balanceOf(msg.sender);
            vote.votes[msg.sender] = VoteOption.No;
        }
        emit VoteCast(msg.sender, _voteYes);
    }

    function getCurrentQuestion() public view returns (string memory) {
        return currentQuestion;
    }
}
