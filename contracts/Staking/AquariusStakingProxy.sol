pragma solidity ^0.5.16;
import "./AquariusStakingStorage.sol";

/**
 * @title AquariusStakingProxy
 * @dev Storage for the aquarius staking is at this address, while execution is delegated to the `aquariusStakingImplementation`.
 */
contract AquariusStakingProxy is AquariusStakingProxyAdminStorage {

    /**
      * @notice Emitted when pendingAquariusStakingImplementation is changed
      */
    event NewPendingImplementation(address oldPendingImplementation, address newPendingImplementation);

    /**
      * @notice Emitted when pendingAquariusStakingImplementation is accepted, which means aquariusStaking implementation is updated
      */
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
      * @notice Emitted when pendingAdmin is changed
      */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
      * @notice Emitted when pendingAdmin is accepted, which means admin is updated
      */
    event NewAdmin(address oldAdmin, address newAdmin);

    constructor() public {
        // Set admin to caller
        admin = msg.sender;
    }

    /*** Admin Functions ***/
    function _setPendingImplementation(address newPendingImplementation) public {
        require(msg.sender == admin, "SET_PENDING_IMPLEMENTATION_OWNER_CHECK");

        address oldPendingImplementation = pendingAquariusStakingImplementation;

        pendingAquariusStakingImplementation = newPendingImplementation;

        emit NewPendingImplementation(oldPendingImplementation, pendingAquariusStakingImplementation);
    }

    /**
    * @notice Accepts new implementation of aquariusStaking. msg.sender must be pendingImplementation
    * @dev Admin function for new implementation to accept it's role as implementation
    */
    function _acceptImplementation() public {
        // Check caller is pendingImplementation and pendingImplementation ≠ address(0)
        require(msg.sender == pendingAquariusStakingImplementation && pendingAquariusStakingImplementation != address(0), "ACCEPT_PENDING_IMPLEMENTATION_ADDRESS_CHECK");

        // Save current values for inclusion in log
        address oldImplementation = aquariusStakingImplementation;
        address oldPendingImplementation = pendingAquariusStakingImplementation;

        aquariusStakingImplementation = pendingAquariusStakingImplementation;

        pendingAquariusStakingImplementation = address(0);

        emit NewImplementation(oldImplementation, aquariusStakingImplementation);
        emit NewPendingImplementation(oldPendingImplementation, pendingAquariusStakingImplementation);
    }

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address newPendingAdmin) public {
        require(msg.sender == admin, "SET_PENDING_ADMIN_OWNER_CHECK");

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() public {
        require(msg.sender == pendingAdmin && msg.sender != address(0), "ACCEPT_ADMIN_PENDING_ADMIN_CHECK");

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    /**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    function () external payable {
        // delegate all other functions to current implementation
        (bool success, ) = aquariusStakingImplementation.delegatecall(msg.data);

        assembly {
              let free_mem_ptr := mload(0x40)
              returndatacopy(free_mem_ptr, 0, returndatasize)

              switch success
              case 0 { revert(free_mem_ptr, returndatasize) }
              default { return(free_mem_ptr, returndatasize) }
        }
    }
}
