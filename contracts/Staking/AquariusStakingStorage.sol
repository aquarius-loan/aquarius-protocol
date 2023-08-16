pragma solidity ^0.5.16;

contract AquariusStakingProxyAdminStorage {
    /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
    * @notice Active brains of AquariusStakingProxy
    */
    address public aquariusStakingImplementation;

    /**
    * @notice Pending brains of AquariusStakingProxy
    */
    address public pendingAquariusStakingImplementation;
}

contract AquariusStakingG1Storage is AquariusStakingProxyAdminStorage {
}
