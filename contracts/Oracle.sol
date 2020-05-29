pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IERC20Token {
	function balanceOf(address) external pure returns (uint256);
}

interface UniswapFactory {
    function getExchange(IERC20Token) external pure returns (address);
}

interface BancorConverter {
    struct tokenInfo {
        uint256 virtualBalance;
        uint32 ratio;
        bool isVirtualBalanceEnabled;
        bool isSaleEnabled;
        bool isSet;
    }

    function connectors(IERC20Token) external pure returns (tokenInfo memory);
    function conversionFee() external pure returns (uint32);
}

interface BalancerPool {
    struct balancerToken {
        address token;
        bool isBound;   // is token bound to pool
        uint index;
        uint denorm;  // denormalized weight
        uint balance;
    }
    struct balancerData {
        address pool;
        balancerToken[] tokens;
        uint fee;
    }

    function isPublicSwap() external view returns (bool);
    function isFinalized() external view returns (bool);
    function isBound(address t) external view returns (bool);
    function getFinalTokens() external view returns (address[] memory tokens);
    function getDenormalizedWeight(address token) external view returns (uint);
    function getBalance(address token) external view returns (uint);
    function getSwapFee() external view returns (uint);
}

interface SynthetixDepot {
    function totalSellableDeposits() external pure returns (uint256);
}

interface SynthetixRates {
    function rateForCurrency(bytes32) external pure returns (uint256);
}

interface CurveExchange {
    function balances(int128) external pure returns (uint256);
    function A() external pure returns (uint256);
}

interface BalancerExchange {
    function pools(int128) external pure returns (uint256);
}

interface yToken {
    function getPricePerFullShare() external pure returns (uint256);
}

interface MatchingMarket {
    function offers(uint256 id) external view returns(uint256 pay_amt, address pay_gem, uint256 buy_amt, address buy_gem, address owner, uint64 timestamp);
    function getOfferCount(address base, address quote) external view returns(uint256 count);
    function getBestOffer(address base, address quote) external view returns(uint256 id);
    function getWorseOffer(uint256 id) external view returns(uint256 worseOfferId);
}

interface cToken {
    function exchangeRateStored() external pure returns (uint256);
}

interface OptionsFactory {
    function getNumberOfOptionsContracts() external pure returns (uint256);
    function optionsContracts(uint256) external pure returns(address);
}

interface oToken {
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function expiry() external pure returns (uint256);
}

contract Oracle {
    struct uniswapData {
        uint256 tokenBalance;
        uint256 ethBalance;
    }
    UniswapFactory public uniFactory = UniswapFactory(0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95);
    function getUniswapData(IERC20Token[] memory tokens) public view returns (uniswapData[] memory) {
        uint256 length = tokens.length;
		uniswapData[] memory data = new uniswapData[](length);
		for (uint256 i = 0; i < length; ++i) {
            IERC20Token token = tokens[i];
            address exchange = uniFactory.getExchange(token);
			uint256 tokenBalance = token.balanceOf(exchange);
			uint256 ethBalance = exchange.balance;
            data[i] = uniswapData({
                tokenBalance: tokenBalance,
                ethBalance: ethBalance
            });
		}
		return data;
	}

    struct bancorData {
        uint32 eWeight;
        uint32 tWeight;
        uint32 tFee;
        uint256 tBalance;
        uint256 eBalance;
    }
    IERC20Token public BNT = IERC20Token(0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C);
    function getBancorData(IERC20Token[] memory tokens, BancorConverter[] memory converters) public view returns (bancorData[] memory) {
        uint256 length = tokens.length;
        bancorData[] memory data = new bancorData[](length);
        for (uint256 i = 0; i < length; ++i) {
            BancorConverter converter = converters[i];
            BancorConverter.tokenInfo memory info = converter.connectors(tokens[i]);
            uint32 eWeight = info.ratio;
            uint32 tWeight = 1000000 - eWeight;
            uint32 tFee = converter.conversionFee();
            uint256 tBalance = tokens[i].balanceOf(address(converter));
            uint256 eBalance = BNT.balanceOf(address(converter));
            data[i] = bancorData({
                eWeight: eWeight,
                tWeight: tWeight,
                tFee: tFee,
                tBalance: tBalance,
                eBalance: eBalance
            });
        }
        return data;
    }


    function getBalancerData(BalancerPool[] memory pools) public view returns (BalancerPool.balancerData[] memory) {
        uint256 length = pools.length;
        BalancerPool.balancerData[] memory data = new BalancerPool.balancerData[](length);
        for (uint256 i = 0; i < length; ++i) {
            address pool = address(pools[i]);
            BalancerPool BP = BalancerPool(pool);
            bool isPublicSwap = BP.isPublicSwap();
            bool isFinalized = BP.isFinalized();
            // Token allows for public swap and pool creation is finalized
            if (isPublicSwap && isFinalized) {
                address[] memory balancerTokens = BP.getFinalTokens();
                BalancerPool.balancerToken[] memory tokenData = new BalancerPool.balancerToken[](balancerTokens.length);
                for (uint256 j = 0; j < balancerTokens.length; ++j) {
                    address token = balancerTokens[j];
                    bool isBound = BP.isBound(token);   // is token bound to pool
                    uint denorm = BP.getDenormalizedWeight(token);  // denormalized weight
                    uint balance = BP.getBalance(token);
                    tokenData[j] = BalancerPool.balancerToken({
                        token: token,
                        isBound: isBound,
                        index: j,
                        denorm: denorm,
                        balance: balance
                    });
                }
                uint fee = BP.getSwapFee();
                data[i] = BalancerPool.balancerData({
                    pool: pool,
                    tokens: tokenData,
                    fee: fee
                });

            }
        }
        return data;
    }

    struct synthetixData {
        uint256 rate;
        uint256 balance;
    }
    SynthetixDepot public Depot = SynthetixDepot(0xE1f64079aDa6Ef07b03982Ca34f1dD7152AA3b86);
    SynthetixRates public Rates = SynthetixRates(0x9D7F70AF5DF5D5CC79780032d47a34615D1F1d77);
    function getSynthetixData() public view returns (synthetixData memory) {
        bytes32 ethKey = 0x4554480000000000000000000000000000000000000000000000000000000000;
        uint256 rate = Rates.rateForCurrency(ethKey);
        uint256 balance = Depot.totalSellableDeposits();
        return synthetixData({
            rate: rate,
            balance: balance
        });
    }

    struct curveData {
        uint256 balance;
        uint256 pricePerShare;
        uint256 A;
    } 
    CurveExchange public Exchange = CurveExchange(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    function getCurveData(int128[] memory ids, yToken[] memory tokens) public view returns (curveData[] memory) {
        uint256 length = ids.length;
        curveData[] memory data = new curveData[](length);
        for (uint256 i = 0; i < length; ++i) {
            uint256 balance = Exchange.balances(ids[i]);
            uint256 pricePerShare = tokens[i].getPricePerFullShare();
            uint256 A = Exchange.A();
            data[i] = curveData({
                balance: balance,
                pricePerShare: pricePerShare,
                A: A
            });
        }
        return data;
    }

    struct curveSusdData {
        uint256 balance;
        uint256 A;
    } 
    CurveExchange public SusdExchange = CurveExchange(0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
    function getCurveSusdData(int128[] memory ids) public view returns (curveSusdData[] memory) {
        uint256 length = ids.length;
        curveSusdData[] memory data = new curveSusdData[](length);
        for (uint256 i = 0; i < length; ++i) {
            uint256 balance = SusdExchange.balances(ids[i]);
            uint256 A = SusdExchange.A();
            data[i] = curveSusdData({
                balance: balance,
                A: A
            });
        }
        return data;
    }

    struct Offer {
        uint256 id;
        address maker;
        uint256 makerAmount;
        uint256 takerAmount;
    }

    struct oasisData {
        Offer[] bids;
        Offer[] asks;
    }
    MatchingMarket oasisMarket = MatchingMarket(0x794e6e91555438aFc3ccF1c5076A74F42133d08D);

    function getOasisData(address[] memory bases, address[] memory quotes) public view returns (oasisData[] memory) {
        uint256 length = bases.length;
        oasisData[] memory data = new oasisData[](length);
        for (uint256 i = 0; i < length; ++i) {
            (Offer[] memory bids, Offer[] memory asks) = getOrderBook(bases[i], quotes[i]);
            data[i] = oasisData({
                bids: bids,
                asks: asks
            });
        }
        return data;
    }

    function getOrderBook(address base, address quote) public view returns(Offer[] memory bids, Offer[] memory asks) {
        uint256 offerId;
        uint256 bidCount = oasisMarket.getOfferCount(quote, base);
        if (bidCount == 0) {
            bids = new Offer[](1);
            bids[0] = Offer({
                id: 0,
                maker: 0x0000000000000000000000000000000000000000,
                makerAmount: 0,
                takerAmount: 0
            });
        } else {
            bids = new Offer[](bidCount);
            offerId = oasisMarket.getBestOffer(quote, base);
            bids[0] = getOffer(offerId);
            for (uint256 i = 1; i < bidCount; i++) {
                offerId = oasisMarket.getWorseOffer(offerId);
                bids[i] = getOffer(offerId);
            }
        }

        uint256 askCount = oasisMarket.getOfferCount(base, quote);
        if (askCount == 0) {
            asks = new Offer[](1);
            asks[0] = Offer({
                id: 0,
                maker: 0x0000000000000000000000000000000000000000,
                makerAmount: 0,
                takerAmount: 0
            });
        } else {
            asks = new Offer[](askCount);
            offerId = oasisMarket.getBestOffer(base, quote);
            asks[0] = getOffer(offerId);
            for (uint256 i = 1; i < askCount; i++) {
                offerId = oasisMarket.getWorseOffer(offerId);
                asks[i] = getOffer(offerId);
            }
        }
    }

        
    function getOffer(uint256 id) private view returns(Offer memory offer) {
        (uint256 pay_amt, , uint256 buy_amt, , address owner, ) = oasisMarket.offers(id);
        offer = Offer(id, owner, pay_amt, buy_amt);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function getCompoundData(cToken[] memory tokens) public view returns (uint256[] memory) {
        uint256 length = tokens.length;
		uint256[] memory data = new uint256[](length);
		for (uint256 i = 0; i < length; ++i) {
			uint256 rate = tokens[i].exchangeRateStored();
            data[i] = rate;
		}
		return data;
    }

    struct opynData {
        address oTokenAddress;
        string name;
        string symbol;
        uint256 expiry;
    }

    OptionsFactory public opynFactory = OptionsFactory(0xcC5d905b9c2c8C9329Eb4e25dc086369D6C7777C);
    function getOpynData() public view returns (opynData[] memory) {
        uint256 numOTokens = opynFactory.getNumberOfOptionsContracts();
        opynData[] memory data = new opynData[](numOTokens);

        for (uint256 i = 0; i < numOTokens; i++) {
            address token = opynFactory.optionsContracts(i);
            oToken o = oToken(token);
            uint256 expiry = o.expiry();
            if (now < expiry) {
                string memory name = o.name();
                string memory symbol = o.symbol();

                data[i] = opynData({
                    oTokenAddress: token,
                    name: name,
                    symbol: symbol,
                    expiry: expiry
                });
            }
        }

        return data;
    }
}