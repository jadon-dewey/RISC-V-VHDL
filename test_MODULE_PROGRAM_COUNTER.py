import pytest
from cocotb.binary import BinaryValue

import lib
from test_MODULES_package import MODULES
from test_GENERIC_MUX_2X1 import GENERIC_MUX_2X1
from test_GENERIC_REGISTER import GENERIC_REGISTER
from test_GENERIC_ADDER import GENERIC_ADDER


class MODULE_PROGRAM_COUNTER(lib.Entity):
    _package = MODULES

    clock = lib.Entity.Input_pin
    clear = lib.Entity.Input_pin
    enable = lib.Entity.Input_pin
    selector = lib.Entity.Input_pin
    source = lib.Entity.Input_pin
    destination = lib.Entity.Output_pin
    mret_internal = lib.Entity.Output_pin
    # New ports for interrupt handling:
    interrupt_req = lib.Entity.Input_pin
    interrupt_addr= lib.Entity.Input_pin
    mret          = lib.Entity.Input_pin

    mux_source = GENERIC_MUX_2X1
    count_register = GENERIC_REGISTER
    count_adder = GENERIC_ADDER


@MODULE_PROGRAM_COUNTER.testcase
async def tb_MODULE_PROGRAM_COUNTER_case_1(dut: MODULE_PROGRAM_COUNTER, trace: lib.Waveform):
    values_enable = ["1", "1", "1", "1", "1", "1", "1", "0"]
    values_selector = ["0", "0", "0", "1", "0", "0", "0", "1"]
    values_source = [
        "00000000000000000000000000100000",
        "00000000000000000000000000100000",
        "00000000000000000000000000100000",
        "00000000000000000000000000100000",
        "00000000000000000000000000100000",
        "00000000000000000000000000100000",
        "00000000000000000000000000100000",
        "00000000000000000000000000100000",
    ]
    values_destination = [
        "00000000000000000000000000000100",
        "00000000000000000000000000001000",
        "00000000000000000000000000001100",
        "00000000000000000000000000100000",
        "00000000000000000000000000100100",
        "00000000000000000000000000101000",
        "00000000000000000000000000101100",
        "00000000000000000000000000101100",
    ]
    
    yield trace.check(dut.destination, "00000000000000000000000000000000", f"At clock 0.")

    for index, (enable, selector, source, destination) in enumerate(
        zip(values_enable, values_selector, values_source, values_destination),
        1,
    ):
        dut.enable.value = BinaryValue(enable)
        dut.selector.value = BinaryValue(selector)
        dut.source.value = BinaryValue(source)

        await trace.cycle()
        yield trace.check(dut.destination, destination, f"At clock {index}.")

@MODULE_PROGRAM_COUNTER.testcase
async def tb_MODULE_PROGRAM_COUNTER_interrupt(dut: MODULE_PROGRAM_COUNTER, trace: lib.Waveform):
    """
    Test the interrupt functionality of the program counter:
      1. Verify normal operation when no interrupt is active.
      2. Assert an interrupt and check that the PC jumps to interrupt_addr.
      3. Simulate a return-from-interrupt (mret) and verify the PC is restored.
    """
    # --- Step 1: Reset and run in normal mode ---
    dut.clear.value = BinaryValue("1")
    await trace.cycle()
    dut.clear.value = BinaryValue("0")
    
    # Drive normal operation: selector '0' selects PC+4; provide a branch jump (or any normal address).
    dut.selector.value = BinaryValue("0")
    dut.source.value = BinaryValue("00000000000000000000000000001000")  # For instance, 8 in decimal.
    dut.enable.value = BinaryValue("1")
    # Make sure no interrupt is active.
    dut.interrupt_req.value = BinaryValue("0")
    dut.interrupt_addr.value = BinaryValue("00000000000000000000000000000000")
    dut.mret.value = BinaryValue("0")
    
    # Let one clock cycle pass so the PC updates.
    await trace.cycle()
    # Capture the current PC (should be the result of normal operation).
    normal_pc_value = dut.destination.value.binstr
    
    # Check that the destination equals the normal jump value.
    yield trace.check(dut.destination, "00000000000000000000000000000100", 
                      "Normal operation: PC should equal address_jump (or normal operation value).")
    
    # --- Step 2: Trigger an interrupt ---
    # Provide a distinct interrupt address.
    dut.interrupt_addr.value = BinaryValue("00000000000000000000010000000000")  # 400 in binary
    dut.interrupt_req.value = BinaryValue("1")
    
    await trace.cycle()
    
    # Now, the PC should load the interrupt address.
    yield trace.check(dut.destination, "00000000000000000000010000000000", 
                      "Interrupt operation: PC should equal interrupt_addr when interrupt_req is high.")
    
    # --- Step 3: Return from interrupt ---
    # Deassert the interrupt, assert mret for one cycle to simulate return.
    await trace.cycle()
    dut.interrupt_req.value = BinaryValue("0")
    #dut.mret.value = BinaryValue("1")
    
    await trace.cycle()
    await trace.cycle()
    
    #dut.mret.value = BinaryValue("0")
    
    # The PC should restore to the normal value that was saved (here we expect it to be the previous normal_pc).
    yield trace.check(dut.destination, normal_pc_value, 
                      "Return-from-interrupt: PC should restore to the saved normal value after mret.")

    for _ in range(6):
        await trace.cycle()


@pytest.mark.synthesis
def test_MODULE_PROGRAM_COUNTER_synthesis():
    MODULE_PROGRAM_COUNTER.build_vhd()
    MODULE_PROGRAM_COUNTER.build_netlistsvg()

@pytest.mark.testcases
def test_MODULE_PROGRAM_COUNTER_testcases():
    MODULE_PROGRAM_COUNTER.test_with(tb_MODULE_PROGRAM_COUNTER_case_1)

@pytest.mark.testcases
def test_MODULE_PROGRAM_COUNTER_testcases_2():
    MODULE_PROGRAM_COUNTER.test_with(tb_MODULE_PROGRAM_COUNTER_interrupt)


if __name__ == "__main__":
    lib.run_test(__file__)
