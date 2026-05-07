# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

# Test for CNN4IC_sky — SPI-based CNN classifier
#
# SPI pin mapping (ui_in):
#   ui_in[0] = SPI_CLK
#   ui_in[1] = SPI_CS_n
#   ui_in[2] = SPI_MOSI
#   ui_in[3] = CMD_Reset
#
# SPI commands (3-bit prefix on MOSI):
#   000 = IDLE
#   001 = LOAD IMAGE   (10 rows x 30 bits)
#   010 = LOAD WEIGHTS (5  rows x 15 bits)
#   011 = START CNN    (no payload)
#   100 = READ RESULT  (1 bit -> MISO)
#
# uo_out[0] = SPI_MISO
# uo_out[2] = done

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


SPI_CLK_BIT  = 0
SPI_CS_N_BIT = 1
SPI_MOSI_BIT = 2
SPI_MISO_BIT = 0


def spi_idle(dut):
    ui = (1 << SPI_CS_N_BIT)
    dut.ui_in.value = ui


async def spi_send_bits(dut, bits, n):
    miso_bits = []
    for i in range(n - 1, -1, -1):
        bit = (bits >> i) & 1
        ui = (0 << SPI_CS_N_BIT) | (bit << SPI_MOSI_BIT) | (0 << SPI_CLK_BIT)
        dut.ui_in.value = ui
        await Timer(50, unit="ns")
        ui |= (1 << SPI_CLK_BIT)
        dut.ui_in.value = ui
        await Timer(50, unit="ns")
        miso_bits.append((dut.uo_out.value.integer >> SPI_MISO_BIT) & 1)
        ui &= ~(1 << SPI_CLK_BIT)
        dut.ui_in.value = ui
        await Timer(50, unit="ns")
    return miso_bits


async def spi_transaction(dut, cmd, payload, payload_len):
    dut.ui_in.value = 0   # CS asserted
    await Timer(100, unit="ns")
    await spi_send_bits(dut, cmd, 3)
    miso = []
    if payload_len > 0:
        miso = await spi_send_bits(dut, payload, payload_len)
    await Timer(100, unit="ns")
    spi_idle(dut)
    await Timer(200, unit="ns")
    return miso


async def spi_read(dut, cmd, n):
    dut.ui_in.value = 0
    await Timer(100, unit="ns")
    await spi_send_bits(dut, cmd, 3)
    miso = await spi_send_bits(dut, 0, n)
    await Timer(100, unit="ns")
    spi_idle(dut)
    await Timer(200, unit="ns")
    return miso


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
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 5)

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

    # Wait for done (uo_out[2]) up to 5000 cycles
    dut._log.info("Waiting for done...")
    done = False
    for _ in range(5000):
        await ClockCycles(dut.clk, 1)
        if (dut.uo_out.value.integer >> 2) & 1:
            done = True
            break
    dut._log.info(f"Done pulse seen: {done}")

    # Check outputs have no X/Z
    assert dut.uo_out.value.is_resolvable, \
        f"uo_out has unresolved bits: {dut.uo_out.value}"

    comp = (dut.uo_out.value.integer >> 1) & 1
    dut._log.info(f"comp_result = {comp}, uo_out = {dut.uo_out.value}")
    dut._log.info("Test PASSED")
