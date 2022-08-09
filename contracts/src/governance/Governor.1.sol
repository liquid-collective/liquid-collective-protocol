//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./GovernanceToken.1.sol";
import "./Timelock.sol";

/// @title Governor (v1)
/// @author Figment
/// @notice This contract accepts proposals to change important values in River, and executes
///         them after running an election for them, where votes are are weighted based on the
///         accompanying token
///         Heavily inspired by Uniswap governance: github.com/Uniswap/governance/tree/master/contracts
///         TODO - optimise, this uses uint256 where it could be using uint96. This is because the token
///         contract has been simplified to do the same thing.
contract GovernorV1 {
    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    function quorumVotes() public pure returns (uint256) {
        return 40_000_000e18;
    } // 4% of rGOV

    /// @notice The number of votes required in order for a voter to become a proposer
    function proposalThreshold() public pure returns (uint256) {
        return 1;
    }

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint256) {
        return 10;
    } // 10 actions

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint256) {
        return 1;
    } // 1 block

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure returns (uint256) {
        return 40_320;
    } // ~7 days in blocks (assuming 15s blocks)

    /// @notice The address of the Timelock
    Timelock public timelock;

    /// @notice The address of the governance token
    GovernanceTokenV1 public governanceToken;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;
        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        /// @notice The ordered list of function selectors to be called
        string[] selectors;
        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;
        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;
    }

    /// @notice Receipts of ballots for the entire set of voters, for each proposalId
    mapping(uint256 => mapping(address => Receipt)) public receipts;

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal
        bool support;
        /// @notice The number of votes the voter had, which were cast
        uint256 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending, // before startBlock
        Active, // between startBlock and endBlock
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    mapping(uint256 => Proposal) public proposals;

    uint256 public proposalCount;

    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);
    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);
    event ProposalCanceled(uint256 id);

    event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);

    constructor(address timelock_, address governanceToken_) {
        timelock = Timelock(timelock_);
        governanceToken = GovernanceTokenV1(governanceToken_);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory selectors,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(
            targets.length == values.length && targets.length == selectors.length && targets.length == calldatas.length,
            "Proposal function information arity mismatch"
        );
        require(targets.length != 0, "Must provide actions");
        require(targets.length <= proposalMaxOperations(), "Too many actions");

        uint256 startBlock = block.number + votingDelay();
        uint256 endBlock = startBlock + votingPeriod();
        proposalCount++;
        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            targets: targets,
            values: values,
            selectors: selectors,
            calldatas: calldatas,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            canceled: false,
            executed: false
        });

        proposals[newProposal.id] = newProposal;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            selectors,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        return newProposal.id;
    }

    function queue(uint256 proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(proposal.targets[i], proposal.values[i], proposal.selectors[i], proposal.calldatas[i], eta);
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function _queueOrRevert(
        address target,
        uint256 value,
        string memory selector,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !timelock.queuedTransactions(keccak256(abi.encode(target, value, selector, data, eta))),
            "Proposal action already queued at eta"
        );
        timelock.queueTransaction(target, value, selector, data, eta);
    }

    function execute(uint256 proposalId) public payable {
        require(state(proposalId) == ProposalState.Queued, "Proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction{value: proposal.values[i]}(
                proposal.targets[i],
                proposal.values[i],
                proposal.selectors[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    // TODO this looks like its saying that a proposer can cancel if their votes are under some threshold;
    //      why not just make it so any non-passed proposal is cancellable, or maybe any non-executed one
    //      by the propser? or even a new election for cancelling queued proposals?
    function cancel(uint256 proposalId) public {
        ProposalState proposalState = state(proposalId);
        require(proposalState != ProposalState.Executed, "Cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];
        require(
            governanceToken.getPriorVotes(proposal.proposer, block.number - 1) < proposalThreshold(),
            "Proposer above threshold"
        );

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.selectors[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    function getActions(uint256 proposalId)
        public
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.selectors, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) public view returns (Receipt memory) {
        return receipts[proposalId][voter];
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "Invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes()) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function castVote(uint256 proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    function _castVote(
        address voter,
        uint256 proposalId,
        bool support
    ) internal {
        require(state(proposalId) == ProposalState.Active, "Voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = receipts[proposalId][voter];
        require(receipt.hasVoted == false, "Voter already voted");
        uint256 votes = governanceToken.getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes -= votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }
}
