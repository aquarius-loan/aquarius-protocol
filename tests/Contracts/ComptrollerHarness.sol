pragma solidity ^0.5.16;

import "../../contracts/Comptroller.sol";
import "../../contracts/PriceOracle.sol";

contract ComptrollerKovan is Comptroller {
  function getArsAddress() public view returns (address) {
    return 0x61460874a7196d6a22D1eE4922473664b3E95270;
  }
}

contract ComptrollerRopsten is Comptroller {
  function getArsAddress() public view returns (address) {
    return 0xf76D4a441E4ba86A923ce32B89AFF89dBccAA075;
  }
}

contract ComptrollerHarness is Comptroller {
    address arsAddress;
    uint public blockNumber;

    constructor() Comptroller() public {}

    function setPauseGuardian(address harnessedPauseGuardian) public {
        pauseGuardian = harnessedPauseGuardian;
    }

    function setArsSupplyState(address aToken, uint224 index, uint32 blockNumber_) public {
        arsSupplyState[aToken].index = index;
        arsSupplyState[aToken].block = blockNumber_;
    }

    function setArsBorrowState(address aToken, uint224 index, uint32 blockNumber_) public {
        arsBorrowState[aToken].index = index;
        arsBorrowState[aToken].block = blockNumber_;
    }

    function setArsAccrued(address user, uint userAccrued) public {
        arsAccrued[user] = userAccrued;
    }

    function setArsAddress(address arsAddress_) public {
        arsAddress = arsAddress_;
    }

    function getArsAddress() public view returns (address) {
        return arsAddress;
    }

    /**
     * @notice Set the amount of ARS distributed per block
     * @param arsRate_ The amount of ARS wei per block to distribute
     */
    function harnessSetArsRate(uint arsRate_) public {
        arsRate = arsRate_;
    }

    /**
     * @notice Recalculate and update ARS speeds for all ARS markets
     */
    function harnessRefreshArsSpeeds() public {
        AToken[] memory allMarkets_ = allMarkets;

        for (uint i = 0; i < allMarkets_.length; i++) {
            AToken aToken = allMarkets_[i];
            Exp memory borrowIndex = Exp({mantissa: aToken.borrowIndex()});
            updateArsSupplyIndex(address(aToken));
            updateArsBorrowIndex(address(aToken), borrowIndex);
        }

        Exp memory totalUtility = Exp({mantissa: 0});
        Exp[] memory utilities = new Exp[](allMarkets_.length);
        for (uint i = 0; i < allMarkets_.length; i++) {
            AToken aToken = allMarkets_[i];
            if (arsSupplySpeeds[address(aToken)] > 0 || arsBorrowSpeeds[address(aToken)] > 0) {
                Exp memory assetPrice = Exp({mantissa: oracle.getUnderlyingPrice(aToken)});
                Exp memory utility = mul_(assetPrice, aToken.totalBorrows());
                utilities[i] = utility;
                totalUtility = add_(totalUtility, utility);
            }
        }

        for (uint i = 0; i < allMarkets_.length; i++) {
            AToken aToken = allMarkets[i];
            uint newSpeed = totalUtility.mantissa > 0 ? mul_(arsRate, div_(utilities[i], totalUtility)) : 0;
            setArsSpeedInternal(aToken, newSpeed, newSpeed);
        }
    }

    function setArsBorrowerIndex(address aToken, address borrower, uint index) public {
        arsBorrowerIndex[aToken][borrower] = index;
    }

    function setArsSupplierIndex(address aToken, address supplier, uint index) public {
        arsSupplierIndex[aToken][supplier] = index;
    }

    function harnessDistributeAllBorrowerArs(address aToken, address borrower, uint marketBorrowIndexMantissa) public {
        distributeBorrowerArs(aToken, borrower, Exp({mantissa: marketBorrowIndexMantissa}));
        arsAccrued[borrower] = grantArsInternal(borrower, arsAccrued[borrower]);
    }

    function harnessDistributeAllSupplierArs(address aToken, address supplier) public {
        distributeSupplierArs(aToken, supplier);
        arsAccrued[supplier] = grantArsInternal(supplier, arsAccrued[supplier]);
    }

    function harnessUpdateArsBorrowIndex(address aToken, uint marketBorrowIndexMantissa) public {
        updateArsBorrowIndex(aToken, Exp({mantissa: marketBorrowIndexMantissa}));
    }

    function harnessUpdateArsSupplyIndex(address aToken) public {
        updateArsSupplyIndex(aToken);
    }

    function harnessDistributeBorrowerArs(address aToken, address borrower, uint marketBorrowIndexMantissa) public {
        distributeBorrowerArs(aToken, borrower, Exp({mantissa: marketBorrowIndexMantissa}));
    }

    function harnessDistributeSupplierArs(address aToken, address supplier) public {
        distributeSupplierArs(aToken, supplier);
    }

    function harnessTransferArs(address user, uint userAccrued, uint threshold) public returns (uint) {
        if (userAccrued > 0 && userAccrued >= threshold) {
            return grantArsInternal(user, userAccrued);
        }
        return userAccrued;
    }

    function harnessAddArsMarkets(address[] memory aTokens) public {
        for (uint i = 0; i < aTokens.length; i++) {
            // temporarily set arsSpeed to 1 (will be fixed by `harnessRefreshArsSpeeds`)
            setArsSpeedInternal(AToken(aTokens[i]), 1, 1);
        }
    }

    function harnessFastForward(uint blocks) public returns (uint) {
        blockNumber += blocks;
        return blockNumber;
    }

    function setBlockNumber(uint number) public {
        blockNumber = number;
    }

    function getBlockNumber() public view returns (uint) {
        return blockNumber;
    }

    function getArsMarkets() public view returns (address[] memory) {
        uint m = allMarkets.length;
        uint n = 0;
        for (uint i = 0; i < m; i++) {
            if (arsSupplySpeeds[address(allMarkets[i])] > 0 || arsBorrowSpeeds[address(allMarkets[i])] > 0) {
                n++;
            }
        }

        address[] memory arsMarkets = new address[](n);
        uint k = 0;
        for (uint i = 0; i < m; i++) {
            if (arsSupplySpeeds[address(allMarkets[i])] > 0 || arsBorrowSpeeds[address(allMarkets[i])] > 0) {
                arsMarkets[k++] = address(allMarkets[i]);
            }
        }
        return arsMarkets;
    }
}

contract ComptrollerBorked {
    function _become(Unitroller unitroller, PriceOracle _oracle, uint _closeFactorMantissa, uint _maxAssets, bool _reinitializing) public {
        _oracle;
        _closeFactorMantissa;
        _maxAssets;
        _reinitializing;

        require(msg.sender == unitroller.admin(), "only unitroller admin can change brains");
        unitroller._acceptImplementation();
    }
}

contract BoolComptroller is ComptrollerInterface {
    bool allowMint = true;
    bool allowRedeem = true;
    bool allowBorrow = true;
    bool allowRepayBorrow = true;
    bool allowLiquidateBorrow = true;
    bool allowSeize = true;
    bool allowTransfer = true;

    bool verifyMint = true;
    bool verifyRedeem = true;
    bool verifyBorrow = true;
    bool verifyRepayBorrow = true;
    bool verifyLiquidateBorrow = true;
    bool verifySeize = true;
    bool verifyTransfer = true;

    bool failCalculateSeizeTokens;
    uint calculatedSeizeTokens;

    address public incentivesController;

    uint noError = 0;
    uint opaqueError = noError + 11; // an arbitrary, opaque error code

    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata _aTokens) external returns (uint[] memory) {
        _aTokens;
        uint[] memory ret;
        return ret;
    }

    function exitMarket(address _aToken) external returns (uint) {
        _aToken;
        return noError;
    }

    /*** Policy Hooks ***/

    function mintAllowed(address _aToken, address _minter, uint _mintAmount) public returns (uint) {
        _aToken;
        _minter;
        _mintAmount;
        return allowMint ? noError : opaqueError;
    }

    function mintVerify(address _aToken, address _minter, uint _mintAmount, uint _mintTokens) external {
        _aToken;
        _minter;
        _mintAmount;
        _mintTokens;
        require(verifyMint, "mintVerify rejected mint");
    }

    function redeemAllowed(address _aToken, address _redeemer, uint _redeemTokens) public returns (uint) {
        _aToken;
        _redeemer;
        _redeemTokens;
        return allowRedeem ? noError : opaqueError;
    }

    function redeemVerify(address _aToken, address _redeemer, uint _redeemAmount, uint _redeemTokens) external {
        _aToken;
        _redeemer;
        _redeemAmount;
        _redeemTokens;
        require(verifyRedeem, "redeemVerify rejected redeem");
    }

    function borrowAllowed(address _aToken, address _borrower, uint _borrowAmount) public returns (uint) {
        _aToken;
        _borrower;
        _borrowAmount;
        return allowBorrow ? noError : opaqueError;
    }

    function borrowVerify(address _aToken, address _borrower, uint _borrowAmount) external {
        _aToken;
        _borrower;
        _borrowAmount;
        require(verifyBorrow, "borrowVerify rejected borrow");
    }

    function repayBorrowAllowed(
        address _aToken,
        address _payer,
        address _borrower,
        uint _repayAmount) public returns (uint) {
        _aToken;
        _payer;
        _borrower;
        _repayAmount;
        return allowRepayBorrow ? noError : opaqueError;
    }

    function repayBorrowVerify(
        address _aToken,
        address _payer,
        address _borrower,
        uint _repayAmount,
        uint _borrowerIndex) external {
        _aToken;
        _payer;
        _borrower;
        _repayAmount;
        _borrowerIndex;
        require(verifyRepayBorrow, "repayBorrowVerify rejected repayBorrow");
    }

    function liquidateBorrowAllowed(
        address _aTokenBorrowed,
        address _aTokenCollateral,
        address _liquidator,
        address _borrower,
        uint _repayAmount) public returns (uint) {
        _aTokenBorrowed;
        _aTokenCollateral;
        _liquidator;
        _borrower;
        _repayAmount;
        return allowLiquidateBorrow ? noError : opaqueError;
    }

    function liquidateBorrowVerify(
        address _aTokenBorrowed,
        address _aTokenCollateral,
        address _liquidator,
        address _borrower,
        uint _repayAmount,
        uint _seizeTokens) external {
        _aTokenBorrowed;
        _aTokenCollateral;
        _liquidator;
        _borrower;
        _repayAmount;
        _seizeTokens;
        require(verifyLiquidateBorrow, "liquidateBorrowVerify rejected liquidateBorrow");
    }

    function seizeAllowed(
        address _aTokenCollateral,
        address _aTokenBorrowed,
        address _borrower,
        address _liquidator,
        uint _seizeTokens) public returns (uint) {
        _aTokenCollateral;
        _aTokenBorrowed;
        _liquidator;
        _borrower;
        _seizeTokens;
        return allowSeize ? noError : opaqueError;
    }

    function seizeVerify(
        address _aTokenCollateral,
        address _aTokenBorrowed,
        address _liquidator,
        address _borrower,
        uint _seizeTokens) external {
        _aTokenCollateral;
        _aTokenBorrowed;
        _liquidator;
        _borrower;
        _seizeTokens;
        require(verifySeize, "seizeVerify rejected seize");
    }

    function transferAllowed(
        address _aToken,
        address _src,
        address _dst,
        uint _transferTokens) public returns (uint) {
        _aToken;
        _src;
        _dst;
        _transferTokens;
        return allowTransfer ? noError : opaqueError;
    }

    function transferVerify(
        address _aToken,
        address _src,
        address _dst,
        uint _transferTokens) external {
        _aToken;
        _src;
        _dst;
        _transferTokens;
        require(verifyTransfer, "transferVerify rejected transfer");
    }

    /*** Special Liquidation Calculation ***/

    function liquidateCalculateSeizeTokens(
        address _aTokenBorrowed,
        address _aTokenCollateral,
        uint _repayAmount) public view returns (uint, uint) {
        _aTokenBorrowed;
        _aTokenCollateral;
        _repayAmount;
        return failCalculateSeizeTokens ? (opaqueError, 0) : (noError, calculatedSeizeTokens);
    }

    /**** Mock Settors ****/

    /*** Policy Hooks ***/

    function setMintAllowed(bool allowMint_) public {
        allowMint = allowMint_;
    }

    function setMintVerify(bool verifyMint_) public {
        verifyMint = verifyMint_;
    }

    function setRedeemAllowed(bool allowRedeem_) public {
        allowRedeem = allowRedeem_;
    }

    function setRedeemVerify(bool verifyRedeem_) public {
        verifyRedeem = verifyRedeem_;
    }

    function setBorrowAllowed(bool allowBorrow_) public {
        allowBorrow = allowBorrow_;
    }

    function setBorrowVerify(bool verifyBorrow_) public {
        verifyBorrow = verifyBorrow_;
    }

    function setRepayBorrowAllowed(bool allowRepayBorrow_) public {
        allowRepayBorrow = allowRepayBorrow_;
    }

    function setRepayBorrowVerify(bool verifyRepayBorrow_) public {
        verifyRepayBorrow = verifyRepayBorrow_;
    }

    function setLiquidateBorrowAllowed(bool allowLiquidateBorrow_) public {
        allowLiquidateBorrow = allowLiquidateBorrow_;
    }

    function setLiquidateBorrowVerify(bool verifyLiquidateBorrow_) public {
        verifyLiquidateBorrow = verifyLiquidateBorrow_;
    }

    function setSeizeAllowed(bool allowSeize_) public {
        allowSeize = allowSeize_;
    }

    function setSeizeVerify(bool verifySeize_) public {
        verifySeize = verifySeize_;
    }

    function setTransferAllowed(bool allowTransfer_) public {
        allowTransfer = allowTransfer_;
    }

    function setTransferVerify(bool verifyTransfer_) public {
        verifyTransfer = verifyTransfer_;
    }

    /*** Liquidity/Liquidation Calculations ***/

    function setCalculatedSeizeTokens(uint seizeTokens_) public {
        calculatedSeizeTokens = seizeTokens_;
    }

    function setFailCalculateSeizeTokens(bool shouldFail) public {
        failCalculateSeizeTokens = shouldFail;
    }

    /*** Setter for Incentives Controller ***/

    function _setIncentivesController(address newController) external returns(address) {
        incentivesController = newController;
    }
}

contract EchoTypesComptroller is UnitrollerAdminStorage {
    function stringy(string memory s) public pure returns(string memory) {
        return s;
    }

    function addresses(address a) public pure returns(address) {
        return a;
    }

    function booly(bool b) public pure returns(bool) {
        return b;
    }

    function listOInts(uint[] memory u) public pure returns(uint[] memory) {
        return u;
    }

    function reverty() public pure {
        require(false, "gotcha sucka");
    }

    function becomeBrains(address payable unitroller) public {
        Unitroller(unitroller)._acceptImplementation();
    }
}
