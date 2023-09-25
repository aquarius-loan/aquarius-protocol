pragma solidity ^0.5.16;

interface IIncentivesController {

    /**
     * @dev Called by the corresponding asset on any update that affects the rewards distribution
     * @param isSupply Specifying if supplying action or not
     * @param user The address of the user
     **/
    function handleActionBefore(bool isSupply, address user) external;

    /**
     * @dev Called by the corresponding asset on any update that affects the rewards distribution
     * @param isSupply Specifying if supplying action or not
     * @param user The address of the user
     * @param userBalance The balance of the user of the asset in the lending pool
     * @param totalSupply The total supply of the asset in the lending pool
     **/
    function handleActionAfter(bool isSupply, address user, uint256 userBalance, uint256 totalSupply) external;
}

interface IIncentivesComptroller {

    function incentivesController() external view returns(IIncentivesController);
}
