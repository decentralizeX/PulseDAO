// SPDX-License-Identifier: NONE
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.8.0. SEE SOURCE BELOW. !!
pragma solidity ^0.8.20;

interface IMasterChef {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event TransferCredit(address from, address to, uint256 amount);
    event TrustedContract(address contractAddress, bool setting);
    event UpdateEmissions(address indexed user, uint256 newEmissions);

    function DTXPerBlock() external view returns (uint256);

    function add(
        uint256 _allocPoint,
        address _participant,
        bool _withUpdate
    ) external;

    function burn(address _from, uint256 _amount) external returns (bool);

    function credit(address) external view returns (uint256);

    function dev(address _devaddr) external;

    function devaddr() external view returns (address);

    function dtx() external view returns (address);

    function existingParticipant(address) external view returns (bool);

    function fairMintSenate() external;

    function fairTokensPublishedToSenate() external view returns (uint256);

    function feeAddress() external view returns (address);

    function governorFee() external view returns (uint256);

    function massAdd(
        uint256[] memory _allocPoint,
        address[] memory _participant,
        bool[] memory _withUpdate
    ) external;

    function massUpdatePools() external;

    function owner() external view returns (address);

    function pendingDtx(uint256 _pid) external view returns (uint256);

    function poolInfo(uint256)
        external
        view
        returns (
            uint256 allocPoint,
            uint256 lastRewardBlock,
            address participant
        );

    function poolLength() external view returns (uint256);

    function publishTokens(address _to, uint256 _amount) external;

    function renounceOwnership() external;

    function renounceRewards() external;

    function rewardSenators(bool _e) external;

    function senatorRewards() external view returns (bool);

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external;

    function setFeeAddress(address _feeAddress) external;

    function setGovernorFee(uint256 _amount) external;

    function setTrustedContract(address _contractAddress, bool _setting)
        external;

    function startBlock() external view returns (uint256);

    function startPublishing(
        uint256 _pid,
        address _participant,
        uint256 _alloc
    ) external;

    function stopPublishing(uint256 _pid) external;

    function tokenChangeOwnership(address _newOwner) external;

    function totalAllocPoint() external view returns (uint256);

    function totalCreditRewards() external view returns (uint256);

    function totalCreditRewardsAtLastFairMint() external view returns (uint256);

    function totalPrincipalBurned() external view returns (uint256);

    function totalPublished() external view returns (uint256);

    function transferCredit(address _to, uint256 _amount) external;

    function transferOwnership(address newOwner) external;

    function trustedContract(address) external view returns (bool);

    function trustedContractCount() external view returns (uint256);

    function updateEmissionRate(uint256 _DTXPerBlock) external;

    function updatePool(uint256 _pid) external;

    function updateStartBlock(uint256 _startBlock) external;

    function virtualTotalSupply() external view returns (uint256);
}

// THIS FILE WAS AUTOGENERATED FROM THE FOLLOWING ABI JSON:
/*
[{"inputs":[{"internalType":"contract IDTX","name":"_DTX","type":"address"},{"internalType":"address","name":"_airdropFull","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"previousOwner","type":"address"},{"indexed":true,"internalType":"address","name":"newOwner","type":"address"}],"name":"OwnershipTransferred","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"from","type":"address"},{"indexed":false,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"}],"name":"TransferCredit","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"contractAddress","type":"address"},{"indexed":false,"internalType":"bool","name":"setting","type":"bool"}],"name":"TrustedContract","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"user","type":"address"},{"indexed":false,"internalType":"uint256","name":"newEmissions","type":"uint256"}],"name":"UpdateEmissions","type":"event"},{"inputs":[],"name":"DTXPerBlock","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_allocPoint","type":"uint256"},{"internalType":"address","name":"_participant","type":"address"},{"internalType":"bool","name":"_withUpdate","type":"bool"}],"name":"add","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_from","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"burn","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"credit","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_devaddr","type":"address"}],"name":"dev","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"devaddr","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"dtx","outputs":[{"internalType":"contract IDTX","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"existingParticipant","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"fairMintSenate","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"fairTokensPublishedToSenate","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"feeAddress","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"governorFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256[]","name":"_allocPoint","type":"uint256[]"},{"internalType":"address[]","name":"_participant","type":"address[]"},{"internalType":"bool[]","name":"_withUpdate","type":"bool[]"}],"name":"massAdd","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"massUpdatePools","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pid","type":"uint256"}],"name":"pendingDtx","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"poolInfo","outputs":[{"internalType":"uint256","name":"allocPoint","type":"uint256"},{"internalType":"uint256","name":"lastRewardBlock","type":"uint256"},{"internalType":"address","name":"participant","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"poolLength","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_to","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"publishTokens","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"renounceOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"renounceRewards","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bool","name":"_e","type":"bool"}],"name":"rewardSenators","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"senatorRewards","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pid","type":"uint256"},{"internalType":"uint256","name":"_allocPoint","type":"uint256"},{"internalType":"bool","name":"_withUpdate","type":"bool"}],"name":"set","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_feeAddress","type":"address"}],"name":"setFeeAddress","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"setGovernorFee","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_contractAddress","type":"address"},{"internalType":"bool","name":"_setting","type":"bool"}],"name":"setTrustedContract","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"startBlock","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pid","type":"uint256"},{"internalType":"address","name":"_participant","type":"address"},{"internalType":"uint256","name":"_alloc","type":"uint256"}],"name":"startPublishing","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pid","type":"uint256"}],"name":"stopPublishing","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_newOwner","type":"address"}],"name":"tokenChangeOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"totalAllocPoint","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalCreditRewards","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalCreditRewardsAtLastFairMint","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalPrincipalBurned","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalPublished","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_to","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"transferCredit","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"newOwner","type":"address"}],"name":"transferOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"trustedContract","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"trustedContractCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_DTXPerBlock","type":"uint256"}],"name":"updateEmissionRate","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_pid","type":"uint256"}],"name":"updatePool","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_startBlock","type":"uint256"}],"name":"updateStartBlock","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"virtualTotalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]
*/
