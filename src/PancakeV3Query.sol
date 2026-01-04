//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

interface IUniswapV3PoolState {
    function liquidity() external view returns (uint128);

    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    function tickSpacing() external view returns (int24);

    function tickBitmap(int16 wordPosition) external view returns (uint256);

    function fee() external view returns (uint24);

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint32 feeProtocol, // here: uniswap v3 is uint8
            bool unlocked
        );
}

contract PancakeV3PoolQuery {
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    function getTickLiqs(address[] memory poolAddrs, bytes[] memory tickDatas)
        external
        view
        returns (bytes[] memory datas)
    {
        uint256 len = poolAddrs.length;
        datas = new bytes[](len);
        for (uint256 i; i < len; ++i) {
            datas[i] = getTickLiq(poolAddrs[i], tickDatas[i]);
        }
    }

    function getTickLiq(address poolAddr, bytes memory tickData) internal view returns (bytes memory data) {
        uint256 len;
        assembly {
            len := div(mload(tickData), 0x3)
        }
        for (uint256 i; i < len; ++i) {
            int24 tick;
            assembly {
                tick := mload(add(add(tickData, 0x3), mul(i, 0x3)))
            }
            (, int128 liquidityNet,,,,,,) = IUniswapV3PoolState(poolAddr).ticks(tick);
            data = abi.encodePacked(data, liquidityNet);
        }
    }

    function getPopulatedTicksInWords(bytes[] memory sdatas) external view returns (bytes[] memory datas) {
        uint256 len = sdatas.length;
        datas = new bytes[](len);
        for (uint256 i; i < len; ++i) {
            datas[i] = getPopulatedTicksInWord(sdatas[i]);
        }
    }

    function getPopulatedTicksInWord(bytes memory sdata) internal view returns (bytes memory data) {
        address poolAddr;
        int24 tickSpacing;
        uint8 lenAdd;
        uint8 lenSub;
        assembly {
            poolAddr := shr(96, mload(add(add(sdata, 0x20), 0x0)))
            tickSpacing := mload(add(add(sdata, 0x3), 0x14))
            lenAdd := mload(add(add(sdata, 0x1), 0x17))
            lenSub := mload(add(add(sdata, 0x1), 0x18))
        }
        (uint160 _sqrtPriceX96, int24 tick,,,,,) = IUniswapV3PoolState(poolAddr).slot0();
        uint128 liquidity = IUniswapV3PoolState(poolAddr).liquidity();
        data = abi.encodePacked(_sqrtPriceX96, liquidity, tick);
        int24 compressed = tick / tickSpacing;
        int16 wordPos = int16(compressed >> 8);
        for (uint256 i = lenSub; i > 0; --i) {
            data = abi.encodePacked(data, IUniswapV3PoolState(poolAddr).tickBitmap(wordPos - int16(i)));
        }
        data = abi.encodePacked(data, IUniswapV3PoolState(poolAddr).tickBitmap(wordPos));
        for (uint256 i = 1; i < lenAdd; ++i) {
            data = abi.encodePacked(data, IUniswapV3PoolState(poolAddr).tickBitmap(wordPos + int16(i)));
        }
    }

    function getAllTicksInWord(address poolAddr, uint32 words)
        external
        view
        returns (
            uint160 sqrtPriceX96,
            uint128 liquidity,
            int24 tickCur,
            int24[] memory ticks,
            int128[] memory liquidityNets
        )
    {
        int16 wordPos;
        int24 tickSpacing;
        IUniswapV3PoolState poolState = IUniswapV3PoolState(poolAddr);
        {
            (sqrtPriceX96, tickCur,,,,,) = poolState.slot0();
            liquidity = poolState.liquidity();
            tickSpacing = poolState.tickSpacing();
            int24 compressed = tickCur / tickSpacing;
            wordPos = int16(compressed >> 8);
        }

        uint256 numberOfTicks;
        bytes memory tickdata;
        bytes memory tickNetdata;
        {
            int16 lWordNum = -int16((words >> 16) & uint32(0xffff));
            int16 rWordNum = int16(words & uint32(0xffff));
            uint256 bitmap;

            for (int16 k = lWordNum; k <= rWordNum; ++k) {
                int16 pos = wordPos + k;
                bitmap = poolState.tickBitmap(pos);
                for (uint256 i = 0; i < 256; ++i) {
                    if (bitmap & (1 << i) > 0) {
                        int24 populatedTick = ((int24(pos) << 8) + int24(i)) * tickSpacing;
                        (, int128 liquidityNet,,,,,,) = poolState.ticks(populatedTick);
                        if (liquidityNet != 0) {
                            tickdata = abi.encodePacked(tickdata, populatedTick);
                            tickNetdata = abi.encodePacked(tickNetdata, liquidityNet);
                            numberOfTicks++;
                        }
                    }
                }
            }
        }

        ticks = new int24[](numberOfTicks);
        liquidityNets = new int128[](numberOfTicks);
        for (uint256 i; i < numberOfTicks; ++i) {
            int24 tick;
            int128 liquidityNet;
            assembly {
                let tickPos := mul(0x3, i)
                let liquidityNetPos := mul(0x10, i)
                tick := mload(add(add(tickdata, 0x3), tickPos))
                liquidityNet := mload(add(add(tickNetdata, 0x10), liquidityNetPos))
            }
            ticks[i] = tick;
            liquidityNets[i] = liquidityNet;
        }
    }

    function getAllTicksInWord2(address poolAddr, uint32 words)
        external
        view
        returns (
            uint160 sqrtPriceX96,
            uint128 liquidity,
            int24 tickCur,
            int24 tickSpacing,
            uint24 fee,
            int24[] memory ticks,
            int128[] memory liquidityNets,
            uint128[] memory liquidityGross
        )
    {
        int16 wordPos;
        IUniswapV3PoolState poolState = IUniswapV3PoolState(poolAddr);
        {
            (sqrtPriceX96, tickCur,,,,,) = poolState.slot0();
            liquidity = poolState.liquidity();
            tickSpacing = poolState.tickSpacing();
            fee = poolState.fee();
            int24 compressed = tickCur / tickSpacing;
            wordPos = int16(compressed >> 8);
        }

        int16 lWordNum;
        int16 rWordNum;
        if (words > 0) {
            lWordNum = -int16((words >> 16) & uint256(0xffff));
            rWordNum = int16(words & uint256(0xffff));
        } else {
            lWordNum = -int16((((tickCur - MIN_TICK) / tickSpacing) >> 8) + 1);
            rWordNum = int16((((MAX_TICK - tickCur) / tickSpacing) >> 8) + 1);
        }

        uint256 numberOfTicks;
        uint256 bitmap;
        int16 pos;
        {
            for (int16 k = lWordNum; k <= rWordNum; ++k) {
                pos = wordPos + k;
                bitmap = poolState.tickBitmap(pos);
                for (uint256 i; i < 256; ++i) {
                    if (bitmap & (1 << i) > 0) {
                        numberOfTicks++;
                    }
                }
            }
        }

        ticks = new int24[](numberOfTicks);
        liquidityNets = new int128[](numberOfTicks);
        liquidityGross = new uint128[](numberOfTicks);
        for (int16 k = lWordNum; k <= rWordNum; ++k) {
            pos = wordPos + k;
            bitmap = poolState.tickBitmap(pos);
            for (uint256 i; i < 256; ++i) {
                if (bitmap & (1 << i) > 0) {
                    int24 populatedTick = ((int24(pos) << 8) + int24(i)) * tickSpacing;
                    (uint128 lg, int128 liquidityNet,,,,,,) = poolState.ticks(populatedTick);
                    ticks[--numberOfTicks] = populatedTick;
                    liquidityNets[numberOfTicks] = liquidityNet;
                    liquidityGross[numberOfTicks] = lg;
                }
            }
        }
    }
}
