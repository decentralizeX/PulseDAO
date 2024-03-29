// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.8.0. SEE SOURCE BELOW. !!
pragma solidity >=0.7.0 <0.9.0;

interface IConsensus {
    event AddVotes(
        uint256 _type,
        uint256 proposalID,
        address indexed voter,
        uint256 tokensSacrificed,
        bool _for
    );
    event ChangeGovernor(
        uint256 proposalID,
        address indexed enforcer,
        bool status
    );
    event ProposeGovernor(
        uint256 proposalID,
        address newGovernor,
        address indexed enforcer
    );
    event TreasuryEnforce(
        uint256 indexed proposalID,
        address indexed enforcer,
        bool isSuccess
    );
    event TreasuryProposal(
        uint256 indexed proposalID,
        uint256 sacrificedTokens,
        address tokenAddress,
        address recipient,
        uint256 amount,
        uint256 consensusVoteID,
        address indexed enforcer,
        uint256 delay
    );

    function approveTreasuryTransfer(uint256 proposalID) external;

    function changeGovernor(uint256 proposalID) external;

    function consensusProposal(uint256)
        external
        view
        returns (
            uint16 typeOfChange,
            address beneficiaryAddress,
            uint256 timestamp
        );

    function creditContract() external view returns (address);

    function enforceGovernor(uint256 proposalID) external;

    function governorCount() external view returns (uint256);

    function highestConsensusVotes(uint256) external view returns (uint256);

    function initiateTreasuryTransferProposal(
        uint256 depositingTokens,
        address tokenAddress,
        address recipient,
        uint256 amountToSend,
        uint256 delay
    ) external;

    function isContract(address _address) external view returns (bool);

    function isGovInvalidated(address)
        external
        view
        returns (bool isInvalidated, bool hasPassed);

    function killTreasuryTransferProposal(uint256 proposalID) external;

    function owner() external view returns (address);

    function proposalLengths() external view returns (uint256, uint256);

    function proposeGovernor(address _newGovernor) external;

    function senateVeto(uint256 proposalID) external;

    function senateVetoTreasury(uint256 proposalID) external;

    function syncCreditContract() external;

    function syncOwner() external;

    function token() external view returns (address);

    function tokensCastedPerVote(uint256 _forID)
        external
        view
        returns (uint256);

    function totalDTXStaked() external view returns (uint256);

    function treasuryProposal(uint256)
        external
        view
        returns (
            bool valid,
            uint256 firstCallTimestamp,
            uint256 valueSacrificedForVote,
            uint256 valueSacrificedAgainst,
            uint256 delay,
            address tokenAddress,
            address beneficiary,
            uint256 amountToSend,
            uint256 consensusProposalID
        );

    function treasuryRequestsCount() external view returns (uint256);

    function updateHighestConsensusVotes(uint256 consensusID) external;

    function vetoGovernor(uint256 proposalID, bool _withUpdate) external;

    function vetoGovernor2(uint256 proposalID, bool _withUpdate) external;

    function vetoTreasuryTransferProposal(uint256 proposalID) external;

    function voteTreasuryTransferProposalN(
        uint256 proposalID,
        uint256 withTokens,
        bool withAction
    ) external;

    function voteTreasuryTransferProposalY(
        uint256 proposalID,
        uint256 withTokens
    ) external;
}

// THIS FILE WAS AUTOGENERATED FROM THE FOLLOWING ABI JSON:
/*
[{"inputs":[{"internalType":"address","name":"_DTX","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"_type","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"proposalID","type":"uint256"},{"indexed":true,"internalType":"address","name":"voter","type":"address"},{"indexed":false,"internalType":"uint256","name":"tokensSacrificed","type":"uint256"},{"indexed":false,"internalType":"bool","name":"_for","type":"bool"}],"name":"AddVotes","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"proposalID","type":"uint256"},{"indexed":true,"internalType":"address","name":"enforcer","type":"address"},{"indexed":false,"internalType":"bool","name":"status","type":"bool"}],"name":"ChangeGovernor","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"proposalID","type":"uint256"},{"indexed":false,"internalType":"address","name":"newGovernor","type":"address"},{"indexed":true,"internalType":"address","name":"enforcer","type":"address"}],"name":"ProposeGovernor","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"proposalID","type":"uint256"},{"indexed":true,"internalType":"address","name":"enforcer","type":"address"},{"indexed":false,"internalType":"bool","name":"isSuccess","type":"bool"}],"name":"TreasuryEnforce","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"proposalID","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"sacrificedTokens","type":"uint256"},{"indexed":false,"internalType":"address","name":"tokenAddress","type":"address"},{"indexed":false,"internalType":"address","name":"recipient","type":"address"},{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"consensusVoteID","type":"uint256"},{"indexed":true,"internalType":"address","name":"enforcer","type":"address"},{"indexed":false,"internalType":"uint256","name":"delay","type":"uint256"}],"name":"TreasuryProposal","type":"event"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"}],"name":"approveTreasuryTransfer","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"}],"name":"changeGovernor","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"consensusProposal","outputs":[{"internalType":"uint16","name":"typeOfChange","type":"uint16"},{"internalType":"address","name":"beneficiaryAddress","type":"address"},{"internalType":"uint256","name":"timestamp","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"creditContract","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"}],"name":"enforceGovernor","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"governorCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"highestConsensusVotes","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"depositingTokens","type":"uint256"},{"internalType":"address","name":"tokenAddress","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amountToSend","type":"uint256"},{"internalType":"uint256","name":"delay","type":"uint256"}],"name":"initiateTreasuryTransferProposal","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_address","type":"address"}],"name":"isContract","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"isGovInvalidated","outputs":[{"internalType":"bool","name":"isInvalidated","type":"bool"},{"internalType":"bool","name":"hasPassed","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"}],"name":"killTreasuryTransferProposal","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"proposalLengths","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_newGovernor","type":"address"}],"name":"proposeGovernor","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"}],"name":"senateVeto","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"}],"name":"senateVetoTreasury","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"syncCreditContract","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"syncOwner","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"token","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_forID","type":"uint256"}],"name":"tokensCastedPerVote","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalDTXStaked","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"treasuryProposal","outputs":[{"internalType":"bool","name":"valid","type":"bool"},{"internalType":"uint256","name":"firstCallTimestamp","type":"uint256"},{"internalType":"uint256","name":"valueSacrificedForVote","type":"uint256"},{"internalType":"uint256","name":"valueSacrificedAgainst","type":"uint256"},{"internalType":"uint256","name":"delay","type":"uint256"},{"internalType":"address","name":"tokenAddress","type":"address"},{"internalType":"address","name":"beneficiary","type":"address"},{"internalType":"uint256","name":"amountToSend","type":"uint256"},{"internalType":"uint256","name":"consensusProposalID","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"treasuryRequestsCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"consensusID","type":"uint256"}],"name":"updateHighestConsensusVotes","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"},{"internalType":"bool","name":"_withUpdate","type":"bool"}],"name":"vetoGovernor","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"},{"internalType":"bool","name":"_withUpdate","type":"bool"}],"name":"vetoGovernor2","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"}],"name":"vetoTreasuryTransferProposal","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"},{"internalType":"uint256","name":"withTokens","type":"uint256"},{"internalType":"bool","name":"withAction","type":"bool"}],"name":"voteTreasuryTransferProposalN","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"proposalID","type":"uint256"},{"internalType":"uint256","name":"withTokens","type":"uint256"}],"name":"voteTreasuryTransferProposalY","outputs":[],"stateMutability":"nonpayable","type":"function"}]
*/
