pragma solidity ^0.5.16;

pragma experimental ABIEncoderV2;

import "../../contracts/Staking/AquariusStaking.sol";

contract AquariusStakingHarness is AquariusStaking {
    
    constructor() AquariusStaking() public {}

}
