import warnings
# Catch the warning so the testing/validation process can run smoothly
warnings.filterwarnings(
    "ignore",
    message=".*Python runners and associated APIs are an experimental feature and subject to change.*", # Insert a try-and-catch statement
    category=UserWarning
)

import pytest

import lib
from test_CPU_package import CPU
from test_MODULE_PROGRAM_COUNTER import MODULE_PROGRAM_COUNTER

from cocotb.binary import BinaryValue
from cocotb.triggers import RisingEdge
import lib
from lib.utils import to_binstr as b

class CPU_STAGE_IF(lib.Entity):
    _package = CPU

    clock = lib.Entity.Input_pin
    clear = lib.Entity.Input_pin
    enable = lib.Entity.Input_pin
    source = lib.Entity.Input_pin
    address_jump = lib.Entity.Input_pin
    address_program = lib.Entity.Output_pin

    # New ports for interrupt handling
    interrupt_req   = lib.Entity.Input_pin
    interrupt_addr  = lib.Entity.Input_pin
    mret            = lib.Entity.Input_pin

    program_counter = MODULE_PROGRAM_COUNTER

@CPU_STAGE_IF.testcase
async def tb_CPU_STAGE_IF_interrupt(dut: CPU_STAGE_IF, trace: lib.Waveform):
    # Reset the system:
    dut.clear.value = BinaryValue("1")
    await trace.cycle()
    dut.clear.value = BinaryValue("0")
    
    # Normal mode: drive a branch jump.
    dut.enable.value = BinaryValue("1")
    dut.interrupt_req.value = BinaryValue("0")
    dut.address_jump.value = BinaryValue("00000000000000000000000000001000")  # e.g., 8 in decimal
    dut.interrupt_addr.value = BinaryValue("00000000000000000000000000000000")
    dut.mret.value = BinaryValue("0")
    
    # Wait one clock cycle for the PC register to update.
    await trace.cycle()
    
    # Check that, in normal mode, the PC output equals address_jump.
    yield trace.check(dut.address_program, "00000000000000000000000000001000",
                      "Normal operation: address_program should equal address_jump.")
    
    # Now, simulate an interrupt condition.
    dut.interrupt_req.value = BinaryValue("1")
    dut.interrupt_addr.value = BinaryValue("00000000000000000000010000000000")  # e.g., 0x1000
    # Wait one clock cycle for the PC register to capture the interrupt address.
    await trace.cycle()
    
    # Check that the PC now equals the interrupt address.
    yield trace.check(dut.address_program, "00000000000000000000010000000000",
                      "Interrupt operation: address_program should equal interrupt_addr when interrupt_req is high.")
    
    # Simulate a return-from-interrupt (mret)
    dut.interrupt_req.value = BinaryValue("0")
    dut.mret.value = BinaryValue("1")
    await trace.cycle()
    dut.mret.value = BinaryValue("0")
    await trace.cycle()
    
    # Here, depending on your PC module’s context-saving, check the restored value.
    # For example, if you expect it to return to the branch jump value:
    yield trace.check(dut.address_program, "00000000000000000000000000001000",
                      "Return-from-interrupt: PC should restore to previous value.")
    
@pytest.mark.synthesis
def test_CPU_STAGE_IF_synthesis():
    CPU_STAGE_IF.build_vhd()
    CPU_STAGE_IF.build_netlistsvg()

@pytest.mark.testcases
def test_CPU_STAGE_IF_testcase():
    CPU_STAGE_IF.test_with(tb_CPU_STAGE_IF_interrupt)

if __name__ == "__main__":
    lib.run_test(__file__)
