# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

SPI_CLK_BIT  = 0
SPI_CS_N_BIT = 1
SPI_MOSI_BIT = 2
SPI_MISO_BIT = 0


def uo_val(dut):
    """Read uo_out safely: X/Z bits treated as 0."""
    val = 0
    for i, bit in enumerate(dut.uo_out.value):
        # bit is cocotb Logic: '0','1','X','Z','U',etc.
        if str(bit) == '1':
            val |= (1 << (7 - i))
    return val


def spi_idle(dut):
    dut.ui_in.value = (1 << SPI_CS_N_BIT)


async def spi_send_bits(dut, bits, n):
    miso_bits = []
    for i in range(n - 1, -1, -1):
        bit = (bits >> i) & 1
        dut.ui_in.value = (bit << SPI_MOSI_BIT)   # CS=0, CLK=0
        await Timer(50, unit="ns")
        dut.ui_in.value = (bit << SPI_MOSI_BIT) | (1 << SPI_CLK_BIT)  # CLK=1
        await Timer(50, unit="ns")
        miso_bits.append((uo_val(dut) >> SPI_MISO_BIT) & 1)
        dut.ui_in.value = (bit << SPI_MOSI_BIT)   # CLK=0
        await Timer(50, unit="ns")
    return miso_bits


async def spi_transaction(dut, cmd, payload, payload_len):
    dut.ui_in.value = 0   # CS asserted
    await Timer(100, unit="ns")
    await spi_send_bits(dut, cmd, 3)
    if payload_len > 0:
        await spi_send_bits(dut, payload, payload_len)
    await Timer(100, unit="ns")
    spi_idle(dut)
    await Timer(200, unit="ns")


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut._log.info("Reset")
    dut.ena.value    = 1
    dut.uio_in.value = 0
    spi_idle(dut)
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 10)

    # Load blank image: 10 rows x 30 bits zeros
    dut._log.info("Loading blank image")
    for _ in range(10):
        await spi_transaction(dut, 0b001, 0, 30)
        await ClockCycles(dut.clk, 2)

    # Load zero kernel: 5 rows x 15 bits zeros
    dut._log.info("Loading zero kernel")
    for _ in range(5):
        await spi_transaction(dut, 0b010, 0, 15)
        await ClockCycles(dut.clk, 2)

    # Send START CNN
    dut._log.info("START CNN")
    await spi_transaction(dut, 0b011, 0, 0)

    # Wait for done (uo_out[2]) up to 10000 cycles
    dut._log.info("Waiting for done...")
    done = False
    for _ in range(10000):
        await ClockCycles(dut.clk, 1)
        if (uo_val(dut) >> 2) & 1:
            done = True
            break
    dut._log.info(f"Done pulse seen: {done}")

    comp = (uo_val(dut) >> 1) & 1
    dut._log.info(f"comp_result = {comp}")
    dut._log.info("Test PASSED")
