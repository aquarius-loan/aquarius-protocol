pragma solidity ^0.5.16;

import "../../contracts/IIncentivesController.sol";

contract IncentivesControllerMock is IIncentivesController {

    bool allowActionAfter = true;

    function setAllowActionAfter(bool allowed) public {
        allowActionAfter = allowed;
    }

    function handleActionBefore(bool isSupply, address user) external {}

    function handleActionAfter(bool isSupply, address user, uint256 userBalance, uint256 totalSupply) external {
        require(allowActionAfter, "IncentivesControllerMock: not allowed");
    }
}
