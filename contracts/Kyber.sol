pragma solidity ^0.6.0;

enum TradeType {BestOfAll, MaskIn, MaskOut, Split}
interface IERC20Token {
	function decimals() external pure returns (uint8);
}

interface KyberProxy {
	function getExpectedRate(IERC20Token _from, IERC20Token _to, uint256 _amount) external view returns(uint256, uint256);
    function getExpectedRateAfterFee(
        IERC20Token src,
        IERC20Token dest,
        uint256 srcQty,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external view returns (uint256 expectedRate);
}

// interface KyberExpected {
// 	function getExpectedRate(IERC20Token _from, IERC20Token _to, uint256 _amount, bool _usePermissionless) external view returns(uint256, uint256);
// }

interface IKyberStorage {
    function getReserveIdsPerTokenSrc(IERC20Token token)
        external
        view
        returns (bytes32[] memory reserveIds);
    function getReserveIdsPerTokenDest(IERC20Token token)
        external
        view
        returns (bytes32[] memory reserveIds);
}

interface IKyberReserve {
    function trade(
        IERC20Token srcToken,
        uint256 srcAmount,
        IERC20Token destToken,
        address payable destAddress,
        uint256 conversionRate,
        bool validate
    ) external payable returns (bool);

    function getConversionRate(
        IERC20Token src,
        IERC20Token dest,
        uint256 srcQty,
        uint256 blockNumber
    ) external view returns (uint256);
}

interface IKyberHint {
    function buildTokenToEthHint(
        IERC20Token tokenSrc,
        TradeType tokenToEthType,
        bytes32[] calldata tokenToEthReserveIds,
        uint256[] calldata tokenToEthSplits
    ) external view returns (bytes memory hint);

    function buildEthToTokenHint(
        IERC20Token tokenDest,
        TradeType ethToTokenType,
        bytes32[] calldata ethToTokenReserveIds,
        uint256[] calldata ethToTokenSplits
    ) external view returns (bytes memory hint);
}

contract KyberPrice {
	KyberProxy private proxy = KyberProxy(0x9AAb3f75489902f3a48495025729a0AF77d4b11e);
	IERC20Token private etherToken = IERC20Token(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IKyberHint private kyberHintBuilder = IKyberHint(0xa1C0Fa73c39CFBcC11ec9Eb1Afc665aba9996E2C);
    IKyberStorage kyberStorage = IKyberStorage(0xC8fb12402cB16970F3C5F4b48Ff68Eb9D1289301);
	// KyberExpected private expected = KyberExpected(0x38a5CF926A0b9B5fE3A265C57D184aD8c0AF05b6);

	function getOutputAmount(IERC20Token _from, IERC20Token _to, uint256 _amount) internal view returns (uint256) {
        bytes32[] memory reserveIds;
        uint256[] memory emptySplits;
        bytes memory hint;
        if (_from == etherToken) {
            reserveIds = kyberStorage.getReserveIdsPerTokenDest(_to);
            hint = kyberHintBuilder.buildEthToTokenHint(_to, TradeType.MaskOut, reserveIds, emptySplits);
        } else {
            reserveIds = kyberStorage.getReserveIdsPerTokenSrc(_from);
            hint = kyberHintBuilder.buildTokenToEthHint(_from, TradeType.MaskOut, reserveIds, emptySplits);
        }
		uint256 expectedRate = proxy.getExpectedRateAfterFee(_from, _to, _amount, 0, hint);
		uint256 defaultMultiplier = getMultiplier(etherToken);
		uint256 fromMultiplier = getMultiplier(_from);
		uint256 toMultiplier = getMultiplier(_to);
		uint256 amount = (expectedRate * toMultiplier * _amount) / (defaultMultiplier * fromMultiplier);
		return amount;
	}

	function getInputAmount(IERC20Token _from, IERC20Token _to, uint256 _amount) internal view returns (uint256) {
		uint256 initialAmount = getMultiplier(_from);
		uint256 initialReturn = getOutputAmount(_from, _to, initialAmount);
		if (initialReturn == 0) {
			return 0;
		}
		uint256 initialCost = _amount * initialAmount / initialReturn;
		uint256 finalReturn = getOutputAmount(_from, _to, initialCost);
		if (finalReturn == 0) {
			return 0;
		}
		return _amount * initialCost / finalReturn;
	}

	function getMultiplier(IERC20Token _token) private view returns(uint256) {
		return 10 ** getDecimals(_token);
	}

	function getDecimals(IERC20Token _token) private view returns(uint256) {
		if (_token == etherToken) {
			return 18;
		}
		return _token.decimals();
	}
}

contract KyberRatesOracle is KyberPrice {
	function getOutputAmounts(IERC20Token _from, IERC20Token _to, uint256[100] memory _amounts) public view returns (uint256[100] memory amounts) {
        for (uint256 i = 0; i < _amounts.length; i++) {
			amounts[i] = getOutputAmount(_from, _to, _amounts[i]);
		}
	}

	function getInputAmounts(IERC20Token _from, IERC20Token _to, uint256[100] memory _amounts) public view returns (uint256[100] memory amounts) {
		for (uint256 i = 0; i < _amounts.length; i++) {
			amounts[i] = getInputAmount(_from, _to, _amounts[i]);
		}
	}
}